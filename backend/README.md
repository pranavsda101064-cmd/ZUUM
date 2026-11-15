# Zuum backend (Django 5 + DRF + Channels)

Phase 2 core: contracts in `docs/03_api_contract.md` (consumer) and
`docs/06_partner_api.md` (driver/fleet) implemented against SQLite + in-memory
Channels for local dev; Postgres/Redis/PostGIS are the production swap-ins
(`infra/render.yaml`).

## Quick start

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate          # Windows  (source .venv/bin/activate on unix)
pip install -r requirements.txt
python manage.py migrate
python manage.py seed_demo      # catalog + pricing + 3 personas
python manage.py runserver
```

| Persona | Login | Password |
|---|---|---|
| Customer | `customer@zuum.in` | `zuum1234` |
| Partner (approved, auto) | `partner@zuum.in` | `zuum1234` |
| Fleet owner ("Namma Fleet") | `fleet@zuum.in` | `zuum1234` |
| Ops desk (staff, admin API) | `ops@zuum.in` | `zuum1234` |

Maps/routing env: `ROUTING_PROVIDER=valhalla`, `ROUTING_BASE_URL`
(public demo by default), `ROUTING_API_KEY`, `ROUTING_TIMEOUT_MS`,
`ROUTING_CACHE_TTL`, `PHOTON_URL`, `NOMINATIM_URL`. Self-hosting Valhalla:
`infra/docker-compose.valhalla.yml` (Karnataka extract).

- REST: `http://127.0.0.1:8000/api/v1/`
- OpenAPI: `/api/v1/schema/` · Swagger UI: `/api/v1/docs/`
- Realtime: `ws://127.0.0.1:8000/ws/{topic}/{id}/?token=<access>`
- Health: `/api/v1/health`

## What is implemented

- **Auth** — email+password, JWT access (15 min) / rotating refresh (7 d,
  blacklist), logout revocation, password reset via signed token (console mail
  in dev). Error envelope `{code, message, details?}` everywhere.
- **Customer** — profile, saved addresses, service catalog, fare quotes
  (base/distance/time/surge/night/loading breakdown), bookings, cancel, rate,
  receipt, driver location + ETA, goods OTP confirm.
- **Dispatch** — offers fan out to the nearest approved+online drivers with a
  matching active vehicle; 15 s expiry; accept is server-authoritative and
  revokes the other offers.
- **Trip state machine** — `CREATED → PRICED → SEARCHING → ASSIGNED →
  (DRIVER_ARRIVING) → ARRIVED → IN_PROGRESS → COMPLETED`, plus
  `CANCELLED/FAILED`. Illegal transitions return `409 illegal_transition`.
  Goods requires delivery-OTP before completion (`409 pod_missing`).
- **Money** — 20 % commission rule (configurable), commission entries, wallet
  with ledger + mock top-up, mock Razorpay order/verify flow, promos
  (percent/flat, limits), payouts, referrals.
- **Partner** — profile promotion on first access, KYC document upload +
  submit gate, vehicles + availability, online/offline rules, offers
  accept/decline, trip actions (arrive, OTP start, delivery OTP, complete,
  cancel), POD uploads, earnings/payouts/stats.
- **Fleet** — overview, roster, invite, detach, fleet vehicles, assign,
  aggregate earnings.
- **Platform** — support topics/tickets, SOS alerts, lifecycle notifications
  (booking/KYC/payout/support) pushed over WS with unread counts, reviews,
  audit log model, feature-flag settings.
- **Routing** — Valhalla client (`/route`, `/matrix`, `/status`) behind a
  `RoutingService` with Redis caching, circuit breaker and haversine fallback;
  routed quotes/bookings, `GET /bookings/{id}/route`, ETA projection and
  turn-by-turn maneuvers.
- **Places** — OSM Photon → Nominatim proxy with caching and Bengaluru bias.
- **Ops/admin** — live overview, daily analytics series, booking search +
  detail + cancel, driver approve/reject/suspend, customers, finance summary,
  payouts mark-paid, promo CRUD, feature settings, ticket replies, audit trail
  (staff JWT).
- **Jobs** — Celery beat: offer expiry sweep (15 s), stale-search failure, raw
  ping retention (72 h), weekly payout generation (idempotent per ISO week).
- **Reliability** — request IDs, stale-search safety net on reads, KYC/POD
  upload type/size validation, stable seed passwords across restarts.
- **Location governance** — server-enforced cadence (5 s on trip / 15 s
  available / 60 s otherwise) with out-of-order drop on REST + WS uplinks.
- **Realtime** — JWT websocket handshake, per-topic authorization
  (`customer/{id}`, `driver/{id}`, `booking/{id}`), `hello`, heartbeat `pong`,
  `resume` ack, offer/status push, driver location + presence uplink.

## Tests

```bash
python manage.py test apps.api.tests      # 68 tests
```

Covers auth/session rotation, quote→book→dispatch→lifecycle→receipt→rating,
promos, wallet/payments, partner onboarding/KYC/vehicles/offers, fleet console,
support/SOS/notifications, the ops/admin surface, scheduled jobs, location
cadence and the websocket protocol.

## Deploying (Render)

Production deploy runbook: [docs/DEPLOY_RENDER.md](../docs/DEPLOY_RENDER.md).
After the first deploy, run in the Render shell:

```bash
python manage.py create_ops_user
python manage.py seed_production_demo
```

Both are idempotent; `seed_production_demo` prints the seeded credentials once.
Media (KYC/POD) lives on a persistent disk and is served staff-only.

## Environment

Copy `.env.example` → `.env` for overrides. Key flags:

- `DB_ENGINE=postgres` + `DB_*` → Postgres (add PostGIS in production)
- `REDIS_URL=redis://...` → Channels + Celery broker on Redis
- `CELERY_EAGER=1` → tasks run inline (dev); 0 → real worker
- `SECRET_KEY`, `DEBUG=0`, `ALLOWED_HOSTS`, `CORS_ALLOWED_ORIGINS` — prod

`python manage.py spectacular --file schema.yml` regenerates the OpenAPI
artifact (0 errors).

## Structure

```
config/          settings, urls, asgi (Channels), wsgi, celery
apps/core/       abstract models + error envelope + realtime helpers + seed_demo
apps/accounts/   users, customer/driver profiles, fleet orgs, vehicles, docs
apps/catalog/    cities, service categories, pricing, commission, promos, referrals
apps/bookings/   bookings, trips, shipments, offers, history, pings, reviews, engine
apps/payments/   payments, wallet ledger, commission entries, payouts
apps/platform/   notifications, support, SOS, audit log, system settings
apps/api/        serializers, views, urls, ws consumers, tests
```
