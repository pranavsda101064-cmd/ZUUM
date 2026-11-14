"""WebSocket consumers implementing docs/04_realtime_protocol.md."""
from __future__ import annotations

import json
from datetime import datetime

from channels.db import database_sync_to_async
from channels.generic.websocket import AsyncJsonWebsocketConsumer
from django.utils import timezone


class TopicConsumer(AsyncJsonWebsocketConsumer):
    """One consumer for customer/{id}, driver/{id} and booking/{id} topics.

    Authorization is checked against the authenticated user before joining a
    group; unknown client message types are rejected per the protocol.
    """

    async def connect(self):
        self.topic_type = self.scope["url_route"]["kwargs"]["topic"]
        self.topic_id = str(self.scope["url_route"]["kwargs"]["identifier"])
        user = self.scope.get("user")

        if not user or not user.is_authenticated:
            await self.close(code=4401)
            return
        if not await self._authorized(user):
            await self.close(code=4403)
            return

        self.group_name = f"{self.topic_type}.{self.topic_id}"
        await self.channel_layer.group_add(self.group_name, self.channel_name)
        if getattr(user, "role", None) == "staff":
            await self.channel_layer.group_add("admin.ops", self.channel_name)
        await self.accept()
        await self.send_json(
            {"type": "hello", "server_time": timezone.now().isoformat()}
        )

    async def disconnect(self, code):
        group = getattr(self, "group_name", None)
        if group:
            await self.channel_layer.group_discard(group, self.channel_name)

    async def receive_json(self, content, **kwargs):
        message_type = content.get("type")
        if message_type == "pong":
            return
        if message_type == "resume":
            await self.send_json(
                {"type": "resumed", "last_event_id": content.get("last_event_id")}
            )
            return
        if message_type == "driver.status":
            await self._set_driver_status(bool(content.get("online")))
            return
        if message_type == "booking.location":
            await self._record_location(content)
            return
        await self.send_json(
            {
                "type": "error",
                "code": "unknown_message",
                "message": f"Unsupported message type: {message_type}",
            }
        )

    # fan-out handler -------------------------------------------------------------
    async def fanout(self, event):
        payload = event.get("payload", {})
        await self.send_json(payload)

    # authorization ----------------------------------------------------------------
    @database_sync_to_async
    def _authorized(self, user) -> bool:
        from apps.accounts.models import DriverProfile
        from apps.bookings.models import Booking, DispatchOffer

        if user.is_superuser or getattr(user, "role", None) == "staff":
            return True
        if self.topic_type == "customer":
            return str(user.id) == self.topic_id
        if self.topic_type == "driver":
            return str(user.id) == self.topic_id and user.role == "driver"
        if self.topic_type == "booking":
            booking = Booking.objects.filter(pk=self.topic_id).first()
            if booking is None:
                return False
            if booking.customer_id == user.id:
                return True
            if user.role == "driver":
                profile = DriverProfile.objects.filter(user=user).first()
                return bool(
                    profile
                    and DispatchOffer.objects.filter(
                        booking=booking,
                        driver=profile,
                        status=DispatchOffer.Status.ACCEPTED,
                    ).exists()
                )
        return False

    # uplinks ----------------------------------------------------------------------
    @database_sync_to_async
    def _set_driver_status(self, online: bool) -> None:
        from apps.accounts.models import DriverProfile

        user = self.scope["user"]
        profile = DriverProfile.objects.filter(user=user).first()
        if profile is None:
            return
        if online and profile.approval_status == DriverProfile.APPROVAL_ACTIVE:
            profile.online_state = DriverProfile.ONLINE_AVAILABLE
        elif not online:
            profile.online_state = DriverProfile.ONLINE_OFFLINE
        profile.last_seen_at = timezone.now()
        profile.save(update_fields=["online_state", "last_seen_at", "updated_at"])

    @database_sync_to_async
    def _record_location(self, content: dict) -> None:
        from apps.accounts.models import DriverProfile
        from apps.bookings.models import Booking, LocationPing
        from apps.core.realtime import push_to_booking

        user = self.scope["user"]
        profile = DriverProfile.objects.filter(user=user).first()
        if profile is None:
            return
        lat, lng = content.get("lat"), content.get("lng")
        if lat is None or lng is None:
            return
        recorded = content.get("recorded_at")
        try:
            recorded_at = (
                datetime.fromisoformat(recorded) if recorded else timezone.now()
            )
        except ValueError:
            recorded_at = timezone.now()
        booking = None
        if content.get("booking_id"):
            booking = Booking.objects.filter(pk=content["booking_id"]).first()
        from apps.bookings.services import accept_location_ping

        if not accept_location_ping(profile, recorded_at=recorded_at, booking=booking):
            return
        LocationPing.objects.create(
            driver=profile,
            booking=booking,
            lat=float(lat),
            lng=float(lng),
            heading=content.get("heading"),
            speed_mps=content.get("speed_mps"),
            source="ws",
            recorded_at=recorded_at,
        )
        if booking is not None:
            push_to_booking(
                str(booking.id),
                {
                    "type": "booking.driver_location",
                    "booking_id": str(booking.id),
                    "lat": float(lat),
                    "lng": float(lng),
                    "heading": content.get("heading"),
                    "speed_mps": content.get("speed_mps"),
                    "recorded_at": recorded_at.isoformat(),
                },
            )
