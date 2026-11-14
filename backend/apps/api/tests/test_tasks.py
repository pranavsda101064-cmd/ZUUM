"""Scheduled jobs + location cadence governance."""
from __future__ import annotations

from datetime import timedelta

from django.utils import timezone

from apps.api.tests.base import ZuumTestCase, make_partner, make_user
from apps.bookings.models import (
    Booking,
    BookingStatusHistory,
    DispatchOffer,
    LocationPing,
)
from apps.bookings.services import create_booking, dispatch_offers
from apps.bookings.tasks import expire_offers, fail_stale_searches, prune_location_pings
from apps.bookings.models import FareQuote
from apps.payments.models import CommissionEntry, Payout
from apps.payments.tasks import generate_weekly_payouts


class TaskTests(ZuumTestCase):
    def setUp(self):
        super().setUp()
        self.customer = make_user("tasks-customer@zuum.in")
        self.driver = make_partner("tasks-driver@zuum.in", online=True)

    def _booking_with_offer(self):
        quote = FareQuote.objects.create(
            customer=self.customer,
            service_category=self.categories["auto"],
            kind="ride",
            pickup={"lat": 12.93, "lng": 77.62},
            drop={"lat": 12.97, "lng": 77.59},
            distance_m=4800,
            duration_s=900,
            breakdown={},
            total_paise=20000,
            valid_until=timezone.now() + timedelta(minutes=5),
        )
        booking = create_booking(
            customer=self.customer,
            quote=quote,
            payload={
                "payment_method": "cash",
                "pickup": {"lat": 12.93, "lng": 77.62, "address": "A"},
                "drop": {"lat": 12.97, "lng": 77.59, "address": "B"},
            },
        )
        return booking

    def test_expire_offers_sweep(self):
        booking = self._booking_with_offer()
        DispatchOffer.objects.filter(booking=booking).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )
        self.assertEqual(expire_offers(), 1)
        self.assertFalse(
            DispatchOffer.objects.filter(
                booking=booking, status=DispatchOffer.Status.OFFERED
            ).exists()
        )

    def test_fail_stale_searches(self):
        booking = self._booking_with_offer()
        Booking.objects.filter(pk=booking.pk).update(
            created_at=timezone.now() - timedelta(minutes=10)
        )
        self.assertEqual(fail_stale_searches(), 1)
        booking.refresh_from_db()
        self.assertEqual(booking.status, Booking.Status.FAILED)
        self.assertTrue(
            BookingStatusHistory.objects.filter(
                booking=booking, to_status=Booking.Status.FAILED
            ).exists()
        )

    def test_prune_location_pings(self):
        old = LocationPing.objects.create(
            driver=self.driver,
            lat=12.9,
            lng=77.6,
            recorded_at=timezone.now() - timedelta(days=5),
        )
        fresh = LocationPing.objects.create(
            driver=self.driver,
            lat=12.91,
            lng=77.61,
            recorded_at=timezone.now(),
        )
        removed = prune_location_pings()
        self.assertGreaterEqual(removed, 1)
        self.assertFalse(LocationPing.objects.filter(pk=old.pk).exists())
        self.assertTrue(LocationPing.objects.filter(pk=fresh.pk).exists())

    def test_weekly_payouts_are_idempotent(self):
        booking = self._booking_with_offer()
        booking.status = Booking.Status.COMPLETED
        booking.save(update_fields=["status"])
        CommissionEntry.objects.create(
            booking=booking,
            driver=self.driver,
            platform_paise=4000,
            driver_paise=16000,
        )
        created = generate_weekly_payouts()
        self.assertEqual(created, 1)
        payout = Payout.objects.get(driver=self.driver)
        self.assertEqual(payout.amount_paise, 16000)
        self.assertEqual(payout.status, Payout.Status.PENDING)

        self.assertEqual(generate_weekly_payouts(), 0)
        self.assertEqual(Payout.objects.filter(driver=self.driver).count(), 1)

    def test_location_cadence_is_enforced(self):
        partner = self.client_for(self.driver.user.email)
        now = timezone.now()
        first = partner.post(
            "/api/v1/partner/location",
            {"lat": 12.93, "lng": 77.62, "recorded_at": now.isoformat()},
            format="json",
        )
        self.assertEqual(first.status_code, 204)
        self.assertEqual(LocationPing.objects.filter(driver=self.driver).count(), 1)

        too_soon = partner.post(
            "/api/v1/partner/location",
            {
                "lat": 12.94,
                "lng": 77.63,
                "recorded_at": (now + timedelta(seconds=2)).isoformat(),
            },
            format="json",
        )
        self.assertEqual(too_soon.status_code, 204)
        self.assertEqual(LocationPing.objects.filter(driver=self.driver).count(), 1)

        out_of_order = partner.post(
            "/api/v1/partner/location",
            {
                "lat": 12.95,
                "lng": 77.64,
                "recorded_at": (now - timedelta(seconds=5)).isoformat(),
            },
            format="json",
        )
        self.assertEqual(out_of_order.status_code, 204)
        self.assertEqual(LocationPing.objects.filter(driver=self.driver).count(), 1)

        accepted = partner.post(
            "/api/v1/partner/location",
            {
                "lat": 12.96,
                "lng": 77.65,
                "recorded_at": (now + timedelta(seconds=20)).isoformat(),
            },
            format="json",
        )
        self.assertEqual(accepted.status_code, 204)
        self.assertEqual(LocationPing.objects.filter(driver=self.driver).count(), 2)
