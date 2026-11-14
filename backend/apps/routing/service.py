"""Routing service: provider selection, caching, circuit breaker, fallback."""
from __future__ import annotations

import hashlib
import json
import logging
from dataclasses import replace

from django.conf import settings
from django.core.cache import cache

from .providers import HaversineProvider, MatrixResult, RouteResult, RoutingError
from .valhalla import ValhallaProvider

logger = logging.getLogger(__name__)

_CIRCUIT_KEY = "zuum:routing:circuit"
_FAILURES_KEY = "zuum:routing:failures"


def build_provider():
    if settings.ROUTING_PROVIDER == "valhalla":
        return ValhallaProvider()
    return HaversineProvider()


def profile_for_category(code: str) -> str:
    if code == "bike":
        return "motorcycle"
    return "auto"


def route_payload(result: RouteResult) -> dict:
    return result.as_dict()


class RoutingService:
    """One entry point for every route/matrix request.

    - caches successful routes for `ROUTING_CACHE_TTL`
    - degrades to straight-line geometry when the engine is down
    - opens a circuit after repeated failures so callers fail fast
    """

    def __init__(self, provider=None) -> None:
        self.provider = provider or build_provider()
        self.fallback = HaversineProvider()

    def _cache_key(self, kind: str, waypoints: list[dict], profile: str) -> str:
        raw = json.dumps(
            {
                "kind": kind,
                "provider": getattr(self.provider, "name", "haversine"),
                "profile": profile,
                "waypoints": [
                    [round(float(p["lat"]), 5), round(float(p["lng"]), 5)]
                    for p in waypoints
                ],
            },
            sort_keys=True,
        )
        return "zuum:routing:route:" + hashlib.sha1(raw.encode()).hexdigest()

    def _record_failure(self) -> None:
        failures = cache.get(_FAILURES_KEY, 0) + 1
        cache.set(_FAILURES_KEY, failures, 600)
        if failures >= 3:
            cache.set(_CIRCUIT_KEY, True, settings.ROUTING_CIRCUIT_SECONDS)
            logger.warning("routing circuit opened after %s failures", failures)

    def _record_success(self) -> None:
        cache.delete(_FAILURES_KEY)
        cache.delete(_CIRCUIT_KEY)

    def route(
        self,
        waypoints: list[dict[str, float]],
        *,
        profile: str = "auto",
        steps: bool = True,
        use_cache: bool = True,
    ) -> RouteResult:
        points = [
            {"lat": float(p["lat"]), "lng": float(p["lng"])} for p in waypoints
        ]
        key = self._cache_key("route", points, profile)
        if use_cache:
            cached = cache.get(key)
            if cached is not None:
                return replace(cached, cached=True)

        if cache.get(_CIRCUIT_KEY):
            return self.fallback.route(points, profile=profile, steps=steps)

        try:
            result = self.provider.route(points, profile=profile, steps=steps)
            self._record_success()
            if use_cache:
                cache.set(key, result, settings.ROUTING_CACHE_TTL)
            return result
        except (RoutingError, Exception) as exc:  # noqa: BLE001 - provider boundary
            logger.warning("routing provider failed (%s); using fallback", exc)
            self._record_failure()
            degraded = self.fallback.route(points, profile=profile, steps=steps)
            if use_cache:
                cache.set(
                    key, degraded, getattr(settings, "ROUTING_DEGRADED_TTL", 30)
                )
            return degraded

    def matrix(
        self,
        sources: list[dict[str, float]],
        targets: list[dict[str, float]],
        *,
        profile: str = "auto",
    ) -> MatrixResult:
        source_points = [{"lat": float(p["lat"]), "lng": float(p["lng"])} for p in sources]
        target_points = [{"lat": float(p["lat"]), "lng": float(p["lng"])} for p in targets]
        if cache.get(_CIRCUIT_KEY):
            return self.fallback.matrix(source_points, target_points, profile=profile)
        try:
            result = self.provider.matrix(
                source_points, target_points, profile=profile
            )
            self._record_success()
            return result
        except (RoutingError, Exception) as exc:  # noqa: BLE001
            logger.warning("routing matrix failed (%s); using fallback", exc)
            self._record_failure()
            return self.fallback.matrix(
                source_points, target_points, profile=profile
            )

    def health(self) -> dict:
        try:
            reachable, latency_ms = self.provider.health()
        except Exception:  # noqa: BLE001
            reachable, latency_ms = False, None
        return {
            "configured_provider": settings.ROUTING_PROVIDER,
            "provider": getattr(self.provider, "name", "unknown"),
            "reachable": reachable,
            "latency_ms": latency_ms,
            "cache_ttl_s": settings.ROUTING_CACHE_TTL,
            "circuit_open": bool(cache.get(_CIRCUIT_KEY)),
        }
