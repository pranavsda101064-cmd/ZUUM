"""Consumer booking endpoints (create, list, detail, lifecycle companions)."""
from __future__ import annotations

from django.db import models
from django.db.models import Avg, Count
from django.utils import timezone
from rest_framework import status
from rest_framework.generics import ListAPIView
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.api.serializers import (
    BookingCreateSerializer,
    BookingSerializer,
    ReviewSerializer,
)
from apps.bookings.models import Booking, FareQuote, LocationPing, Review
from apps.bookings.services import (
    cancel_booking,
    create_booking,
    haversine_m,
)
from apps.core.exceptions import ApiError


def _booking_for(user, booking_id) -> Booking:
    booking = (
        Booking.objects.filter(pk=booking_id)
        .select_related("service_category", "customer")
        .prefetch_related("offers__driver__user", "offers__vehicle__category", "history")
        .first()
    )
    if booking is None or booking.customer_id != user.id:
        raise ApiError("Booking not found", code="not_found", status_code=404)
    return booking


class BookingListCreateView(APIView):
    serializer_class = BookingSerializer
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "bookings_write"

    def get(self, request):
        qs = (
            Booking.objects.filter(customer=request.user)
            .select_related("service_category")
            .prefetch_related("offers__driver__user", "offers__vehicle__category", "history")
            .order_by("-created_at")
        )
        status_filter = request.query_params.get("status")
        if status_filter:
            qs = qs.filter(status=status_filter.upper())
        page = int(request.query_params.get("page", 1) or 1)
        page_size = int(request.query_params.get("page_size", 20) or 20)
        page_size = max(1, min(page_size, 100))
        total = qs.count()
        start = (page - 1) * page_size
        items = qs[start : start + page_size]
        next_url = (
            request.build_absolute_uri(f"?page={page + 1}&page_size={page_size}")
            if start + page_size < total
            else None
        )
        return Response(
            {
                "count": total,
                "next": next_url,
                "previous": None,
                "results": BookingSerializer(items, many=True).data,
            }
        )

    def post(self, request):
        serializer = BookingCreateSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        quote = FareQuote.objects.filter(
            pk=data["quote_id"], customer=request.user
        ).first()
        if quote is None:
            raise ApiError(
                "Quote not found or already used",
                code="not_found",
                status_code=404,
            )
        if quote.valid_until < timezone.now():
            raise ApiError(
                "Quote expired, request a fresh fare",
                code="quote_expired",
                status_code=409,
            )
        booking = create_booking(customer=request.user, quote=quote, payload=data)
        booking.refresh_from_db()
        booking = (
            Booking.objects.filter(pk=booking.pk)
            .select_related("service_category")
            .prefetch_related("offers__driver__user", "offers__vehicle__category", "history")
            .first()
        )
        return Response(
            BookingSerializer(booking).data, status=status.HTTP_201_CREATED
        )


class BookingDetailView(APIView):
    serializer_class = BookingSerializer
    def get(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        return Response(BookingSerializer(booking).data)


class BookingCancelView(APIView):
    serializer_class = BookingSerializer
    def post(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        reason = (request.data.get("reason") or "").strip()
        if not reason:
            raise ApiError(
                "A cancellation reason is required",
                code="validation_error",
                status_code=400,
            )
        cancel_booking(
            booking, by="customer", actor_id=request.user.id, reason=reason
        )
        return Response(BookingSerializer(booking).data)


class BookingRateView(APIView):
    serializer_class = ReviewSerializer
    def post(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        if booking.status != Booking.Status.COMPLETED:
            raise ApiError(
                "You can only rate completed trips",
                code="illegal_transition",
                status_code=409,
            )
        rating = int(request.data.get("rating") or 0)
        if not 1 <= rating <= 5:
            raise ApiError(
                "Rating must be between 1 and 5",
                code="validation_error",
                status_code=400,
            )
        offer = booking.offers.filter(status="accepted").select_related("driver__user").first()
        reviewee = offer.driver.user if offer else None
        review, created = Review.objects.update_or_create(
            booking=booking,
            reviewer=request.user,
            defaults={
                "reviewer_role": Review.ReviewerRole.CUSTOMER,
                "reviewee": reviewee,
                "rating": rating,
                "comment": request.data.get("comment") or "",
                "tags": request.data.get("tags") or [],
            },
        )
        if reviewee is not None and offer is not None:
            stats = Review.objects.filter(reviewee=reviewee).aggregate(
                avg=Avg("rating"), count=Count("id")
            )
            driver = offer.driver
            driver.rating_avg = round(float(stats["avg"] or 0), 2)
            driver.rating_count = stats["count"] or 0
            driver.save(update_fields=["rating_avg", "rating_count"])
        return Response(
            ReviewSerializer(review).data,
            status=status.HTTP_201_CREATED if created else status.HTTP_200_OK,
        )


class BookingReceiptView(APIView):
    serializer_class = BookingSerializer
    def get(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        quote = booking.quotes.order_by("-created_at").first()
        commission = getattr(booking, "commission", None)
        return Response(
            {
                "booking_id": str(booking.id),
                "type": booking.type,
                "status": booking.status,
                "service_category": booking.service_category.name,
                "pickup": booking.pickup_address,
                "drop": booking.drop_address,
                "distance_m": booking.distance_m,
                "duration_s": booking.duration_s,
                "fare": {
                    "quoted_paise": booking.quoted_fare_paise,
                    "final_paise": booking.final_fare_paise,
                    "discount_paise": booking.discount_paise,
                    "promo_code": booking.promo_code,
                    "currency": booking.currency,
                },
                "breakdown": quote.breakdown if quote else {},
                "payment_method": booking.payment_method,
                "payment_state": booking.payment_state,
                "commission": (
                    {
                        "platform_paise": commission.platform_paise,
                        "driver_paise": commission.driver_paise,
                        "percent": commission.percent_snapshot,
                    }
                    if commission
                    else None
                ),
                "completed_at": booking.completed_at,
                "issued_at": timezone.now(),
            }
        )


class BookingLocationView(APIView):
    serializer_class = BookingSerializer
    def get(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        offer = booking.offers.filter(status="accepted").first()
        if offer is None:
            raise ApiError(
                "No driver assigned yet",
                code="not_assigned",
                status_code=409,
            )
        ping = (
            LocationPing.objects.filter(driver=offer.driver)
            .order_by("-recorded_at")
            .first()
        )
        if ping is None:
            raise ApiError(
                "Driver location not available yet",
                code="no_location",
                status_code=404,
            )
        return Response(
            {
                "lat": ping.lat,
                "lng": ping.lng,
                "heading": ping.heading,
                "speed_mps": ping.speed_mps,
                "recorded_at": ping.recorded_at,
            }
        )


class BookingEtaView(APIView):
    serializer_class = BookingSerializer
    def get(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        offer = booking.offers.filter(status="accepted").first()
        if offer is None:
            raise ApiError(
                "No driver assigned yet", code="not_assigned", status_code=409
            )
        ping = (
            LocationPing.objects.filter(driver=offer.driver)
            .order_by("-recorded_at")
            .first()
        )
        if ping is None:
            return Response(
                {"eta_seconds": booking.duration_s, "distance_m": booking.distance_m}
            )
        target = (
            {"lat": booking.drop_lat, "lng": booking.drop_lng}
            if booking.status == Booking.Status.IN_PROGRESS
            else {"lat": booking.pickup_lat, "lng": booking.pickup_lng}
        )
        distance = int(haversine_m({"lat": ping.lat, "lng": ping.lng}, target))
        return Response(
            {
                "eta_seconds": max(60, int(distance / 1000 / 22 * 3600)),
                "distance_m": distance,
            }
        )


class BookingOtpVerifyView(APIView):
    serializer_class = BookingSerializer
    def post(self, request, booking_id):
        booking = _booking_for(request.user, booking_id)
        if booking.type != Booking.Type.GOODS or not hasattr(booking, "shipment"):
            raise ApiError(
                "OTP confirmation applies to goods deliveries",
                code="illegal_transition",
                status_code=409,
            )
        otp = (request.data.get("otp") or "").strip()
        shipment = booking.shipment
        if otp != shipment.delivery_otp:
            raise ApiError(
                "Incorrect OTP", code="otp_invalid", status_code=400
            )
        shipment.delivery_otp_verified_at = timezone.now()
        shipment.save(update_fields=["delivery_otp_verified_at"])
        return Response({"verified": True})
