# Zuum Partner API Contract — `/api/v1/partner/`

Consumer surface: `docs/03_api_contract.md`. Realtime: `docs/04_realtime_protocol.md`
(`driver:{id}` offers, `booking:{id}` statuses). Auth: same JWT flow as the
consumer app; partner endpoints require a user whose `role == driver`.

Unless noted, all responses are JSON, money is integer paise, IDs are UUIDs,
timestamps ISO-8601 UTC. Writes are server-authoritative — the client proposes,
the server decides.

## Auth (shared with consumer)

| Method | Path | Notes |
|---|---|---|
| POST | `/auth/register` | role defaults to `customer`; partner promotion happens via KYC |
| POST | `/auth/login` | returns session + `user.role` |
| GET | `/auth/me` | |

## Partner profile & KYC

| Method | Path | Notes |
|---|---|---|
| GET | `/partner/profile` | driver profile + `kyc_status` + `approval_status` |
| PUT | `/partner/profile` | personal details, languages, home base |
| POST | `/partner/kyc/submit` | marks KYC `submitted`; requires all mandatory documents |
| GET | `/partner/kyc` | `{status, submitted_at, reviewed_at, rejection_reason, documents[]}` |

`kyc_status`: `draft | submitted | approved | rejected`
`approval_status`: `pending | active | suspended`

### Documents

| Method | Path | Notes |
|---|---|---|
| GET | `/partner/documents` | list with `type`, `expires_at`, `status` |
| POST | `/partner/documents` | multipart: `type` (`licence|rc|insurance|puc|profile_photo|vehicle_photo`), `file`, `expires_at?` |
| DELETE | `/partner/documents/{id}` | only while `draft`/`rejected` |

## Vehicles

| Method | Path | Notes |
|---|---|---|
| GET | `/partner/vehicles` | own vehicles (fleet drivers: assigned vehicles) |
| POST | `/partner/vehicles` | `{category, registration_number, make, model, color, capacity_kg?, volume_cuft?, seats?}` |
| PUT/DELETE | `/partner/vehicles/{id}` | |
| PATCH | `/partner/vehicles/{id}/availability` | `{is_active: bool}` |

`category` values: `bike|auto|hatchback|sedan|suv|premium` (passenger),
`goods_2w|goods_3w|ace|pickup|van|tempo` (goods).

## Availability & location

| Method | Path | Notes |
|---|---|---|
| POST | `/partner/availability` | `{online: bool, vehicle_id?, lat?, lng?}`; going online requires `approval_status=active` |
| POST | `/partner/location` | `{lat, lng, heading?, speed_mps?, recorded_at}` — REST fallback when WS is unavailable; WS preferred per protocol |

Cadence (server-enforced): 5 s min interval while on an active trip, 15 s while
available, 60 s while online outside the service geofence, no sends while
stationary >90 s.

## Offers & dispatch

| Method | Path | Notes |
|---|---|---|
| GET | `/partner/offers` | currently pending offers for this driver (also pushed over WS) |
| POST | `/partner/offers/{id}/accept` | 409 if expired or already taken |
| POST | `/partner/offers/{id}/decline` | `{reason?}` |

`offer` shape:
```json
{
  "id": "uuid", "booking_id": "uuid", "expires_at": "...",
  "pickup": {"lat": 0, "lng": 0, "address": "..."},
  "drop": {"lat": 0, "lng": 0, "address": "..."},
  "distance_m": 4800, "pickup_eta_s": 240,
  "fare_paise": 14200, "surge_multiplier": 1.2,
  "service_category": {"code": "auto", "kind": "ride", "name": "Auto"},
  "booking_type": "ride|goods",
  "goods": null | {"goods_type": "...", "weight_kg": 120, "needs_loading_help": true}
}
```

## Trip lifecycle (driver actions)

All transitions are validated server-side against the booking state machine
(`docs/02_data_model.md`). Illegal transitions → `409 illegal_transition`.

| Method | Path | Notes |
|---|---|---|
| POST | `/partner/bookings/{id}/arrive` | `DRIVER_ARRIVING → ARRIVED` (pickup) |
| POST | `/partner/bookings/{id}/verify-otp` | `{otp}` → `ARRIVED → IN_PROGRESS`; ride start / goods loading complete |
| POST | `/partner/bookings/{id}/pickup-pod` | goods only, multipart `photo` → records pickup evidence |
| POST | `/partner/bookings/{id}/complete` | `IN_PROGRESS → COMPLETED`; goods requires delivery OTP verified |
| POST | `/partner/bookings/{id}/verify-delivery-otp` | goods only `{otp}` |
| POST | `/partner/bookings/{id}/delivery-pod` | goods only: `receiver_name`, `photo`, `signature` (multipart) |
| POST | `/partner/bookings/{id}/cancel` | `{reason}`; fee rules by stage |

`booking` (partner view) adds: `customer` (first name only + masked phone),
`otp_required`, `fare_paise`, `commission_paise`, `earning_paise`,
`payment_method`, `payment_state`.

## Earnings & payouts

| Method | Path | Notes |
|---|---|---|
| GET | `/partner/earnings?range=today|week|month` | `{gross_paise, commission_paise, net_paise, trips, online_minutes, acceptance_rate, cancellation_rate}` |
| GET | `/partner/earnings/trips?page=` | trip ledger rows with per-trip split |
| GET | `/partner/payouts?page=` | `{id, amount_paise, status, method, paid_at, batch_ref}` |
| GET | `/partner/stats` | ratings average/count, completion rate, weekly trend |

Commission: `commission = fare * commission_percent` (server rule, e.g. 20%),
`earning = fare - commission - tips_paid_to_cash?` (cash trips: fare collected
by driver, commission invoiced separately — rule configured server-side).

## Fleet (fleet_owner role)

| Method | Path | Notes |
|---|---|---|
| GET | `/fleet/overview` | `{drivers_active, vehicles_active, earnings_today_paise, utilisation}` |
| GET | `/fleet/drivers?page=` | drivers with status, rating, earnings |
| POST | `/fleet/drivers/invite` | `{phone?, email?}` → invitation |
| DELETE | `/fleet/drivers/{id}` | detach driver (does not delete account) |
| GET/POST | `/fleet/vehicles` | fleet-owned vehicles |
| PUT | `/fleet/vehicles/{id}/assign` | `{driver_id}` |
| GET | `/fleet/earnings?range=` | aggregate + per-driver breakdown |

## Errors

Same envelope as consumer (`{code, message, details?}`). Partner-specific codes:
`kyc_incomplete`, `not_approved`, `offer_expired`, `offer_taken`,
`illegal_transition`, `vehicle_inactive`, `otp_invalid`, `pod_missing`.

## Realtime (existing protocol)

- `driver/{id}` — `booking.offer`, `booking.offer.expired`, `booking.cancelled`,
  `payout.paid`
- `booking/{id}` — `booking.status`, `booking.driver_location`, `booking.eta`
- Uplink from partner: `booking.location` (throttled), `driver.status`

## Mock parity (ENV=mock)

`MockPartnerApi` implements this surface in-memory with a self-driving offer
simulator (offer every 20–40 s while online, 15 s expiry, compressed trip
timings) so the partner app is demoable before the Django backend (Phase 2).
Any deviation from this contract is a bug.

## Backend implementation notes (Phase 2)

The Django backend (`backend/apps/api/views/partner.py`) implements this
contract with these documented extensions:

- `GET /partner/bookings/active` - `{"trip": booking | null}` for profile
  restore on app launch (the mock app's `activeTrip()` parity).
- `dev_otp_hint` on offers/partner bookings while `DEBUG=1` (single-phone demo
  convenience; never present in production builds).
- Offer expiry is 15 s; a sweep runs on `GET /partner/offers` and on accept
  (`offer_expired` / `offer_taken`).
- `POST /partner/availability` returns `{online, state}`.
- Delivery POD (`delivery-pod`) requires the delivery OTP to be verified first
  (`409 pod_missing`), matching `complete`.
