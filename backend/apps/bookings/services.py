"""Booking engine: pricing, dispatch offers and the trip state machine."""
from __future__ import annotations

import math
import secrets
from datetime import timedelta

from django.db import transaction
from django.utils import timezone

from apps.accounts.models import DriverProfile, Vehicle
from apps.core.exceptions import ApiError, illegal_transition
from apps.core.notifications import notify_user
from apps.core.realtime import push_to_booking, push_to_driver
from apps.payments.services import settle_commission

from .models import (
    Booking,
    BookingStatusHistory,
    DispatchOffer,
    FareQuote,
    GoodsShipment,
    PassengerTrip,
)

OFFER_TTL = timedelta(seconds=15)
AVG_SPEED_KMH = 22.0


def otp_code() -> str:
    return f"{secrets.randbelow(10000):04d}"


def haversine_m(a: dict[str, float], b: dict[str, float]) -> float:
    r = 6371000.0
    lat1, lng1 = math.radians(a["lat"]), math.radians(a["lng"])
    lat2, lng2 = math.radians(b["lat"]), math.radians(b["lng"])
    dlat, dlng = lat2 - lat1, lng2 - lng1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


def estimate_duration_s(distance_m: float) -> int:
    return max(120, int(distance_m / 1000 / AVG_SPEED_KMH * 3600))


def rule_for(category):
    from apps.catalog.models import PricingRule

    rule = (
        PricingRule.objects.filter(category=category)
        .order_by("-created_at")
        .first()
    )
    if rule is None:
        raise ApiError(
            "No pricing configured for this service category",
            code="pricing_unavailable",
            status_code=409,
        )
    return rule


def compute_quote(
    *,
    category,
    pickup: dict,
    drop: dict,
    scheduled_at=None,
    goods: dict | None = None,
    route=None,
) -> dict:
    rule = rule_for(category)
    if route is not None:
        distance_m = max(500, int(route.distance_m))
        duration_s = max(120, int(route.duration_s))
    else:
        distance_m = max(500, int(haversine_m(pickup, drop)))
        duration_s = max(120, estimate_duration_s(distance_m))

    base = rule.base_paise
    distance_paise = int(rule.per_km_paise * distance_m / 1000)
    time_paise = int(rule.per_min_paise * duration_s / 60)
    subtotal = base + distance_paise + time_paise

    now_hour = timezone.localtime().hour
    night = rule.night_multiplier if now_hour >= 22 or now_hour < 6 else 1.0
    surge = float(rule.surge_multiplier or 1.0)
    multiplier = night * surge
    surge_paise = int(subtotal * (multiplier - 1))
    loading_paise = 0
    if goods and goods.get("needs_loading_help"):
        loading_paise = rule.goods_loading_fee_paise

    gross = max(rule.min_fare_paise, int(round(subtotal * multiplier))) + loading_paise
    breakdown = {
        "base_paise": base,
        "distance_paise": distance_paise,
        "time_paise": time_paise,
        "surge_paise": surge_paise,
        "toll_paise": 0,
        "waiting_paise": 0,
        "loading_paise": loading_paise,
        "discount_paise": 0,
        "total_paise": gross,
        "surge_multiplier": surge,
        "night_multiplier": night,
    }
    return {
        "distance_m": distance_m,
        "duration_s": duration_s,
        "breakdown": breakdown,
        "total_paise": gross,
        "valid_until": timezone.now() + timedelta(minutes=5),
    }


def record_transition(
    booking: Booking,
    to_status: str,
    *,
    actor_type: str = "system",
    actor_id=None,
    reason: str = "",
) -> None:
    BookingStatusHistory.objects.create(
        booking=booking,
        from_status=booking.status,
        to_status=to_status,
        actor_type=actor_type,
        actor_id=actor_id,
        reason=reason,
    )
    booking.status = to_status
    booking.save(update_fields=["status", "updated_at"])


def push_status(booking: Booking, data: dict | None = None) -> None:
    push_to_booking(
        str(booking.id),
        {
            "type": "booking.status",
            "booking_id": str(booking.id),
            "status": booking.status,
            "at": timezone.now().isoformat(),
            "data": data or {},
        },
    )


def create_booking(*, customer, quote: FareQuote, payload: dict) -> Booking:
    category = quote.service_category
    pickup = payload.get("pickup") or quote.pickup
    drop = payload.get("drop") or quote.drop
    goods = payload.get("goods") or None
    if quote.kind == "goods" and not goods:
        raise ApiError(
            "Goods bookings require shipment details",
            code="validation_error",
            status_code=400,
        )

    quoted = quote.total_paise
    discount = 0
    promo_code = (payload.get("promo_code") or "").strip().upper()
    if promo_code:
        from apps.catalog.services import validate_promo

        promo, discount = validate_promo(
            code=promo_code,
            fare_paise=quoted,
            category=category,
            customer=customer,
        )
        promo_code = promo.code if hasattr(promo, "code") else promo_code
        quoted = max(0, quoted - discount)

    with transaction.atomic():
        booking = Booking.objects.create(
            customer=customer,
            type=quote.kind,
            service_category=category,
            status=Booking.Status.PRICED,
            pickup_lat=float(pickup["lat"]),
            pickup_lng=float(pickup["lng"]),
            pickup_address=pickup.get("address", "Pickup"),
            drop_lat=float(drop["lat"]),
            drop_lng=float(drop["lng"]),
            drop_address=drop.get("address", "Drop"),
            distance_m=quote.distance_m,
            duration_s=quote.duration_s,
            quoted_fare_paise=quoted,
            discount_paise=discount,
            promo_code=promo_code,
            payment_method=payload.get("payment_method") or "cash",
            notes=payload.get("notes") or "",
            scheduled_at=payload.get("scheduled_at"),
            route_geometry=quote.route_geometry,
            route_steps=quote.route_steps,
            route_provider=quote.route_provider,
            route_degraded=quote.route_degraded,
        )
        quote.booking = booking
        quote.save(update_fields=["booking"])

        if quote.kind == Booking.Type.RIDE:
            PassengerTrip.objects.create(
                booking=booking,
                ride_type=(
                    PassengerTrip.RideType.SCHEDULED
                    if payload.get("scheduled_at")
                    else PassengerTrip.RideType.NOW
                ),
                start_otp=otp_code(),
            )
        else:
            goods = goods or {}
            GoodsShipment.objects.create(
                booking=booking,
                goods_type=goods.get("goods_type", "Goods"),
                weight_kg=goods.get("weight_kg"),
                dimensions_cuft=goods.get("dimensions_cuft"),
                needs_loading_help=bool(goods.get("needs_loading_help")),
                load_type=goods.get("load_type", "full"),
                sender_name=goods.get("sender_name", ""),
                sender_phone=goods.get("sender_phone", ""),
                receiver_name=goods.get("receiver_name", ""),
                receiver_phone=goods.get("receiver_phone", ""),
                stops=goods.get("stops", []),
                pickup_otp=otp_code(),
                delivery_otp=otp_code(),
            )

        record_transition(booking, Booking.Status.SEARCHING, actor_type="customer", actor_id=customer.id)
        if promo_code:
            from apps.catalog.services import record_redemption

            record_redemption(
                code=promo_code,
                customer=customer,
                booking_id=booking.id,
                discount_paise=discount,
            )

    dispatch_offers(booking)
    push_status(booking)
    return booking


def eligible_drivers(booking: Booking):
    kind = (
        "passenger"
        if booking.type == Booking.Type.RIDE
        else "goods"
    )
    qs = (
        DriverProfile.objects.filter(
            approval_status=DriverProfile.APPROVAL_ACTIVE,
            online_state=DriverProfile.ONLINE_AVAILABLE,
            vehicles__is_active=True,
            vehicles__category=booking.service_category,
        )
        .select_related("user")
        .distinct()
    )
    pickup = {"lat": booking.pickup_lat, "lng": booking.pickup_lng}
    ranked = []
    for driver in qs:
        origin = (
            {"lat": driver.home_lat, "lng": driver.home_lng}
            if driver.home_lat is not None
            else pickup
        )
        ranked.append((haversine_m(origin, pickup), driver))
    ranked.sort(key=lambda row: row[0])
    return [driver for _, driver in ranked]


def accept_location_ping(
    driver, *, recorded_at, booking: Booking | None = None
) -> bool:
    """Server-side cadence + ordering guard (docs/04_realtime_protocol.md).

    - drops out-of-order / duplicate timestamps (last-point-wins)
    - 5 s while on an active trip, 15 s while available, 60 s otherwise
    """
    from .models import LocationPing

    last = (
        LocationPing.objects.filter(driver=driver)
        .order_by("-recorded_at")
        .first()
    )
    if last is not None:
        if recorded_at <= last.recorded_at:
            return False
        on_trip = booking is not None and booking.status in (
            Booking.Status.ASSIGNED,
            Booking.Status.ARRIVED,
            Booking.Status.IN_PROGRESS,
        )
        interval = 5 if on_trip else (15 if driver.online_state != "offline" else 60)
        elapsed = (recorded_at - last.recorded_at).total_seconds()
        if elapsed < interval * 0.8:
            return False
    return True


def dispatch_offers(booking: Booking, *, limit: int = 3) -> list[DispatchOffer]:
    drivers = eligible_drivers(booking)[:limit]
    offers: list[DispatchOffer] = []
    seq = booking.offers.count()
    for driver in drivers:
        seq += 1
        vehicle = (
            driver.vehicles.filter(is_active=True, category=booking.service_category)
            .order_by("-created_at")
            .first()
        )
        offer = DispatchOffer.objects.create(
            booking=booking,
            driver=driver,
            vehicle=vehicle,
            expires_at=timezone.now() + OFFER_TTL,
            offer_seq=seq,
        )
        offers.append(offer)
        push_to_driver(
            str(driver.user_id),
            {
                "type": "booking.offer",
                "offer_id": str(offer.id),
                "booking_id": str(booking.id),
                "expires_in_s": 15,
                "fare_paise": booking.quoted_fare_paise,
                "service_category": booking.service_category.code,
                "pickup": {
                    "lat": booking.pickup_lat,
                    "lng": booking.pickup_lng,
                    "address": booking.pickup_address,
                },
                "drop": {
                    "lat": booking.drop_lat,
                    "lng": booking.drop_lng,
                    "address": booking.drop_address,
                },
            },
        )
    return offers


def expire_stale_offers(booking: Booking | None = None) -> None:
    qs = DispatchOffer.objects.filter(
        status=DispatchOffer.Status.OFFERED, expires_at__lt=timezone.now()
    )
    if booking is not None:
        qs = qs.filter(booking=booking)
    stale = list(qs)
    if not stale:
        return
    qs.update(status=DispatchOffer.Status.EXPIRED, responded_at=timezone.now())
    for offer in stale:
        push_to_driver(
            str(offer.driver.user_id),
            {"type": "booking.offer.expired", "offer_id": str(offer.id)},
        )


def accept_offer(*, driver: DriverProfile, offer: DispatchOffer) -> Booking:
    with transaction.atomic():
        offer = DispatchOffer.objects.select_for_update().get(pk=offer.pk)
        if offer.status != DispatchOffer.Status.OFFERED:
            raise ApiError(
                "This offer has already been taken",
                code="offer_taken",
                status_code=409,
            )
        if offer.expires_at < timezone.now():
            offer.status = DispatchOffer.Status.EXPIRED
            offer.responded_at = timezone.now()
            offer.save(update_fields=["status", "responded_at"])
            raise ApiError(
                "Offer expired", code="offer_expired", status_code=409
            )
        booking = offer.booking
        if booking.status != Booking.Status.SEARCHING:
            raise ApiError(
                "This booking is no longer available",
                code="offer_taken",
                status_code=409,
            )
        offer.status = DispatchOffer.Status.ACCEPTED
        offer.responded_at = timezone.now()
        offer.save(update_fields=["status", "responded_at"])

        booking.offers.exclude(pk=offer.pk).filter(
            status=DispatchOffer.Status.OFFERED
        ).update(status=DispatchOffer.Status.REVOKED, responded_at=timezone.now())

        record_transition(
            booking,
            Booking.Status.ASSIGNED,
            actor_type="driver",
            actor_id=driver.user_id,
        )
        driver.online_state = DriverProfile.ONLINE_BUSY
        driver.last_seen_at = timezone.now()
        driver.save(update_fields=["online_state", "last_seen_at"])

    push_status(booking)
    push_to_booking(
        str(booking.id),
        {
            "type": "booking.assigned_driver",
            "booking_id": str(booking.id),
            "driver": {
                "id": str(driver.id),
                "name": driver.user.full_name,
                "phone": driver.user.phone,
                "rating_avg": float(driver.rating_avg),
            },
            "vehicle": (
                {
                    "registration_number": offer.vehicle.registration_number,
                    "make": offer.vehicle.make,
                    "color": offer.vehicle.color,
                    "category": offer.vehicle.category.code,
                }
                if offer.vehicle
                else None
            ),
        },
    )
    notify_user(
        booking.customer,
        type="booking",
        title="Captain on the way",
        body=(
            f"{driver.user.full_name} is heading to "
            f"{booking.pickup_address}."
        ),
        data={"booking_id": str(booking.id), "status": booking.status},
    )
    return booking


def decline_offer(*, driver: DriverProfile, offer: DispatchOffer, reason: str = "") -> None:
    if offer.driver_id != driver.id:
        raise ApiError("Offer not found", code="not_found", status_code=404)
    if offer.status == DispatchOffer.Status.OFFERED:
        offer.status = DispatchOffer.Status.REJECTED
        offer.rejection_reason = reason[:120]
        offer.responded_at = timezone.now()
        offer.save(update_fields=["status", "rejection_reason", "responded_at"])


def assigned_trip(driver: DriverProfile) -> Booking | None:
    return (
        Booking.objects.filter(
            offers__driver=driver,
            offers__status=DispatchOffer.Status.ACCEPTED,
            status__in=Booking.OPEN_STATUSES,
        )
        .exclude(status=Booking.Status.SEARCHING)
        .order_by("-created_at")
        .first()
    )


def require_trip(driver: DriverProfile, booking_id) -> Booking:
    booking = assigned_trip(driver)
    if booking is None or str(booking.id) != str(booking_id):
        raise ApiError("Trip not found", code="not_found", status_code=404)
    return booking


def require_status(booking: Booking, *allowed: str) -> None:
    if booking.status not in allowed:
        illegal_transition(
            "This action is not valid for the current trip stage."
        )


def arrive(*, driver: DriverProfile, booking: Booking) -> Booking:
    require_status(booking, Booking.Status.ASSIGNED, Booking.Status.DRIVER_ARRIVING)
    record_transition(booking, Booking.Status.ARRIVED, actor_type="driver", actor_id=driver.user_id)
    push_status(booking)
    notify_user(
        booking.customer,
        type="booking",
        title="Your captain has arrived",
        body=f"Meet at {booking.pickup_address}.",
        data={"booking_id": str(booking.id), "status": booking.status},
    )
    return booking


def _otp_for(booking: Booking) -> str:
    if booking.type == Booking.Type.GOODS and hasattr(booking, "shipment"):
        return booking.shipment.pickup_otp
    if hasattr(booking, "passenger_trip"):
        return booking.passenger_trip.start_otp
    return ""


def verify_start_otp(*, driver: DriverProfile, booking: Booking, otp: str) -> Booking:
    require_status(booking, Booking.Status.ARRIVED)
    expected = _otp_for(booking)
    if (otp or "").strip() != expected:
        raise ApiError("Incorrect OTP", code="otp_invalid", status_code=400)
    record_transition(
        booking, Booking.Status.IN_PROGRESS, actor_type="driver", actor_id=driver.user_id
    )
    if booking.type == Booking.Type.GOODS and hasattr(booking, "shipment"):
        booking.shipment.pickup_otp_verified_at = timezone.now()
        booking.shipment.save(update_fields=["pickup_otp_verified_at"])
    push_status(booking)
    notify_user(
        booking.customer,
        type="booking",
        title="Trip started",
        body=f"On the way to {booking.drop_address}.",
        data={"booking_id": str(booking.id), "status": booking.status},
    )
    return booking


def verify_delivery_otp(*, driver: DriverProfile, booking: Booking, otp: str) -> Booking:
    require_status(booking, Booking.Status.IN_PROGRESS)
    if booking.type != Booking.Type.GOODS or not hasattr(booking, "shipment"):
        illegal_transition("Delivery OTP applies to goods trips only.")
    shipment = booking.shipment
    if (otp or "").strip() != shipment.delivery_otp:
        raise ApiError(
            "Incorrect delivery OTP", code="otp_invalid", status_code=400
        )
    shipment.delivery_otp_verified_at = timezone.now()
    shipment.save(update_fields=["delivery_otp_verified_at"])
    return booking


def complete_trip(*, driver: DriverProfile, booking: Booking) -> Booking:
    require_status(booking, Booking.Status.IN_PROGRESS)
    if booking.type == Booking.Type.GOODS and hasattr(booking, "shipment"):
        if booking.shipment.delivery_otp_verified_at is None:
            raise ApiError(
                "Verify the delivery OTP first",
                code="pod_missing",
                status_code=409,
            )

    fare = booking.quoted_fare_paise
    settle_commission(booking=booking, driver=driver, fare_paise=fare)
    booking.final_fare_paise = fare
    booking.payment_state = Booking.PaymentState.PAID
    booking.completed_at = timezone.now()
    booking.save(
        update_fields=[
            "final_fare_paise",
            "payment_state",
            "completed_at",
            "updated_at",
        ]
    )
    record_transition(
        booking, Booking.Status.COMPLETED, actor_type="driver", actor_id=driver.user_id
    )
    driver.online_state = (
        DriverProfile.ONLINE_AVAILABLE
        if driver.online_state != DriverProfile.ONLINE_OFFLINE
        else DriverProfile.ONLINE_OFFLINE
    )
    driver.save(update_fields=["online_state"])

    push_status(
        booking,
        {"fare_paise": fare, "payment_state": Booking.PaymentState.PAID},
    )
    push_to_booking(
        str(booking.id),
        {
            "type": "booking.completed",
            "booking_id": str(booking.id),
            "fare_paise": fare,
            "payment_state": Booking.PaymentState.PAID,
        },
    )
    notify_user(
        booking.customer,
        type="booking",
        title="Trip completed",
        body=f"Fare Rs {fare / 100:.2f}. Thanks for riding with Zuum.",
        data={"booking_id": str(booking.id), "status": booking.status},
    )
    notify_user(
        driver.user,
        type="earnings",
        title="Trip completed",
        body=f"You earned Rs {booking.commission.driver_paise / 100:.2f} on this trip.",
        data={"booking_id": str(booking.id), "status": booking.status},
    )
    return booking


def cancel_booking(
    booking: Booking,
    *,
    by: str,
    actor_id=None,
    reason: str = "",
) -> Booking:
    require_status(
        booking,
        Booking.Status.CREATED,
        Booking.Status.PRICED,
        Booking.Status.SEARCHING,
        Booking.Status.ASSIGNED,
        Booking.Status.DRIVER_ARRIVING,
        Booking.Status.ARRIVED,
    )
    with transaction.atomic():
        booking.cancelled_by = by
        booking.cancel_reason = reason[:240]
        booking.offers.filter(status=DispatchOffer.Status.OFFERED).update(
            status=DispatchOffer.Status.REVOKED, responded_at=timezone.now()
        )
        record_transition(
            booking, Booking.Status.CANCELLED, actor_type=by, actor_id=actor_id, reason=reason
        )
        offer = booking.offers.filter(status=DispatchOffer.Status.ACCEPTED).first()
        if offer:
            driver = offer.driver
            if driver.online_state == DriverProfile.ONLINE_BUSY:
                driver.online_state = DriverProfile.ONLINE_AVAILABLE
                driver.save(update_fields=["online_state"])
    push_status(booking, {"by": by, "reason": reason})
    push_to_booking(
        str(booking.id),
        {
            "type": "booking.cancelled",
            "booking_id": str(booking.id),
            "by": by,
            "reason": reason,
        },
    )
    accepted = booking.offers.filter(status=DispatchOffer.Status.ACCEPTED).first()
    if by == "customer" and accepted is not None:
        notify_user(
            accepted.driver.user,
            type="booking",
            title="Customer cancelled",
            body=reason or "The customer cancelled this trip.",
            data={"booking_id": str(booking.id), "status": booking.status},
        )
    elif by == "driver":
        notify_user(
            booking.customer,
            type="booking",
            title="Trip cancelled",
            body=(
                f"Your captain cancelled the trip"
                + (f": {reason}" if reason else ".")
            ),
            data={"booking_id": str(booking.id), "status": booking.status},
        )
    return booking


def project_onto_route(
    geometry: list[dict], point: dict
) -> tuple[int, int]:
    """Remaining and total route metres for a driver `point` (flat projection).

    Used by the ETA endpoint so polling never hits the routing engine.
    """
    if len(geometry) < 2:
        return 0, 0
    mean_lat = sum(p["lat"] for p in geometry) / len(geometry)
    kx = 111320.0 * math.cos(math.radians(mean_lat))
    ky = 110540.0

    def xy(p):
        return (float(p["lng"]) * kx, float(p["lat"]) * ky)

    segments = []
    total = 0.0
    for a, b in zip(geometry, geometry[1:]):
        ax, ay = xy(a)
        bx, by = xy(b)
        length = math.hypot(bx - ax, by - ay)
        segments.append((ax, ay, bx, by, length, total))
        total += length

    px, py = xy(point)
    best_along = 0.0
    best_distance = float("inf")
    for ax, ay, bx, by, length, start in segments:
        if length == 0:
            continue
        t = ((px - ax) * (bx - ax) + (py - ay) * (by - ay)) / (length * length)
        t = max(0.0, min(1.0, t))
        cx, cy = ax + t * (bx - ax), ay + t * (by - ay)
        distance = math.hypot(px - cx, py - cy)
        if distance < best_distance:
            best_distance = distance
            best_along = start + t * length
    remaining = max(0.0, total - best_along)
    return int(round(remaining)), int(round(total))


def fail_stale_search(booking: Booking) -> bool:
    """Free/paid safety net: no Celery beat required to avoid limbo bookings."""
    from django.conf import settings

    if booking.status != Booking.Status.SEARCHING:
        return False
    minutes = int(getattr(settings, "STALE_SEARCH_MINUTES", 5))
    if booking.created_at > timezone.now() - timedelta(minutes=minutes):
        return False
    record_transition(
        booking,
        Booking.Status.FAILED,
        actor_type="system",
        reason="no_driver",
    )
    push_status(booking, {"reason": "no_driver"})
    notify_user(
        booking.customer,
        type="booking",
        title="No captain found",
        body="We could not find a captain nearby. Please try again.",
        data={"booking_id": str(booking.id), "status": booking.status},
    )
    return True
