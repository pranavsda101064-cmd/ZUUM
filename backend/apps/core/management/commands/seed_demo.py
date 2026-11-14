"""Idempotent demo seed: catalog, pricing, promo and three personas.

    python manage.py seed_demo

Personas (password `zuum1234`):
  customer@zuum.in  → consumer app
  partner@zuum.in   → approved driver with an auto + earnings history
  fleet@zuum.in     → fleet owner with the Namma Fleet roster
"""
from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.core.management.base import BaseCommand
from django.utils import timezone

from apps.accounts.models import (
    CustomerProfile,
    DriverProfile,
    FleetPartner,
    KycDocument,
    User,
    Vehicle,
)
from apps.bookings.models import Booking
from apps.catalog.models import City, CommissionRule, PricingRule, PromoCampaign, ServiceCategory
from apps.payments.models import CommissionEntry, Payout, Wallet
from apps.platform.models import SystemSetting

PASSWORD = "zuum1234"

CATEGORIES = [
    # code, kind, name, seats, capacity_kg, volume, sort
    ("bike", "passenger", "Bike", 1, None, None, 10),
    ("auto", "passenger", "Auto", 3, None, None, 20),
    ("hatchback", "passenger", "Hatchback", 4, None, None, 30),
    ("sedan", "passenger", "Sedan", 4, None, None, 40),
    ("suv", "passenger", "SUV", 6, None, None, 50),
    ("premium", "passenger", "Premium", 4, None, None, 60),
    ("goods_2w", "goods", "2W Goods", None, 120, 18, 10),
    ("goods_3w", "goods", "3W Cargo", None, 500, 70, 20),
    ("ace", "goods", "Tata Ace", None, 750, 130, 30),
    ("pickup", "goods", "Pickup", None, 1250, 180, 40),
    ("van", "goods", "Van", None, 1000, 220, 50),
    ("tempo", "goods", "Tempo", None, 2500, 420, 60),
]

RATES = {
    "bike": (2000, 700, 80),
    "auto": (3000, 1100, 120),
    "hatchback": (4500, 1400, 150),
    "sedan": (5000, 1600, 170),
    "suv": (7000, 2000, 200),
    "premium": (9000, 2400, 240),
    "goods_2w": (3500, 1100, 120),
    "goods_3w": (5000, 1600, 150),
    "ace": (6500, 1900, 180),
    "pickup": (8500, 2200, 200),
    "van": (9000, 2300, 210),
    "tempo": (12000, 2800, 260),
}


class Command(BaseCommand):
    help = "Seed the demo catalog, pricing and personas (idempotent)."

    def handle(self, *args, **options):
        city, _ = City.objects.get_or_create(code="blr", defaults={"name": "Bengaluru"})
        categories = {}
        for code, kind, name, seats, capacity, volume, sort in CATEGORIES:
            category, _ = ServiceCategory.objects.update_or_create(
                code=code,
                defaults={
                    "kind": kind,
                    "name": name,
                    "seats": seats,
                    "capacity_kg": capacity,
                    "volume_cuft": volume,
                    "sort_order": sort,
                    "is_enabled": True,
                },
            )
            categories[code] = category
            base, per_km, per_min = RATES[code]
            PricingRule.objects.update_or_create(
                category=category,
                city=city,
                defaults={
                    "base_paise": base,
                    "per_km_paise": per_km,
                    "per_min_paise": per_min,
                    "min_fare_paise": max(base, 4000),
                    "goods_loading_fee_paise": 5000 if kind == "goods" else 0,
                },
            )
        CommissionRule.objects.get_or_create(
            category=None, city=None, defaults={"percent": Decimal("20.00")}
        )
        PromoCampaign.objects.update_or_create(
            code="WELCOME20",
            defaults={
                "kind": PromoCampaign.Kind.PERCENT,
                "value": 20,
                "max_discount_paise": 5000,
                "min_fare_paise": 0,
                "valid_to": timezone.now() + timedelta(days=90),
                "is_active": True,
            },
        )
        PromoCampaign.objects.update_or_create(
            code="FIRST100",
            defaults={
                "kind": PromoCampaign.Kind.FLAT,
                "value": 10000,
                "min_fare_paise": 20000,
                "valid_to": timezone.now() + timedelta(days=90),
                "is_active": True,
            },
        )
        SystemSetting.objects.update_or_create(
            key="feature_flags",
            defaults={
                "value": {
                    "surge_enabled": True,
                    "maintenance_mode": False,
                    "goods_enabled": True,
                }
            },
        )

        # personas -------------------------------------------------------------------
        customer = self._user("customer@zuum.in", "Aarav", "Menon", "9845011111", "customer")
        CustomerProfile.objects.get_or_create(user=customer)
        Wallet.objects.get_or_create(customer=customer)

        partner_user = self._user("partner@zuum.in", "Ravi", "Kumar", "9845012345", "driver")
        partner, _ = DriverProfile.objects.get_or_create(
            user=partner_user,
            defaults={
                "licence_number": "KA0120180012345",
                "languages": ["Kannada", "English"],
                "home_lat": 12.9352,
                "home_lng": 77.6245,
            },
        )
        partner.kyc_status = DriverProfile.KYC_APPROVED
        partner.approval_status = DriverProfile.APPROVAL_ACTIVE
        partner.submitted_at = partner.submitted_at or timezone.now()
        partner.reviewed_at = timezone.now()
        partner.rating_avg = Decimal("4.80")
        partner.rating_count = 126
        partner.online_state = DriverProfile.ONLINE_AVAILABLE
        partner.save()
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
                    "expires_at": (timezone.now() + timedelta(days=300)).date(),
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
        self._seed_partner_ledger(customer, partner)

        fleet_owner = self._user("fleet@zuum.in", "Namma", "Fleet", "9845022222", "fleet_owner")
        fleet, _ = FleetPartner.objects.get_or_create(
            owner=fleet_owner,
            defaults={"name": "Namma Fleet", "kyc_status": FleetPartner.KycStatus.APPROVED},
        )
        roster = [
            ("Suresh", "Babu", "9845033331", True, "auto", "KA03MK8890", Decimal("4.80"), 7),
            ("Manjunath", "H", "9845033332", True, "sedan", "KA51MN4477", Decimal("4.60"), 4),
            ("Lakshmi", "R", "9845033333", False, None, None, Decimal("4.90"), 0),
        ]
        for first, last, phone, online, code, plate, rating, trips in roster:
            user = self._user(
                f"{first.lower()}@fleet.zuum.in", first, last, phone, "driver"
            )
            driver, _ = DriverProfile.objects.get_or_create(
                user=user,
                defaults={
                    "fleet": fleet,
                    "languages": ["Kannada", "English"],
                    "home_lat": 12.97 + trips * 0.001,
                    "home_lng": 77.59 + trips * 0.001,
                },
            )
            driver.fleet = fleet
            driver.kyc_status = DriverProfile.KYC_APPROVED
            driver.approval_status = DriverProfile.APPROVAL_ACTIVE
            driver.rating_avg = rating
            driver.rating_count = 40 + trips
            driver.online_state = (
                DriverProfile.ONLINE_AVAILABLE
                if online and trips
                else DriverProfile.ONLINE_OFFLINE
            )
            driver.save()
            if code and plate:
                Vehicle.objects.update_or_create(
                    registration_number=plate,
                    defaults={
                        "driver": driver,
                        "fleet": fleet,
                        "category": categories[code],
                        "make": "Maruti" if code == "sedan" else "Bajaj",
                        "model": "Dzire" if code == "sedan" else "RE Auto",
                        "color": "White" if code == "sedan" else "Yellow",
                        "is_active": True,
                    },
                )

        self.stdout.write(self.style.SUCCESS("Seeded Zuum demo data."))
        self.stdout.write("  customer@zuum.in / zuum1234")
        self.stdout.write("  partner@zuum.in  / zuum1234")
        self.stdout.write("  fleet@zuum.in    / zuum1234")

    def _user(self, email, first, last, phone, role) -> User:
        user = User.objects.filter(email=email).first()
        if user is None:
            user = User.objects.create_user(
                email=email,
                password=PASSWORD,
                first_name=first,
                last_name=last,
                phone=phone,
                role=role,
            )
        else:
            user.first_name = first
            user.last_name = last
            user.phone = phone
            user.role = role
            user.set_password(PASSWORD)
            user.save()
        return user

    def _seed_partner_ledger(self, customer: User, partner: DriverProfile) -> None:
        if CommissionEntry.objects.filter(driver=partner).exists():
            return
        now = timezone.now()
        samples = [
            ("auto", "Auto", 22800, now - timedelta(hours=1)),
            ("bike", "Bike", 8600, now - timedelta(hours=4)),
            ("sedan", "Sedan", 23500, now - timedelta(days=1)),
            ("ace", "Tata Ace", 31200, now - timedelta(days=3)),
        ]
        for code, name, fare, at in samples:
            booking = Booking.objects.create(
                customer=customer,
                type="goods" if name == "Tata Ace" else "ride",
                service_category=ServiceCategory.objects.get(code=code),
                status=Booking.Status.COMPLETED,
                pickup_lat=12.9352,
                pickup_lng=77.6245,
                pickup_address="Koramangala 5th Block",
                drop_lat=12.9716,
                drop_lng=77.5946,
                drop_address="MG Road",
                distance_m=4800,
                duration_s=960,
                quoted_fare_paise=fare,
                final_fare_paise=fare,
                payment_state=Booking.PaymentState.PAID,
                completed_at=at,
            )
            Booking.objects.filter(pk=booking.pk).update(created_at=at)
            CommissionEntry.objects.create(
                booking=booking,
                driver=partner,
                platform_paise=int(round(fare * 0.2)),
                driver_paise=fare - int(round(fare * 0.2)),
                percent_snapshot=20,
                created_at=at,
            )
        Payout.objects.create(
            driver=partner,
            amount_paise=432000,
            method="bank",
            status=Payout.Status.PENDING,
            batch_ref="PO-2026-46",
        )
        Payout.objects.create(
            driver=partner,
            amount_paise=512000,
            method="bank",
            status=Payout.Status.PAID,
            paid_at=now - timedelta(days=7),
            batch_ref="PO-2026-45",
        )
