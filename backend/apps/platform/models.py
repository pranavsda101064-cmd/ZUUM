"""Platform: notifications, support, safety, audit trail, settings."""
from __future__ import annotations

from django.db import models

from apps.core.models import TimeStampedModel


class Notification(TimeStampedModel):
    class Channel(models.TextChoices):
        PUSH = "push", "Push"
        SMS = "sms", "SMS"
        EMAIL = "email", "Email"
        IN_APP = "in_app", "In-app"

    user = models.ForeignKey(
        "accounts.User", on_delete=models.CASCADE, related_name="notifications"
    )
    type = models.CharField(max_length=24, default="system")
    title = models.CharField(max_length=120)
    body = models.CharField(max_length=500)
    data = models.JSONField(default=dict, blank=True)
    channel = models.CharField(
        max_length=10, choices=Channel.choices, default=Channel.IN_APP
    )
    read_at = models.DateTimeField(null=True, blank=True)
    sent_at = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("-created_at",)
        indexes = [models.Index(fields=["user", "read_at"])]


class SupportTicket(TimeStampedModel):
    class Status(models.TextChoices):
        OPEN = "open", "Open"
        PENDING = "pending", "Pending"
        RESOLVED = "resolved", "Resolved"
        CLOSED = "closed", "Closed"

    class Priority(models.TextChoices):
        LOW = "low", "Low"
        NORMAL = "normal", "Normal"
        HIGH = "high", "High"
        URGENT = "urgent", "Urgent"

    customer = models.ForeignKey(
        "accounts.User", on_delete=models.CASCADE, related_name="support_tickets"
    )
    booking = models.ForeignKey(
        "bookings.Booking",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="support_tickets",
    )
    category = models.CharField(max_length=40)
    subject = models.CharField(max_length=160)
    status = models.CharField(
        max_length=10, choices=Status.choices, default=Status.OPEN
    )
    priority = models.CharField(
        max_length=10, choices=Priority.choices, default=Priority.NORMAL
    )

    class Meta:
        ordering = ("-created_at",)


class SupportMessage(TimeStampedModel):
    ticket = models.ForeignKey(
        SupportTicket, on_delete=models.CASCADE, related_name="messages"
    )
    author = models.ForeignKey(
        "accounts.User", on_delete=models.SET_NULL, null=True, related_name="+"
    )
    body = models.CharField(max_length=2000)
    attachments = models.JSONField(default=list, blank=True)


class SosAlert(TimeStampedModel):
    booking = models.ForeignKey(
        "bookings.Booking",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="sos_alerts",
    )
    customer = models.ForeignKey(
        "accounts.User", on_delete=models.CASCADE, related_name="sos_alerts"
    )
    lat = models.FloatField(null=True, blank=True)
    lng = models.FloatField(null=True, blank=True)
    resolved_at = models.DateTimeField(null=True, blank=True)


class AuditLog(models.Model):
    id = models.BigAutoField(primary_key=True)
    actor_id = models.UUIDField(null=True, blank=True)
    actor_role = models.CharField(max_length=20, default="system")
    action = models.CharField(max_length=80)
    entity_type = models.CharField(max_length=60)
    entity_id = models.CharField(max_length=64, blank=True)
    before = models.JSONField(default=dict, blank=True)
    after = models.JSONField(default=dict, blank=True)
    ip = models.GenericIPAddressField(null=True, blank=True)
    at = models.DateTimeField(auto_now_add=True)

    class Meta:
        ordering = ("-at",)
        indexes = [models.Index(fields=["entity_type", "entity_id"])]


class SystemSetting(models.Model):
    key = models.CharField(max_length=80, unique=True)
    value = models.JSONField(default=dict)
    updated_at = models.DateTimeField(auto_now=True)

    def __str__(self) -> str:  # pragma: no cover
        return self.key
