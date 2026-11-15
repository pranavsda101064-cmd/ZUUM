"""Partner surface: promotion, KYC, documents, vehicles, availability, fleet."""
from __future__ import annotations

from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.accounts.models import DriverProfile, FleetPartner, User, Vehicle
from apps.accounts.services import approve_driver
from apps.bookings.models import DispatchOffer
from apps.api.tests.base import PASSWORD, ZuumTestCase, make_partner, make_user, seed_catalog


class PartnerOnboardingTests(APITestCase):
    def setUp(self):
        from django.core.cache import cache

        cache.clear()
        self.user = make_user("newpartner@zuum.in")
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": self.user.email, "password": PASSWORD},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.data['access']}"
        )

    def test_first_profile_access_promotes_to_driver(self):
        response = self.client.get("/api/v1/partner/profile")
        self.assertEqual(response.status_code, 200, response.content)
        self.user.refresh_from_db()
        self.assertEqual(self.user.role, "driver")
        self.assertEqual(response.data["kyc_status"], "draft")
        self.assertTrue(DriverProfile.objects.filter(user=self.user).exists())

    def test_document_type_is_validated(self):
        self.client.get("/api/v1/partner/profile")
        response = self.client.post(
            "/api/v1/partner/documents",
            {
                "type": "licence",
                "file": SimpleUploadedFile(
                    "notes.txt", b"not-an-image", content_type="text/plain"
                ),
            },
            format="multipart",
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data["code"], "validation_error")

    def test_kyc_requires_all_documents_then_submits(self):
        self.client.get("/api/v1/partner/profile")
        missing = self.client.post("/api/v1/partner/kyc/submit")
        self.assertEqual(missing.status_code, 400)
        self.assertEqual(missing.data["code"], "kyc_incomplete")
        self.assertEqual(
            set(missing.data["details"]["missing"]), {"licence", "rc", "insurance"}
        )

        for doc_type in ("licence", "rc", "insurance"):
            upload = self.client.post(
                "/api/v1/partner/documents",
                {
                    "type": doc_type,
                    "file": SimpleUploadedFile(
                        f"{doc_type}.jpg", b"fake-image-bytes", content_type="image/jpeg"
                    ),
                },
                format="multipart",
            )
            self.assertEqual(upload.status_code, 201, upload.content)

        submitted = self.client.post("/api/v1/partner/kyc/submit")
        self.assertEqual(submitted.status_code, 200, submitted.content)
        self.assertEqual(submitted.data["status"], "submitted")

        # Approval is an ops action.
        driver = DriverProfile.objects.get(user=self.user)
        approve_driver(driver)
        detail = self.client.get("/api/v1/partner/kyc")
        self.assertEqual(detail.data["status"], "approved")


class PartnerOperationsTests(ZuumTestCase):
    def setUp(self):
        super().setUp()
        make_user("cust2@zuum.in")
        self.customer = self.client_for("cust2@zuum.in")
        self.driver = make_partner("ops@zuum.in", category_code="auto", online=True)
        self.partner = self.client_for("ops@zuum.in")

    def test_vehicle_duplicate_and_availability_toggle(self):
        duplicate = self.partner.post(
            "/api/v1/partner/vehicles",
            {
                "category": "auto",
                "registration_number": self.driver.vehicles.first().registration_number,
                "make": "Bajaj",
                "model": "RE Auto",
                "color": "Yellow",
            },
            format="json",
        )
        self.assertEqual(duplicate.status_code, 409)
        self.assertEqual(duplicate.data["code"], "already_exists")

        vehicles = self.partner.get("/api/v1/partner/vehicles")
        vehicle_id = vehicles.data[0]["id"]
        paused = self.partner.patch(
            f"/api/v1/partner/vehicles/{vehicle_id}/availability",
            {"is_active": False},
            format="json",
        )
        # A driver cannot pause the vehicle while online.
        self.assertEqual(paused.status_code, 409)

        offline = self.partner.post(
            "/api/v1/partner/availability", {"online": False}, format="json"
        )
        self.assertEqual(offline.status_code, 200)
        paused = self.partner.patch(
            f"/api/v1/partner/vehicles/{vehicle_id}/availability",
            {"is_active": False},
            format="json",
        )
        self.assertEqual(paused.status_code, 200, paused.content)
        self.assertFalse(paused.data["is_active"])

    def test_going_online_requires_approval_and_active_vehicle(self):
        driver = make_partner("pending@zuum.in", online=False, approved=False)
        client = self.client_for(driver.user.email)
        response = client.post(
            "/api/v1/partner/availability", {"online": True}, format="json"
        )
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.data["code"], "not_approved")

        approved_no_vehicle = make_partner("novehicle@zuum.in", online=False)
        approved_no_vehicle.vehicles.all().delete()
        client = self.client_for(approved_no_vehicle.user.email)
        response = client.post(
            "/api/v1/partner/availability", {"online": True}, format="json"
        )
        self.assertEqual(response.status_code, 409)
        self.assertEqual(response.data["code"], "vehicle_inactive")

    def test_expired_offer_cannot_be_accepted(self):
        self.create_ride(self.customer)
        offers = self.partner.get("/api/v1/partner/offers").data
        self.assertTrue(offers)
        DispatchOffer.objects.filter(pk=offers[0]["id"]).update(
            expires_at=timezone.now() - timedelta(seconds=1)
        )
        self.assertEqual(self.partner.get("/api/v1/partner/offers").data, [])
        response = self.partner.post(
            f"/api/v1/partner/offers/{offers[0]['id']}/accept"
        )
        self.assertEqual(response.status_code, 409)
        # The offers listing sweeps stale rows to `expired`, so accepting a
        # swept offer is either `offer_taken` or `offer_expired`.
        self.assertIn(response.data["code"], {"offer_expired", "offer_taken"})

    def test_decline_removes_offer(self):
        self.create_ride(self.customer)
        offers = self.partner.get("/api/v1/partner/offers").data
        declined = self.partner.post(
            f"/api/v1/partner/offers/{offers[0]['id']}/decline",
            {"reason": "Far away"},
            format="json",
        )
        self.assertEqual(declined.status_code, 204)
        self.assertEqual(self.partner.get("/api/v1/partner/offers").data, [])
        offer = DispatchOffer.objects.get(pk=offers[0]["id"])
        self.assertEqual(offer.status, DispatchOffer.Status.REJECTED)

    def test_active_trip_and_stats(self):
        self.assertEqual(
            self.partner.get("/api/v1/partner/bookings/active").data["trip"], None
        )
        booking = self.create_ride(self.customer)
        self.accept_first_offer(self.partner)
        active = self.partner.get("/api/v1/partner/bookings/active")
        self.assertEqual(active.data["trip"]["booking_id"], booking["id"])
        self.assertEqual(active.data["trip"]["status"], "ASSIGNED")

        stats = self.partner.get("/api/v1/partner/stats")
        self.assertEqual(stats.status_code, 200)
        self.assertEqual(len(stats.data["weekly_trend"]), 7)

    def test_payouts_listed(self):
        from apps.payments.services import create_payout

        create_payout(driver=self.driver, amount_paise=432000)
        response = self.partner.get("/api/v1/partner/payouts")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["count"], 1)
        self.assertEqual(response.data["results"][0]["status"], "pending")


class FleetTests(APITestCase):
    def setUp(self):
        from django.core.cache import cache

        cache.clear()
        self.categories = seed_catalog()
        self.owner = make_user("fleetowner@zuum.in", role="fleet_owner")
        self.fleet = FleetPartner.objects.create(owner=self.owner, name="Test Fleet")
        partner = make_partner("fleetdriver@zuum.in", category_code="auto")
        partner.fleet = self.fleet
        partner.save(update_fields=["fleet"])
        partner.vehicles.all().update(fleet=self.fleet)
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": self.owner.email, "password": PASSWORD},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.data['access']}"
        )

    def test_overview_and_roster(self):
        overview = self.client.get("/api/v1/fleet/overview")
        self.assertEqual(overview.status_code, 200, overview.content)
        self.assertEqual(overview.data["drivers_total"], 1)
        self.assertEqual(overview.data["drivers_active"], 1)
        self.assertEqual(overview.data["vehicles_total"], 1)

        roster = self.client.get("/api/v1/fleet/drivers")
        self.assertEqual(roster.status_code, 200)
        self.assertEqual(roster.data["count"], 1)
        driver = roster.data["results"][0]
        self.assertTrue(driver["online"])
        self.assertTrue(driver["is_verified"])
        self.assertIsNotNone(driver["vehicle_registration"])

    def test_assign_and_detach(self):
        driver = DriverProfile.objects.get(user__email="fleetdriver@zuum.in")
        vehicles = self.client.get("/api/v1/fleet/vehicles").data
        self.assertEqual(len(vehicles), 1)
        assigned = self.client.put(
            f"/api/v1/fleet/vehicles/{vehicles[0]['id']}/assign",
            {"driver_id": str(driver.id)},
            format="json",
        )
        self.assertEqual(assigned.status_code, 200, assigned.content)
        detached = self.client.delete(f"/api/v1/fleet/drivers/{driver.id}")
        self.assertEqual(detached.status_code, 204)
        driver.refresh_from_db()
        self.assertIsNone(driver.fleet)

    def test_invite_existing_user_notifies(self):
        make_user("invitee@zuum.in")
        response = self.client.post(
            "/api/v1/fleet/drivers/invite",
            {"email": "invitee@zuum.in"},
            format="json",
        )
        self.assertEqual(response.status_code, 202)
        from apps.platform.models import Notification

        self.assertTrue(
            Notification.objects.filter(
                user__email="invitee@zuum.in", type="fleet_invite"
            ).exists()
        )
