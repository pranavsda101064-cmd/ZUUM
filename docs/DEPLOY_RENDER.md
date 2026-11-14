# Deploying Zuum to Render

## Option A — Free demo (no credit card)

Render's free plan supports one always-on-ish web service + free Postgres.
Use the root `render.yaml` (free demo). It runs migrations + ops/seed commands
on every boot (free services have no shell) and uses in-memory channels/Celery
eager mode.

Free-tier tradeoffs: spins down after 15 min idle (~1 min cold start), uploads
are lost on restart (ephemeral disk), the free Postgres expires after 30 days,
and there are no workers/beat.

1. Render → New → Blueprint → repo → branch `main` → it picks `render.yaml`.
2. Set `DJANGO_SUPERUSER_EMAIL`, `DJANGO_SUPERUSER_PASSWORD`, `SEED_PASSWORD`.
3. Deploy. Check the **Logs** for the three seeded credentials printed by
   `seed_production_demo`.
4. Verify `https://<service>.onrender.com/api/v1/health`.

## Option B — Production (Starter plans, card required)

Use `render.production.yaml` as the Blueprint Path. It adds Celery worker +
beat, Redis, a 10 GB media disk and migrations via `preDeployCommand`.
Deployment steps are the same; you can also open a shell to run the seed
commands manually.


1. Push this repo to GitHub (branch `main`).
2. Render Dashboard → **New → Blueprint** → select the repo → `infra/render.yaml`.
3. Apply. Render creates:
   - `zuum-api` (Docker, daphne ASGI, 10 GB media disk)
   - `zuum-worker` (Celery)
   - `zuum-beat` (Celery beat)
   - `zuum-db` (Postgres)
   - `zuum-redis` (Redis)
4. Set the secret env vars on the API service (Dashboard → Environment):
   - `DJANGO_SUPERUSER_EMAIL`, `DJANGO_SUPERUSER_PASSWORD` (ops login)
   - `SEED_PASSWORD` (same password for the three seeded demo accounts)
   - `ROUTING_API_KEY` only if you move off the public Valhalla demo
5. After the first deploy finishes, open **zuum-api → Shell**:
   ```bash
   python manage.py create_ops_user
   python manage.py seed_production_demo
   ```
   Copy the three credentials printed (ops / partner / customer).
6. Open `https://<service>.onrender.com/api/v1/health` → `{"status":"ok"}`.
7. Optional: `/api/v1/docs/` for Swagger, `/admin/` for KYC approvals.
8. Give the mobile build:
   - `API_BASE_URL=https://<service>.onrender.com/api/v1`
   - `WS_BASE_URL=wss://<service>.onrender.com/ws`

## Notes

- WebSockets and the media disk require the paid Starter plan (free instances sleep).
- The media disk holds KYC/POD files; download them through Django admin (staff-only).
- Email uses the console backend in v1 (password-reset tokens appear in Render logs).
- Payments remain simulated (wallet/cash + mock Razorpay order/verify) until live keys are configured.
- To self-host routing, point `ROUTING_BASE_URL` at a Valhalla instance (see `docs/07_maps_routing.md`).
