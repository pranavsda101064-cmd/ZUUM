"""Money: payments, wallet, commission entries and payouts."""
from __future__ import annotations

from django.db import models

from apps.core.models import TimeStampedModel


class Payment(TimeStampedModel):
    class Method(models.TextChoices):
        CASH = "cash", "Cash"
        UPI = "upi", "UPI"
        CARD = "card", "Card"
        WALLET = "wallet", "Wallet"

    class Status(models.TextChoices):
        CREATED = "created", "Created"
        AUTHORIZED = "authorized", "Authorized"
        CAPTURED = "captured", "Captured"
        FAILED = "failed", "Failed"
        REFUNDED = "refunded", "Refunded"

    booking = models.ForeignKey(
        "bookings.Booking", on_delete=models.CASCADE, related_name="payments"
    )
    method = models.CharField(max_length=10, choices=Method.choices)
    amount_paise = models.PositiveIntegerField()
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.CREATED
    )
    gateway_order_id = models.CharField(max_length=80, blank=True)
    gateway_payment_id = models.CharField(max_length=80, blank=True)
    gateway_signature = models.CharField(max_length=160, blank=True)
    failure_reason = models.CharField(max_length=160, blank=True)
    processed_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)


class Wallet(TimeStampedModel):
    customer = models.OneToOneField(
        "accounts.User", on_delete=models.CASCADE, related_name="wallet"
    )
    balance_paise = models.PositiveIntegerField(default=0)
    currency = models.CharField(max_length=3, default="INR")


class WalletTransaction(TimeStampedModel):
    class Kind(models.TextChoices):
        CREDIT = "credit", "Credit"
        DEBIT = "debit", "Debit"
        REFUND = "refund", "Refund"
        TOPUP = "topup", "Top-up"
        PAYOUT = "payout", "Payout"
        ADJUSTMENT = "adjustment", "Adjustment"

    wallet = models.ForeignKey(
        Wallet, on_delete=models.CASCADE, related_name="transactions"
    )
    kind = models.CharField(max_length=12, choices=Kind.choices)
    amount_paise = models.PositiveIntegerField()
    balance_after = models.PositiveIntegerField()
    reference = models.CharField(max_length=80, blank=True)
    note = models.CharField(max_length=200, blank=True)

    class Meta:
        ordering = ("-created_at",)


class CommissionEntry(TimeStampedModel):
    booking = models.OneToOneField(
        "bookings.Booking", on_delete=models.CASCADE, related_name="commission"
    )
    driver = models.ForeignKey(
        "accounts.DriverProfile", on_delete=models.CASCADE, related_name="commissions"
    )
    platform_paise = models.PositiveIntegerField()
    driver_paise = models.PositiveIntegerField()
    percent_snapshot = models.FloatField(default=20)
    tips_paise = models.PositiveIntegerField(default=0)


class Payout(TimeStampedModel):
    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        PROCESSING = "processing", "Processing"
        PAID = "paid", "Paid"
        FAILED = "failed", "Failed"

    driver = models.ForeignKey(
        "accounts.DriverProfile", on_delete=models.CASCADE, related_name="payouts"
    )
    amount_paise = models.PositiveIntegerField()
    method = models.CharField(max_length=10, default="bank")
    status = models.CharField(
        max_length=12, choices=Status.choices, default=Status.PENDING
    )
    gateway_ref = models.CharField(max_length=80, blank=True)
    batch_ref = models.CharField(max_length=80, blank=True)
    paid_at = models.DateTimeField(null=True, blank=True)
    period_start = models.DateTimeField(null=True, blank=True)
    period_end = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)
