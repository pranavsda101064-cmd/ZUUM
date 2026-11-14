"""Catalog, service pricing and commission rules."""
from __future__ import annotations

from django.db import models

from apps.core.models import TimeStampedModel


class City(TimeStampedModel):
    code = models.CharField(max_length=10, unique=True)
    name = models.CharField(max_length=80)
    polygon = models.JSONField(default=list, blank=True)
    is_active = models.BooleanField(default=True)

    class Meta:
        verbose_name_plural = "cities"
        ordering = ("name",)


class ServiceCategory(TimeStampedModel):
    class Kind(models.TextChoices):
        PASSENGER = "passenger", "Passenger"
        GOODS = "goods", "Goods"

    code = models.CharField(max_length=20, unique=True)
    kind = models.CharField(max_length=10, choices=Kind.choices)
    name = models.CharField(max_length=40)
    seats = models.PositiveSmallIntegerField(null=True, blank=True)
    capacity_kg = models.PositiveIntegerField(null=True, blank=True)
    volume_cuft = models.FloatField(null=True, blank=True)
    max_weight_kg = models.PositiveIntegerField(null=True, blank=True)
    is_enabled = models.BooleanField(default=True)
    sort_order = models.PositiveSmallIntegerField(default=0)

    class Meta:
        ordering = ("kind", "sort_order", "name")
        verbose_name_plural = "service categories"


class PricingRule(TimeStampedModel):
    category = models.ForeignKey(
        ServiceCategory, on_delete=models.CASCADE, related_name="pricing_rules"
    )
    city = models.ForeignKey(
        City,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="pricing_rules",
    )
    base_paise = models.PositiveIntegerField(default=3000)
    per_km_paise = models.PositiveIntegerField(default=1100)
    per_min_paise = models.PositiveIntegerField(default=120)
    min_fare_paise = models.PositiveIntegerField(default=4000)
    waiting_per_min_paise = models.PositiveIntegerField(default=0)
    night_multiplier = models.FloatField(default=1.0)
    surge_multiplier = models.FloatField(default=1.0)
    goods_loading_fee_paise = models.PositiveIntegerField(default=0)
    valid_from = models.DateTimeField(null=True, blank=True)
    valid_to = models.DateTimeField(null=True, blank=True)

    class Meta:
        ordering = ("category__sort_order", "-created_at")


class CommissionRule(TimeStampedModel):
    category = models.ForeignKey(
        ServiceCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="commission_rules",
    )
    city = models.ForeignKey(
        City,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="commission_rules",
    )
    percent = models.DecimalField(max_digits=5, decimal_places=2, default=20)
    valid_from = models.DateTimeField(null=True, blank=True)
    valid_to = models.DateTimeField(null=True, blank=True)

    @classmethod
    def percent_for(cls, category, city=None) -> float:
        rule = (
            cls.objects.filter(category=category)
            .filter(city__in=[city, None])
            .order_by("-created_at")
            .first()
        )
        return float(rule.percent) if rule else 20.0


class PromoCampaign(TimeStampedModel):
    class Kind(models.TextChoices):
        PERCENT = "percent", "Percent"
        FLAT = "flat", "Flat"

    code = models.CharField(max_length=24, unique=True)
    kind = models.CharField(max_length=10, choices=Kind.choices)
    value = models.PositiveIntegerField(help_text="Percent (0-100) or paise for flat")
    max_discount_paise = models.PositiveIntegerField(default=0)
    min_fare_paise = models.PositiveIntegerField(default=0)
    usage_limit = models.PositiveIntegerField(default=0)
    per_user_limit = models.PositiveIntegerField(default=1)
    used_count = models.PositiveIntegerField(default=0)
    valid_from = models.DateTimeField(null=True, blank=True)
    valid_to = models.DateTimeField(null=True, blank=True)
    is_active = models.BooleanField(default=True)
    scope_category = models.ForeignKey(
        ServiceCategory,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="promos",
    )
    scope_city = models.ForeignKey(
        City,
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="promos",
    )

    class Meta:
        ordering = ("-created_at",)


class PromoRedemption(TimeStampedModel):
    promo = models.ForeignKey(
        PromoCampaign, on_delete=models.CASCADE, related_name="redemptions"
    )
    customer = models.ForeignKey(
        "accounts.CustomerProfile",
        on_delete=models.CASCADE,
        related_name="promo_redemptions",
    )
    booking_id = models.UUIDField(null=True, blank=True)
    discount_paise = models.PositiveIntegerField(default=0)


class Referral(TimeStampedModel):
    class Status(models.TextChoices):
        INVITED = "invited", "Invited"
        JOINED = "joined", "Joined"
        REWARDED = "rewarded", "Rewarded"

    referrer = models.ForeignKey(
        "accounts.User", on_delete=models.CASCADE, related_name="referrals_made"
    )
    referee = models.ForeignKey(
        "accounts.User",
        on_delete=models.SET_NULL,
        null=True,
        blank=True,
        related_name="referrals_received",
    )
    code = models.CharField(max_length=16, unique=True)
    status = models.CharField(
        max_length=10, choices=Status.choices, default=Status.INVITED
    )
    reward_referrer_paise = models.PositiveIntegerField(default=10000)
    reward_referee_paise = models.PositiveIntegerField(default=5000)
