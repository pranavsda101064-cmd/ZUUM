"""Wallet, payments (mock gateway), promos and referrals."""
from __future__ import annotations

import uuid

from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.api.serializers import (
    PaymentSerializer,
    PromoSerializer,
    ReferralSerializer,
    WalletSerializer,
    WalletTransactionSerializer,
)
from apps.bookings.models import Booking
from apps.catalog.models import PromoCampaign
from apps.catalog.services import ensure_referral, validate_promo
from apps.core.exceptions import ApiError
from apps.payments.models import Payment, WalletTransaction
from apps.payments.services import (
    apply_wallet_txn,
    ensure_wallet,
    mark_payment_paid,
)


class PaymentMethodsView(APIView):
    serializer_class = PaymentSerializer
    def get(self, request):
        wallet = ensure_wallet(request.user)
        return Response(
            [
                {"method": "cash", "available": True, "label": "Cash"},
                {"method": "upi", "available": True, "label": "UPI"},
                {"method": "card", "available": True, "label": "Card"},
                {
                    "method": "wallet",
                    "available": wallet.balance_paise > 0,
                    "label": "Zuum wallet",
                    "balance_paise": wallet.balance_paise,
                },
            ]
        )


class PaymentOrderView(APIView):
    serializer_class = PaymentSerializer
    def post(self, request):
        booking_id = request.data.get("booking_id")
        amount = int(request.data.get("amount_paise") or 0)
        booking = Booking.objects.filter(pk=booking_id, customer=request.user).first()
        if booking is None:
            raise ApiError("Booking not found", code="not_found", status_code=404)
        if amount <= 0:
            raise ApiError(
                "Amount must be positive", code="validation_error", status_code=400
            )
        payment = Payment.objects.create(
            booking=booking,
            method=booking.payment_method,
            amount_paise=amount,
            gateway_order_id=f"order_mock_{uuid.uuid4().hex[:16]}",
        )
        booking.payment_state = Booking.PaymentState.AUTHORIZED
        booking.save(update_fields=["payment_state", "updated_at"])
        return Response(
            {
                "order_id": payment.gateway_order_id,
                "amount_paise": payment.amount_paise,
                "currency": "INR",
                "booking_id": str(booking.id),
                "key_id": "rzp_test_mock",
            },
            status=status.HTTP_201_CREATED,
        )


class PaymentVerifyView(APIView):
    serializer_class = PaymentSerializer
    def post(self, request):
        booking_id = request.data.get("booking_id")
        order_id = request.data.get("razorpay_order_id") or request.data.get("order_id")
        booking = Booking.objects.filter(pk=booking_id, customer=request.user).first()
        if booking is None:
            raise ApiError("Booking not found", code="not_found", status_code=404)
        payment = (
            Payment.objects.filter(booking=booking, gateway_order_id=order_id)
            .order_by("-created_at")
            .first()
        )
        if payment is None:
            raise ApiError(
                "Payment order not found", code="not_found", status_code=404
            )
        payment.gateway_payment_id = (
            request.data.get("razorpay_payment_id") or f"pay_mock_{uuid.uuid4().hex[:12]}"
        )
        payment.gateway_signature = request.data.get("razorpay_signature") or ""
        payment = mark_payment_paid(payment)
        return Response(PaymentSerializer(payment).data)


class WalletView(APIView):
    serializer_class = WalletSerializer
    def get(self, request):
        return Response(WalletSerializer(ensure_wallet(request.user)).data)


class WalletTransactionsView(APIView):
    serializer_class = WalletTransactionSerializer
    def get(self, request):
        wallet = ensure_wallet(request.user)
        qs = wallet.transactions.order_by("-created_at")
        page = max(1, int(request.query_params.get("page", 1) or 1))
        size = max(1, min(100, int(request.query_params.get("page_size", 20) or 20)))
        total = qs.count()
        items = qs[(page - 1) * size : page * size]
        return Response(
            {
                "count": total,
                "next": (
                    request.build_absolute_uri(f"?page={page + 1}")
                    if page * size < total
                    else None
                ),
                "previous": None,
                "results": WalletTransactionSerializer(items, many=True).data,
            }
        )


class WalletTopupView(APIView):
    serializer_class = WalletTransactionSerializer
    """Mock gateway top-up: credits immediately, ledgered for the demo."""

    def post(self, request):
        amount = int(request.data.get("amount_paise") or 0)
        if amount <= 0:
            raise ApiError(
                "Amount must be positive", code="validation_error", status_code=400
            )
        wallet = ensure_wallet(request.user)
        txn = apply_wallet_txn(
            wallet=wallet,
            kind=WalletTransaction.Kind.TOPUP,
            amount_paise=amount,
            reference=f"order_mock_{uuid.uuid4().hex[:16]}",
            note="Wallet top-up (mock gateway)",
        )
        return Response(
            {
                "balance_paise": txn.balance_after,
                "currency": wallet.currency,
                "transaction": WalletTransactionSerializer(txn).data,
            },
            status=status.HTTP_201_CREATED,
        )


class ActivePromosView(APIView):
    serializer_class = PromoSerializer
    def get(self, request):
        now = timezone.now()
        promos = PromoCampaign.objects.filter(is_active=True).filter(
            models_valid(now)
        ).order_by("-created_at")[:20]
        return Response(PromoSerializer(promos, many=True).data)


def models_valid(now):
    from django.db.models import Q

    return Q(valid_from__isnull=True) | Q(valid_from__lte=now)


class ValidatePromoView(APIView):
    serializer_class = PromoSerializer
    def post(self, request):
        from apps.catalog.models import ServiceCategory

        code = (request.data.get("code") or "").strip()
        fare = int(request.data.get("fare_paise") or 0)
        category = ServiceCategory.objects.filter(
            code=request.data.get("service_category")
        ).first()
        if category is None:
            raise ApiError(
                "Unknown service category", code="validation_error", status_code=400
            )
        promo, discount = validate_promo(
            code=code, fare_paise=fare, category=category, customer=request.user
        )
        return Response(
            {
                "code": promo.code,
                "discount_paise": discount,
                "fare_paise": fare,
                "payable_paise": max(0, fare - discount),
            }
        )


class ReferralMeView(APIView):
    serializer_class = ReferralSerializer
    def get(self, request):
        referral = ensure_referral(request.user)
        return Response(ReferralSerializer(referral).data)
