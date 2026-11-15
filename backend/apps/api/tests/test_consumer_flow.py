"""Consumer journey: quote → book → dispatch → driver lifecycle → receipt."""
from datetime import timedelta

from django.core.files.uploadedfile import SimpleUploadedFile
from django.utils import timezone
from apps.api.tests.base import ZuumTestCase, make_user, make_partner


class ConsumerFlowTests(ZuumTestCase):
    def setUp(self):
        make_user("customer@zuum.in")
        self.customer = self.client_for("customer@zuum.in")
        self.driver = make_partner("driver@zuum.in", category_code="auto")
        self.partner = self.client_for("driver@zuum.in")

    def test_catalog_and_quote(self):
        categories = self.customer.get("/api/v1/service-categories?kind=ride")
        self.assertEqual(categories.status_code, 200)
        codes = {c["code"] for c in categories.data}
        self.assertIn("auto", codes)
        self.assertIn("bike", codes)

        quote = self.quote(self.customer)
        self.assertGreater(quote["total_paise"], 0)
        self.assertGreater(quote["distance_m"], 0)
        self.assertEqual(
            set(quote["breakdown"]),
            {
                "base_paise",
                "distance_paise",
                "time_paise",
                "surge_paise",
                "toll_paise",
                "waiting_paise",
                "loading_paise",
                "discount_paise",
                "total_paise",
                "surge_multiplier",
                "night_multiplier",
            },
        )

    def test_booking_dispatches_offer_and_full_lifecycle(self):
        booking = self.create_ride(self.customer)
        self.assertEqual(booking["status"], "SEARCHING")
        self.assertEqual(booking["type"], "ride")

        offers = self.partner.get("/api/v1/partner/offers")
        self.assertEqual(offers.status_code, 200)
        self.assertEqual(len(offers.data), 1)
        offer = offers.data[0]
        self.assertEqual(offer["booking_id"], booking["id"])
        self.assertTrue(offer["expires_in_s"] > 0)

        accepted = self.accept_first_offer(self.partner)
        self.assertEqual(accepted["status"], "ASSIGNED")

        notifications = self.customer.get("/api/v1/notifications?unread=true")
        titles = [row["title"] for row in notifications.data["results"]]
        self.assertIn("Captain on the way", titles)

        detail = self.customer.get(f"/api/v1/bookings/{booking['id']}")
        self.assertEqual(detail.data["status"], "ASSIGNED")
        self.assertIsNotNone(detail.data["driver"])
        self.assertEqual(detail.data["driver"]["name"], "Test Driver")

        # cannot complete before arrival/OTP
        illegal = self.partner.post(
            f"/api/v1/partner/bookings/{booking['id']}/complete"
        )
        self.assertEqual(illegal.status_code, 409)
        self.assertEqual(illegal.data["code"], "illegal_transition")

        arrive = self.partner.post(
            f"/api/v1/partner/bookings/{booking['id']}/arrive"
        )
        self.assertEqual(arrive.status_code, 200)
        self.assertEqual(arrive.data["status"], "ARRIVED")

        bad_otp = self.partner.post(
            f"/api/v1/partner/bookings/{booking['id']}/verify-otp",
            {"otp": "0000"},
            format="json",
        )
        self.assertEqual(bad_otp.status_code, 400)
        self.assertEqual(bad_otp.data["code"], "otp_invalid")

        from apps.bookings.models import Booking

        trip = Booking.objects.get(pk=booking["id"]).passenger_trip
        started = self.partner.post(
            f"/api/v1/partner/bookings/{booking['id']}/verify-otp",
            {"otp": trip.start_otp},
            format="json",
        )
        self.assertEqual(started.status_code, 200, started.content)
        self.assertEqual(started.data["status"], "IN_PROGRESS")

        completed = self.partner.post(
            f"/api/v1/partner/bookings/{booking['id']}/complete"
        )
        self.assertEqual(completed.status_code, 200, completed.content)
        self.assertEqual(completed.data["status"], "COMPLETED")
        self.assertGreater(completed.data["commission_paise"], 0)
        self.assertEqual(
            completed.data["commission_paise"] + completed.data["earning_paise"],
            completed.data["fare_paise"],
        )

        detail = self.customer.get(f"/api/v1/bookings/{booking['id']}")
        self.assertEqual(detail.data["status"], "COMPLETED")

        notifications = self.customer.get("/api/v1/notifications")
        titles = [row["title"] for row in notifications.data["results"]]
        self.assertIn("Trip completed", titles)
        self.assertGreaterEqual(notifications.data["unread_count"], 1)

        receipt = self.customer.get(f"/api/v1/bookings/{booking['id']}/receipt")
        self.assertEqual(receipt.status_code, 200)
        self.assertEqual(receipt.data["fare"]["final_paise"], booking["fare"]["quoted_paise"])
        self.assertIsNotNone(receipt.data["commission"])

        rate = self.customer.post(
            f"/api/v1/bookings/{booking['id']}/rate",
            {"rating": 5, "comment": "Smooth ride"},
            format="json",
        )
        self.assertEqual(rate.status_code, 201, rate.content)

        self.driver.refresh_from_db()
        self.assertEqual(float(self.driver.rating_avg), 5.0)

        earnings = self.partner.get("/api/v1/partner/earnings?range=month")
        self.assertEqual(earnings.status_code, 200)
        self.assertEqual(earnings.data["trips"], 1)
        self.assertGreater(earnings.data["net_paise"], 0)

    def test_offer_accept_twice_is_conflict(self):
        self.create_ride(self.customer)
        offers = self.partner.get("/api/v1/partner/offers").data
        self.partner.post(f"/api/v1/partner/offers/{offers[0]['id']}/accept")
        again = self.partner.post(
            f"/api/v1/partner/offers/{offers[0]['id']}/accept"
        )
        self.assertEqual(again.status_code, 409)
        self.assertIn(again.data["code"], {"offer_taken", "offer_expired"})

    def test_stale_search_fails_on_read(self):
        booking = self.create_ride(self.customer)
        from apps.bookings.models import Booking

        Booking.objects.filter(pk=booking["id"]).update(
            created_at=timezone.now() - timedelta(minutes=10)
        )
        detail = self.customer.get(f"/api/v1/bookings/{booking['id']}")
        self.assertEqual(detail.data["status"], "FAILED")

    def test_cancel_booking(self):
        booking = self.create_ride(self.customer)
        cancelled = self.customer.post(
            f"/api/v1/bookings/{booking['id']}/cancel",
            {"reason": "Changed my mind"},
            format="json",
        )
        self.assertEqual(cancelled.status_code, 200)
        self.assertEqual(cancelled.data["status"], "CANCELLED")

        offers = self.partner.get("/api/v1/partner/offers")
        self.assertEqual(offers.data, [])

    def test_goods_booking_requires_pod_otp(self):
        make_partner("goods@zuum.in", category_code="goods_3w")
        goods_client = self.client_for("goods@zuum.in")
        booking = self.create_goods(self.customer)
        self.assertEqual(booking["type"], "goods")

        offers = goods_client.get("/api/v1/partner/offers").data
        self.assertTrue(offers)
        goods_client.post(f"/api/v1/partner/offers/{offers[0]['id']}/accept")
        goods_client.post(f"/api/v1/partner/bookings/{booking['id']}/arrive")

        from apps.bookings.models import Booking

        shipment = Booking.objects.get(pk=booking["id"]).shipment
        start = goods_client.post(
            f"/api/v1/partner/bookings/{booking['id']}/verify-otp",
            {"otp": shipment.pickup_otp},
            format="json",
        )
        self.assertEqual(start.status_code, 200, start.content)
        self.assertEqual(start.data["status"], "IN_PROGRESS")

        blocked = goods_client.post(
            f"/api/v1/partner/bookings/{booking['id']}/complete"
        )
        self.assertEqual(blocked.status_code, 409)
        self.assertEqual(blocked.data["code"], "pod_missing")

        bad = goods_client.post(
            f"/api/v1/partner/bookings/{booking['id']}/verify-delivery-otp",
            {"otp": "0000"},
            format="json",
        )
        self.assertEqual(bad.status_code, 400)

        verified = goods_client.post(
            f"/api/v1/partner/bookings/{booking['id']}/verify-delivery-otp",
            {"otp": shipment.delivery_otp},
            format="json",
        )
        self.assertEqual(verified.status_code, 200, verified.content)

        pod = self.customer.post(
            f"/api/v1/bookings/{booking['id']}/pod",
            {
                "otp": shipment.delivery_otp,
                "receiver_name": "Meera",
                "photo": SimpleUploadedFile(
                    "drop.jpg", b"fake-photo", content_type="image/jpeg"
                ),
                "signature": SimpleUploadedFile(
                    "sig.png", b"fake-signature", content_type="image/png"
                ),
            },
            format="multipart",
        )
        self.assertEqual(pod.status_code, 200, pod.content)
        self.assertTrue(pod.data["recorded"])
        shipment.refresh_from_db()
        self.assertEqual(shipment.pod_receiver, "Meera")
        self.assertIsNotNone(shipment.pod_signed_at)

        done = goods_client.post(
            f"/api/v1/partner/bookings/{booking['id']}/complete"
        )
        self.assertEqual(done.status_code, 200, done.content)
        self.assertEqual(done.data["status"], "COMPLETED")

    def test_promo_validation_and_booking_discount(self):
        from apps.catalog.models import PromoCampaign

        PromoCampaign.objects.create(
            code="WELCOME20",
            kind=PromoCampaign.Kind.PERCENT,
            value=20,
            max_discount_paise=5000,
        )
        quote = self.quote(self.customer)
        validate = self.customer.post(
            "/api/v1/promos/validate",
            {
                "code": "welcome20",
                "fare_paise": quote["total_paise"],
                "service_category": "auto",
            },
            format="json",
        )
        self.assertEqual(validate.status_code, 200, validate.content)
        self.assertGreater(validate.data["discount_paise"], 0)

        booking = self.create_ride(self.customer, promo_code="WELCOME20")
        self.assertEqual(booking["promo_code"], "WELCOME20")
        self.assertGreater(booking["discount_paise"], 0)
        self.assertEqual(
            booking["fare"]["quoted_paise"],
            quote["total_paise"] - booking["discount_paise"],
        )

    def test_wallet_topup_and_booking_payment(self):
        topup = self.customer.post(
            "/api/v1/wallet/topup", {"amount_paise": 50000}, format="json"
        )
        self.assertEqual(topup.status_code, 201, topup.content)
        self.assertEqual(topup.data["balance_paise"], 50000)

        wallet = self.customer.get("/api/v1/wallet")
        self.assertEqual(wallet.data["balance_paise"], 50000)

        booking = self.create_ride(self.customer, payment_method="upi")
        order = self.customer.post(
            "/api/v1/payments/orders",
            {"booking_id": booking["id"], "amount_paise": booking["fare"]["quoted_paise"]},
            format="json",
        )
        self.assertEqual(order.status_code, 201, order.content)
        verify = self.customer.post(
            "/api/v1/payments/verify",
            {
                "booking_id": booking["id"],
                "razorpay_order_id": order.data["order_id"],
                "razorpay_payment_id": "pay_mock_test",
            },
            format="json",
        )
        self.assertEqual(verify.status_code, 200, verify.content)
        self.assertEqual(verify.data["status"], "captured")

    def test_support_and_notifications(self):
        topics = self.customer.get("/api/v1/support/topics")
        self.assertEqual(topics.status_code, 200)
        self.assertGreaterEqual(len(topics.data), 4)

        ticket = self.customer.post(
            "/api/v1/support/tickets",
            {"category": "fare", "subject": "Refund", "message": "Please help"},
            format="json",
        )
        self.assertEqual(ticket.status_code, 201, ticket.content)
        detail = self.customer.get(f"/api/v1/support/tickets/{ticket.data['id']}")
        self.assertEqual(len(detail.data["messages"]), 1)

        sos = self.customer.post("/api/v1/safety/sos", {}, format="json")
        self.assertEqual(sos.status_code, 201)
        self.assertIn("helplines", sos.data)

        notifications = self.customer.get("/api/v1/notifications")
        self.assertEqual(notifications.status_code, 200)
        self.assertGreaterEqual(notifications.data["count"], 1)
