"""Routing provider contracts + local haversine fallback."""
from __future__ import annotations

import math
from dataclasses import asdict, dataclass, field

from .polyline import encode_polyline

PROFILE_TO_COSTING = {
    "auto": "auto",
    "motorcycle": "motorcycle",
    "truck": "truck",
    "bicycle": "bicycle",
    "pedestrian": "pedestrian",
}

AVG_SPEED_KMH = 22.0


class RoutingError(Exception):
    """Provider failure (network, HTTP status, malformed payload)."""


@dataclass
class RouteStep:
    type: int = 0
    instruction: str = ""
    street: str = ""
    distance_m: int = 0
    duration_s: int = 0
    begin_shape_index: int = 0
    end_shape_index: int = 0


@dataclass
class RouteResult:
    distance_m: int
    duration_s: int
    geometry: list[dict[str, float]]
    steps: list[RouteStep] = field(default_factory=list)
    bbox: dict[str, float] = field(default_factory=dict)
    provider: str = "haversine"
    degraded: bool = False
    cached: bool = False
    toll: bool | None = None

    def as_dict(self) -> dict:
        return {
            "distance_m": self.distance_m,
            "duration_s": self.duration_s,
            "geometry": self.geometry,
            "encoded_polyline": encode_polyline(self.geometry),
            "steps": [asdict(step) for step in self.steps],
            "bbox": self.bbox,
            "provider": self.provider,
            "degraded": self.degraded,
            "cached": self.cached,
            "toll": self.toll,
        }

    def summary(self) -> dict:
        return {
            "distance_m": self.distance_m,
            "duration_s": self.duration_s,
            "provider": self.provider,
            "degraded": self.degraded,
            "toll": self.toll,
        }


def haversine_m(a: dict[str, float], b: dict[str, float]) -> float:
    r = 6371000.0
    lat1, lng1 = math.radians(a["lat"]), math.radians(a["lng"])
    lat2, lng2 = math.radians(b["lat"]), math.radians(b["lng"])
    dlat, dlng = lat2 - lat1, lng2 - lng1
    h = math.sin(dlat / 2) ** 2 + math.cos(lat1) * math.cos(lat2) * math.sin(dlng / 2) ** 2
    return 2 * r * math.asin(math.sqrt(h))


@dataclass
class MatrixResult:
    durations_s: list[list[int | None]]
    distances_m: list[list[int | None]]
    provider: str
    degraded: bool = False


class HaversineProvider:
    """Deterministic fallback so quotes and navigation never hard-fail."""

    name = "haversine"

    def route(
        self,
        waypoints: list[dict[str, float]],
        *,
        profile: str = "auto",
        steps: bool = True,
    ) -> RouteResult:
        distance = 0.0
        for a, b in zip(waypoints, waypoints[1:]):
            distance += haversine_m(a, b)
        distance_m = max(500, int(distance))
        duration_s = max(120, int(distance_m / 1000 / AVG_SPEED_KMH * 3600))
        geometry = [
            {"lat": float(p["lat"]), "lng": float(p["lng"])} for p in waypoints
        ]
        lats = [p["lat"] for p in geometry]
        lngs = [p["lng"] for p in geometry]
        return RouteResult(
            distance_m=distance_m,
            duration_s=duration_s,
            geometry=geometry,
            steps=[],
            bbox={
                "min_lat": min(lats),
                "min_lng": min(lngs),
                "max_lat": max(lats),
                "max_lng": max(lngs),
            },
            provider=self.name,
            degraded=True,
            toll=None,
        )

    def matrix(
        self,
        sources: list[dict[str, float]],
        targets: list[dict[str, float]],
        *,
        profile: str = "auto",
    ) -> MatrixResult:
        durations: list[list[int | None]] = []
        distances: list[list[int | None]] = []
        for source in sources:
            row_d: list[int | None] = []
            row_t: list[int | None] = []
            for target in targets:
                meters = max(1, int(haversine_m(source, target)))
                row_d.append(meters)
                row_t.append(max(60, int(meters / 1000 / AVG_SPEED_KMH * 3600)))
            durations.append(row_t)
            distances.append(row_d)
        return MatrixResult(
            durations_s=durations,
            distances_m=distances,
            provider=self.name,
            degraded=True,
        )

    def health(self) -> tuple[bool, int]:
        return True, 0


def bounding_box(points: list[dict[str, float]]) -> dict[str, float]:
    lats = [p["lat"] for p in points]
    lngs = [p["lng"] for p in points]
    return {
        "min_lat": min(lats),
        "min_lng": min(lngs),
        "max_lat": max(lats),
        "max_lng": max(lngs),
    }
