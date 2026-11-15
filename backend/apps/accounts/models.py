"""Accounts: users, customer/driver profiles, fleet orgs, vehicles, documents."""
from __future__ import annotations

import uuid

from django.contrib.auth.models import AbstractBaseUser, BaseUserManager, PermissionsMixin
from django.db import models

from apps.core.models import TimeStampedModel


class UserManager(BaseUserManager):
    use_in_migrations = True

    def _create_user(self, email: str, password: str | None, **extra):
        if not email:
            raise ValueError("Email is required")
        email = self.normalize_email(email).lower()
        user = self.model(email=email, **extra)
        user.set_password(password)
        user.save(using=self._db)
        return user

    def create_user(self, email: str, password: str | None = None, **extra):
        extra.setdefault("role", User.Role.CUSTOMER)
        return self._create_user(email, password, **extra)

    def create_superuser(self, email: str, password: str | None = None, **extra):
        extra.setdefault("role", User.Role.STAFF)
        extra.setdefault("is_staff", True)
        extra.setdefault("is_superuser", True)
        return self._create_user(email, password, **extra)


class User(AbstractBaseUser, PermissionsMixin):
    class Role(models.TextChoices):
        CUSTOMER = "customer", "Customer"
        DRIVER = "driver", "Driver"
        FLEET_OWNER = "fleet_owner", "Fleet owner"
        STAFF = "staff", "Staff"

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    email = models.EmailField(unique=True)
    first_name = models.CharField(max_length=80)
    last_name = models.CharField(max_length=80, blank=True)
    phone = models.CharField(max_length=20, blank=True)
    phone_verified = models.BooleanField(default=False)
    role = models.CharField(
        max_length=20, choices=Role.choices, default=Role.CUSTOMER
    )
    is_active = models.BooleanField(default=True)
    is_staff = models.BooleanField(default=False)
    created_at = models.DateTimeField(auto_now_add=True)

    objects = UserManager()

    USERNAME_FIELD = "email"
    REQUIRED_FIELDS = ["first_name", "last_name"]

    class Meta:
        db_table = "users"
        ordering = ("-created_at",)

    def __str__(self) -> str:  # pragma: no cover
        return self.email

    @property
    def full_name(self) -> str:
        return f"{self.first_name} {self.last_name}".strip()


class CustomerProfile(TimeStampedModel):
    class PaymentMethod(models.TextChoices):
        CASH = "cash", "Cash"
        UPI = "upi", "UPI"
        CARD = "card", "Card"
        WALLET = "wallet", "Wallet"

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="customer_profile"
    )
    default_payment_method = models.CharField(
        max_length=10, choices=PaymentMethod.choices, default=PaymentMethod.CASH
    )
    gstin = models.CharField(max_length=15, blank=True)
    business_name = models.CharField(max_length=160, blank=True)
    is_restricted = models.BooleanField(default=False)


class TrustedContact(TimeStampedModel):
    customer = models.ForeignKey(
        CustomerProfile, on_delete=models.CASCADE, related_name="trusted_contacts"
    )
    name = models.CharField(max_length=80)
    phone = models.CharField(max_length=20)

    class Meta:
        ordering = ("created_at",)


class FleetPartner(TimeStampedModel):
    class KycStatus(models.TextChoices):
        DRAFT = "draft", "Draft"
        SUBMITTED = "submitted", "Submitted"
        APPROVED = "approved", "Approved"
        REJECTED = "rejected", "Rejected"

    owner = models.ForeignKey(
        User, on_delete=models.CASCADE, related_name="fleet_partners"
    )
    name = models.CharField(max_length=160)
    gstin = models.CharField(max_length=20, blank=True)
    kyc_status = models.CharField(
        max_length=20, choices=KycStatus.choices, default=KycStatus.DRAFT
    )
    payout_method = models.CharField(max_length=10, default="bank")
    payout_ref = models.CharField(max_length=120, blank=True)


class DriverProfile(TimeStampedModel):
    KYC_DRAFT = "draft"
    KYC_SUBMITTED = "submitted"
    KYC_APPROVED = "approved"
    KYC_REJECTED = "rejected"
    KYC_CHOICES = [
        (KYC_DRAFT, "Draft"),
        (KYC_SUBMITTED, "Submitted"),
        (KYC_APPROVED, "Approved"),
        (KYC_REJECTED, "Rejected"),
    ]

    APPROVAL_PENDING = "pending"
    APPROVAL_ACTIVE = "active"
    APPROVAL_SUSPENDED = "suspended"
    APPROVAL_CHOICES = [
        (APPROVAL_PENDING, "Pending"),
        (APPROVAL_ACTIVE, "Active"),
        (APPROVAL_SUSPENDED, "Suspended"),
    ]

    ONLINE_OFFLINE = "offline"
    ONLINE_AVAILABLE = "available"
    ONLINE_BUSY = "busy"
    ONLINE_CHOICES = [
        (ONLINE_OFFLINE, "Offline"),
        (ONLINE_AVAILABLE, "Available"),
        (ONLINE_BUSY, "Busy"),
    ]

    user = models.OneToOneField(
        User, on_delete=models.CASCADE, related_name="driver_profile"
    )
    fleet = models.ForeignKey(
        FleetPartner,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="drivers",
    )
    licence_number = models.CharField(max_length=40, blank=True)
    kyc_status = models.CharField(
        max_length=20, choices=KYC_CHOICES, default=KYC_DRAFT
    )
    approval_status = models.CharField(
        max_length=20, choices=APPROVAL_CHOICES, default=APPROVAL_PENDING
    )
    bank_account_ref = models.CharField(max_length=120, blank=True)
    bank_account_holder = models.CharField(max_length=120, blank=True)
    bank_account_number = models.CharField(max_length=24, blank=True)
    bank_ifsc = models.CharField(max_length=11, blank=True)
    notifications_enabled = models.BooleanField(default=True)
    rating_avg = models.DecimalField(max_digits=3, decimal_places=2, default=0)
    rating_count = models.PositiveIntegerField(default=0)
    online_state = models.CharField(
        max_length=20, choices=ONLINE_CHOICES, default=ONLINE_OFFLINE
    )
    last_seen_at = models.DateTimeField(null=True, blank=True)
    home_lat = models.FloatField(null=True, blank=True)
    home_lng = models.FloatField(null=True, blank=True)
    languages = models.JSONField(default=list, blank=True)
    submitted_at = models.DateTimeField(null=True, blank=True)
    reviewed_at = models.DateTimeField(null=True, blank=True)
    rejection_reason = models.CharField(max_length=240, blank=True)

    class Meta:
        ordering = ("-created_at",)

    @property
    def is_approved(self) -> bool:
        return self.approval_status == self.APPROVAL_ACTIVE


class KycDocument(TimeStampedModel):
    class Type(models.TextChoices):
        LICENCE = "licence", "Driving licence"
        RC = "rc", "Vehicle RC"
        INSURANCE = "insurance", "Insurance"
        PUC = "puc", "PUC"
        PROFILE_PHOTO = "profile_photo", "Profile photo"
        VEHICLE_PHOTO = "vehicle_photo", "Vehicle photo"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        VERIFIED = "verified", "Verified"
        REJECTED = "rejected", "Rejected"

    driver = models.ForeignKey(
        DriverProfile, on_delete=models.CASCADE, related_name="documents"
    )
    type = models.CharField(max_length=20, choices=Type.choices)
    file = models.FileField(upload_to="kyc/%Y/%m", blank=True)
    expires_at = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )

    class Meta:
        unique_together = ("driver", "type")


class Vehicle(TimeStampedModel):
    driver = models.ForeignKey(
        DriverProfile,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="vehicles",
    )
    fleet = models.ForeignKey(
        FleetPartner,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="vehicles",
    )
    category = models.ForeignKey(
        "catalog.ServiceCategory",
        on_delete=models.PROTECT,
        related_name="vehicles",
    )
    registration_number = models.CharField(max_length=20, unique=True)
    make = models.CharField(max_length=60)
    model = models.CharField(max_length=60)
    color = models.CharField(max_length=40)
    capacity_kg = models.PositiveIntegerField(null=True, blank=True)
    volume_cuft = models.FloatField(null=True, blank=True)
    seats = models.PositiveSmallIntegerField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    insurance_expires_at = models.DateField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)

    def save(self, *args, **kwargs):
        self.registration_number = self.registration_number.replace(" ", "").upper()
        super().save(*args, **kwargs)


class VehicleDocument(TimeStampedModel):
    class Type(models.TextChoices):
        RC = "rc", "RC"
        INSURANCE = "insurance", "Insurance"
        PUC = "puc", "PUC"
        PERMIT = "permit", "Permit"
        PHOTO = "photo", "Photo"

    class Status(models.TextChoices):
        PENDING = "pending", "Pending"
        VERIFIED = "verified", "Verified"
        EXPIRED = "expired", "Expired"

    vehicle = models.ForeignKey(
        Vehicle, on_delete=models.CASCADE, related_name="documents"
    )
    type = models.CharField(max_length=20, choices=Type.choices)
    file = models.FileField(upload_to="vehicles/%Y/%m", blank=True)
    expires_at = models.DateField(null=True, blank=True)
    status = models.CharField(
        max_length=20, choices=Status.choices, default=Status.PENDING
    )


class SavedAddress(TimeStampedModel):
    class Label(models.TextChoices):
        HOME = "home", "Home"
        WORK = "work", "Work"
        OTHER = "other", "Other"

    customer = models.ForeignKey(
        CustomerProfile, on_delete=models.CASCADE, related_name="addresses"
    )
    label = models.CharField(max_length=10, choices=Label.choices, default=Label.OTHER)
    name = models.CharField(max_length=80)
    lat = models.FloatField()
    lng = models.FloatField()
    formatted_address = models.CharField(max_length=240)
    is_default = models.BooleanField(default=False)
