"""OSM place search proxy (Photon primary, Nominatim fallback) with caching."""
from __future__ import annotations

import hashlib
import json
import logging

import httpx
from django.conf import settings
from django.core.cache import cache

logger = logging.getLogger(__name__)


class PlacesError(Exception):
    pass


def _address_from_photon(properties: dict) -> str:
    parts = [
        properties.get("name"),
        properties.get("street"),
        properties.get("housenumber"),
        properties.get("district"),
        properties.get("city"),
        properties.get("state"),
    ]
    seen: list[str] = []
    for part in parts:
        if part and part not in seen:
            seen.append(str(part))
    return ", ".join(seen)


def _cache_key(kind: str, payload: dict) -> str:
    raw = json.dumps(payload, sort_keys=True)
    return f"zuum:places:{kind}:" + hashlib.sha1(raw.encode()).hexdigest()


def _client(url: str) -> httpx.Client:
    provider_name = "photon" if "photon" in url else "nominatim"
    return httpx.Client(
        base_url=url,
        timeout=settings.PLACES_TIMEOUT_MS / 1000,
        headers={
            "User-Agent": settings.PLACES_USER_AGENT,
            "Accept": "application/json",
            "Accept-Language": "en",
            "X-Zuum-Provider": provider_name,
        },
        follow_redirects=True,
    )


class PlacesService:
    def __init__(self, client: httpx.Client | None = None) -> None:
        self._client = client or _client(settings.PHOTON_URL)

    # -- search ---------------------------------------------------------------
    def search(
        self,
        query: str,
        *,
        lat: float | None = None,
        lng: float | None = None,
        limit: int = 8,
    ) -> dict:
        query = (query or "").strip()
        if not query:
            return {"results": [], "provider": "none"}
        limit = max(1, min(limit, 20))
        payload = {"q": query.lower(), "lat": lat, "lng": lng, "limit": limit}
        key = _cache_key("search", payload)
        cached = cache.get(key)
        if cached is not None:
            return {**cached, "cached": True}

        try:
            results = self._photon_search(query, lat, lng, limit)
            provider = "photon"
        except (httpx.HTTPError, PlacesError, ValueError) as exc:
            logger.warning("photon search failed (%s); trying nominatim", exc)
            try:
                results = self._nominatim_search(query, lat, lng, limit)
                provider = "nominatim"
            except (httpx.HTTPError, PlacesError, ValueError) as exc2:
                logger.warning("nominatim search failed (%s)", exc2)
                raise PlacesError("Place search is unavailable right now") from exc2

        payload_out = {"results": results, "provider": provider, "cached": False}
        cache.set(key, payload_out, settings.PLACES_CACHE_TTL)
        return payload_out

    def _photon_search(
        self, query: str, lat, lng, limit: int
    ) -> list[dict]:
        params: dict = {"q": query, "limit": limit, "lang": "en"}
        if lat is not None and lng is not None:
            params["lat"] = lat
            params["lon"] = lng
        bbox = getattr(settings, "PLACES_BBOX", "")
        if bbox:
            params["bbox"] = bbox
        response = self._client.get("/api/", params=params)
        if response.status_code >= 400:
            raise PlacesError(f"photon HTTP {response.status_code}")
        data = response.json()
        features = data.get("features") or []
        results = []
        for feature in features:
            geometry = feature.get("geometry") or {}
            coordinates = geometry.get("coordinates") or []
            if len(coordinates) < 2:
                continue
            properties = feature.get("properties") or {}
            name = (
                properties.get("name")
                or properties.get("street")
                or properties.get("city")
                or "Unnamed place"
            )
            results.append(
                {
                    "name": str(name),
                    "address": _address_from_photon(properties) or str(name),
                    "lat": float(coordinates[1]),
                    "lng": float(coordinates[0]),
                    "osm_id": properties.get("osm_id"),
                    "osm_type": properties.get("osm_type"),
                }
            )
        return results

    def _nominatim_search(
        self, query: str, lat, lng, limit: int
    ) -> list[dict]:
        client = _client(settings.NOMINATIM_URL)
        params: dict = {
            "q": query,
            "format": "jsonv2",
            "limit": limit,
            "addressdetails": 1,
        }
        if lat is not None and lng is not None:
            params["viewbox"] = (
                f"{lng - 0.25},{lat + 0.18},{lng + 0.25},{lat - 0.18}"
            )
            params["bounded"] = 0
        response = client.get("/search", params=params)
        if response.status_code >= 400:
            raise PlacesError(f"nominatim HTTP {response.status_code}")
        rows = response.json()
        results = []
        for row in rows or []:
            display = row.get("display_name") or ""
            parts = [p.strip() for p in display.split(",") if p.strip()]
            results.append(
                {
                    "name": parts[0] if parts else display,
                    "address": display,
                    "lat": float(row["lat"]),
                    "lng": float(row["lon"]),
                    "osm_id": row.get("osm_id"),
                    "osm_type": row.get("osm_type"),
                }
            )
        return results

    # -- reverse --------------------------------------------------------------
    def reverse(self, *, lat: float, lng: float) -> dict:
        key = _cache_key("reverse", {"lat": round(lat, 5), "lng": round(lng, 5)})
        cached = cache.get(key)
        if cached is not None:
            return {**cached, "cached": True}
        try:
            response = self._client.get(
                "/reverse", params={"lat": lat, "lon": lng, "lang": "en"}
            )
            if response.status_code >= 400:
                raise PlacesError(f"photon HTTP {response.status_code}")
            data = response.json()
            features = data.get("features") or []
            if not features:
                raise PlacesError("no reverse result")
            properties = features[0].get("properties") or {}
            result = {
                "name": properties.get("name") or "Dropped pin",
                "address": _address_from_photon(properties)
                or properties.get("name")
                or "",
                "lat": lat,
                "lng": lng,
                "cached": False,
            }
        except (httpx.HTTPError, PlacesError, ValueError) as exc:
            logger.warning("photon reverse failed (%s); trying nominatim", exc)
            client = _client(settings.NOMINATIM_URL)
            response = client.get(
                "/reverse",
                params={"lat": lat, "lon": lng, "format": "jsonv2"},
            )
            if response.status_code >= 400:
                raise PlacesError("Reverse geocoding is unavailable")
            row = response.json() or {}
            result = {
                "name": (row.get("display_name") or "Dropped pin").split(",")[0],
                "address": row.get("display_name") or "",
                "lat": lat,
                "lng": lng,
                "cached": False,
            }
        cache.set(key, result, settings.PLACES_REVERSE_CACHE_TTL)
        return result
