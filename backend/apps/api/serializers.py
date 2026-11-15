"""DRF serializers matching the frozen consumer + partner contracts."""
from __future__ import annotations

from datetime import timedelta

from django.utils import timezone
from rest_framework import serializers

from apps.accounts.models import (
    CustomerProfile,
    DriverProfile,
    FleetPartner,
    KycDocument,
    SavedAddress,
    User,
    Vehicle,
)
from apps.bookings.models import (
    Booking,
    BookingStatusHistory,
    DispatchOffer,
    FareQuote,
    GoodsShipment,
    PassengerTrip,
    Review,
)
from apps.catalog.models import PromoCampaign, Referral, ServiceCategory
from apps.payments.models import Payment, Payout, Wallet, WalletTransaction
from apps.platform.models import Notification, SupportTicket


# --- users / profiles -----------------------------------------------------------------


class UserSerializer(serializers.ModelSerializer):
    class Meta:
        model = User
        fields = (
            "id",
            "email",
            "first_name",
            "last_name",
            "phone",
            "phone_verified",
            "role",
            "created_at",
        )
        read_only_fields = ("id", "phone_verified", "role", "created_at")


class CustomerProfileSerializer(serializers.ModelSerializer):
    class Meta:
        model = CustomerProfile
        fields = ("id", "default_payment_method", "is_restricted")
        read_only_fields = ("id", "is_restricted")


class SavedAddressSerializer(serializers.ModelSerializer):
    address = serializers.CharField(source="formatted_address")

    class Meta:
        model = SavedAddress
        fields = ("id", "label", "name", "lat", "lng", "address", "is_default")
        read_only_fields = ("id",)


class DriverProfileSerializer(serializers.ModelSerializer):
    user = UserSerializer(read_only=True)
    full_name = serializers.CharField(source="user.full_name", read_only=True)
    acceptance_rate = serializers.SerializerMethodField()
    document_count = serializers.SerializerMethodField()
    required_document_count = serializers.SerializerMethodField()

    class Meta:
        model = DriverProfile
        fields = (
            "id",
            "user",
            "full_name",
            "licence_number",
            "kyc_status",
            "approval_status",
            "rating_avg",
            "rating_count",
            "online_state",
            "languages",
            "home_lat",
            "home_lng",
            "rejection_reason",
            "submitted_at",
            "reviewed_at",
            "acceptance_rate",
            "document_count",
            "required_document_count",
        )
        read_only_fields = (
            "id",
            "kyc_status",
            "approval_status",
            "rating_avg",
            "rating_count",
            "online_state",
            "rejection_reason",
            "submitted_at",
            "reviewed_at",
            "acceptance_rate",
            "document_count",
            "required_document_count",
        )

    def get_acceptance_rate(self, obj) -> float:
        from apps.bookings.models import DispatchOffer

        since = timezone.now() - timedelta(days=30)
        offers = DispatchOffer.objects.filter(driver=obj, offered_at__gte=since)
        responded = offers.exclude(status=DispatchOffer.Status.OFFERED).count()
        accepted = offers.filter(status=DispatchOffer.Status.ACCEPTED).count()
        return round(accepted / responded * 100, 1) if responded else 0.0

    def get_document_count(self, obj) -> int:
        return obj.documents.count()

    def get_required_document_count(self, obj) -> int:
        return 3


class KycDocumentSerializer(serializers.ModelSerializer):
    class Meta:
        model = KycDocument
        fields = ("id", "type", "expires_at", "status", "created_at")
        read_only_fields = ("id", "status", "created_at")


class VehicleSerializer(serializers.ModelSerializer):
    category_name = serializers.CharField(source="category.name", read_only=True)
    category_code = serializers.CharField(source="category.code", read_only=True)

    class Meta:
        model = Vehicle
        fields = (
            "id",
            "category_code",
            "category_name",
            "registration_number",
            "make",
            "model",
            "color",
            "capacity_kg",
            "volume_cuft",
            "seats",
            "is_active",
            "insurance_expires_at",
            "created_at",
        )
        read_only_fields = ("id", "category_code", "category_name", "created_at")


class FleetDriverSerializer(serializers.ModelSerializer):
    name = serializers.CharField(source="user.full_name", read_only=True)
    phone_masked = serializers.SerializerMethodField()
    online = serializers.SerializerMethodField()
    trips_today = serializers.SerializerMethodField()
    earnings_today_paise = serializers.SerializerMethodField()
    vehicle_registration = serializers.SerializerMethodField()
    is_verified = serializers.SerializerMethodField()

    class Meta:
        model = DriverProfile
        fields = (
            "id",
            "name",
            "phone_masked",
            "online",
            "rating_avg",
            "trips_today",
            "earnings_today_paise",
            "vehicle_registration",
            "is_verified",
        )

    def get_phone_masked(self, obj) -> str:
        phone = obj.user.phone or ""
        return f"{phone[:5]}•••{phone[-2:]}" if len(phone) > 6 else phone

    def get_online(self, obj) -> bool:
        return obj.online_state != DriverProfile.ONLINE_OFFLINE

    def _today_commissions(self, obj):
        from django.utils import timezone as tz

        start = tz.localtime().replace(hour=0, minute=0, second=0, microsecond=0)
        return obj.commissions.filter(created_at__gte=start)

    def get_trips_today(self, obj) -> int:
        return self._today_commissions(obj).count()

    def get_earnings_today_paise(self, obj) -> int:
        return sum(c.driver_paise for c in self._today_commissions(obj))

    def get_vehicle_registration(self, obj):
        vehicle = obj.vehicles.order_by("-is_active", "-created_at").first()
        return vehicle.registration_number if vehicle else None

    def get_is_verified(self, obj) -> bool:
        return obj.kyc_status == DriverProfile.KYC_APPROVED


class FleetPartnerSerializer(serializers.ModelSerializer):
    class Meta:
        model = FleetPartner
        fields = ("id", "name", "gstin", "kyc_status", "payout_method")


# --- catalog --------------------------------------------------------------------------


class ServiceCategorySerializer(serializers.ModelSerializer):
    kind = serializers.SerializerMethodField()

    class Meta:
        model = ServiceCategory
        fields = (
            "code",
            "kind",
            "name",
            "seats",
            "capacity_kg",
            "volume_cuft",
            "max_weight_kg",
        )

    def get_kind(self, obj) -> str:
        return "ride" if obj.kind == ServiceCategory.Kind.PASSENGER else "goods"


class QuoteRequestSerializer(serializers.Serializer):
    kind = serializers.ChoiceField(choices=["ride", "goods"])
    service_category = serializers.CharField()
    pickup = serializers.DictField()
    drop = serializers.DictField()
    scheduled_at = serializers.DateTimeField(required=False, allow_null=True)
    weight_kg = serializers.IntegerField(required=False, allow_null=True)
    needs_loading_help = serializers.BooleanField(required=False, default=False)


class FareQuoteSerializer(serializers.ModelSerializer):
    service_category = serializers.SerializerMethodField()
    total_paise = serializers.IntegerField()
    breakdown = serializers.JSONField()

    class Meta:
        model = FareQuote
        fields = (
            "id",
            "service_category",
            "distance_m",
            "duration_s",
            "breakdown",
            "total_paise",
            "valid_until",
            "created_at",
        )

    def get_service_category(self, obj) -> dict:
        return ServiceCategorySerializer(obj.service_category).data


# --- bookings -------------------------------------------------------------------------


class BookingStatusHistorySerializer(serializers.ModelSerializer):
    class Meta:
        model = BookingStatusHistory
        fields = ("from_status", "to_status", "actor_type", "reason", "at")


class PassengerTripSerializer(serializers.ModelSerializer):
    class Meta:
        model = PassengerTrip
        fields = ("ride_type", "passengers", "stops")


class GoodsShipmentSerializer(serializers.ModelSerializer):
    class Meta:
        model = GoodsShipment
        fields = (
            "goods_type",
            "weight_kg",
            "dimensions_cuft",
            "needs_loading_help",
            "load_type",
            "sender_name",
            "sender_phone",
            "receiver_name",
            "receiver_phone",
            "stops",
            "pod_required",
        )


class ParticipantDriverSerializer(serializers.Serializer):
    id = serializers.UUIDField()
    name = serializers.CharField()
    phone = serializers.CharField()
    rating_avg = serializers.FloatField()
    photo_url = serializers.CharField(allow_null=True)


class ParticipantVehicleSerializer(serializers.Serializer):
    registration_number = serializers.CharField()
    make = serializers.CharField()
    color = serializers.CharField()
    category = serializers.CharField()


class BookingSerializer(serializers.ModelSerializer):
    service_category = ServiceCategorySerializer(read_only=True)
    pickup = serializers.SerializerMethodField()
    drop = serializers.SerializerMethodField()
    fare = serializers.SerializerMethodField()
    driver = serializers.SerializerMethodField()
    vehicle = serializers.SerializerMethodField()
    trip = serializers.SerializerMethodField()
    shipment = serializers.SerializerMethodField()
    history = serializers.SerializerMethodField()
    route = serializers.SerializerMethodField()
    otp = serializers.SerializerMethodField()

    class Meta:
        model = Booking
        fields = (
            "id",
            "type",
            "status",
            "service_category",
            "pickup",
            "drop",
            "fare",
            "payment_method",
            "payment_state",
            "scheduled_at",
            "created_at",
            "driver",
            "vehicle",
            "trip",
            "shipment",
            "history",
            "promo_code",
            "discount_paise",
            "route",
            "otp",
        )

    def get_fare(self, obj) -> dict:
        return {
            "quoted_paise": obj.quoted_fare_paise,
            "final_paise": obj.final_fare_paise,
            "currency": obj.currency,
        }

    def _offer(self, obj):
        return obj.offers.filter(status=DispatchOffer.Status.ACCEPTED).first()

    def get_driver(self, obj) -> dict | None:
        offer = self._offer(obj)
        if not offer:
            return None
        driver = offer.driver
        return ParticipantDriverSerializer(
            {
                "id": driver.id,
                "name": driver.user.full_name,
                "phone": driver.user.phone,
                "rating_avg": float(driver.rating_avg),
                "photo_url": None,
            }
        ).data

    def get_vehicle(self, obj) -> dict | None:
        offer = self._offer(obj)
        if not offer or not offer.vehicle:
            return None
        vehicle = offer.vehicle
        return ParticipantVehicleSerializer(
            {
                "registration_number": vehicle.registration_number,
                "make": vehicle.make,
                "color": vehicle.color,
                "category": vehicle.category.code,
            }
        ).data

    def get_trip(self, obj) -> dict | None:
        if hasattr(obj, "passenger_trip"):
            return PassengerTripSerializer(obj.passenger_trip).data
        return None

    def get_shipment(self, obj) -> dict | None:
        if hasattr(obj, "shipment"):
            return GoodsShipmentSerializer(obj.shipment).data
        return None

    def get_history(self, obj) -> list:
        return BookingStatusHistorySerializer(obj.history.all()[:10], many=True).data

    def get_route(self, obj) -> dict | None:
        if not obj.route_geometry:
            return None
        return {
            "geometry": obj.route_geometry,
            "steps": obj.route_steps,
            "provider": obj.route_provider,
            "degraded": obj.route_degraded,
            "distance_m": obj.distance_m,
            "duration_s": obj.duration_s,
        }

    def get_otp(self, obj) -> str | None:
        # Customer-facing trip OTP (shared with the driver at pickup/delivery).
        if obj.type == Booking.Type.GOODS and hasattr(obj, "shipment"):
            return obj.shipment.delivery_otp
        if hasattr(obj, "passenger_trip"):
            return obj.passenger_trip.start_otp
        return None

    def get_pickup(self, obj) -> dict:
        return {
            "lat": obj.pickup_lat,
            "lng": obj.pickup_lng,
            "address": obj.pickup_address,
        }

    def get_drop(self, obj) -> dict:
        return {
            "lat": obj.drop_lat,
            "lng": obj.drop_lng,
            "address": obj.drop_address,
        }


class BookingCreateSerializer(serializers.Serializer):
    quote_id = serializers.UUIDField()
    pickup = serializers.DictField(required=False)
    drop = serializers.DictField(required=False)
    payment_method = serializers.ChoiceField(
        choices=Booking.PaymentMethod.choices, default=Booking.PaymentMethod.CASH
    )
    promo_code = serializers.CharField(required=False, allow_blank=True)
    notes = serializers.CharField(required=False, allow_blank=True)
    scheduled_at = serializers.DateTimeField(required=False, allow_null=True)
    goods = serializers.DictField(required=False, allow_null=True)


class PartnerTripSerializer(serializers.ModelSerializer):
    """Booking as seen by the assigned driver (contract section 06)."""

    kind = serializers.SerializerMethodField()
    pickup = serializers.SerializerMethodField()
    drop = serializers.SerializerMethodField()
    service_category_name = serializers.CharField(
        source="service_category.name", read_only=True
    )
    customer = serializers.SerializerMethodField()
    fare_paise = serializers.SerializerMethodField()
    quoted_fare_paise = serializers.IntegerField(read_only=True)
    commission_paise = serializers.SerializerMethodField()
    earning_paise = serializers.SerializerMethodField()
    customer_first_name = serializers.SerializerMethodField()
    customer_phone_masked = serializers.SerializerMethodField()
    goods_type = serializers.SerializerMethodField()
    needs_loading_help = serializers.SerializerMethodField()
    dev_otp_hint = serializers.SerializerMethodField()
    route = serializers.SerializerMethodField()
    booking_id = serializers.UUIDField(source="id", read_only=True)

    class Meta:
        model = Booking
        fields = (
            "booking_id",
            "kind",
            "status",
            "pickup",
            "drop",
            "distance_m",
            "quoted_fare_paise",
            "fare_paise",
            "commission_paise",
            "earning_paise",
            "service_category_name",
            "customer",
            "customer_first_name",
            "customer_phone_masked",
            "payment_method",
            "payment_state",
            "goods_type",
            "needs_loading_help",
            "created_at",
            "route",
            "dev_otp_hint",
        )

    def get_kind(self, obj) -> str:
        return "goods" if obj.type == Booking.Type.GOODS else "ride"

    def get_route(self, obj) -> dict | None:
        if not obj.route_geometry:
            return None
        return {
            "geometry": obj.route_geometry,
            "steps": obj.route_steps,
            "provider": obj.route_provider,
            "degraded": obj.route_degraded,
            "distance_m": obj.distance_m,
            "duration_s": obj.duration_s,
        }

    def get_otp(self, obj) -> str | None:
        # Customer-facing trip OTP (shared with the driver at pickup/delivery).
        if obj.type == Booking.Type.GOODS and hasattr(obj, "shipment"):
            return obj.shipment.delivery_otp
        if hasattr(obj, "passenger_trip"):
            return obj.passenger_trip.start_otp
        return None

    def get_pickup(self, obj) -> dict:
        return {
            "lat": obj.pickup_lat,
            "lng": obj.pickup_lng,
            "address": obj.pickup_address,
        }

    def get_drop(self, obj) -> dict:
        return {"lat": obj.drop_lat, "lng": obj.drop_lng, "address": obj.drop_address}

    def get_customer(self, obj) -> dict:
        return {
            "first_name": obj.customer.first_name,
            "phone_masked": self.get_customer_phone_masked(obj),
        }

    def get_customer_first_name(self, obj) -> str:
        return obj.customer.first_name

    def get_customer_phone_masked(self, obj) -> str:
        phone = obj.customer.phone
        return f"{phone[:5]} •••{phone[-2:]}" if len(phone) > 6 else "•••••"

    def _offer(self, obj):
        return obj.offers.filter(status=DispatchOffer.Status.ACCEPTED).first()

    def _commission(self, obj):
        return getattr(obj, "commission", None)

    def get_commission_paise(self, obj) -> int:
        entry = self._commission(obj)
        if entry:
            return entry.platform_paise
        return 0

    def get_earning_paise(self, obj) -> int:
        entry = self._commission(obj)
        if entry:
            return entry.driver_paise
        return 0

    def get_fare_paise(self, obj) -> int:
        return obj.final_fare_paise or obj.quoted_fare_paise

    def get_goods_type(self, obj) -> str | None:
        return obj.shipment.goods_type if hasattr(obj, "shipment") else None

    def get_needs_loading_help(self, obj) -> bool:
        return obj.shipment.needs_loading_help if hasattr(obj, "shipment") else False

    def get_route(self, obj) -> dict | None:
        if not obj.route_geometry:
            return None
        return {
            "geometry": obj.route_geometry,
            "steps": obj.route_steps,
            "provider": obj.route_provider,
            "degraded": obj.route_degraded,
            "distance_m": obj.distance_m,
            "duration_s": obj.duration_s,
        }

    def get_dev_otp_hint(self, obj) -> str | None:
        from django.conf import settings

        if not getattr(settings, "EXPOSE_DEV_OTP", settings.DEBUG):
            return None
        if obj.type == Booking.Type.GOODS and hasattr(obj, "shipment"):
            return obj.shipment.delivery_otp or obj.shipment.pickup_otp
        if hasattr(obj, "passenger_trip"):
            return obj.passenger_trip.start_otp
        return None


class DispatchOfferSerializer(serializers.ModelSerializer):
    booking_id = serializers.UUIDField(source="booking.id", read_only=True)
    pickup = serializers.SerializerMethodField()
    drop = serializers.SerializerMethodField()
    distance_m = serializers.IntegerField(source="booking.distance_m")
    pickup_eta_s = serializers.SerializerMethodField()
    fare_paise = serializers.SerializerMethodField()
    surge_multiplier = serializers.SerializerMethodField()
    service_category = serializers.SerializerMethodField()
    booking_type = serializers.SerializerMethodField()
    goods = serializers.SerializerMethodField()
    kind = serializers.SerializerMethodField()
    service_category_name = serializers.SerializerMethodField()
    customer_first_name = serializers.SerializerMethodField()
    dev_otp_hint = serializers.SerializerMethodField()
    expires_in_s = serializers.SerializerMethodField()

    class Meta:
        model = DispatchOffer
        fields = (
            "id",
            "booking_id",
            "status",
            "expires_at",
            "expires_in_s",
            "pickup",
            "drop",
            "distance_m",
            "pickup_eta_s",
            "fare_paise",
            "surge_multiplier",
            "service_category",
            "booking_type",
            "kind",
            "service_category_name",
            "customer_first_name",
            "goods",
            "dev_otp_hint",
        )

    def get_pickup(self, obj) -> dict:
        b = obj.booking
        return {"lat": b.pickup_lat, "lng": b.pickup_lng, "address": b.pickup_address}

    def get_drop(self, obj) -> dict:
        b = obj.booking
        return {"lat": b.drop_lat, "lng": b.drop_lng, "address": b.drop_address}

    def get_pickup_eta_s(self, obj) -> int:
        return max(60, obj.booking.duration_s // 4)

    def get_fare_paise(self, obj) -> int:
        return obj.booking.quoted_fare_paise

    def get_surge_multiplier(self, obj) -> float:
        quote = obj.booking.quotes.order_by("-created_at").first()
        return float(quote.breakdown.get("surge_multiplier", 1.0)) if quote else 1.0

    def get_service_category(self, obj) -> dict:
        return ServiceCategorySerializer(obj.booking.service_category).data

    def get_booking_type(self, obj) -> str:
        return "goods" if obj.booking.type == Booking.Type.GOODS else "ride"

    def get_kind(self, obj) -> str:
        return self.get_booking_type(obj)

    def get_service_category_name(self, obj) -> str:
        return obj.booking.service_category.name

    def get_customer_first_name(self, obj) -> str:
        return obj.booking.customer.first_name

    def get_goods(self, obj) -> dict | None:
        if not hasattr(obj.booking, "shipment"):
            return None
        shipment = obj.booking.shipment
        return {
            "goods_type": shipment.goods_type,
            "weight_kg": shipment.weight_kg,
            "needs_loading_help": shipment.needs_loading_help,
        }

    def get_route(self, obj) -> dict | None:
        if not obj.route_geometry:
            return None
        return {
            "geometry": obj.route_geometry,
            "steps": obj.route_steps,
            "provider": obj.route_provider,
            "degraded": obj.route_degraded,
            "distance_m": obj.distance_m,
            "duration_s": obj.duration_s,
        }

    def get_dev_otp_hint(self, obj) -> str | None:
        from django.conf import settings

        if not getattr(settings, "EXPOSE_DEV_OTP", settings.DEBUG):
            return None
        b = obj.booking
        if b.type == Booking.Type.GOODS and hasattr(b, "shipment"):
            return b.shipment.pickup_otp
        if hasattr(b, "passenger_trip"):
            return b.passenger_trip.start_otp
        return None

    def get_expires_in_s(self, obj) -> int:
        return max(0, int((obj.expires_at - timezone.now()).total_seconds()))


class ReviewSerializer(serializers.ModelSerializer):
    class Meta:
        model = Review
        fields = ("id", "booking", "rating", "comment", "tags", "created_at")
        read_only_fields = ("id", "booking", "created_at")


# --- money ----------------------------------------------------------------------------


class WalletSerializer(serializers.ModelSerializer):
    class Meta:
        model = Wallet
        fields = ("balance_paise", "currency")


class WalletTransactionSerializer(serializers.ModelSerializer):
    class Meta:
        model = WalletTransaction
        fields = (
            "id",
            "kind",
            "amount_paise",
            "balance_after",
            "reference",
            "note",
            "created_at",
        )


class PaymentSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payment
        fields = (
            "id",
            "booking",
            "method",
            "amount_paise",
            "status",
            "gateway_order_id",
            "gateway_payment_id",
            "processed_at",
        )


class PayoutSerializer(serializers.ModelSerializer):
    class Meta:
        model = Payout
        fields = (
            "id",
            "amount_paise",
            "status",
            "method",
            "paid_at",
            "batch_ref",
            "created_at",
        )


class PromoSerializer(serializers.ModelSerializer):
    class Meta:
        model = PromoCampaign
        fields = (
            "code",
            "kind",
            "value",
            "max_discount_paise",
            "min_fare_paise",
            "valid_to",
        )


class ReferralSerializer(serializers.ModelSerializer):
    invites = serializers.SerializerMethodField()
    rewards_paise = serializers.SerializerMethodField()

    class Meta:
        model = Referral
        fields = ("code", "status", "invites", "rewards_paise")

    def get_invites(self, obj) -> int:
        return Referral.objects.filter(referrer=obj.referrer).count()

    def get_rewards_paise(self, obj) -> int:
        rewarded = Referral.objects.filter(
            referrer=obj.referrer, status=Referral.Status.REWARDED
        ).count()
        return rewarded * obj.reward_referrer_paise


# --- platform -------------------------------------------------------------------------


class NotificationSerializer(serializers.ModelSerializer):
    class Meta:
        model = Notification
        fields = ("id", "type", "title", "body", "data", "read_at", "created_at")


class SupportTicketSerializer(serializers.ModelSerializer):
    class Meta:
        model = SupportTicket
        fields = (
            "id",
            "booking",
            "category",
            "subject",
            "status",
            "priority",
            "created_at",
        )
        read_only_fields = ("id", "status", "created_at")

class LoginSerializer(serializers.Serializer):
    email = serializers.EmailField()
    password = serializers.CharField()


class LogoutSerializer(serializers.Serializer):
    refresh = serializers.CharField()


class PasswordForgotSerializer(serializers.Serializer):
    email = serializers.EmailField()


class PasswordResetSerializer(serializers.Serializer):
    token = serializers.CharField()
    password = serializers.CharField(min_length=6)
