"""Seed the production demo accounts (catalog + ops + approved partner + customer).

    SEED_PASSWORD='choose-a-strong-password' python manage.py seed_production_demo

- With SEED_PASSWORD: accounts are created/updated to that password (stable).
- Without it: a random password is generated only for NEW accounts; existing
  passwords are left untouched so free-tier restarts never rotate them.
Safe to re-run.
"""
from __future__ import annotations

import os
import secrets
import uuid
from datetime import timedelta
from decimal import Decimal
from pathlib import Path

from django.conf import settings
from django.core.files import File
from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import (
    CustomerProfile,
    DriverProfile,
    KycDocument,
    User,
    Vehicle,
)
from apps.bookings.models import Booking, PassengerTrip
from apps.core.seed import seed_catalog
from apps.payments.models import CommissionEntry, Payment, Payout, Wallet
from apps.platform.models import SupportMessage, SupportTicket


class Command(BaseCommand):
    help = "Seed the catalog plus ops, approved partner and customer accounts."

    def _pending_driver(
        self,
        *,
        email: str,
        first_name: str,
        last_name: str,
        phone: str,
        registration: str,
        category,
        password: str,
        password_env: str | None,
    ) -> DriverProfile:
        user, created = User.objects.get_or_create(
            email=email,
            defaults={
                "first_name": first_name,
                "last_name": last_name,
                "phone": phone,
                "role": User.Role.DRIVER,
            },
        )
        user.role = User.Role.DRIVER
        user.is_active = True
        if created or password_env:
            user.set_password(password)
        user.save()

        driver, driver_created = DriverProfile.objects.get_or_create(
            user=user,
            defaults={"languages": ["Kannada", "English"]},
        )
        if driver_created or driver.kyc_status == DriverProfile.KYC_DRAFT:
            driver.licence_number = driver.licence_number or "KA0120190012345"
            driver.kyc_status = DriverProfile.KYC_SUBMITTED
            driver.approval_status = DriverProfile.APPROVAL_PENDING
            driver.submitted_at = driver.submitted_at or timezone.now()
            driver.home_lat = driver.home_lat or 12.9352
            driver.home_lng = driver.home_lng or 77.6245
            driver.languages = driver.languages or ["Kannada", "English"]
            driver.save()
        Vehicle.objects.get_or_create(
            registration_number=registration,
            defaults={
                "driver": driver,
                "category": category,
                "make": "Bajaj",
                "model": "RE Auto",
                "color": "Yellow",
                "seats": 3,
                "is_active": True,
            },
        )

        asset_dir = Path(settings.BASE_DIR) / "demo_assets" / "kyc"
        expiry = (timezone.now() + timedelta(days=365)).date()
        for doc_type in (
            KycDocument.Type.LICENCE,
            KycDocument.Type.RC,
            KycDocument.Type.INSURANCE,
        ):
            document, _ = KycDocument.objects.get_or_create(
                driver=driver,
                type=doc_type,
                defaults={
                    "status": KycDocument.Status.PENDING,
                    "expires_at": expiry,
                },
            )
            if not document.file:
                source = asset_dir / f"{doc_type}.png"
                if source.exists():
                    with source.open("rb") as handle:
                        document.file.save(
                            f"{doc_type}.png", File(handle), save=True
                        )
        return driver

    def _seed_bookings(self, *, customer, partner, categories) -> None:
        now = timezone.now()
        samples = [
            (
                "completed-1",
                "Koramangala 5th Block",
                "Indiranagar 100 Feet Road",
                Booking.Status.COMPLETED,
                4200,
                780,
                21800,
                now - timedelta(minutes=55),
                "seed-completed-1",
            ),
            (
                "completed-2",
                "Jayanagar 4th Block",
                "MG Road Metro",
                Booking.Status.COMPLETED,
                6300,
                1120,
                28600,
                now - timedelta(hours=3),
                "seed-completed-2",
            ),
            (
                "completed-3",
                "HSR Layout Sector 2",
                "Whitefield Main Road",
                Booking.Status.COMPLETED,
                12400,
                2100,
                47400,
                now - timedelta(days=1, hours=2),
                "seed-completed-3",
            ),
            (
                "cancelled-1",
                "Malleshwaram",
                "Cubbon Park",
                Booking.Status.CANCELLED,
                3100,
                620,
                17600,
                now - timedelta(hours=5),
                "seed-cancelled-1",
            ),
        ]
        for (
            key,
            pickup,
            drop,
            status,
            distance_m,
            duration_s,
            fare_paise,
            when,
            note,
        ) in samples:
            booking_id = uuid.uuid5(uuid.NAMESPACE_URL, f"zuum-demo-{key}")
            booking, created = Booking.objects.get_or_create(
                id=booking_id,
                defaults={
                    "customer": customer,
                    "type": Booking.Type.RIDE,
                    "service_category": categories["auto"],
                    "status": status,
                    "pickup_lat": 12.9352,
                    "pickup_lng": 77.6245,
                    "pickup_address": pickup,
                    "drop_lat": 12.9719,
                    "drop_lng": 77.6412,
                    "drop_address": drop,
                    "distance_m": distance_m,
                    "duration_s": duration_s,
                    "quoted_fare_paise": fare_paise,
                    "final_fare_paise": (
                        fare_paise
                        if status == Booking.Status.COMPLETED
                        else None
                    ),
                    "payment_state": (
                        Booking.PaymentState.PAID
                        if status == Booking.Status.COMPLETED
                        else Booking.PaymentState.UNPAID
                    ),
                    "payment_method": Booking.PaymentMethod.CASH,
                    "completed_at": (
                        when if status == Booking.Status.COMPLETED else None
                    ),
                    "cancelled_by": (
                        "customer"
                        if status == Booking.Status.CANCELLED
                        else ""
                    ),
                    "cancel_reason": (
                        "Plans changed"
                        if status == Booking.Status.CANCELLED
                        else ""
                    ),
                    "notes": note,
                    "route_provider": "seed",
                    "route_degraded": True,
                },
            )
            if not created:
                continue
            PassengerTrip.objects.get_or_create(
                booking=booking,
                defaults={"start_otp": "1234"},
            )
            if status == Booking.Status.COMPLETED:
                platform = round(fare_paise * 0.2)
                CommissionEntry.objects.get_or_create(
                    booking=booking,
                    defaults={
                        "driver": partner,
                        "platform_paise": platform,
                        "driver_paise": fare_paise - platform,
                        "percent_snapshot": 20,
                    },
                )
                Payment.objects.get_or_create(
                    booking=booking,
                    defaults={
                        "method": Payment.Method.CASH,
                        "amount_paise": fare_paise,
                        "status": Payment.Status.CAPTURED,
                        "processed_at": when,
                    },
                )

    def _seed_ops_queue(self, *, customer, partner) -> None:
        Payout.objects.get_or_create(
            batch_ref="DEMO-PAYOUT-PENDING",
            defaults={
                "driver": partner,
                "amount_paise": 432000,
                "method": "bank",
                "status": Payout.Status.PENDING,
            },
        )
        Payout.objects.get_or_create(
            batch_ref="DEMO-PAYOUT-PAID",
            defaults={
                "driver": partner,
                "amount_paise": 512000,
                "method": "bank",
                "status": Payout.Status.PAID,
                "paid_at": timezone.now() - timedelta(days=7),
            },
        )
        ticket, created = SupportTicket.objects.get_or_create(
            customer=customer,
            subject="Driver took a long route",
            defaults={
                "category": "ride",
                "priority": SupportTicket.Priority.NORMAL,
                "status": SupportTicket.Status.OPEN,
            },
        )
        if created:
            SupportMessage.objects.create(
                ticket=ticket,
                author=customer,
                body="The captain took the ring road instead of the direct route.",
            )
        ticket2, created2 = SupportTicket.objects.get_or_create(
            customer=customer,
            subject="Payment receipt request",
            defaults={
                "category": "payments",
                "priority": SupportTicket.Priority.LOW,
                "status": SupportTicket.Status.PENDING,
            },
        )
        if created2:
            SupportMessage.objects.create(
                ticket=ticket2,
                author=customer,
                body="Please share the GST invoice for my last ride.",
            )

    def handle(self, *args, **options):
        categories = seed_catalog()

        password_env = os.getenv("SEED_PASSWORD")
        password = password_env or secrets.token_urlsafe(10)
        ops_email = os.getenv("SEED_OPS_EMAIL", "ops@zuum.in")
        partner_email = os.getenv("SEED_PARTNER_EMAIL", "partner@zuum.in")
        customer_email = os.getenv("SEED_CUSTOMER_EMAIL", "customer@zuum.in")

        ops, ops_created = User.objects.get_or_create(
            email=ops_email,
            defaults={"first_name": "Ops", "last_name": "Desk", "role": User.Role.STAFF},
        )
        ops.role = User.Role.STAFF
        ops.is_staff = True
        ops.is_superuser = False
        ops.is_active = True
        if ops_created or password_env:
            ops.set_password(password)
        ops.save()

        partner_user, partner_created = User.objects.get_or_create(
            email=partner_email,
            defaults={
                "first_name": "Ravi",
                "last_name": "Kumar",
                "phone": "9845012345",
                "role": User.Role.DRIVER,
            },
        )
        partner_user.role = User.Role.DRIVER
        partner_user.is_active = True
        if partner_created or password_env:
            partner_user.set_password(password)
        partner_user.save()

        partner, _ = DriverProfile.objects.get_or_create(
            user=partner_user,
            defaults={"languages": ["Kannada", "English"]},
        )
        partner.licence_number = partner.licence_number or "KA0120180012345"
        partner.kyc_status = DriverProfile.KYC_APPROVED
        partner.approval_status = DriverProfile.APPROVAL_ACTIVE
        partner.submitted_at = partner.submitted_at or timezone.now()
        partner.reviewed_at = timezone.now()
        partner.rating_avg = partner.rating_avg or Decimal("4.80")
        partner.rating_count = partner.rating_count or 126
        partner.online_state = DriverProfile.ONLINE_OFFLINE
        partner.home_lat = partner.home_lat or 12.9352
        partner.home_lng = partner.home_lng or 77.6245
        partner.languages = partner.languages or ["Kannada", "English"]
        partner.save()
        expiry = (timezone.now() + timedelta(days=365)).date()
        for doc_type in (
            KycDocument.Type.LICENCE,
            KycDocument.Type.RC,
            KycDocument.Type.INSURANCE,
        ):
            KycDocument.objects.update_or_create(
                driver=partner,
                type=doc_type,
                defaults={
                    "status": KycDocument.Status.VERIFIED,
                    "expires_at": expiry,
                },
            )
        Vehicle.objects.update_or_create(
            registration_number="KA05AB1234",
            defaults={
                "driver": partner,
                "category": categories["auto"],
                "make": "Bajaj",
                "model": "RE Auto",
                "color": "Yellow",
                "is_active": True,
            },
        )

        customer, customer_created = User.objects.get_or_create(
            email=customer_email,
            defaults={
                "first_name": "Aarav",
                "last_name": "Menon",
                "phone": "9845011111",
                "role": User.Role.CUSTOMER,
            },
        )
        customer.role = User.Role.CUSTOMER
        customer.is_active = True
        if customer_created or password_env:
            customer.set_password(password)
        customer.save()
        CustomerProfile.objects.get_or_create(user=customer)
        Wallet.objects.get_or_create(customer=customer)

        kyc_demo = self._pending_driver(
            email=os.getenv("SEED_KYC_EMAIL", "kyc-demo@zuum.in"),
            first_name="Kavya",
            last_name="Rao",
            phone="9845000123",
            registration="KA05QA9999",
            category=categories["auto"],
            password=password,
            password_env=password_env,
        )
        self._pending_driver(
            email=os.getenv("SEED_KYC_VERIFY_EMAIL", "kyc-verify@zuum.in"),
            first_name="Nikhil",
            last_name="Shetty",
            phone="9845000456",
            registration="KA05QA8888",
            category=categories["auto"],
            password=password,
            password_env=password_env,
        )
        self._seed_bookings(
            customer=customer,
            partner=partner,
            categories=categories,
        )
        self._seed_ops_queue(customer=customer, partner=partner)

        self.stdout.write(self.style.SUCCESS("Production demo data seeded."))
        if password_env or (ops_created and partner_created and customer_created):
            self.stdout.write("  Save these credentials now (shown once):")
            self.stdout.write(f"    ops      {ops_email} / {password}")
            self.stdout.write(f"    partner  {partner_email} / {password}")
            self.stdout.write(f"    customer {customer_email} / {password}")
            self.stdout.write(
                f"    kyc demo {kyc_demo.user.email} / {password}"
            )
        else:
            self.stdout.write(
                "  Accounts already existed; passwords were NOT changed."
            )
            self.stdout.write(
                f"  {ops_email} · {partner_email} · {customer_email}"
            )
            self.stdout.write(
                self.style.WARNING(
                    "  Set SEED_PASSWORD to rotate all three passwords on next boot."
                )
            )
