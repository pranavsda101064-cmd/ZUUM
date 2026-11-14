"""Polyline (Google encoding) helpers used by Valhalla shapes (precision 6)."""
from __future__ import annotations


def decode_polyline(encoded: str, precision: int = 6) -> list[dict[str, float]]:
    if not encoded:
        return []
    factor = float(10**precision)
    index = lat = lng = 0
    points: list[dict[str, float]] = []
    length = len(encoded)

    def _next_value() -> int:
        nonlocal index
        result = shift = 0
        while True:
            if index >= length:
                raise ValueError("Malformed polyline")
            byte = ord(encoded[index]) - 63
            index += 1
            result |= (byte & 0x1F) << shift
            shift += 5
            if byte < 0x20:
                break
        return ~(result >> 1) if result & 1 else result >> 1

    while index < length:
        lat += _next_value()
        lng += _next_value()
        points.append({"lat": lat / factor, "lng": lng / factor})
    return points


def encode_polyline(points: list[dict[str, float]], precision: int = 6) -> str:
    factor = 10**precision
    last_lat = last_lng = 0
    out: list[str] = []

    def _encode(value: int) -> None:
        value = ~(value << 1) if value < 0 else value << 1
        while value >= 0x20:
            out.append(chr((0x20 | (value & 0x1F)) + 63))
            value >>= 5
        out.append(chr(value + 63))

    for point in points:
        lat = int(round(point["lat"] * factor))
        lng = int(round(point["lng"] * factor))
        _encode(lat - last_lat)
        _encode(lng - last_lng)
        last_lat, last_lng = lat, lng
    return "".join(out)
