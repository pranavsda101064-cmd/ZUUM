"""Driver onboarding + availability rules."""
from __future__ import annotations

from django.utils import timezone

from apps.core.exceptions import ApiError

from .models import DriverProfile, KycDocument

REQUIRED_DOCS = (
    KycDocument.Type.LICENCE,
    KycDocument.Type.RC,
    KycDocument.Type.INSURANCE,
)


def ensure_driver_profile(user) -> DriverProfile:
    profile, created = DriverProfile.objects.get_or_create(
        user=user, defaults={"languages": ["Kannada", "English"]}
    )
    if created and not user.role == "customer":
        pass
    return profile


def submit_kyc(driver: DriverProfile) -> DriverProfile:
    have = set(driver.documents.values_list("type", flat=True))
    missing = [t for t in REQUIRED_DOCS if t not in have]
    if missing:
        raise ApiError(
            "Upload the remaining documents to submit KYC",
            code="kyc_incomplete",
            status_code=400,
            details={"missing": missing},
        )
    driver.kyc_status = DriverProfile.KYC_SUBMITTED
    driver.submitted_at = driver.submitted_at or timezone.now()
    driver.rejection_reason = ""
    driver.save(update_fields=["kyc_status", "submitted_at", "rejection_reason", "updated_at"])
    return driver


def set_availability(
    driver: DriverProfile, *, online: bool, vehicle_id=None
) -> DriverProfile:
    if online:
        if driver.approval_status != DriverProfile.APPROVAL_ACTIVE:
            raise ApiError(
                "Your account is pending approval",
                code="not_approved",
                status_code=409,
            )
        vehicles = driver.vehicles.filter(is_active=True)
        if vehicle_id:
            vehicles = vehicles.filter(id=vehicle_id)
        if not vehicles.exists():
            raise ApiError(
                "Add an active vehicle before going online",
                code="vehicle_inactive",
                status_code=409,
            )
        driver.online_state = DriverProfile.ONLINE_AVAILABLE
    else:
        driver.online_state = DriverProfile.ONLINE_OFFLINE
    driver.last_seen_at = timezone.now()
    driver.save(update_fields=["online_state", "last_seen_at", "updated_at"])
    return driver


def approve_driver(driver: DriverProfile) -> DriverProfile:
    required = set(REQUIRED_DOCS)
    verified = set(
        driver.documents.filter(status=KycDocument.Status.VERIFIED).values_list(
            "type", flat=True
        )
    )
    missing = sorted(required - verified)
    if missing:
        raise ApiError(
            "Verify every required KYC document before approving this captain",
            code="documents_unverified",
            status_code=409,
            details={"missing": missing},
        )
    driver.kyc_status = DriverProfile.KYC_APPROVED
    driver.approval_status = DriverProfile.APPROVAL_ACTIVE
    driver.reviewed_at = timezone.now()
    driver.rejection_reason = ""
    driver.save(
        update_fields=[
            "kyc_status",
            "approval_status",
            "reviewed_at",
            "rejection_reason",
            "updated_at",
        ]
    )
    driver.documents.update(status=KycDocument.Status.VERIFIED)
    return driver
