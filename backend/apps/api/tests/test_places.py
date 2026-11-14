"""Places proxy: Photon parsing, fallback, cache and API contract."""
from __future__ import annotations

from unittest.mock import patch

import httpx
from django.core.cache import cache
from rest_framework.test import APITestCase

from apps.api.tests.base import make_user, seed_catalog
from apps.places.service import PlacesError, PlacesService


def photon_payload():
    return {
        "features": [
            {
                "geometry": {"coordinates": [77.6245, 12.9352]},
                "properties": {
                    "name": "Koramangala",
                    "street": "80 Feet Road",
                    "district": "Koramangala",
                    "city": "Bengaluru",
                    "state": "Karnataka",
                    "osm_id": 123,
                    "osm_type": "N",
                },
            },
            {
                "geometry": {"coordinates": [77.5946, 12.9716]},
                "properties": {
                    "name": "MG Road",
                    "city": "Bengaluru",
                    "state": "Karnataka",
                },
            },
        ]
    }


class PlacesServiceTests(APITestCase):
    def setUp(self):
        cache.clear()

    def test_photon_search_parses_features(self):
        def handler(request: httpx.Request) -> httpx.Response:
            assert request.url.path == "/api/"
            return httpx.Response(200, json=photon_payload())

        client = httpx.Client(
            base_url="https://photon.test",
            transport=httpx.MockTransport(handler),
        )
        service = PlacesService(client=client)
        payload = service.search("koramangala", lat=12.93, lng=77.62)
        self.assertEqual(payload["provider"], "photon")
        self.assertEqual(len(payload["results"]), 2)
        first = payload["results"][0]
        self.assertEqual(first["name"], "Koramangala")
        self.assertIn("Bengaluru", first["address"])
        self.assertAlmostEqual(first["lat"], 12.9352)

    def test_search_is_cached(self):
        calls = {"count": 0}

        def handler(request: httpx.Request) -> httpx.Response:
            calls["count"] += 1
            return httpx.Response(200, json=photon_payload())

        client = httpx.Client(
            base_url="https://photon.test",
            transport=httpx.MockTransport(handler),
        )
        service = PlacesService(client=client)
        service.search("koramangala", lat=12.93, lng=77.62)
        again = service.search("koramangala", lat=12.93, lng=77.62)
        self.assertEqual(calls["count"], 1)
        self.assertTrue(again["cached"])

    def test_nominatim_fallback(self):
        service = PlacesService(client=None)
        with patch.object(
            PlacesService, "_photon_search", side_effect=PlacesError("down")
        ), patch.object(
            PlacesService,
            "_nominatim_search",
            return_value=[
                {
                    "name": "Koramangala",
                    "address": "Koramangala, Bengaluru, Karnataka, India",
                    "lat": 12.9352,
                    "lng": 77.6245,
                }
            ],
        ):
            payload = service.search("koramangala")
        self.assertEqual(payload["provider"], "nominatim")
        self.assertEqual(payload["results"][0]["name"], "Koramangala")

    def test_search_reports_unavailable_when_all_providers_fail(self):
        service = PlacesService(client=None)
        with patch.object(
            PlacesService, "_photon_search", side_effect=PlacesError("down")
        ), patch.object(
            PlacesService, "_nominatim_search", side_effect=PlacesError("down")
        ):
            with self.assertRaises(PlacesError):
                service.search("nowhere")

    def test_reverse(self):
        def handler(request: httpx.Request) -> httpx.Response:
            assert request.url.path == "/reverse"
            return httpx.Response(
                200,
                json={
                    "features": [
                        {
                            "properties": {
                                "name": "Koramangala",
                                "city": "Bengaluru",
                            }
                        }
                    ]
                },
            )

        client = httpx.Client(
            base_url="https://photon.test",
            transport=httpx.MockTransport(handler),
        )
        payload = PlacesService(client=client).reverse(lat=12.9352, lng=77.6245)
        self.assertEqual(payload["name"], "Koramangala")
        self.assertIn("Bengaluru", payload["address"])


class PlacesApiTests(APITestCase):
    def setUp(self):
        cache.clear()
        seed_catalog()
        make_user("places@zuum.in")
        login = self.client.post(
            "/api/v1/auth/login",
            {"email": "places@zuum.in", "password": "zuum1234"},
            format="json",
        )
        self.client.credentials(
            HTTP_AUTHORIZATION=f"Bearer {login.data['access']}"
        )

    def test_search_endpoint(self):
        fake = type(
            "FakePlaces",
            (),
            {
                "search": lambda self, *a, **k: {
                    "results": [
                        {
                            "name": "Koramangala",
                            "address": "Koramangala, Bengaluru",
                            "lat": 12.9352,
                            "lng": 77.6245,
                        }
                    ],
                    "provider": "photon",
                    "cached": False,
                }
            },
        )
        with patch("apps.api.views.places.PlacesService", fake):
            response = self.client.get(
                "/api/v1/places/search?q=koramangala&lat=12.93&lng=77.62"
            )
        self.assertEqual(response.status_code, 200, response.content)
        self.assertEqual(response.data["provider"], "photon")
        self.assertEqual(response.data["results"][0]["name"], "Koramangala")

    def test_search_validation(self):
        response = self.client.get("/api/v1/places/search?q=")
        self.assertEqual(response.status_code, 400)

    def test_search_requires_auth(self):
        from rest_framework.test import APIClient

        response = APIClient().get("/api/v1/places/search?q=x")
        self.assertEqual(response.status_code, 401)

    def test_unavailable_maps_to_503(self):
        fake = type(
            "FakePlaces",
            (),
            {"search": lambda self, *a, **k: (_ for _ in ()).throw(PlacesError("down"))},
        )
        with patch("apps.api.views.places.PlacesService", fake):
            response = self.client.get("/api/v1/places/search?q=x")
        self.assertEqual(response.status_code, 503)
        self.assertEqual(response.data["code"], "places_unavailable")
