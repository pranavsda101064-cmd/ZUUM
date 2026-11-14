"""Service catalog + pricing quotes."""
from __future__ import annotations

from django.utils import timezone
from rest_framework import status
from rest_framework.permissions import AllowAny
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.api.serializers import (
    FareQuoteSerializer,
    QuoteRequestSerializer,
    ServiceCategorySerializer,
)
from apps.bookings.models import FareQuote
from apps.bookings.services import compute_quote
from apps.routing.service import RoutingService, profile_for_category
from apps.catalog.models import ServiceCategory
from apps.core.exceptions import ApiError


class ServiceCategoryListView(APIView):
    serializer_class = ServiceCategorySerializer
    permission_classes = [AllowAny]

    def get(self, request):
        qs = ServiceCategory.objects.filter(is_enabled=True)
        kind = request.query_params.get("kind")
        if kind == "ride":
            qs = qs.filter(kind=ServiceCategory.Kind.PASSENGER)
        elif kind == "goods":
            qs = qs.filter(kind=ServiceCategory.Kind.GOODS)
        return Response(ServiceCategorySerializer(qs, many=True).data)


class QuoteView(APIView):
    serializer_class = FareQuoteSerializer
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "quote"

    def post(self, request):
        serializer = QuoteRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data

        category = ServiceCategory.objects.filter(
            code=data["service_category"], is_enabled=True
        ).first()
        if category is None:
            raise ApiError(
                "Unknown service category", code="validation_error", status_code=400
            )
        expected = (
            ServiceCategory.Kind.PASSENGER
            if data["kind"] == "ride"
            else ServiceCategory.Kind.GOODS
        )
        if category.kind != expected:
            raise ApiError(
                "Service category does not match the booking kind",
                code="validation_error",
                status_code=400,
            )

        pickup = {"lat": float(data["pickup"].get("lat")), "lng": float(data["pickup"].get("lng"))}
        drop = {"lat": float(data["drop"].get("lat")), "lng": float(data["drop"].get("lng"))}
        goods = {
            "weight_kg": data.get("weight_kg"),
            "needs_loading_help": data.get("needs_loading_help", False),
        }

        route = RoutingService().route(
            [pickup, drop], profile=profile_for_category(category.code)
        )
        computed = compute_quote(
            category=category,
            pickup=pickup,
            drop=drop,
            scheduled_at=data.get("scheduled_at"),
            goods=goods if data["kind"] == "goods" else None,
            route=route,
        )
        quote = FareQuote.objects.create(
            customer=request.user,
            service_category=category,
            kind="ride" if data["kind"] == "ride" else "goods",
            pickup={**pickup, "address": data["pickup"].get("address", "")},
            drop={**drop, "address": data["drop"].get("address", "")},
            distance_m=computed["distance_m"],
            duration_s=computed["duration_s"],
            breakdown=computed["breakdown"],
            total_paise=computed["total_paise"],
            valid_until=computed["valid_until"],
            route_geometry=route.geometry,
            route_steps=[step.__dict__ for step in route.steps],
            route_provider=route.provider,
            route_degraded=route.degraded,
        )
        return Response(
            {
                "id": str(quote.id),
                "service_category": category.code,
                "service_category_name": category.name,
                "kind": quote.kind,
                "distance_m": quote.distance_m,
                "duration_s": quote.duration_s,
                "breakdown": quote.breakdown,
                "total_paise": quote.total_paise,
                "valid_until": quote.valid_until,
                "quoted_at": quote.created_at,
                "route": route.as_dict(),
            },
            status=status.HTTP_201_CREATED,
        )
