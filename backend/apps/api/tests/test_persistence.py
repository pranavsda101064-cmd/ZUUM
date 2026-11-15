"""Entered profile data is persisted by the backend, not only locally."""
from apps.api.tests.base import ZuumTestCase, make_partner, make_user


class PersistenceTests(ZuumTestCase):
    def setUp(self):
        make_user("customer@zuum.in")
        self.customer = self.client_for("customer@zuum.in")

    def test_profile_gst_and_trusted_contacts_persist(self):
        updated = self.customer.put(
            "/api/v1/auth/me",
            {"first_name": "Asha", "last_name": "Rao", "phone": "9845000001"},
            format="json",
        )
        self.assertEqual(updated.status_code, 200)
        self.assertEqual(updated.data["user"]["first_name"], "Asha")

        me = self.customer.get("/api/v1/auth/me")
        self.assertEqual(me.data["user"]["first_name"], "Asha")
        self.assertEqual(me.data["user"]["phone"], "9845000001")

        saved = self.customer.put(
            "/api/v1/customers/me",
            {"gstin": "29ABCDE1234F1Z5", "business_name": "Rao Traders"},
            format="json",
        )
        self.assertEqual(saved.status_code, 200)
        self.assertEqual(saved.data["gstin"], "29ABCDE1234F1Z5")

        details = self.customer.get("/api/v1/customers/me")
        self.assertEqual(details.data["business_name"], "Rao Traders")

        contact = self.customer.post(
            "/api/v1/customers/me/trusted-contacts",
            {"name": "Amma", "phone": "+919845000002"},
            format="json",
        )
        self.assertEqual(contact.status_code, 201)
        listed = self.customer.get("/api/v1/customers/me/trusted-contacts")
        self.assertEqual(len(listed.data), 1)
        self.assertEqual(listed.data[0]["name"], "Amma")

        deleted = self.customer.delete(
            f"/api/v1/customers/me/trusted-contacts/{contact.data['id']}"
        )
        self.assertEqual(deleted.status_code, 204)
        self.assertEqual(
            self.customer.get("/api/v1/customers/me/trusted-contacts").data,
            [],
        )

    def test_partner_payout_and_notification_preference_persist(self):
        make_partner("payout@zuum.in")
        partner = self.client_for("payout@zuum.in")

        saved = partner.put(
            "/api/v1/partner/payout-account",
            {
                "holder_name": "Ravi Kumar",
                "account_number": "123456789012",
                "ifsc": "HDFC0001234",
            },
            format="json",
        )
        self.assertEqual(saved.status_code, 200)
        self.assertEqual(saved.data["account_last4"], "9012")

        payout = partner.get("/api/v1/partner/payout-account")
        self.assertEqual(payout.data["holder_name"], "Ravi Kumar")
        self.assertEqual(payout.data["ifsc"], "HDFC0001234")

        updated = partner.put(
            "/api/v1/partner/profile",
            {"notifications_enabled": False},
            format="json",
        )
        self.assertEqual(updated.status_code, 200)
        self.assertFalse(updated.data["notifications_enabled"])
        self.assertEqual(updated.data["bank_account_last4"], "9012")
