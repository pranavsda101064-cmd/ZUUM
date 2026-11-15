"""Ops/admin surface used by the Flutter Web dashboard."""
from __future__ import annotations

import tempfile

from django.core.cache import cache
from django.core.files.uploadedfile import SimpleUploadedFile
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.accounts.models import DriverProfile, KycDocument, User
from apps.api.tests.base import PASSWORD, make_partner, make_user, seed_catalog
from apps.payments.models import Payout
from apps.platform.models import AuditLog, Notification, SupportMessage, SupportTicket


class OpsApiTests(APITestCase):
    def setUp(self):
        cache.clear()
        seed_catalog()
        self.staff = User.objects.create_user(
            email="ops@zuum.in",
            password=PASSWORD,
            first_name="Ops",
            last_name="Desk",
            role="staff",
            is_staff=True,
            is_superuser=True,
        )
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": "ops@zuum.in", "password": PASSWORD},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.data['access']}"
        )

    def test_customer_cannot_use_ops(self):
        make_user("nosy@zuum.in")
        other = APITestCase().client_class()
        login = other.post(
            "/api/v1/auth/login",
            {"email": "nosy@zuum.in", "password": PASSWORD},
            format="json",
        )
        other.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        response = other.get("/api/v1/ops/overview")
        self.assertEqual(response.status_code, 403)
        self.assertEqual(response.data["code"], "permission_denied")

    def test_request_id_header(self):
        response = self.client.get("/api/v1/health")
        self.assertIn("X-Request-ID", response.headers)

    def test_analytics_series(self):
        from apps.bookings.models import Booking
        from apps.catalog.models import ServiceCategory
        from apps.payments.models import CommissionEntry

        customer = make_user("analytics-customer@zuum.in")
        booking = Booking.objects.create(
            customer=customer,
            type="ride",
            service_category=ServiceCategory.objects.get(code="auto"),
            status=Booking.Status.COMPLETED,
            pickup_lat=12.93,
            pickup_lng=77.62,
            pickup_address="A",
            drop_lat=12.97,
            drop_lng=77.59,
            drop_address="B",
            distance_m=4800,
            duration_s=900,
            quoted_fare_paise=20000,
            final_fare_paise=20000,
            completed_at=timezone.now(),
        )
        driver = make_partner("analytics-driver@zuum.in", online=False)
        CommissionEntry.objects.create(
            booking=booking,
            driver=driver,
            platform_paise=4000,
            driver_paise=16000,
        )
        response = self.client.get("/api/v1/ops/analytics?range=week")
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(len(response.data["series"]), 7)
        self.assertEqual(response.data["totals"]["trips"], 1)
        self.assertEqual(response.data["top_categories"][0]["name"], "Auto")

    def test_overview_shape(self):
        response = self.client.get("/api/v1/ops/overview")
        self.assertEqual(response.status_code, 200, response.content)
        for key in (
            "bookings_today",
            "active_by_status",
            "online_drivers",
            "completed_today",
            "revenue_today_paise",
            "commission_today_paise",
            "open_tickets",
            "active_sos",
            "payouts_pending_paise",
        ):
            self.assertIn(key, response.data)

    def test_driver_approval_workflow(self):
        driver = make_partner("pending@zuum.in", approved=False, online=False)
        for doc_type in (
            KycDocument.Type.LICENCE,
            KycDocument.Type.RC,
            KycDocument.Type.INSURANCE,
        ):
            KycDocument.objects.create(
                driver=driver,
                type=doc_type,
                status=KycDocument.Status.VERIFIED,
            )
        listing = self.client.get("/api/v1/ops/drivers?kyc=submitted")
        self.assertEqual(listing.status_code, 200)
        self.assertEqual(listing.data["count"], 1)

        rejected = self.client.post(
            f"/api/v1/ops/drivers/{driver.id}/reject",
            {"reason": "Licence photo is blurred"},
            format="json",
        )
        self.assertEqual(rejected.status_code, 200, rejected.content)
        driver.refresh_from_db()
        self.assertEqual(driver.kyc_status, DriverProfile.KYC_REJECTED)

        approved = self.client.post(f"/api/v1/ops/drivers/{driver.id}/approve")
        self.assertEqual(approved.status_code, 200, approved.content)
        driver.refresh_from_db()
        self.assertEqual(driver.approval_status, DriverProfile.APPROVAL_ACTIVE)
        self.assertTrue(
            Notification.objects.filter(
                user=driver.user, title="You are approved"
            ).exists()
        )
        self.assertTrue(
            AuditLog.objects.filter(action="driver.approve").exists()
        )

        suspended = self.client.post(f"/api/v1/ops/drivers/{driver.id}/suspend")
        self.assertEqual(suspended.status_code, 200)
        driver.refresh_from_db()
        self.assertEqual(driver.approval_status, DriverProfile.APPROVAL_SUSPENDED)

    def test_reject_requires_reason(self):
        driver = make_partner("rej@zuum.in", approved=False, online=False)
        response = self.client.post(f"/api/v1/ops/drivers/{driver.id}/reject")
        self.assertEqual(response.status_code, 400)

    def test_manual_document_review_and_file_preview(self):
        with tempfile.TemporaryDirectory() as media_root:
            with self.settings(MEDIA_ROOT=media_root):
                driver = make_partner(
                    "docs@zuum.in", approved=False, online=False
                )
                documents = {}
                for doc_type in (
                    KycDocument.Type.LICENCE,
                    KycDocument.Type.RC,
                    KycDocument.Type.INSURANCE,
                ):
                    documents[doc_type] = KycDocument.objects.create(
                        driver=driver,
                        type=doc_type,
                        file=SimpleUploadedFile(
                            f"{doc_type}.jpg",
                            b"fake-image-bytes",
                            content_type="image/jpeg",
                        ),
                    )

                detail = self.client.get(f"/api/v1/ops/drivers/{driver.id}")
                self.assertEqual(detail.status_code, 200, detail.content)
                self.assertEqual(len(detail.data["documents"]), 3)
                licence = next(
                    doc
                    for doc in detail.data["documents"]
                    if doc["type"] == "licence"
                )
                self.assertTrue(licence["file_available"])

                preview = self.client.get(
                    f"/api/v1/ops/documents/{documents[KycDocument.Type.LICENCE].id}/file"
                )
                self.assertEqual(preview.status_code, 200)
                self.assertEqual(preview["Content-Type"], "image/jpeg")
                b"".join(preview.streaming_content)
                preview.close()

                no_note = self.client.post(
                    f"/api/v1/ops/documents/{documents[KycDocument.Type.RC].id}/review",
                    {"status": "rejected"},
                    format="json",
                )
                self.assertEqual(no_note.status_code, 400)

                approved = self.client.post(
                    f"/api/v1/ops/documents/{documents[KycDocument.Type.LICENCE].id}/review",
                    {"status": "verified", "note": "Clear photo"},
                    format="json",
                )
                self.assertEqual(approved.status_code, 200, approved.content)
                self.assertEqual(approved.data["status"], "verified")

                blocked = self.client.post(
                    f"/api/v1/ops/drivers/{driver.id}/approve"
                )
                self.assertEqual(blocked.status_code, 409)
                self.assertEqual(blocked.data["code"], "documents_unverified")

                for doc_type in (
                    KycDocument.Type.RC,
                    KycDocument.Type.INSURANCE,
                ):
                    verified = self.client.post(
                        f"/api/v1/ops/documents/{documents[doc_type].id}/review",
                        {"status": "verified"},
                        format="json",
                    )
                    self.assertEqual(verified.status_code, 200)

                final = self.client.post(f"/api/v1/ops/drivers/{driver.id}/approve")
                self.assertEqual(final.status_code, 200, final.content)
                driver.refresh_from_db()
                self.assertEqual(
                    driver.approval_status, DriverProfile.APPROVAL_ACTIVE
                )

    def test_payouts_marking_paid_notifies(self):
        driver = make_partner("pay@zuum.in", online=False)
        payout = Payout.objects.create(driver=driver, amount_paise=432000)
        listing = self.client.get("/api/v1/ops/payouts?status=pending")
        self.assertEqual(listing.data["count"], 1)
        paid = self.client.post(f"/api/v1/ops/payouts/{payout.id}/mark-paid")
        self.assertEqual(paid.status_code, 200, paid.content)
        payout.refresh_from_db()
        self.assertEqual(payout.status, Payout.Status.PAID)
        self.assertIsNotNone(payout.paid_at)
        self.assertTrue(
            Notification.objects.filter(user=driver.user, type="payout").exists()
        )
        again = self.client.post(f"/api/v1/ops/payouts/{payout.id}/mark-paid")
        self.assertEqual(again.status_code, 409)

    def test_promo_crud_and_settings(self):
        created = self.client.post(
            "/api/v1/ops/promos",
            {
                "code": "ops25",
                "kind": "percent",
                "value": 25,
                "max_discount_paise": 7500,
                "min_fare_paise": 10000,
                "per_user_limit": 2,
                "is_active": True,
            },
            format="json",
        )
        self.assertEqual(created.status_code, 201, created.content)
        self.assertEqual(created.data["code"], "OPS25")

        patched = self.client.patch(
            f"/api/v1/ops/promos/{created.data['id']}",
            {"is_active": False},
            format="json",
        )
        self.assertEqual(patched.status_code, 200)
        self.assertFalse(patched.data["is_active"])

        settings = self.client.put(
            "/api/v1/ops/settings",
            {"feature_flags": {"surge_enabled": False}},
            format="json",
        )
        self.assertEqual(settings.status_code, 200)
        again = self.client.get("/api/v1/ops/settings")
        self.assertEqual(
            again.data["feature_flags"], {"surge_enabled": False}
        )

    def test_ticket_reply_flow(self):
        make_user("ticket@zuum.in")
        ticket = SupportTicket.objects.create(
            customer=User.objects.get(email="ticket@zuum.in"),
            category="fare",
            subject="Refund",
        )
        reply = self.client.post(
            f"/api/v1/ops/tickets/{ticket.id}",
            {"message": "We have processed your refund.", "status": "resolved"},
            format="json",
        )
        self.assertEqual(reply.status_code, 200, reply.content)
        ticket.refresh_from_db()
        self.assertEqual(ticket.status, SupportTicket.Status.RESOLVED)
        self.assertEqual(ticket.messages.count(), 1)
        self.assertTrue(
            Notification.objects.filter(
                user=ticket.customer, type="support"
            ).exists()
        )
        self.assertEqual(
            self.client.get(f"/api/v1/ops/tickets/{ticket.id}").data["messages"][0][
                "author"
            ],
            "ops",
        )

    def test_bookings_and_finance(self):
        booking_list = self.client.get("/api/v1/ops/bookings")
        self.assertEqual(booking_list.status_code, 200)
        finance = self.client.get("/api/v1/ops/finance/summary?range=month")
        self.assertEqual(finance.status_code, 200)
        for key in ("trips", "gross_paise", "commission_paise", "driver_paise"):
            self.assertIn(key, finance.data)
        self.assertEqual(self.client.get("/api/v1/ops/audit").status_code, 200)
