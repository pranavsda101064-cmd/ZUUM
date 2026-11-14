# ADR-001 — Zuum Platform Architecture

Status: **Accepted** · Date: 2026-11-12 · Supersedes: none

## Context

Zuum is a unified mobility & logistics ecosystem for Bengaluru: one platform covering
passenger rides (bike/auto/cab), goods transport (2W/3W/Ace/Pickup/Van/Tempo), and
eventually freight. It is a four-sided marketplace (customer, driver, fleet, platform).

Brand: **Zuum** — *Old Bengaluru soul. New Bengaluru movement.*

## Decisions

| # | Decision | Choice | Consequence |
|---|---|---|---|
| 1 | Client stack | Flutter (mobile x2 + web admin) | One language, shared `packages/` design system |
| 2 | Backend | Django 5 + DRF + Channels + Celery | Server-authoritative business logic |
| 3 | DB | PostgreSQL + PostGIS, Redis | Geo queries (nearby drivers), channel layer, queues |
| 4 | Launch market | Bengaluru only | City model in DB, INR (minor units), IST |
| 5 | Maps | MapLibre + OpenStreetMap + Valhalla | Mobile: `maplibre_gl` + OpenFreeMap; Web admin: MapLibre GL JS; both behind `ZMapView`; routing via Django → Valhalla (see ADR-002) |
| 6 | Payments | Cash + UPI/wallet via Razorpay | `PaymentGateway` interface; payouts in platform batches |
| 7 | Auth (MVP) | Email + password → JWT | `phone`/`phone_verified` reserved; OTP slots in later |
| 8 | Goods categories | 2W, 3W, Ace, Pickup, Van, Tempo | `ServiceCategory` rows; LCV/heavy flagged off |
| 9 | Fleet partners | In MVP | `FleetPartner` orgs, multi-driver/multi-vehicle |
| 10 | Customer app scope | Full IA (milestones A–F) | No placeholder screens in release |
| 11 | Customer identity | Balanced Old+New Bengaluru | Kannada secondary labels, landmark line art, local voice |

## Three-application architecture

```
zuum_customer (Flutter mobile)   zuum_partner (Flutter mobile)   zuum_admin (Flutter Web)
        │ REST + JWT                      │ REST + JWT                  │ REST + JWT (RBAC)
        │ WS: booking:{id}, customer:{id} │ WS: driver:{id}, booking:{id}│ WS: admin:ops
        └────────────────┬────────────────┴─────────────┬──────────────┘
                         ▼                              │
              Django backend (DRF + Channels + Celery)  │
              auth users customers drivers fleet vehicles bookings
              dispatch mobility logistics tracking pricing payments
              wallets commissions notifications reviews support
              analytics administration audit core
                         │
              PostgreSQL/PostGIS · Redis · Celery workers
```

Rules:
- Clients never decide fare, eligibility, ownership, payment or trip state.
- All mutations of money/booking/driver state are service-layer calls writing `AuditLog`.
- Booking engine is shared; passenger (`PassengerTrip`) and goods (`GoodsShipment`)
  differ only in 1:1 extension tables and their lifecycle hooks.

## Booking state machine (server-authoritative)

```
CREATED → PRICED → SEARCHING → ASSIGNED → DRIVER_ARRIVING → IN_PROGRESS → COMPLETED
   ↳ CANCELLED (customer|driver|ops)     ↳ FAILED (no_driver|payment_failed|expired)
```

Transitions: `booking_service.transition(booking, event, actor)` — validates legality,
writes `BookingStatusHistory`, emits domain event → notifications + WS fan-out + audit.

## Repository layout (monorepo)

```
zuum/
├── apps/zuum_customer      # Flutter mobile — customer app (this phase)
├── apps/zuum_partner       # Flutter mobile — driver & fleet partner (Phase 4)
├── apps/zuum_admin         # Flutter Web — ops dashboard (Phase 5)
├── packages/core           # API client, WS client, DTOs, env, token storage
├── packages/design_system  # Tokens, components, map abstraction, illustrations
├── backend/                # Django project (Phase 2)
├── infra/                  # Render blueprint, .env templates, runbooks
└── docs/                   # ADRs, contracts, PROGRESS.md
```

## Real-time strategy

- Django Channels over Redis; topics: `driver:{id}`, `booking:{id}`, `customer:{id}`,
  `admin:ops`.
- Location: throttled adaptive rate (5 s in-trip / 15–30 s idle / 60 s idle out-of-zone,
  paused when stationary). Batches, last-point-wins, PostGIS storage with retention jobs.
- Clients reconnect with exponential backoff + resume token; REST snapshot fallback.

## Infrastructure (Render)

`web` (Daphne ASGI) · `worker` (Celery) · `beat` · managed Postgres (PostGIS) ·
managed Redis · S3-compatible media bucket (KYC docs, POD photos, signed URLs).
Secrets via environment variables only — never in source or Flutter bundles.

## Consequences

- Flutter Web admin is viable but map performance needs clustering/aggregation server-side.
- Email+password MVP is weaker for a mobility product; phone OTP (Firebase Auth or SMS
  gateway) is designed for but deferred — auth backend is provider-agnostic.
- Single-city launch keeps pricing/geo simple; multi-city is configuration, not schema.
