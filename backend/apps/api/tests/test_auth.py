"""Auth contract: register, login, refresh rotation, logout, reset."""
from django.core import mail
from django.test import override_settings
from rest_framework.test import APITestCase

from apps.accounts.models import CustomerProfile, User

PASSWORD = "zuum1234"


class AuthTests(APITestCase):
    def test_register_creates_customer(self):
        response = self.client.post(
            "/api/v1/auth/register",
            {
                "email": "New@Zuum.in",
                "password": PASSWORD,
                "first_name": "Meera",
                "last_name": "Rao",
                "phone": "9845011111",
            },
            format="json",
        )
        self.assertEqual(response.status_code, 201, response.content)
        self.assertEqual(response.data["user"]["email"], "new@zuum.in")
        self.assertEqual(response.data["user"]["role"], "customer")
        self.assertNotIn("password", response.data["user"])
        user = User.objects.get(email="new@zuum.in")
        self.assertTrue(CustomerProfile.objects.filter(user=user).exists())

    def test_register_rejects_duplicates_and_short_password(self):
        User.objects.create_user(email="dup@zuum.in", password=PASSWORD)
        response = self.client.post(
            "/api/v1/auth/register",
            {"email": "dup@zuum.in", "password": PASSWORD, "first_name": "D"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data["code"], "validation_error")

        response = self.client.post(
            "/api/v1/auth/register",
            {"email": "short@zuum.in", "password": "123", "first_name": "S"},
            format="json",
        )
        self.assertEqual(response.status_code, 400)
        self.assertEqual(response.data["code"], "validation_error")

    def test_login_wrong_password_uses_error_envelope(self):
        User.objects.create_user(email="a@zuum.in", password=PASSWORD)
        response = self.client.post(
            "/api/v1/auth/login",
            {"email": "a@zuum.in", "password": "nope"},
            format="json",
        )
        self.assertEqual(response.status_code, 401)
        self.assertEqual(response.data["code"], "invalid_credentials")

    def test_login_returns_rotating_session_and_me(self):
        User.objects.create_user(
            email="a@zuum.in", password=PASSWORD, first_name="Aarav", role="customer"
        )
        response = self.client.post(
            "/api/v1/auth/login",
            {"email": "a@zuum.in", "password": PASSWORD},
            format="json",
        )
        self.assertEqual(response.status_code, 200)
        self.assertIn("access", response.data)
        self.assertIn("refresh", response.data)
        self.assertEqual(response.data["user"]["role"], "customer")

        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {response.data['access']}"
        )
        me = self.client.get("/api/v1/auth/me")
        self.assertEqual(me.status_code, 200)
        self.assertEqual(me.data["user"]["email"], "a@zuum.in")

    def test_refresh_rotates_and_blacklists_old_token(self):
        User.objects.create_user(email="r@zuum.in", password=PASSWORD)
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": "r@zuum.in", "password": PASSWORD},
            format="json",
        )
        refresh = login.data["refresh"]
        first = self.client.post(
            "/api/v1/auth/refresh", {"refresh": refresh}, format="json"
        )
        self.assertEqual(first.status_code, 200, first.content)
        self.assertNotEqual(first.data["refresh"], refresh)

        reuse = self.client.post(
            "/api/v1/auth/refresh", {"refresh": refresh}, format="json"
        )
        self.assertEqual(reuse.status_code, 401)
        self.assertEqual(reuse.data["code"], "token_not_valid")

    def test_logout_revokes_refresh(self):
        User.objects.create_user(email="l@zuum.in", password=PASSWORD)
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": "l@zuum.in", "password": PASSWORD},
            format="json",
        )
        refresh = login.data["refresh"]
        logout = self.client.post(
            "/api/v1/auth/logout", {"refresh": refresh}, format="json"
        )
        self.assertEqual(logout.status_code, 204)
        again = self.client.post(
            "/api/v1/auth/refresh", {"refresh": refresh}, format="json"
        )
        self.assertEqual(again.status_code, 401)

    @override_settings(EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend")
    def test_password_reset_flow(self):
        User.objects.create_user(email="p@zuum.in", password=PASSWORD)
        forgot = self.client.post(
            "/api/v1/auth/password/forgot", {"email": "p@zuum.in"}, format="json"
        )
        self.assertEqual(forgot.status_code, 204)
        self.assertEqual(len(mail.outbox), 1)
        token = mail.outbox[0].body.split("Token: ")[1].strip()

        reset = self.client.post(
            "/api/v1/auth/password/reset",
            {"token": token, "password": "newpass123"},
            format="json",
        )
        self.assertEqual(reset.status_code, 204)
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": "p@zuum.in", "password": "newpass123"},
            format="json",
        )
        self.assertEqual(login.status_code, 200)

    def test_forgot_password_does_not_enumerate(self):
        with override_settings(
            EMAIL_BACKEND="django.core.mail.backends.locmem.EmailBackend"
        ):
            response = self.client.post(
                "/api/v1/auth/password/forgot",
                {"email": "ghost@zuum.in"},
                format="json",
            )
        self.assertEqual(response.status_code, 204)
        self.assertEqual(len(mail.outbox), 0)

    def test_me_requires_token(self):
        response = self.client.get("/api/v1/auth/me")
        self.assertEqual(response.status_code, 401)
        self.assertIn("code", response.data)
