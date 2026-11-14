"""Shared test helpers: catalog seed + actor clients."""
from __future__ import annotations

from datetime import timedelta

from django.utils import timezone
from rest_framework.test import APIClient, APITestCase

from apps.accounts.models import (
    CustomerProfile,
    DriverProfile,
    KycDocument,
    User,
    Vehicle,
)
from apps.catalog.models import City, CommissionRule, PricingRule, ServiceCategory

PASSWORD = "zuum1234"


def seed_catalog() -> dict[str, ServiceCategory]:
    City.objects.get_or_create(code="blr", defaults={"name": "Bengaluru"})
    specs = [
        ("bike", "passenger", "Bike", 1, 2000, 700, 80),
        ("auto", "passenger", "Auto", 3, 3000, 1100, 120),
        ("sedan", "passenger", "Sedan", 4, 5000, 1600, 170),
        ("goods_3w", "goods", "3W Cargo", None, 5000, 1600, 150),
    ]
    categories: dict[str, ServiceCategory] = {}
    for code, kind, name, seats, base, per_km, per_min in specs:
        category, _ = ServiceCategory.objects.get_or_create(
            code=code,
            defaults={"kind": kind, "name": name, "seats": seats},
        )
        categories[code] = category
        PricingRule.objects.get_or_create(
            category=category,
            city=None,
            defaults={
                "base_paise": base,
                "per_km_paise": per_km,
                "per_min_paise": per_min,
                "min_fare_paise": max(base, 4000),
                "goods_loading_fee_paise": 5000 if kind == "goods" else 0,
            },
        )
    CommissionRule.objects.get_or_create(
        category=None, city=None, defaults={"percent": 20}
    )
    return categories


def make_user(email: str, *, role: str = "customer", phone: str = "9845012345") -> User:
    user = User.objects.create_user(
        email=email,
        password=PASSWORD,
        first_name="Test",
        last_name=role.title(),
        phone=phone,
        role=role,
    )
    if role == "customer":
        CustomerProfile.objects.get_or_create(user=user)
    return user


def make_partner(
    email: str = "driver@zuum.in",
    *,
    category_code: str = "auto",
    online: bool = True,
    approved: bool = True,
) -> DriverProfile:
    user = make_user(email, role="driver")
    driver = DriverProfile.objects.create(
        user=user,
        licence_number="KA0120180012345",
        kyc_status=DriverProfile.KYC_APPROVED if approved else DriverProfile.KYC_SUBMITTED,
        approval_status=(
            DriverProfile.APPROVAL_ACTIVE if approved else DriverProfile.APPROVAL_PENDING
        ),
        online_state=(
            DriverProfile.ONLINE_AVAILABLE if online else DriverProfile.ONLINE_OFFLINE
        ),
        home_lat=12.9352,
        home_lng=77.6245,
        languages=["Kannada", "English"],
    )
    if approved:
        for doc_type in (
            KycDocument.Type.LICENCE,
            KycDocument.Type.RC,
            KycDocument.Type.INSURANCE,
        ):
            KycDocument.objects.create(driver=driver, type=doc_type)
        Vehicle.objects.create(
            driver=driver,
            category=ServiceCategory.objects.get(code=category_code),
            registration_number=f"KA05AB{abs(hash(email)) % 9000 + 1000}",
            make="Bajaj",
            model="RE Auto",
            color="Yellow",
            is_active=True,
        )
    return driver


class ZuumTestCase(APITestCase):
    @classmethod
    def setUpTestData(cls):
        cls.categories = seed_catalog()

    def setUp(self):
        from django.core.cache import cache

        cache.clear()  # isolate throttle counters between tests

    def client_for(self, email: str) -> APIClient:
        client = APIClient()
        response = client.post(
            "/api/v1/auth/login",
            {"email": email, "password": PASSWORD},
            format="json",
        )
        assert response.status_code == 200, response.content
        client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {response.data['access']}"
        )
        return client

    def quote(self, client: APIClient, category: str = "auto", kind: str = "ride"):
        response = client.post(
            "/api/v1/pricing/quote",
            {
                "kind": kind,
                "service_category": category,
                "pickup": {"lat": 12.9352, "lng": 77.6245, "address": "Koramangala"},
                "drop": {"lat": 12.9716, "lng": 77.5946, "address": "MG Road"},
            },
            format="json",
        )
        assert response.status_code == 201, response.content
        return response.data

    def create_ride(
        self,
        customer_client: APIClient,
        *,
        category: str = "auto",
        promo_code: str | None = None,
        payment_method: str = "cash",
    ):
        quote = self.quote(customer_client, category=category)
        payload = {
            "quote_id": quote["id"],
            "pickup": {
                "lat": 12.9352,
                "lng": 77.6245,
                "address": "Koramangala 5th Block",
            },
            "drop": {"lat": 12.9716, "lng": 77.5946, "address": "MG Road"},
            "payment_method": payment_method,
        }
        if promo_code:
            payload["promo_code"] = promo_code
        response = customer_client.post("/api/v1/bookings", payload, format="json")
        assert response.status_code == 201, response.content
        return response.data

    def create_goods(
        self,
        customer_client: APIClient,
        *,
        category: str = "goods_3w",
        payment_method: str = "cash",
    ):
        quote = self.quote(customer_client, category=category, kind="goods")
        response = customer_client.post(
            "/api/v1/bookings",
            {
                "quote_id": quote["id"],
                "payment_method": payment_method,
                "goods": {
                    "goods_type": "Furniture",
                    "weight_kg": 120,
                    "needs_loading_help": True,
                    "sender_name": "Aarav",
                    "sender_phone": "9845011111",
                    "receiver_name": "Meera",
                    "receiver_phone": "9845022222",
                },
            },
            format="json",
        )
        assert response.status_code == 201, response.content
        return response.data

    def accept_first_offer(self, partner_client: APIClient) -> dict:
        offers = partner_client.get("/api/v1/partner/offers")
        assert offers.status_code == 200, offers.content
        assert offers.data, "no offers dispatched"
        response = partner_client.post(
            f"/api/v1/partner/offers/{offers.data[0]['id']}/accept"
        )
        assert response.status_code == 200, response.content
        return response.data

    @staticmethod
    def open_trip_payload(booking: dict) -> dict:
        from apps.bookings.models import Booking

        return Booking.objects.get(pk=booking["id"])
