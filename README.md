# Zuum

*Old Bengaluru soul. New Bengaluru movement.*

Unified mobility & logistics ecosystem: passenger rides (bike/auto/cab) + goods
transport (2W/3W/Ace/Pickup/Van/Tempo), built as one platform.

| App | Purpose | Status |
|---|---|---|
| `apps/zuum_customer` | Customer booking app (Flutter mobile) | 🟨 Phase 3 |
| `apps/zuum_partner` | Driver & fleet partner app (Flutter mobile) | ⬜ Phase 4 |
| `apps/zuum_admin` | Ops & monitoring dashboard (Flutter Web) | ⬜ Phase 5 |
| `backend/` | Django + DRF + Channels + Celery | ⬜ Phase 2 |

## Docs

- [Architecture ADR-001](docs/01_architecture.md)
- [Data model](docs/02_data_model.md)
- [API contract](docs/03_api_contract.md)
- [Realtime protocol](docs/04_realtime_protocol.md)
- [Design tokens](docs/05_design_tokens.md)
- [Progress tracker](docs/PROGRESS.md)

## Quick start (customer app)

```bash
cd apps/zuum_customer
flutter pub get
flutter run --dart-define=ENV=mock
```

`ENV=mock` runs the app against the **dev-only mock API adapter** (clearly labeled,
never used in production builds). `ENV=dev|prod` points at a real backend
(`API_BASE_URL`, `WS_BASE_URL`, `MAPBOX_ACCESS_TOKEN` via `--dart-define`).

## Repo layout

```
apps/       Flutter applications
packages/   Shared Dart packages (core, design_system)
backend/    Django backend (Phase 2)
infra/      Render blueprint, env templates
docs/       Architecture & contracts
```
