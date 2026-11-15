"""Fleet owner console: overview, roster, vehicles, assignment, earnings."""
from __future__ import annotations

from django.db.models import Sum
from django.utils import timezone
from rest_framework import status
from rest_framework.response import Response
from rest_framework.views import APIView

from apps.accounts.models import DriverProfile, FleetPartner, User, Vehicle
from apps.api.serializers import (
    FleetDriverSerializer,
    FleetPartnerSerializer,
    VehicleSerializer,
)
from apps.api.views.partner import partner_for
from apps.bookings.models import Booking, DispatchOffer
from apps.catalog.models import ServiceCategory
from apps.core.exceptions import ApiError
from apps.core.permissions import IsFleetOwner
from apps.payments.models import CommissionEntry
from apps.core.notifications import notify_user


def fleet_for(request) -> FleetPartner:
    fleet = FleetPartner.objects.filter(owner=request.user).first()
    if fleet is None:
        fleet = FleetPartner.objects.create(
            owner=request.user,
            name=request.data.get("name")
            or f"{request.user.full_name or 'Zuum'} fleet",
        )
    return fleet


class FleetOverviewView(APIView):
    serializer_class = FleetPartnerSerializer
    permission_classes = [IsFleetOwner]

    def get(self, request):
        fleet = fleet_for(request)
        drivers = DriverProfile.objects.filter(fleet=fleet)
        today = timezone.localtime().replace(
            hour=0, minute=0, second=0, microsecond=0
        )
        online = drivers.exclude(online_state=DriverProfile.ONLINE_OFFLINE).count()
        on_trip = Booking.objects.filter(
            offers__driver__fleet=fleet,
            offers__status=DispatchOffer.Status.ACCEPTED,
            status=Booking.Status.IN_PROGRESS,
        ).distinct().count()
        vehicles = Vehicle.objects.filter(fleet=fleet)
        earnings = (
            CommissionEntry.objects.filter(
                driver__fleet=fleet, created_at__gte=today
            ).aggregate(total=Sum("driver_paise"))["total"]
            or 0
        )
        return Response(
            {
                "drivers_active": online,
                "drivers_total": drivers.count(),
                "vehicles_active": vehicles.filter(is_active=True).count(),
                "vehicles_total": vehicles.count(),
                "earnings_today_paise": earnings,
                "utilisation": round(on_trip / online, 3) if online else 0.0,
            }
        )


class FleetDriversView(APIView):
    serializer_class = FleetDriverSerializer
    permission_classes = [IsFleetOwner]

    def get(self, request):
        fleet = fleet_for(request)
        qs = (
            DriverProfile.objects.filter(fleet=fleet)
            .select_related("user")
            .order_by("-online_state", "user__first_name")
        )
        return Response(
            {
                "count": qs.count(),
                "next": None,
                "previous": None,
                "results": FleetDriverSerializer(qs, many=True).data,
            }
        )


class FleetInviteView(APIView):
    serializer_class = FleetPartnerSerializer
    permission_classes = [IsFleetOwner]

    def post(self, request):
        fleet = fleet_for(request)
        email = (request.data.get("email") or "").strip().lower()
        phone = (request.data.get("phone") or "").strip()
        if not email and not phone:
            raise ApiError(
                "Provide an email or phone to invite",
                code="validation_error",
                status_code=400,
            )
        invited_user = User.objects.filter(
            **({"email": email} if email else {"phone": phone})
        ).first()
        if invited_user is not None:
            notify_user(
                invited_user,
                type="fleet_invite",
                title="Fleet invitation",
                body=f"{fleet.name} invited you to drive with their fleet.",
                data={"fleet_id": str(fleet.id)},
            )
        return Response(
            {"status": "invited", "email": email, "phone": phone},
            status=status.HTTP_202_ACCEPTED,
        )


class FleetDriverDetailView(APIView):
    serializer_class = FleetDriverSerializer
    permission_classes = [IsFleetOwner]

    def delete(self, request, driver_id):
        fleet = fleet_for(request)
        driver = DriverProfile.objects.filter(pk=driver_id, fleet=fleet).first()
        if driver is None:
            raise ApiError("Driver not found", code="not_found", status_code=404)
        driver.fleet = None
        driver.save(update_fields=["fleet", "updated_at"])
        return Response(status=status.HTTP_204_NO_CONTENT)


class FleetVehiclesView(APIView):
    serializer_class = VehicleSerializer
    permission_classes = [IsFleetOwner]

    def get(self, request):
        fleet = fleet_for(request)
        vehicles = Vehicle.objects.filter(fleet=fleet).select_related("category")
        return Response(VehicleSerializer(vehicles, many=True).data)

    def post(self, request):
        fleet = fleet_for(request)
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
        driver = None
        if request.data.get("driver_id"):
            driver = DriverProfile.objects.filter(
                pk=request.data["driver_id"], fleet=fleet
            ).first()
        vehicle = Vehicle.objects.create(
            fleet=fleet,
            driver=driver,
            category=category,
            registration_number=plate,
            make=request.data.get("make") or "",
            model=request.data.get("model") or "",
            color=request.data.get("color") or "",
        )
        return Response(
            VehicleSerializer(vehicle).data, status=status.HTTP_201_CREATED
        )


class FleetVehicleAssignView(APIView):
    serializer_class = VehicleSerializer
    permission_classes = [IsFleetOwner]

    def put(self, request, vehicle_id):
        fleet = fleet_for(request)
        vehicle = Vehicle.objects.filter(pk=vehicle_id, fleet=fleet).first()
        if vehicle is None:
            raise ApiError("Vehicle not found", code="not_found", status_code=404)
        driver = DriverProfile.objects.filter(
            pk=request.data.get("driver_id"), fleet=fleet
        ).first()
        if driver is None:
            raise ApiError(
                "Driver is not part of this fleet",
                code="not_found",
                status_code=404,
            )
        vehicle.driver = driver
        vehicle.save(update_fields=["driver", "updated_at"])
        return Response(VehicleSerializer(vehicle).data)


class FleetEarningsView(APIView):
    serializer_class = FleetPartnerSerializer
    permission_classes = [IsFleetOwner]

    def get(self, request):
        from apps.api.views.partner import _range_start

        fleet = fleet_for(request)
        start = _range_start(request.query_params.get("range", "today"))
        entries = CommissionEntry.objects.filter(
            driver__fleet=fleet, created_at__gte=start
        )
        per_driver = (
            entries.values("driver__user__first_name", "driver__user__last_name")
            .annotate(
                net_paise=Sum("driver_paise"),
                commission_paise=Sum("platform_paise"),
            )
            .order_by("-net_paise")
        )
        return Response(
            {
                "range": request.query_params.get("range", "today"),
                "net_paise": entries.aggregate(total=Sum("driver_paise"))["total"]
                or 0,
                "commission_paise": entries.aggregate(
                    total=Sum("platform_paise")
                )["total"]
                or 0,
                "trips": entries.count(),
                "drivers": [
                    {
                        "name": f"{row['driver__user__first_name']} "
                        f"{row['driver__user__last_name']}".strip(),
                        "net_paise": row["net_paise"] or 0,
                        "commission_paise": row["commission_paise"] or 0,
                    }
                    for row in per_driver
                ],
            }
        )
