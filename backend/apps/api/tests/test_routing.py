"""Routing: polyline, Valhalla parsing, cache/circuit, API + quote integration."""
from __future__ import annotations

from datetime import timedelta

import httpx
from django.core.cache import cache
from django.test import override_settings
from django.utils import timezone
from rest_framework.test import APITestCase

from apps.api.tests.base import ZuumTestCase, make_user
from apps.bookings.models import FareQuote
from apps.bookings.services import project_onto_route
from apps.routing.polyline import decode_polyline, encode_polyline
from apps.routing.providers import (
    HaversineProvider,
    RouteResult,
    RouteStep,
    RoutingError,
)
from apps.routing.service import RoutingService
from apps.routing.valhalla import ValhallaProvider, parse_valhalla_route

POINTS = [
    {"lat": 12.9352, "lng": 77.6245},
    {"lat": 12.9410, "lng": 77.6300},
    {"lat": 12.9500, "lng": 77.6350},
    {"lat": 12.9716, "lng": 77.5946},
]


def valhalla_payload():
    shape = encode_polyline(POINTS)
    return {
        "trip": {
            "summary": {"length": 5.184, "time": 848.0},
            "legs": [
                {
                    "shape": shape,
                    "summary": {"has_toll": False},
                    "maneuvers": [
                        {
                            "type": 1,
                            "instruction": "Start on 5th Block Road.",
                            "street_names": ["5th Block Road"],
                            "length": 1.2,
                            "time": 180.0,
                            "begin_shape_index": 0,
                            "end_shape_index": 1,
                        },
                        {
                            "type": 15,
                            "instruction": "Turn left onto MG Road.",
                            "street_names": ["MG Road"],
                            "length": 3.984,
                            "time": 668.0,
                            "begin_shape_index": 1,
                            "end_shape_index": 3,
                        },
                    ],
                }
            ],
        }
    }


class PolylineTests(APITestCase):
    def test_round_trip_precision_six(self):
        encoded = encode_polyline(POINTS)
        decoded = decode_polyline(encoded)
        self.assertEqual(len(decoded), len(POINTS))
        for expected, actual in zip(POINTS, decoded):
            self.assertAlmostEqual(expected["lat"], actual["lat"], places=5)
            self.assertAlmostEqual(expected["lng"], actual["lng"], places=5)


class ValhallaParsingTests(APITestCase):
    def test_parse_trip(self):
        result = parse_valhalla_route(valhalla_payload())
        self.assertEqual(result.provider, "valhalla")
        self.assertFalse(result.degraded)
        self.assertEqual(result.distance_m, 5184)
        self.assertEqual(result.duration_s, 848)
        self.assertEqual(len(result.geometry), 4)
        self.assertEqual(len(result.steps), 2)
        self.assertEqual(result.steps[1].instruction, "Turn left onto MG Road.")
        self.assertEqual(result.steps[1].begin_shape_index, 1)
        self.assertEqual(result.steps[1].end_shape_index, 3)
        self.assertFalse(result.toll)
        self.assertEqual(result.bbox["min_lat"], 12.9352)

    def test_provider_http_roundtrip(self):
        seen = {}

        def handler(request: httpx.Request) -> httpx.Response:
            import json

            seen["path"] = request.url.path
            seen["body"] = json.loads(request.content)
            return httpx.Response(200, json=valhalla_payload())

        client = httpx.Client(
            base_url="https://valhalla.test",
            transport=httpx.MockTransport(handler),
        )
        provider = ValhallaProvider(
            base_url="https://valhalla.test", client=client, timeout_ms=1000
        )
        result = provider.route(POINTS[:2], profile="motorcycle")
        self.assertEqual(result.provider, "valhalla")
        self.assertEqual(seen["path"], "/route")
        self.assertEqual(seen["body"]["costing"], "motorcycle")
        self.assertEqual(seen["body"]["locations"][0], {"lat": 12.9352, "lon": 77.6245})

    def test_provider_http_error_raises(self):
        client = httpx.Client(
            base_url="https://valhalla.test",
            transport=httpx.MockTransport(
                lambda request: httpx.Response(503, text="busy")
            ),
        )
        provider = ValhallaProvider(base_url="https://valhalla.test", client=client)
        with self.assertRaises(RoutingError):
            provider.route(POINTS[:2])


class _CountingProvider:
    name = "valhalla"

    def __init__(self):
        self.calls = 0

    def route(self, waypoints, *, profile="auto", steps=True):
        self.calls += 1
        return RouteResult(
            distance_m=5000,
            duration_s=900,
            geometry=waypoints,
            steps=[RouteStep(instruction="Go")],
            provider="valhalla",
        )

    def matrix(self, sources, targets, *, profile="auto"):
        from apps.routing.providers import MatrixResult

        return MatrixResult(
            durations_s=[[300]], distances_m=[[1000]], provider="valhalla"
        )

    def health(self):
        return True, 12


class _FailingProvider:
    name = "valhalla"

    def __init__(self):
        self.calls = 0

    def route(self, waypoints, *, profile="auto", steps=True):
        self.calls += 1
        raise RoutingError("down")

    def matrix(self, sources, targets, *, profile="auto"):
        self.calls += 1
        raise RoutingError("down")

    def health(self):
        return False, None


class RoutingServiceTests(APITestCase):
    def setUp(self):
        cache.clear()

    def test_route_is_cached(self):
        provider = _CountingProvider()
        service = RoutingService(provider=provider)
        first = service.route(POINTS[:2])
        second = service.route(POINTS[:2])
        self.assertEqual(provider.calls, 1)
        self.assertFalse(first.cached)
        self.assertTrue(second.cached)
        self.assertEqual(first.distance_m, second.distance_m)

    def test_cache_key_rounds_coordinates(self):
        provider = _CountingProvider()
        service = RoutingService(provider=provider)
        service.route(POINTS[:2])
        service.route(
            [
                {"lat": POINTS[0]["lat"] + 0.0000001, "lng": POINTS[0]["lng"]},
                POINTS[1],
            ]
        )
        self.assertEqual(provider.calls, 1)

    def test_fallback_and_circuit_breaker(self):
        provider = _FailingProvider()
        service = RoutingService(provider=provider)
        for i in range(3):
            result = service.route(
                [
                    {"lat": 12.90 + i * 0.01, "lng": 77.60},
                    {"lat": 12.95 + i * 0.01, "lng": 77.62},
                ]
            )
            self.assertTrue(result.degraded)
            self.assertEqual(result.provider, "haversine")
        self.assertEqual(provider.calls, 3)
        self.assertTrue(cache.get("zuum:routing:circuit"))

        calls_before = provider.calls
        fresh = service.route(
            [
                {"lat": 13.10, "lng": 77.70},
                {"lat": 13.20, "lng": 77.80},
            ]
        )
        self.assertTrue(fresh.degraded)
        self.assertEqual(
            provider.calls, calls_before, "circuit open must skip the provider"
        )

    def test_service_health(self):
        service = RoutingService(provider=_CountingProvider())
        health = service.health()
        self.assertTrue(health["reachable"])
        self.assertEqual(health["provider"], "valhalla")


class _BaseApi(APITestCase):
    @override_settings(ROUTING_PROVIDER="haversine")
    def test_route_endpoint(self):
        make_user("router@zuum.in")
        client = self.client_class()
        login = client.post(
            "/api/v1/auth/login",
            {"email": "router@zuum.in", "password": "zuum1234"},
            format="json",
        )
        client.credentials(HTTP_AUTHORIZATION=f"Bearer {login.data['access']}")
        response = client.post(
            "/api/v1/routing/route",
            {
                "profile": "auto",
                "waypoints": [
                    {"lat": 12.9352, "lng": 77.6245},
                    {"lat": 12.9716, "lng": 77.5946},
                ],
            },
            format="json",
        )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.data["provider"], "haversine")
        self.assertTrue(response.data["degraded"])
        self.assertGreaterEqual(len(response.data["geometry"]), 2)
        self.assertIn("encoded_polyline", response.data)

        matrix = client.post(
            "/api/v1/routing/matrix",
            {
                "sources": [{"lat": 12.93, "lng": 77.62}],
                "targets": [{"lat": 12.97, "lng": 77.59}],
            },
            format="json",
        )
        self.assertEqual(matrix.status_code, 200)
        self.assertEqual(len(matrix.data["durations_s"]), 1)

    def test_route_requires_auth(self):
        response = self.client.post(
            "/api/v1/routing/route",
            {"waypoints": [{"lat": 1, "lng": 1}, {"lat": 2, "lng": 2}]},
            format="json",
        )
        self.assertEqual(response.status_code, 401)

    @override_settings(ROUTING_PROVIDER="haversine")
    def test_health_is_public(self):
        response = self.client.get("/api/v1/routing/health")
        self.assertEqual(response.status_code, 200)
        self.assertEqual(response.data["provider"], "haversine")


class RoutedBookingTests(ZuumTestCase):
    def setUp(self):
        super().setUp()
        make_user("routed-customer@zuum.in")
        self.customer = self.client_for("routed-customer@zuum.in")

    @override_settings(ROUTING_PROVIDER="haversine")
    def test_quote_and_booking_store_route(self):
        quote = self.quote(self.customer)
        self.assertIn("route", quote)
        self.assertGreaterEqual(len(quote["route"]["geometry"]), 2)
        self.assertEqual(quote["route"]["provider"], "haversine")

        stored = FareQuote.objects.get(pk=quote["id"])
        self.assertEqual(len(stored.route_geometry), 2)
        self.assertTrue(stored.route_degraded)

        booking = self.create_ride(self.customer)
        detail = self.customer.get(f"/api/v1/bookings/{booking['id']}")
        self.assertIsNotNone(detail.data["route"])
        self.assertEqual(
            len(detail.data["route"]["geometry"]), len(stored.route_geometry)
        )

        route = self.customer.get(
            f"/api/v1/bookings/{booking['id']}/route?leg=drop"
        )
        self.assertEqual(route.status_code, 200, route.content)
        self.assertEqual(route.data["leg"], "drop")
        self.assertIn("steps", route.data)

    @override_settings(ROUTING_PROVIDER="haversine")
    def test_route_endpoint_blocks_other_customers(self):
        booking = self.create_ride(self.customer)
        make_user("stranger@zuum.in")
        stranger = self.client_for("stranger@zuum.in")
        response = stranger.get(f"/api/v1/bookings/{booking['id']}/route")
        self.assertEqual(response.status_code, 404)


class ProjectionTests(APITestCase):
    def test_remaining_distance_along_line(self):
        geometry = [
            {"lat": 12.9300, "lng": 77.6200},
            {"lat": 12.9400, "lng": 77.6200},
            {"lat": 12.9500, "lng": 77.6200},
        ]
        remaining, total = project_onto_route(geometry, {"lat": 12.9400, "lng": 77.6200})
        self.assertGreater(total, 2000)
        self.assertAlmostEqual(remaining, total / 2, delta=max(30, total * 0.05))

        at_end, _ = project_onto_route(geometry, {"lat": 12.9500, "lng": 77.6200})
        self.assertLess(at_end, 5)
