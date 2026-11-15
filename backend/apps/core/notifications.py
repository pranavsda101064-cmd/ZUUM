"""In-app notifications + realtime fan-out."""
from __future__ import annotations

from typing import Any

from apps.core.realtime import push_to_customer, push_to_driver


def notify_user(
    user,
    *,
    type: str,
    title: str,
    body: str,
    data: dict[str, Any] | None = None,
    channel: str = "in_app",
):
    """Create a notification row and push it to the user's WS topic."""
    from apps.platform.models import Notification

    notification = Notification.objects.create(
        user=user,
        type=type,
        title=title,
        body=body,
        data=data or {},
        channel=channel,
    )
    payload = {
        "type": "customer.notification",
        "id": str(notification.id),
        "notification_type": type,
        "title": title,
        "body": body,
        "data": data or {},
        "at": notification.created_at.isoformat(),
    }
    if getattr(user, "role", None) == "driver":
        push_to_driver(str(user.id), payload)
    else:
        push_to_customer(str(user.id), payload)
    return notification
