"""Place search + reverse geocoding endpoints (OSM proxied, cached)."""
from __future__ import annotations

from rest_framework import serializers
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.throttling import ScopedRateThrottle
from rest_framework.views import APIView

from apps.core.exceptions import ApiError
from apps.places.service import PlacesError, PlacesService


class PlaceSearchQuerySerializer(serializers.Serializer):
    q = serializers.CharField(max_length=120)
    lat = serializers.FloatField(required=False)
    lng = serializers.FloatField(required=False)
    limit = serializers.IntegerField(required=False, default=8, min_value=1, max_value=20)


class ReverseQuerySerializer(serializers.Serializer):
    lat = serializers.FloatField()
    lng = serializers.FloatField()


class PlaceSearchView(APIView):
    serializer_class = PlaceSearchQuerySerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "quote"

    def get(self, request):
        serializer = PlaceSearchQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = PlacesService().search(
                data["q"],
                lat=data.get("lat"),
                lng=data.get("lng"),
                limit=data.get("limit", 8),
            )
        except PlacesError as exc:
            raise ApiError(
                str(exc), code="places_unavailable", status_code=503
            ) from exc
        return Response(payload)


class PlaceReverseView(APIView):
    serializer_class = ReverseQuerySerializer
    permission_classes = [IsAuthenticated]
    throttle_classes = [ScopedRateThrottle]
    throttle_scope = "quote"

    def get(self, request):
        serializer = ReverseQuerySerializer(data=request.query_params)
        serializer.is_valid(raise_exception=True)
        data = serializer.validated_data
        try:
            payload = PlacesService().reverse(lat=data["lat"], lng=data["lng"])
        except PlacesError as exc:
            raise ApiError(
                str(exc), code="places_unavailable", status_code=503
            ) from exc
        return Response(payload)
