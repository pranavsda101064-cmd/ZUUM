"""Shared abstract models, money/geo helpers and lifecycle constants."""
from __future__ import annotations

import uuid
from decimal import Decimal

from django.db import models


class TimeStampedModel(models.Model):
    """UUID primary key + audit timestamps for every externally-visible row."""

    id = models.UUIDField(primary_key=True, default=uuid.uuid4, editable=False)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        abstract = True


def paise(rupees: Decimal | int | float | str) -> int:
    """Rupees → integer paise (bankers-safe rounding)."""
    return int((Decimal(str(rupees)) * 100).quantize(Decimal("1")))


def rupees(value_paise: int) -> Decimal:
    """Integer paise → rupees with 2dp (for display/serializers)."""
    return (Decimal(value_paise) / 100).quantize(Decimal("0.01"))


class PointMixin(models.Model):
    """Flat lat/lng columns (PostGIS is a production swap-in)."""

    lat = models.FloatField()
    lng = models.FloatField()

    class Meta:
        abstract = True

    @property
    def point(self) -> dict[str, float]:
        return {"lat": self.lat, "lng": self.lng}
