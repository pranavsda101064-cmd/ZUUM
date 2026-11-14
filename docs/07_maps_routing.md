# ADR-002: Maps, routing and navigation stack

Status: accepted (2026-11-14) · supersedes the Mapbox row in ADR-001.

## Decision

- **Rendering**: MapLibre GL (`maplibre_gl` on Flutter, maplibre-gl-js on the
  web admin) with **OpenFreeMap** vector styles (OSM data, no API key).
- **Map data**: OpenStreetMap contributors. Attribution is always visible:
  `© OpenStreetMap contributors · OpenFreeMap`.
- **Routing**: **Valhalla** through a Django `RoutingService`; public demo
  server (`https://valhalla1.openstreetmap.de`) for development, self-hosted
  container or a hosted provider in production via `ROUTING_BASE_URL`.
- **Geocoding**: OSM Photon (primary) → Nominatim (fallback), proxied and
  cached by Django (`/api/v1/places/*`); no provider keys on devices.
- **Location**: foreground-only GPS (`geolocator`) with a labelled demo
  fallback when permission is denied.
- **Navigation scope**: route preview, live ETA, next-turn banner, recentre
  and basic off-route reroute. No voice guidance; no background tracking.

## Why

| Option | Verdict |
|---|---|
| Mapbox | Great product, but token cost + lock-in for a city-first product. |
| flutter_map + raster CARTO | Fine for the prototype; no vector styles, tilt, or nav camera; CARTO tiles are not a production tile plan. |
| MapLibre + OpenFreeMap | Native vector rendering, 3D/tilt, runtime styling, keyless for the demo, self-hostable later. |
| OSRM | Faster/simpler, but no turn-by-turn narrative and weaker costing (auto-rickshaw/goods/truck). |
| Valhalla | Maneuver instructions, rich costing (auto/motorcycle/truck), matrix, isochrones; heavier to self-host but the API surface fits the product. |
| GraphHopper | Solid, but hosted pricing/commercial constraints and less control than Valhalla at this stage. |

## How it works

1. `POST /api/v1/pricing/quote` calls `RoutingService.route()` (rounded-coord
   cache, 5 min) and prices distance/duration from the **routed** trip.
2. The quote/booking stores geometry + maneuvers. `GET /bookings/{id}/route`
   returns the trip route (`leg=drop`) or the driver approach (`leg=pickup`).
3. Booking ETA projects the driver's last ping onto the stored geometry — no
   external call while polling. Partner navigation loads maneuvers once and
   advances locally; off-route (>120 m for >15 s) triggers a throttled reload.
4. Valhalla failures degrade to straight-line haversine geometry with
   `degraded: true`; the UI shows an honest “Approximate route” chip. A circuit
   breaker opens after 3 failures for 60 s.
5. Public demo server usage is polite: cache-first, 4.5 s timeout, no matrix
   calls on the dispatch hot path (`DISPATCH_USE_MATRIX=0` default).

## Attribution & licensing

- OSM data © OpenStreetMap contributors (ODbL). OpenFreeMap styles/tiles have
  their own terms; read them before commercial launch.
- Valhalla is BSD-3; public demo server has no SLA — production must use a
  hosted or self-hosted instance.
- Do not scrape Nominatim; the backend caches searches and sends a UA.

## Operations

- Dev without Docker: routing points at the public demo server.
- Self-host: `infra/docker-compose.valhalla.yml` (Karnataka extract) and set
  `ROUTING_BASE_URL=http://valhalla:8002`; all-India extract is documented in
  the compose comment.
- Prod: dedicated Valhalla container/VM with persistent tile volume, or a
  hosted Valhalla (e.g. Stadia Maps) via `ROUTING_BASE_URL` + `ROUTING_API_KEY`.
- Observability: structured logs `routing provider failed/using fallback`;
  inspect `GET /api/v1/routing/health` for provider reachability, latency,
  cache TTL and circuit state.

## Consequences

- Widget tests never touch a platform map: `ZMapView` falls back to a
  deterministic canvas renderer outside Android/iOS.
- `flutter_map` was removed; `maplibre_gl` pulls native SDKs (minSdk 21+).
- Live traffic is not included by default (free-flow ETA); time-dependent
  Valhalla costing is a future enhancement.
