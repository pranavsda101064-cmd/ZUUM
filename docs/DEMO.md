# Zuum — Demo Script (mock build)

APK: `builds/zuum-customer-mock.apk` · install it, allow "install unknown apps".
Build: `flutter build apk --release --dart-define=ENV=mock` (ENV=mock is required —
there is no backend yet; all business logic runs on the labeled dev mock).

> Mock quirks (by design): session resets on every app restart · maps use live
> OpenStreetMap tiles · place search is live (Nominatim) · bookings/fare/money
> are simulated · trip timings are compressed (~30 s end to end).

## 1. First run (1 min)
Splash (tagline EN + Kannada) → 3-slide onboarding → **Create account**
(any valid email + 6-char password; phone optional).

## 2. Book a ride (2 min)
Home → **Where to?** → tap **Current location** → type `whitefield` →
pick **Whitefield** → fare screen: 6 vehicle categories with server-computed
fares → tap a fare for the **breakdown sheet** → pick **Sedan** →
optionally switch payment to **UPI** → **Book Sedan**.

## 3. Watch the live trip (30 s)
Tracking screen: driver assigned (name/vehicle/OTP) → **Arriving in N s** with
moving driver on the live map → **On trip** → completed.
Buttons: Cancel (with confirm) · Share trip · SOS (helplines + alert).

## 4. Pay, rate, receipt (30 s)
Trip payment → add a tip (₹0/10/20/30) → pay **Cash / UPI / wallet** →
rate with stars + tags → **receipt** (itemized, payment state) → Done →
check **Activity** (status = Completed).

## 5. Send goods (2 min)
Home → **Send Goods** → route (e.g. Whitefield) → goods details:
type chips, weight, dims, loading help (+₹50), sender/receiver →
**Tata Ace** (capacity matched) → book → track (**In transit**) →
on completion **proof-of-delivery sheet**: receiver name (prefilled) +
4-digit OTP (`4321` on the mock) + optional camera photo → pay → receipt
shows **Delivered · Received by**.

## 6. Money & account (2 min)
- **Wallet**: ₹150 seeded → **Add money** (₹100/200/500 UPI sheet) →
  ledger of top-ups/debits → pay a trip from the wallet.
- **Account**: profile edit · saved-addresses CRUD · offers (code `ZUUM50`,
  `NAMMA100`, `BLR20`) · notifications (tap to mark read) · support
  (topics + raise ticket) · safety (112/100/108/1091/1098/1930) · settings.

## 7. Cancel path
On the tracking screen → **Cancel** → confirm → home; the booking shows
Cancelled in Activity.

## Tests (CI gate)
```bash
cd packages/core && flutter test            # 28
cd packages/design_system && flutter test   # 11
cd apps/zuum_customer && flutter test       # 11
```
All packages: `flutter analyze` clean.

## Real-service swap (no UI changes)
- Mapbox tiles/geocoding: `--dart-define=MAPBOX_ACCESS_TOKEN=pk...`
- Razorpay: keys → `PaymentGateway` Razorpay impl (Phase 6)
- Backend: Django Phase 2 implements `/api/v1` per `docs/03_api_contract.md`;
  set `API_BASE_URL`/`WS_BASE_URL` + `ENV=dev`.

## Backend (Phase 2) demo

```bash
cd backend
python -m venv .venv && .venv\Scripts\activate
pip install -r requirements.txt
python manage.py migrate && python manage.py seed_demo
python manage.py runserver
```

- Swagger: http://127.0.0.1:8000/api/v1/docs/
- Personas (password `zuum1234`): `customer@zuum.in`, `partner@zuum.in`,
  `fleet@zuum.in`
- 60-second API walkthrough: login customer -> `POST /pricing/quote` ->
  `POST /bookings` -> login partner -> `GET /partner/offers` ->
  `POST /partner/offers/{id}/accept` -> `POST /partner/bookings/{id}/arrive`
  -> `POST /partner/bookings/{id}/verify-otp` (OTP in `dev_otp_hint` while
  `DEBUG=1`) -> `POST /partner/bookings/{id}/complete` ->
  `GET /bookings/{id}/receipt`.
- WebSocket: `ws://127.0.0.1:8000/ws/driver/{user_id}/?token=<access>` emits
  `hello`, `booking.offer`, `booking.offer.expired` and accepts
  `driver.status` / `booking.location` uplinks.
- Tests: `python manage.py test apps.api.tests` (32 green).
