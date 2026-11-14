"""Partner surface: KYC, vehicles, availability, offers, trip lifecycle, money."""
from __future__ import annotations

import secrets
from datetime import datetime, timedelta

from django.db.models import Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import DriverProfile, KycDocument, User, Vehicle
from apps.accounts.services import ensure_driver_profile, set_availability, submit_kyc
from apps.api.serializers import (
    DispatchOfferSerializer,
    DriverProfileSerializer,
    KycDocumentSerializer,
    PartnerTripSerializer,
    PayoutSerializer,
    VehicleSerializer,
)
from apps.bookings.models import Booking, DispatchOffer, LocationPing
from apps.bookings.services import (
    accept_offer,
    arrive,
    assigned_trip,
    cancel_booking,
    complete_trip,
    decline_offer,
    expire_stale_offers,
    require_trip,
    verify_delivery_otp,
    verify_start_otp,
)
from apps.catalog.models import ServiceCategory
from apps.core.exceptions import ApiError
from rest_framework.permissions import IsAuthenticated

from apps.core.permissions import IsDriver
from apps.payments.models import CommissionEntry, Payout


def partner_for(request) -> DriverProfile:
    user = request.user
    profile = ensure_driver_profile(user)
    if user.role == User.Role.CUSTOMER:
        user.role = User.Role.DRIVER
        user.save(update_fields=["role"])
    return profile


def _trip_payload(booking: Booking) -> dict:
    booking = (
        Booking.objects.filter(pk=booking.pk)
        .select_related("customer", "service_category")
        .prefetch_related("offers__driver__user", "offers__vehicle__category")
        .first()
    )
    return PartnerTripSerializer(booking).data


class PartnerProfileView(APIView):
    serializer_class = DriverProfileSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        return Response(DriverProfileSerializer(driver).data)

    def put(self, request):
        driver = partner_for(request)
        user = request.user
        changed_user = False
        for field in ("first_name", "last_name", "phone"):
            if field in request.data:
                setattr(user, field, str(request.data[field]).strip())
                changed_user = True
        if changed_user:
            user.save(update_fields=["first_name", "last_name", "phone"])
        user_fields = []
        for field in ("languages", "home_lat", "home_lng", "bank_account_ref"):
            if field in request.data:
                setattr(driver, field, request.data[field])
                user_fields.append(field)
        if user_fields:
            driver.save(update_fields=[*user_fields, "updated_at"])
        return Response(DriverProfileSerializer(driver).data)


class PartnerKycView(APIView):
    serializer_class = KycDocumentSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        documents = driver.documents.all().order_by("type")
        return Response(
            {
                "status": driver.kyc_status,
                "submitted_at": driver.submitted_at,
                "reviewed_at": driver.reviewed_at,
                "rejection_reason": driver.rejection_reason,
                "documents": KycDocumentSerializer(documents, many=True).data,
            }
        )


class PartnerKycSubmitView(APIView):
    serializer_class = KycDocumentSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        driver = partner_for(request)
        submit_kyc(driver)
        return Response({"status": driver.kyc_status, "submitted_at": driver.submitted_at})


class PartnerDocumentListCreateView(APIView):
    serializer_class = KycDocumentSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        return Response(KycDocumentSerializer(driver.documents.all(), many=True).data)

    def post(self, request):
        driver = partner_for(request)
        doc_type = request.data.get("type")
        if doc_type not in dict(KycDocument.Type.choices):
            raise ApiError(
                "Unknown document type", code="validation_error", status_code=400
            )
        expires_at = request.data.get("expires_at") or None
        if expires_at:
            try:
                expires_at = datetime.fromisoformat(str(expires_at)).date()
            except ValueError:
                raise ApiError(
                    "expires_at must be an ISO date",
                    code="validation_error",
                    status_code=400,
                )
        document, _ = KycDocument.objects.update_or_create(
            driver=driver,
            type=doc_type,
            defaults={
                "file": request.FILES.get("file"),
                "expires_at": expires_at,
                "status": KycDocument.Status.PENDING,
            },
        )
        return Response(
            KycDocumentSerializer(document).data, status=status.HTTP_201_CREATED
        )


class PartnerDocumentDetailView(APIView):
    serializer_class = KycDocumentSerializer
    permission_classes = [IsAuthenticated]

    def delete(self, request, document_id):
        driver = partner_for(request)
        if driver.kyc_status not in (DriverProfile.KYC_DRAFT, DriverProfile.KYC_REJECTED):
            raise ApiError(
                "Documents can only be removed before submission",
                code="illegal_transition",
                status_code=409,
            )
        document = driver.documents.filter(pk=document_id).first()
        if document is None:
            raise ApiError("Document not found", code="not_found", status_code=404)
        document.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PartnerVehicleListCreateView(APIView):
    serializer_class = VehicleSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        vehicles = Vehicle.objects.filter(driver=driver).select_related("category")
        return Response(VehicleSerializer(vehicles, many=True).data)

    def post(self, request):
        driver = partner_for(request)
        category = ServiceCategory.objects.filter(
            code=request.data.get("category") or request.data.get("category_code")
        ).first()
        if category is None:
            raise ApiError(
                "Unknown vehicle category", code="validation_error", status_code=400
            )
        plate = (request.data.get("registration_number") or "").replace(" ", "").upper()
        if not plate:
            raise ApiError(
                "Registration number is required",
                code="validation_error",
                status_code=400,
            )
        if Vehicle.objects.filter(registration_number=plate).exists():
            raise ApiError(
                "A vehicle with this registration already exists",
                code="already_exists",
                status_code=409,
            )
        vehicle = Vehicle.objects.create(
            driver=driver,
            fleet=driver.fleet,
            category=category,
            registration_number=plate,
            make=request.data.get("make") or "",
            model=request.data.get("model") or "",
            color=request.data.get("color") or "",
            capacity_kg=request.data.get("capacity_kg") or category.capacity_kg,
            volume_cuft=request.data.get("volume_cuft") or category.volume_cuft,
            seats=request.data.get("seats") or category.seats,
        )
        return Response(
            VehicleSerializer(vehicle).data, status=status.HTTP_201_CREATED
        )


class PartnerVehicleDetailView(APIView):
    serializer_class = VehicleSerializer
    permission_classes = [IsAuthenticated]

    def _vehicle(self, request, vehicle_id):
        driver = partner_for(request)
        vehicle = Vehicle.objects.filter(pk=vehicle_id, driver=driver).first()
        if vehicle is None:
            raise ApiError("Vehicle not found", code="not_found", status_code=404)
        return vehicle

    def put(self, request, vehicle_id):
        vehicle = self._vehicle(request, vehicle_id)
        for field in ("make", "model", "color", "capacity_kg", "volume_cuft", "seats"):
            if field in request.data:
                setattr(vehicle, field, request.data[field])
        vehicle.save()
        return Response(VehicleSerializer(vehicle).data)

    def delete(self, request, vehicle_id):
        vehicle = self._vehicle(request, vehicle_id)
        if vehicle.is_active and vehicle.driver and vehicle.driver.online_state != DriverProfile.ONLINE_OFFLINE:
            raise ApiError(
                "Go offline before removing your active vehicle",
                code="illegal_transition",
                status_code=409,
            )
        vehicle.delete()
        return Response(status=status.HTTP_204_NO_CONTENT)


class PartnerVehicleAvailabilityView(APIView):
    serializer_class = VehicleSerializer
    permission_classes = [IsAuthenticated]

    def patch(self, request, vehicle_id):
        driver = partner_for(request)
        vehicle = Vehicle.objects.filter(pk=vehicle_id, driver=driver).first()
        if vehicle is None:
            raise ApiError("Vehicle not found", code="not_found", status_code=404)
        is_active = bool(request.data.get("is_active"))
        if not is_active and driver.online_state != DriverProfile.ONLINE_OFFLINE:
            raise ApiError(
                "Go offline before pausing your vehicle",
                code="illegal_transition",
                status_code=409,
            )
        vehicle.is_active = is_active
        vehicle.save(update_fields=["is_active", "updated_at"])
        return Response(VehicleSerializer(vehicle).data)


class PartnerAvailabilityView(APIView):
    serializer_class = DriverProfileSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        driver = partner_for(request)
        online = bool(request.data.get("online"))
        set_availability(
            driver, online=online, vehicle_id=request.data.get("vehicle_id")
        )
        return Response(
            {
                "online": driver.online_state != DriverProfile.ONLINE_OFFLINE,
                "state": driver.online_state,
            }
        )


class PartnerLocationView(APIView):
    serializer_class = DriverProfileSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request):
        driver = partner_for(request)
        lat, lng = request.data.get("lat"), request.data.get("lng")
        if lat is None or lng is None:
            raise ApiError(
                "lat and lng are required", code="validation_error", status_code=400
            )
        recorded = request.data.get("recorded_at")
        try:
            recorded_at = (
                datetime.fromisoformat(str(recorded)) if recorded else timezone.now()
            )
        except ValueError:
            recorded_at = timezone.now()
        from apps.bookings.services import accept_location_ping

        booking = assigned_trip(driver)
        if not accept_location_ping(driver, recorded_at=recorded_at, booking=booking):
            return Response(status=status.HTTP_204_NO_CONTENT)
        LocationPing.objects.create(
            driver=driver,
            lat=float(lat),
            lng=float(lng),
            heading=request.data.get("heading"),
            speed_mps=request.data.get("speed_mps"),
            source="rest",
            recorded_at=recorded_at,
        )
        driver.last_seen_at = timezone.now()
        driver.save(update_fields=["last_seen_at", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class PartnerOffersView(APIView):
    serializer_class = DispatchOfferSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        expire_stale_offers()
        offers = (
            DispatchOffer.objects.filter(
                driver=driver,
                status=DispatchOffer.Status.OFFERED,
                expires_at__gt=timezone.now(),
                booking__status=Booking.Status.SEARCHING,
            )
            .select_related("booking__service_category", "booking__customer")
            .order_by("expires_at")
        )
        return Response(DispatchOfferSerializer(offers, many=True).data)


class PartnerOfferAcceptView(APIView):
    serializer_class = PartnerTripSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, offer_id):
        driver = partner_for(request)
        offer = DispatchOffer.objects.select_related("booking").filter(
            pk=offer_id, driver=driver
        ).first()
        if offer is None:
            raise ApiError("Offer not found", code="not_found", status_code=404)
        booking = accept_offer(driver=driver, offer=offer)
        return Response(_trip_payload(booking))


class PartnerOfferDeclineView(APIView):
    serializer_class = DispatchOfferSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, offer_id):
        driver = partner_for(request)
        offer = DispatchOffer.objects.filter(pk=offer_id, driver=driver).first()
        if offer is None:
            raise ApiError("Offer not found", code="not_found", status_code=404)
        decline_offer(driver=driver, offer=offer, reason=request.data.get("reason") or "")
        return Response(status=status.HTTP_204_NO_CONTENT)


class PartnerActiveTripView(APIView):
    serializer_class = PartnerTripSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        booking = assigned_trip(driver)
        return Response({"trip": _trip_payload(booking) if booking else None})


class PartnerTripActionView(APIView):
    serializer_class = PartnerTripSerializer
    permission_classes = [IsAuthenticated]

    ACTION_MAP = {
        "arrive": None,
        "verify-otp": None,
        "verify-delivery-otp": None,
        "complete": None,
        "cancel": None,
    }

    def post(self, request, booking_id, action):
        if action not in self.ACTION_MAP:
            raise ApiError("Unknown action", code="not_found", status_code=404)
        driver = partner_for(request)
        booking = require_trip(driver, booking_id)

        if action == "arrive":
            arrive(driver=driver, booking=booking)
        elif action == "verify-otp":
            otp = (request.data.get("otp") or "").strip()
            verify_start_otp(driver=driver, booking=booking, otp=otp)
        elif action == "verify-delivery-otp":
            otp = (request.data.get("otp") or "").strip()
            verify_delivery_otp(driver=driver, booking=booking, otp=otp)
        elif action == "complete":
            complete_trip(driver=driver, booking=booking)
        elif action == "cancel":
            reason = (request.data.get("reason") or "").strip()
            if not reason:
                raise ApiError(
                    "A cancellation reason is required",
                    code="validation_error",
                    status_code=400,
                )
            cancel_booking(
                booking, by="driver", actor_id=driver.user_id, reason=reason
            )
        booking.refresh_from_db()
        return Response(_trip_payload(booking))


class PartnerPickupPodView(APIView):
    serializer_class = PartnerTripSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, booking_id):
        driver = partner_for(request)
        booking = require_trip(driver, booking_id)
        if booking.type != Booking.Type.GOODS or not hasattr(booking, "shipment"):
            raise ApiError(
                "Pickup POD applies to goods trips only",
                code="illegal_transition",
                status_code=409,
            )
        photo = request.FILES.get("photo")
        if photo is None:
            raise ApiError(
                "A pickup photo is required", code="validation_error", status_code=400
            )
        shipment = booking.shipment
        shipment.pickup_pod = photo
        shipment.save(update_fields=["pickup_pod"])
        return Response({"recorded": True})


class PartnerDeliveryPodView(APIView):
    serializer_class = PartnerTripSerializer
    permission_classes = [IsAuthenticated]

    def post(self, request, booking_id):
        driver = partner_for(request)
        booking = require_trip(driver, booking_id)
        if booking.type != Booking.Type.GOODS or not hasattr(booking, "shipment"):
            raise ApiError(
                "Delivery POD applies to goods trips only",
                code="illegal_transition",
                status_code=409,
            )
        shipment = booking.shipment
        if shipment.delivery_otp_verified_at is None:
            raise ApiError(
                "Verify the delivery OTP first",
                code="pod_missing",
                status_code=409,
            )
        receiver = (request.data.get("receiver_name") or "").strip()
        if not receiver:
            raise ApiError(
                "Receiver name is required",
                code="validation_error",
                status_code=400,
            )
        shipment.pod_receiver = receiver[:80]
        shipment.pod_signed_at = timezone.now()
        if request.FILES.get("photo"):
            shipment.delivery_pod = request.FILES["photo"]
        if request.FILES.get("signature"):
            shipment.delivery_signature = request.FILES["signature"]
        shipment.save()
        return Response({"recorded": True, "receiver": shipment.pod_receiver})


def _range_start(range_key: str) -> datetime:
    now = timezone.localtime()
    if range_key == "week":
        return now - timedelta(days=7)
    if range_key == "month":
        return now - timedelta(days=30)
    return now.replace(hour=0, minute=0, second=0, microsecond=0)


class PartnerEarningsView(APIView):
    serializer_class = PayoutSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        start = _range_start(request.query_params.get("range", "today"))
        entries = CommissionEntry.objects.filter(
            driver=driver, created_at__gte=start
        )
        gross = entries.aggregate(
            gross=Sum("platform_paise") + Sum("driver_paise")
        )["gross"] or 0
        platform = entries.aggregate(total=Sum("platform_paise"))["total"] or 0
        net = entries.aggregate(total=Sum("driver_paise"))["total"] or 0

        offers = DispatchOffer.objects.filter(driver=driver, offered_at__gte=start)
        responded = offers.exclude(status=DispatchOffer.Status.OFFERED).count()
        accepted = offers.filter(status=DispatchOffer.Status.ACCEPTED).count()
        acceptance = round(accepted / responded * 100, 1) if responded else 0.0

        trips = entries.count()
        cancelled = Booking.objects.filter(
            offers__driver=driver,
            offers__status=DispatchOffer.Status.ACCEPTED,
            status=Booking.Status.CANCELLED,
            created_at__gte=start,
        ).distinct().count()
        cancellation = (
            round(cancelled / (trips + cancelled) * 100, 1) if trips + cancelled else 0.0
        )
        online_minutes = (
            entries.aggregate(total=Sum("booking__duration_s"))["total"] or 0
        ) // 60
        return Response(
            {
                "gross_paise": gross,
                "commission_paise": platform,
                "net_paise": net,
                "trips": trips,
                "online_minutes": online_minutes,
                "acceptance_rate": acceptance,
                "cancellation_rate": cancellation,
            }
        )


class PartnerEarningTripsView(APIView):
    serializer_class = PayoutSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        entries = (
            CommissionEntry.objects.filter(driver=driver)
            .select_related("booking__service_category")
            .order_by("-created_at")
        )
        page = max(1, int(request.query_params.get("page", 1) or 1))
        size = max(1, min(100, int(request.query_params.get("page_size", 20) or 20)))
        total = entries.count()
        items = entries[(page - 1) * size : page * size]
        return Response(
            {
                "count": total,
                "next": (
                    request.build_absolute_uri(f"?page={page + 1}")
                    if page * size < total
                    else None
                ),
                "previous": None,
                "results": [
                    {
                        "booking_id": str(entry.booking_id),
                        "at": entry.created_at,
                        "category_name": entry.booking.service_category.name,
                        "is_goods": entry.booking.type == Booking.Type.GOODS,
                        "fare_paise": entry.driver_paise + entry.platform_paise,
                        "commission_paise": entry.platform_paise,
                        "earning_paise": entry.driver_paise,
                        "payment_method": entry.booking.payment_method,
                        "tip_paise": entry.tips_paise,
                    }
                    for entry in items
                ],
            }
        )


class PartnerPayoutsView(APIView):
    serializer_class = PayoutSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        payouts = Payout.objects.filter(driver=driver).order_by("-created_at")
        return Response(
            {
                "count": payouts.count(),
                "next": None,
                "previous": None,
                "results": PayoutSerializer(payouts[:50], many=True).data,
            }
        )


class PartnerStatsView(APIView):
    serializer_class = DriverProfileSerializer
    permission_classes = [IsAuthenticated]

    def get(self, request):
        driver = partner_for(request)
        today = _range_start("today")
        week = _range_start("week")
        completed = Booking.objects.filter(
            offers__driver=driver,
            offers__status=DispatchOffer.Status.ACCEPTED,
            status=Booking.Status.COMPLETED,
        ).distinct()
        cancelled = Booking.objects.filter(
            offers__driver=driver,
            offers__status=DispatchOffer.Status.ACCEPTED,
            status=Booking.Status.CANCELLED,
        ).distinct()
        total = completed.count() + cancelled.count()
        trend = []
        for offset in range(6, -1, -1):
            day = today - timedelta(days=offset)
            day_end = day + timedelta(days=1)
            entries = CommissionEntry.objects.filter(
                driver=driver, created_at__gte=day, created_at__lt=day_end
            )
            trend.append(
                {
                    "date": day.date().isoformat(),
                    "trips": entries.count(),
                    "net_paise": entries.aggregate(total=Sum("driver_paise"))["total"]
                    or 0,
                }
            )
        return Response(
            {
                "rating_avg": float(driver.rating_avg),
                "rating_count": driver.rating_count,
                "completion_rate": (
                    round(completed.count() / total * 100, 1) if total else 100.0
                ),
                "weekly_trend": trend,
                "trips_today": CommissionEntry.objects.filter(
                    driver=driver, created_at__gte=today
                ).count(),
                "week_trips": CommissionEntry.objects.filter(
                    driver=driver, created_at__gte=week
                ).count(),
            }
        )
