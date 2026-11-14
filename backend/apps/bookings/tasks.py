"""Scheduled jobs: offer expiry sweep and raw location retention."""
from __future__ import annotations

from datetime import timedelta

from celery import shared_task
from django.utils import timezone


@shared_task
def expire_offers() -> int:
    """Mark lapsed offers expired and notify drivers (every 15 s via beat)."""
    from apps.bookings.models import DispatchOffer
    from apps.bookings.services import expire_stale_offers

    stale = DispatchOffer.objects.filter(
        status=DispatchOffer.Status.OFFERED, expires_at__lt=timezone.now()
    ).count()
    if stale:
        expire_stale_offers()
    return stale


@shared_task
def prune_location_pings(days: int = 3) -> int:
    """Raw pings are retained 72 h (docs/02_data_model.md)."""
    from apps.bookings.models import LocationPing

    cutoff = timezone.now() - timedelta(days=days)
    deleted, _ = LocationPing.objects.filter(recorded_at__lt=cutoff).delete()
    return deleted


@shared_task
def fail_stale_searches(minutes: int = 5) -> int:
    """Bookings stuck searching for too long fail honestly (no silent limbo)."""
    from apps.bookings.models import Booking
    from apps.bookings.services import push_status, record_transition

    cutoff = timezone.now() - timedelta(minutes=minutes)
    stale = Booking.objects.filter(status=Booking.Status.SEARCHING, created_at__lt=cutoff)
    count = 0
    for booking in stale:
        record_transition(
            booking,
            Booking.Status.FAILED,
            actor_type="system",
            reason="no_driver",
        )
        push_status(booking, {"reason": "no_driver"})
        count += 1
    return count
