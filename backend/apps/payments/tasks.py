"""Scheduled settlement jobs."""
from __future__ import annotations

from datetime import timedelta

from celery import shared_task
from django.utils import timezone

from .models import Payout


@shared_task
def generate_weekly_payouts() -> int:
    """Create one pending payout per driver for last week's net earnings."""
    from apps.accounts.models import DriverProfile
    from apps.payments.models import CommissionEntry

    now = timezone.localtime()
    week_start = now - timedelta(days=7)
    iso = now.isocalendar()
    batch_ref = f"PO-{iso.year}-{iso.week:02d}"
    created = 0
    for driver in DriverProfile.objects.filter(
        approval_status=DriverProfile.APPROVAL_ACTIVE
    ):
        if Payout.objects.filter(driver=driver, batch_ref=batch_ref).exists():
            continue
        net = (
            CommissionEntry.objects.filter(
                driver=driver, created_at__gte=week_start
            ).aggregate(total=__import__("django").db.models.Sum("driver_paise"))[
                "total"
            ]
            or 0
        )
        if net <= 0:
            continue
        Payout.objects.create(
            driver=driver,
            amount_paise=net,
            method="bank",
            status=Payout.Status.PENDING,
            batch_ref=batch_ref,
            period_start=week_start,
            period_end=now,
        )
        created += 1
    return created


@shared_task
def mark_processing_payouts(batch_ref: str) -> int:
    updated = Payout.objects.filter(
        batch_ref=batch_ref, status=Payout.Status.PENDING
    ).update(status=Payout.Status.PROCESSING)
    return updated
