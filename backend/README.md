# Zuum backend (Django)

Phase 2 target — not yet scaffolded. The deployment contract lives in
`infra/render.yaml` (web + worker + beat + Postgres/PostGIS + Redis).

Planned layout:

```
backend/
├── config/          # settings (dev/prod), asgi, urls, celery
├── apps/
│   ├── core/ authentication/ users/ customers/ drivers/ fleet/ vehicles/
│   ├── bookings/ mobility/ logistics/ dispatch/ tracking/
│   ├── pricing/ payments/ wallets/ commissions/
│   ├── notifications/ reviews/ support/ analytics/
│   ├── administration/ audit/
└── manage.py
```

Contract to implement first: `docs/03_api_contract.md` (consumer surface).
