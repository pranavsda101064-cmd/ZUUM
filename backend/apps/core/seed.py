"""Shared catalog seeding for demo + production test commands."""
from __future__ import annotations

from datetime import timedelta
from decimal import Decimal

from django.utils import timezone

from apps.catalog.models import (
    City,
    CommissionRule,
    PricingRule,
    PromoCampaign,
    ServiceCategory,
)
from apps.platform.models import SystemSetting

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


def seed_catalog() -> dict[str, ServiceCategory]:
    city, _ = City.objects.get_or_create(code="blr", defaults={"name": "Bengaluru"})
    categories: dict[str, ServiceCategory] = {}
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
    return categories
