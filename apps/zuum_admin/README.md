# zuum_admin

Zuum ops dashboard (Flutter Web). Consumes the staff-only `/api/v1/ops/*`
surface: live overview, bookings, driver KYC, finance/payouts and support.

## Run against local API

```bash
# backend
cd backend
.venv\Scripts\python.exe manage.py runserver 127.0.0.1:8000

# dashboard
cd apps/zuum_admin
flutter run -d chrome --dart-define=API_BASE_URL=http://127.0.0.1:8000/api/v1
```

Debug backend runs with `DEBUG=1`, which allows all CORS origins.

## Build / preview

```bash
flutter build web
python -m http.server 8080 --directory build/web
```

Release builds default to `https://zuum-api.onrender.com/api/v1`. The Render
blueprint allows `localhost:8080` / `127.0.0.1:8080`; add your hosted dashboard
origin to `CORS_ALLOWED_ORIGINS` before deploying it elsewhere.

Staff accounts only. Every write action calls the audited ops API.
