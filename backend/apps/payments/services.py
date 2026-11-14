"""Money services: commission split, wallet ledger, payouts."""
from __future__ import annotations

from django.db import transaction
from django.utils import timezone

from apps.catalog.models import CommissionRule

from .models import CommissionEntry, Payment, Payout, Wallet, WalletTransaction


def commission_for(*, booking, driver, fare_paise: int) -> tuple[int, int, float]:
    percent = CommissionRule.percent_for(
        category=booking.service_category,
    )
    platform = int(round(fare_paise * percent / 100))
    return platform, fare_paise - platform, percent


def settle_commission(*, booking, driver, fare_paise: int) -> CommissionEntry:
    platform, driver_amount, percent = commission_for(
        booking=booking, driver=driver, fare_paise=fare_paise
    )
    entry, _ = CommissionEntry.objects.update_or_create(
        booking=booking,
        defaults={
            "driver": driver,
            "platform_paise": platform,
            "driver_paise": driver_amount,
            "percent_snapshot": percent,
        },
    )
    return entry


def ensure_wallet(user) -> Wallet:
    wallet, _ = Wallet.objects.get_or_create(customer=user)
    return wallet


def apply_wallet_txn(
    *,
    wallet: Wallet,
    kind: str,
    amount_paise: int,
    reference: str = "",
    note: str = "",
) -> WalletTransaction:
    signed = amount_paise if kind in (
        WalletTransaction.Kind.CREDIT,
        WalletTransaction.Kind.REFUND,
        WalletTransaction.Kind.TOPUP,
    ) else -amount_paise
    with transaction.atomic():
        wallet = Wallet.objects.select_for_update().get(pk=wallet.pk)
        new_balance = wallet.balance_paise + signed
        if new_balance < 0:
            from apps.core.exceptions import ApiError

            raise ApiError(
                "Insufficient wallet balance",
                code="insufficient_balance",
                status_code=409,
            )
        wallet.balance_paise = new_balance
        wallet.save(update_fields=["balance_paise", "updated_at"])
        return WalletTransaction.objects.create(
            wallet=wallet,
            kind=kind,
            amount_paise=amount_paise,
            balance_after=new_balance,
            reference=reference,
            note=note,
        )


def mark_payment_paid(payment: Payment) -> Payment:
    payment.status = Payment.Status.CAPTURED
    payment.processed_at = timezone.now()
    payment.save(update_fields=["status", "processed_at", "updated_at"])
    booking = payment.booking
    booking.payment_state = booking.PaymentState.PAID
    booking.save(update_fields=["payment_state", "updated_at"])
    return payment


def create_payout(
    *,
    driver,
    amount_paise: int,
    method: str = "bank",
    status: str = Payout.Status.PENDING,
    batch_ref: str = "",
) -> Payout:
    return Payout.objects.create(
        driver=driver,
        amount_paise=amount_paise,
        method=method,
        status=status,
        batch_ref=batch_ref,
    )
