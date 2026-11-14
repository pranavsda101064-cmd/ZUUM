"""Valhalla HTTP provider (public demo by default; env-swappable)."""
from __future__ import annotations

import time

import httpx
from django.conf import settings

from .polyline import decode_polyline
from .providers import (
    PROFILE_TO_COSTING,
    MatrixResult,
    RouteResult,
    RouteStep,
    RoutingError,
    bounding_box,
)

_MANEUVER_FALLBACKS = {
    0: "Continue",
    1: "Start",
    2: "Start on the right",
    3: "Start on the left",
    4: "Destination",
    5: "Destination on the right",
    6: "Destination on the left",
    7: "Becomes",
    8: "Continue",
    9: "Slight right",
    10: "Right",
    11: "Sharp right",
    12: "U-turn right",
    13: "U-turn left",
    14: "Sharp left",
    15: "Left",
    16: "Slight left",
    17: "Ramp straight",
    18: "Ramp right",
    19: "Ramp left",
    20: "Exit right",
    21: "Exit left",
    22: "Stay straight",
    23: "Stay right",
    24: "Stay left",
    25: "Merge",
    26: "Roundabout enter",
    27: "Roundabout exit",
    28: "Ferry enter",
    29: "Ferry exit",
    30: "Transit",
    31: "Transit transfer",
    32: "Transit remain on",
    33: "Transit connection start",
    34: "Transit connection transfer",
    35: "Transit connection destination",
    36: "Post-transit destination",
    37: "Merge right",
    38: "Merge left",
}


class ValhallaProvider:
    name = "valhalla"

    def __init__(
        self,
        *,
        base_url: str | None = None,
        api_key: str | None = None,
        timeout_ms: int | None = None,
        client: httpx.Client | None = None,
    ) -> None:
        self.base_url = (base_url or settings.ROUTING_BASE_URL).rstrip("/")
        self.api_key = api_key if api_key is not None else settings.ROUTING_API_KEY
        self.timeout = (timeout_ms or settings.ROUTING_TIMEOUT_MS) / 1000
        self._client = client or httpx.Client(
            base_url=self.base_url,
            timeout=self.timeout,
            headers={"User-Agent": settings.ROUTING_USER_AGENT},
            follow_redirects=True,
        )

    def _params(self) -> dict:
        return {"api_key": self.api_key} if self.api_key else {}

    def route(
        self,
        waypoints: list[dict[str, float]],
        *,
        profile: str = "auto",
        steps: bool = True,
    ) -> RouteResult:
        costing = PROFILE_TO_COSTING.get(profile, "auto")
        payload = {
            "locations": [
                {"lat": float(p["lat"]), "lon": float(p["lng"])} for p in waypoints
            ],
            "costing": costing,
            "directions_options": {"units": "kilometers", "language": "en-US"},
            "directions_type": "instructions" if steps else "none",
        }
        try:
            response = self._client.post("/route", json=payload, params=self._params())
        except httpx.HTTPError as exc:  # pragma: no cover - network path
            raise RoutingError(f"Valhalla unreachable: {exc}") from exc
        if response.status_code >= 400:
            raise RoutingError(
                f"Valhalla HTTP {response.status_code}: {response.text[:200]}"
            )
        try:
            data = response.json()
        except ValueError as exc:
            raise RoutingError("Valhalla returned non-JSON") from exc
        return parse_valhalla_route(data)

    def matrix(
        self,
        sources: list[dict[str, float]],
        targets: list[dict[str, float]],
        *,
        profile: str = "auto",
    ) -> MatrixResult:
        payload = {
            "sources": [
                {"lat": float(p["lat"]), "lon": float(p["lng"])} for p in sources
            ],
            "targets": [
                {"lat": float(p["lat"]), "lon": float(p["lng"])} for p in targets
            ],
            "costing": PROFILE_TO_COSTING.get(profile, "auto"),
        }
        try:
            response = self._client.post(
                "/matrix", json=payload, params=self._params()
            )
        except httpx.HTTPError as exc:  # pragma: no cover
            raise RoutingError(f"Valhalla matrix unreachable: {exc}") from exc
        if response.status_code >= 400:
            raise RoutingError(
                f"Valhalla matrix HTTP {response.status_code}: "
                f"{response.text[:200]}"
            )
        data = response.json()
        rows = data.get("sources_to_targets")
        if not isinstance(rows, list):
            raise RoutingError("Valhalla matrix response missing sources_to_targets")
        durations: list[list[int | None]] = []
        distances: list[list[int | None]] = []
        for row in rows:
            row_d: list[int | None] = []
            row_t: list[int | None] = []
            for cell in row:
                distance = cell.get("distance")
                duration = cell.get("time")
                row_d.append(
                    None if distance is None else int(round(distance * 1000))
                )
                row_t.append(None if duration is None else int(round(duration)))
            distances.append(row_d)
            durations.append(row_t)
        return MatrixResult(
            durations_s=durations,
            distances_m=distances,
            provider=self.name,
        )

    def health(self) -> tuple[bool, int]:
        started = time.perf_counter()
        try:
            response = self._client.get(
                "/status", timeout=min(2.0, self.timeout), params=self._params()
            )
            latency = int((time.perf_counter() - started) * 1000)
            return response.status_code < 400, latency
        except httpx.HTTPError:  # pragma: no cover - network path
            return False, int((time.perf_counter() - started) * 1000)


def parse_valhalla_route(data: dict) -> RouteResult:
    trip = data.get("trip")
    if not isinstance(trip, dict) or not trip.get("legs"):
        raise RoutingError("Valhalla response missing trip.legs")
    legs = trip["legs"]
    summary = trip.get("summary") or {}
    geometry: list[dict[str, float]] = []
    steps: list[RouteStep] = []
    has_toll = False

    for leg in legs:
        leg_points = decode_polyline(leg.get("shape") or "", precision=6)
        if not leg_points:
            continue
        if geometry and leg_points[0] == geometry[-1]:
            offset = len(geometry) - 1
            geometry.extend(leg_points[1:])
        else:
            offset = len(geometry)
            geometry.extend(leg_points)
        for maneuver in leg.get("maneuvers") or []:
            maneuver_type = int(maneuver.get("type") or 0)
            street_names = maneuver.get("street_names") or []
            instruction = maneuver.get("instruction") or _MANEUVER_FALLBACKS.get(
                maneuver_type, "Continue"
            )
            if street_names and not maneuver.get("instruction"):
                instruction = f"{instruction} on {street_names[0]}"
            steps.append(
                RouteStep(
                    type=maneuver_type,
                    instruction=str(instruction).strip(),
                    street=" / ".join(street_names[:2]),
                    distance_m=int(round(float(maneuver.get("length") or 0) * 1000)),
                    duration_s=int(round(float(maneuver.get("time") or 0))),
                    begin_shape_index=offset
                    + int(maneuver.get("begin_shape_index") or 0),
                    end_shape_index=offset
                    + int(maneuver.get("end_shape_index") or 0),
                )
            )
        leg_summary = leg.get("summary") or {}
        has_toll = has_toll or bool(leg_summary.get("has_toll"))

    if len(geometry) < 2:
        raise RoutingError("Valhalla route has insufficient geometry")

    distance_m = int(round(float(summary.get("length") or 0) * 1000))
    duration_s = int(round(float(summary.get("time") or 0)))
    if distance_m <= 0:
        from .providers import haversine_m

        distance_m = int(
            sum(
                haversine_m(a, b) for a, b in zip(geometry, geometry[1:])
            )
        )
    if duration_s <= 0:
        duration_s = max(120, int(distance_m / 1000 / 22 * 3600))

    return RouteResult(
        distance_m=distance_m,
        duration_s=duration_s,
        geometry=geometry,
        steps=steps,
        bbox=bounding_box(geometry),
        provider="valhalla",
        degraded=False,
        toll=has_toll,
    )
