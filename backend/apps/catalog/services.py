"""Promo validation and referral helpers."""
from __future__ import annotations

from django.utils import timezone

from apps.core.exceptions import ApiError

from .models import PromoCampaign, PromoRedemption, Referral


def _active_promos():
    now = timezone.now()
    return PromoCampaign.objects.filter(is_active=True).filter(
        valid_from__isnull=True
    ) | PromoCampaign.objects.filter(is_active=True).filter(valid_from__lte=now)


def validate_promo(*, code: str, fare_paise: int, category, customer=None):
    promo = PromoCampaign.objects.filter(code=code.upper(), is_active=True).first()
    if promo is None:
        raise ApiError("Promo code is not valid", code="promo_invalid", status_code=400)
    now = timezone.now()
    if promo.valid_from and promo.valid_from > now:
        raise ApiError("Promo is not active yet", code="promo_invalid", status_code=400)
    if promo.valid_to and promo.valid_to < now:
        raise ApiError("Promo has expired", code="promo_expired", status_code=400)
    if promo.scope_category_id and promo.scope_category_id != category.id:
        raise ApiError(
            "Promo does not apply to this service",
            code="promo_invalid",
            status_code=400,
        )
    if fare_paise < promo.min_fare_paise:
        raise ApiError(
            "Fare is below the promo minimum",
            code="promo_invalid",
            status_code=400,
        )
    if promo.usage_limit and promo.used_count >= promo.usage_limit:
        raise ApiError("Promo usage limit reached", code="promo_exhausted", status_code=400)
    if customer is not None and promo.per_user_limit:
        used = PromoRedemption.objects.filter(
            promo=promo, customer__user=customer
        ).count()
        if used >= promo.per_user_limit:
            raise ApiError(
                "Promo already used", code="promo_exhausted", status_code=400
            )

    if promo.kind == PromoCampaign.Kind.PERCENT:
        discount = int(round(fare_paise * promo.value / 100))
    else:
        discount = promo.value
    if promo.max_discount_paise:
        discount = min(discount, promo.max_discount_paise)
    return promo, min(discount, fare_paise)


def record_redemption(*, code: str, customer, booking_id, discount_paise: int) -> None:
    promo = PromoCampaign.objects.filter(code=code.upper()).first()
    if promo is None:
        return
    PromoRedemption.objects.create(
        promo=promo,
        customer=customer.customer_profile,
        booking_id=booking_id,
        discount_paise=discount_paise,
    )
    promo.used_count += 1
    promo.save(update_fields=["used_count"])


def ensure_referral(user) -> Referral:
    referral = Referral.objects.filter(referrer=user).first()
    if referral:
        return referral
    code = (user.first_name or "ZUUM").upper()[:4] + str(user.id).replace("-", "")[:4].upper()
    return Referral.objects.create(referrer=user, code=code)
