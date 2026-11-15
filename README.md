# Zuum

*Old Bengaluru soul. New Bengaluru movement.*

Unified mobility & logistics ecosystem: passenger rides (bike/auto/cab) + goods
transport (2W/3W/Ace/Pickup/Van/Tempo), built as one platform.

| App | Purpose | Status |
|---|---|---|
| `apps/zuum_customer` | Customer booking app (Flutter mobile) | ✅ Phase 3 (mock) |
| `apps/zuum_partner` | Driver & fleet partner app (Flutter mobile) | ✅ Phase 4 (mock) |
| `apps/zuum_admin` | Ops & monitoring dashboard (Flutter Web) | ⬜ Phase 5 |
| `backend/` | Django + DRF + Channels + Celery | ✅ Phase 2 core (dev) |

## Docs

- [Architecture ADR-001](docs/01_architecture.md)
- [Data model](docs/02_data_model.md)
- [API contract](docs/03_api_contract.md)
- [Realtime protocol](docs/04_realtime_protocol.md)
- [Design tokens](docs/05_design_tokens.md)
- [Maps, routing & navigation ADR](docs/07_maps_routing.md)
- [Progress tracker](docs/PROGRESS.md)

## Quick start (customer app)

```bash
cd apps/zuum_customer
flutter pub get
flutter run --dart-define=ENV=mock
```

Maps use **MapLibre + OpenFreeMap (OSM)** and routing uses **Valhalla** through the
Django API (public demo server by default; `ROUTING_BASE_URL` in production).

`ENV=mock` runs the app against the **dev-only mock API adapter** (clearly labeled,
never used in production builds). `ENV=dev|prod` points at a real backend
(`API_BASE_URL`, `WS_BASE_URL`, `MAPBOX_ACCESS_TOKEN` via `--dart-define`).

## Quick start (partner app)

```bash
cd apps/zuum_partner
flutter pub get
flutter run --dart-define=ENV=mock
```

In mock builds the login screen has a **“Demo partner (dev)”** button that seeds
a fully-approved partner (documents + auto vehicle) in one tap. For kiosk demos
add `--dart-define=AUTO_DEMO=true` to sign in automatically on launch.

Demo builds: `builds/zuum-customer-mock.apk`, `builds/zuum-partner-mock.apk`.
Both ship branded launcher icons + native splash screens, shared page
transitions, skeleton loading, animated counters, vector maps with routed
geometry and (partner) turn-by-turn navigation.

## Live builds (Render API)

```bash
flutter build apk --release   --dart-define=ENV=prod   --dart-define=API_BASE_URL=https://zuum-api.onrender.com/api/v1   --dart-define=WS_BASE_URL=wss://zuum-api.onrender.com/ws
```

Offline/demo builds still use `--dart-define=ENV=mock` (no backend needed).
The free Render instance may sleep; clients retry once and show a
"server is waking up" message.

## Quick start (backend)

```bash
cd backend
python -m venv .venv && .venv\Scripts\activate   # (source .venv/bin/activate)
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_demo
python manage.py runserver
```

Demo logins (password `zuum1234`): `customer@zuum.in` · `partner@zuum.in` ·
`fleet@zuum.in`. API at `/api/v1/` · Swagger at `/api/v1/docs/` ·
WebSocket at `/ws/{topic}/{id}/?token=<access>`. See
[backend/README.md](backend/README.md).

## Partner docs

- [Partner API contract](docs/06_partner_api.md)

## Repo layout

```
apps/       Flutter applications
packages/   Shared Dart packages (core, design_system)
backend/    Django backend (Phase 2)
landing/    Customer + partner marketing site (static, Render)
infra/      Render blueprint, env templates
docs/       Architecture & contracts
```
