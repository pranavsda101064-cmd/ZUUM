"""Realtime fan-out helpers (Channels) with event envelopes."""
from __future__ import annotations

import uuid

from asgiref.sync import async_to_sync
from channels.layers import get_channel_layer


def _send(group: str, payload: dict) -> None:
    layer = get_channel_layer()
    if layer is None:
        return
    payload = {
        **payload,
        "event_id": payload.get("event_id") or uuid.uuid4().hex,
        "at": payload.get("at"),
    }
    if payload["at"] is None:
        from django.utils import timezone

        payload["at"] = timezone.now().isoformat()
    async_to_sync(layer.group_send)(group, {"type": "fanout", "payload": payload})


def push_to_user(user_id: str, payload: dict) -> None:
    _send(f"customer.{user_id}", payload)
    _send(f"driver.{user_id}", payload)


def push_to_driver(user_id: str, payload: dict) -> None:
    _send(f"driver.{user_id}", payload)


def push_to_booking(booking_id: str, payload: dict) -> None:
    _send(f"booking.{booking_id}", payload)


def push_to_customer(user_id: str, payload: dict) -> None:
    _send(f"customer.{user_id}", payload)
