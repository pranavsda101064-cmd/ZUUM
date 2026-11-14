"""Routing endpoints + request validation."""
from __future__ import annotations

from rest_framework import serializers
from rest_framework.permissions import AllowAny, IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.routing.providers import PROFILE_TO_COSTING
from apps.routing.service import RoutingService


class WaypointSerializer(serializers.Serializer):
    lat = serializers.FloatField(min_value=-90, max_value=90)
    lng = serializers.FloatField(min_value=-180, max_value=180)


_PROFILES = list(PROFILE_TO_COSTING.keys())


class RouteRequestSerializer(serializers.Serializer):
    profile = serializers.ChoiceField(choices=_PROFILES, default="auto")
    waypoints = WaypointSerializer(many=True)
    steps = serializers.BooleanField(default=True)

    def validate_waypoints(self, value):
        if len(value) < 2:
            raise serializers.ValidationError("At least two waypoints are required")
        if len(value) > 25:
            raise serializers.ValidationError("At most 25 waypoints are supported")
        return value


class MatrixRequestSerializer(serializers.Serializer):
    profile = serializers.ChoiceField(choices=_PROFILES, default="auto")
    sources = WaypointSerializer(many=True)
    targets = WaypointSerializer(many=True)

    def validate(self, attrs):
        if not attrs["sources"] or not attrs["targets"]:
            raise serializers.ValidationError("Sources and targets are required")
        if len(attrs["sources"]) * len(attrs["targets"]) > 625:
            raise serializers.ValidationError("Matrix too large (max 25 x 25)")
        return attrs


class RouteView(APIView):
    serializer_class = RouteRequestSerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "quote"

    def post(self, request):
        serializer = RouteRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        result = RoutingService().route(
            data["waypoints"], profile=data["profile"], steps=data["steps"]
        )
        return Response(result.as_dict())


class MatrixView(APIView):
    serializer_class = MatrixRequestSerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "quote"

    def post(self, request):
        serializer = MatrixRequestSerializer(data=request.data)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        result = RoutingService().matrix(
            data["sources"], data["targets"], profile=data["profile"]
        )
        return Response(
            {
                "durations_s": result.durations_s,
                "distances_m": result.distances_m,
                "provider": result.provider,
                "degraded": result.degraded,
            }
        )


class RoutingHealthView(APIView):
    serializer_class = RouteRequestSerializer
    permission_classes = [AllowAny]
    authentication_classes = []

    def get(self, request):
        return Response(RoutingService().health())
