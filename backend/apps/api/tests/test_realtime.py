"""Realtime protocol: JWT handshake, topic authorization, uplinks."""
from __future__ import annotations

from asgiref.sync import async_to_sync
from channels.testing import WebsocketCommunicator
from django.test import TransactionTestCase
from rest_framework_simplejwt.tokens import RefreshToken

from apps.accounts.models import DriverProfile, User
from config.asgi import application


def access_token(user) -> str:
    return str(RefreshToken.for_user(user).access_token)


class RealtimeTests(TransactionTestCase):
    def setUp(self):
        self.customer = User.objects.create_user(
            email="rt-customer@zuum.in", password="x", first_name="RT", role="customer"
        )
        self.driver_user = User.objects.create_user(
            email="rt-driver@zuum.in", password="x", first_name="RT", role="driver"
        )
        self.driver = DriverProfile.objects.create(
            user=self.driver_user,
            kyc_status=DriverProfile.KYC_APPROVED,
            approval_status=DriverProfile.APPROVAL_ACTIVE,
        )

    def test_hello_unknown_message_and_pong(self):
        token = access_token(self.customer)

        async def scenario():
            comm = WebsocketCommunicator(
                application, f"/ws/customer/{self.customer.id}/?token={token}"
            )
            connected, _ = await comm.connect()
            self.assertTrue(connected)
            hello = await comm.receive_json_from()
            self.assertEqual(hello["type"], "hello")
            self.assertIn("server_time", hello)

            await comm.send_json_to({"type": "pong"})
            await comm.send_json_to({"type": "make.me.a.sandwich"})
            error = await comm.receive_json_from()
            self.assertEqual(error["type"], "error")
            self.assertEqual(error["code"], "unknown_message")
            await comm.disconnect()

        async_to_sync(scenario)()

    def test_unauthorized_topic_is_refused(self):
        intruder = User.objects.create_user(
            email="rt-intruder@zuum.in", password="x", first_name="In", role="customer"
        )
        token = access_token(intruder)

        async def scenario():
            comm = WebsocketCommunicator(
                application, f"/ws/customer/{self.customer.id}/?token={token}"
            )
            connected, code = await comm.connect()
            self.assertFalse(connected)
            self.assertEqual(code, 4403)
            await comm.disconnect()

        async_to_sync(scenario)()

    def test_missing_token_is_refused(self):
        async def scenario():
            comm = WebsocketCommunicator(
                application, f"/ws/customer/{self.customer.id}/"
            )
            connected, code = await comm.connect()
            self.assertFalse(connected)
            self.assertEqual(code, 4401)
            await comm.disconnect()

        async_to_sync(scenario)()

    def test_driver_status_uplink_updates_presence(self):
        token = access_token(self.driver_user)

        async def scenario():
            comm = WebsocketCommunicator(
                application, f"/ws/driver/{self.driver_user.id}/?token={token}"
            )
            connected, _ = await comm.connect()
            self.assertTrue(connected)
            await comm.receive_json_from()  # hello
            await comm.send_json_to({"type": "driver.status", "online": True})
            await comm.disconnect()

        async_to_sync(scenario)()
        self.driver.refresh_from_db()
        self.assertEqual(self.driver.online_state, DriverProfile.ONLINE_AVAILABLE)
