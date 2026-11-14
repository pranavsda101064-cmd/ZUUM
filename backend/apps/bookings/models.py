"""Bookings, dispatch offers, trip lifecycle and location pings."""
from __future__ import annotations

from django.db import models

from apps.core.models import TimeStampedModel


class Booking(TimeStampedModel):
    class Type(models.TextChoices):
        RIDE = "ride", "Ride"
        GOODS = "goods", "Goods"

    class Status(models.TextChoices):
        CREATED = "CREATED", "Created"
        PRICED = "PRICED", "Priced"
        SEARCHING = "SEARCHING", "Searching"
        ASSIGNED = "ASSIGNED", "Assigned"
        DRIVER_ARRIVING = "DRIVER_ARRIVING", "Driver arriving"
        ARRIVED = "ARRIVED", "Arrived"
        IN_PROGRESS = "IN_PROGRESS", "In progress"
        COMPLETED = "COMPLETED", "Completed"
        CANCELLED = "CANCELLED", "Cancelled"
        FAILED = "FAILED", "Failed"

    class PaymentState(models.TextChoices):
        UNPAID = "unpaid", "Unpaid"
        AUTHORIZED = "authorized", "Authorized"
        PAID = "paid", "Paid"
        REFUNDED = "refunded", "Refunded"
        FAILED = "failed", "Failed"

    class PaymentMethod(models.TextChoices):
        CASH = "cash", "Cash"
        UPI = "upi", "UPI"
        CARD = "card", "Card"
        WALLET = "wallet", "Wallet"

    OPEN_STATUSES = (
        Status.CREATED,
        Status.PRICED,
        Status.SEARCHING,
        Status.ASSIGNED,
        Status.DRIVER_ARRIVING,
        Status.ARRIVED,
        Status.IN_PROGRESS,
    )

    customer = models.ForeignKey(
        "accounts.User", on_delete=models.PROTECT, related_name="bookings"
    )
    type = models.CharField(max_length=10, choices=Type.choices)
    service_category = models.ForeignKey(
        "catalog.ServiceCategory",
        on_delete=models.PROTECT,
        related_name="bookings",
    )
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.CREATED
    )

    pickup_lat = models.FloatField()
    pickup_lng = models.FloatField()
    pickup_address = models.CharField(max_length=240)
    drop_lat = models.FloatField()
    drop_lng = models.FloatField()
    drop_address = models.CharField(max_length=240)

    distance_m = models.PositiveIntegerField(default=0)
    duration_s = models.PositiveIntegerField(default=0)
    quoted_fare_paise = models.PositiveIntegerField(default=0)
    final_fare_paise = models.PositiveIntegerField(null=True, blank=True)
    promo_code = models.CharField(max_length=24, blank=True)
    discount_paise = models.PositiveIntegerField(default=0)
    currency = models.CharField(max_length=3, default="INR")
    payment_state = models.CharField(
        max_length=12,
        choices=PaymentState.choices,
        default=PaymentState.UNPAID,
    )
    payment_method = models.CharField(
        max_length=10, choices=PaymentMethod.choices, default=PaymentMethod.CASH
    )
    scheduled_at = models.DateTimeField(null=True, blank=True)
    notes = models.CharField(max_length=500, blank=True)
    cancelled_by = models.CharField(max_length=12, blank=True)
    cancel_reason = models.CharField(max_length=240, blank=True)
    completed_at = models.DateTimeField(null=True, blank=True)
    route_geometry = models.JSONField(default=list, blank=True)
    route_steps = models.JSONField(default=list, blank=True)
    route_provider = models.CharField(max_length=20, default="haversine")
    route_degraded = models.BooleanField(default=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [
            models.Index(fields=["status", "created_at"]),
            models.Index(fields=["customer", "-created_at"]),
        ]


class PassengerTrip(TimeStampedModel):
    class RideType(models.TextChoices):
        NOW = "now", "Now"
        SCHEDULED = "scheduled", "Scheduled"
        RENTAL = "rental", "Rental"
        OUTSTATION = "outstation", "Outstation"

    booking = models.OneToOneField(
        Booking, on_delete=models.CASCADE, related_name="passenger_trip"
    )
    ride_type = models.CharField(
        max_length=12, choices=RideType.choices, default=RideType.NOW
    )
    passengers = models.PositiveSmallIntegerField(default=1)
    stops = models.JSONField(default=list, blank=True)
    start_otp = models.CharField(max_length=6, blank=True)


class GoodsShipment(TimeStampedModel):
    class LoadType(models.TextChoices):
        FULL = "full", "Full"
        PART = "part", "Part"

    booking = models.OneToOneField(
        Booking, on_delete=models.CASCADE, related_name="shipment"
    )
    goods_type = models.CharField(max_length=80)
    weight_kg = models.PositiveIntegerField(null=True, blank=True)
    dimensions_cuft = models.FloatField(null=True, blank=True)
    needs_loading_help = models.BooleanField(default=False)
    load_type = models.CharField(
        max_length=10, choices=LoadType.choices, default=LoadType.FULL
    )
    sender_name = models.CharField(max_length=80, blank=True)
    sender_phone = models.CharField(max_length=20, blank=True)
    receiver_name = models.CharField(max_length=80, blank=True)
    receiver_phone = models.CharField(max_length=20, blank=True)
    stops = models.JSONField(default=list, blank=True)
    pod_required = models.BooleanField(default=True)
    pickup_otp = models.CharField(max_length=6, blank=True)
    delivery_otp = models.CharField(max_length=6, blank=True)
    pickup_otp_verified_at = models.DateTimeField(null=True, blank=True)
    delivery_otp_verified_at = models.DateTimeField(null=True, blank=True)
    pickup_pod = models.FileField(upload_to="pods/%Y/%m", blank=True)
    delivery_pod = models.FileField(upload_to="pods/%Y/%m", blank=True)
    delivery_signature = models.FileField(upload_to="pods/%Y/%m", blank=True)
    pod_receiver = models.CharField(max_length=80, blank=True)
    pod_signed_at = models.DateTimeField(null=True, blank=True)


class DispatchOffer(TimeStampedModel):
    class Status(models.TextChoices):
        OFFERED = "offered", "Offered"
        ACCEPTED = "accepted", "Accepted"
        REJECTED = "rejected", "Rejected"
        EXPIRED = "expired", "Expired"
        REVOKED = "revoked", "Revoked"

    booking = models.ForeignKey(
        Booking, on_delete=models.CASCADE, related_name="offers"
    )
    driver = models.ForeignKey(
        "accounts.DriverProfile", on_delete=models.CASCADE, related_name="offers"
    )
    vehicle = models.ForeignKey(
        "accounts.Vehicle",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="offers",
    )
    status = models.CharField(
        max_length=10, choices=Status.choices, default=Status.OFFERED
    )
    offer_seq = models.PositiveIntegerField(default=1)
    offered_at = models.DateTimeField(auto_now_add=True)
    expires_at = models.DateTimeField()
    responded_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.CharField(max_length=120, blank=True)

    class Meta:
        ordering = ("-offered_at",)
        unique_together = ("booking", "offer_seq")
        indexes = [models.Index(fields=["driver", "status"])]

    @property
    def is_expired(self) -> bool:
        from django.utils import timezone

        return timezone.now() > self.expires_at


class BookingStatusHistory(models.Model):
    id = models.BigAutoField(primary_key=True)
    booking = models.ForeignKey(
        Booking, on_delete=models.CASCADE, related_name="history"
    )
    from_status = models.CharField(max_length=20, blank=True)
    to_status = models.CharField(max_length=20)
    actor_type = models.CharField(max_length=10, default="system")
    actor_id = models.UUIDField(null=True, blank=True)
    reason = models.CharField(max_length=240, blank=True)
    at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-at",)


class FareQuote(TimeStampedModel):
    customer = models.ForeignKey(
        "accounts.User",
        on_delete=models.CASCADE,
        related_name="fare_quotes",
        null=True,
        blank=True,
    )
    service_category = models.ForeignKey(
        "catalog.ServiceCategory", on_delete=models.PROTECT
    )
    kind = models.CharField(max_length=10, choices=Booking.Type.choices)
    pickup = models.JSONField()
    drop = models.JSONField()
    distance_m = models.PositiveIntegerField()
    duration_s = models.PositiveIntegerField()
    breakdown = models.JSONField()
    total_paise = models.PositiveIntegerField()
    valid_until = models.DateTimeField()
    route_geometry = models.JSONField(default=list, blank=True)
    route_steps = models.JSONField(default=list, blank=True)
    route_provider = models.CharField(max_length=20, default="haversine")
    route_degraded = models.BooleanField(default=True)
    booking = models.ForeignKey(
        Booking,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="quotes",
    )


class LocationPing(models.Model):
    id = models.BigAutoField(primary_key=True)
    driver = models.ForeignKey(
        "accounts.DriverProfile", on_delete=models.CASCADE, related_name="pings"
    )
    booking = models.ForeignKey(
        Booking,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="pings",
    )
    lat = models.FloatField()
    lng = models.FloatField()
    heading = models.FloatField(null=True, blank=True)
    speed_mps = models.FloatField(null=True, blank=True)
    source = models.CharField(max_length=8, default="ws")
    recorded_at = models.DateTimeField(db_index=True)

    class Meta:
        ordering = ("-recorded_at",)
        indexes = [models.Index(fields=["driver", "recorded_at"])]


class Review(TimeStampedModel):
    class ReviewerRole(models.TextChoices):
        CUSTOMER = "customer", "Customer"
        DRIVER = "driver", "Driver"

    booking = models.ForeignKey(
        Booking, on_delete=models.CASCADE, related_name="reviews"
    )
    reviewer = models.ForeignKey(
        "accounts.User", on_delete=models.CASCADE, related_name="reviews_given"
    )
    reviewee = models.ForeignKey(
        "accounts.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="reviews_received",
    )
    reviewer_role = models.CharField(
        max_length=10, choices=ReviewerRole.choices, default=ReviewerRole.CUSTOMER
    )
    rating = models.PositiveSmallIntegerField()
    comment = models.CharField(max_length=500, blank=True)
    tags = models.JSONField(default=list, blank=True)

    class Meta:
        unique_together = ("booking", "reviewer")
        ordering = ("-created_at",)
