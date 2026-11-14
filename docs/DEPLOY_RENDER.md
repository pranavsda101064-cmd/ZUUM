# Deploying Zuum to Render

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
