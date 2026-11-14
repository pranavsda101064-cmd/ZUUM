# Zuum Data Model

PostgreSQL + PostGIS. UUID primary keys on all externally-referenced entities.
Money = integer minor units (paise). All timestamps UTC (IST for display).

## ER overview

```
User ──1:1── CustomerProfile ──N── Booking ──1:1── PassengerTrip
User ──1:1── DriverProfile ──N── Vehicle
FleetPartner ──N── DriverProfile
FleetPartner ──N── Vehicle
Booking ──1:1── GoodsShipment
Booking ──N── DispatchOffer ──N── DriverProfile
Booking ──N── BookingStatusHistory
Booking ──1:1── Payment
Booking ──N── Review
Booking ──1:N── LocationPing (via driver)
Wallet ──N── WalletTransaction
CommissionRule → CommissionEntry → Payout
```

## Entities

### core / users
- **User** (UUID) — `email` (unique), `password_hash`, `role`
  (`customer|driver|fleet_owner|staff`), `first_name`, `last_name`, `phone`,
  `phone_verified`, `is_active`, `created_at`. Email is the login identity (MVP);
  phone reserved for OTP later.
- **StaffRole** — `superadmin|ops|finance|support|regional` for `role=staff`.

### customers
- **CustomerProfile** — FK User, default pickup, `preferred_payment_method`,
  flags (`is_restricted`).
- **SavedAddress** — FK customer, label (`home|work|other`), name, point (PostGIS),
  formatted address, is_default.

### drivers / fleet / vehicles
- **DriverProfile** — FK User, FK FleetPartner (nullable → independent owner-driver),
  license number, `kyc_status` (`pending|submitted|approved|rejected`),
  `approval_status`, `bank_account_ref`, `rating_avg`, `rating_count`,
  `online_state` (`offline|available|busy`), `last_seen_at`, home point.
- **FleetPartner** — org name, `gstin`, KYC status, owner FK User, payout config.
- **Vehicle** — FK driver (assigned driver), FK fleet (nullable), `category` FK
  ServiceCategory, `registration_number` (unique), make/model/color, `capacity_kg`,
  `volume_cuft`, `is_active`, `documents`.
- **VehicleDocument** — type (`rc|insurance|puc|permit|photo`), file key (private S3,
  signed URL), expiry, verification status.

### service catalog / geo
- **ServiceCategory** — `code` (bike, auto, hatchback, sedan, suv, premium,
  goods_2w, goods_3w, ace, pickup, van, tempo), `kind` (`passenger|goods`),
  `capacity_kg`/`volume_cuft` (goods), `seats` (passenger), `is_enabled`.
- **City** — `code` (blr), name, polygon (PostGIS), `is_active`.
- **Geofence** — polygon + type (`surge|service|restricted`), city FK.

### bookings (shared engine)
- **Booking** (UUID) — `type` (`ride|goods`), FK customer, FK service_category,
  pickup point + address, drop point + address, `status`, `quoted_fare`,
  `final_fare`, `currency` (INR), `payment_state`
  (`unpaid|authorized|paid|refunded|failed`), `payment_method`
  (`cash|upi|card|wallet`), `scheduled_at` (nullable → instant), `notes`,
  `cancelled_by`, `cancel_reason`, `created_at`.
- **PassengerTrip** (1:1) — `ride_type` (`now|scheduled|rental|outstation`),
  `passengers`, stops (JSON list), OTP (for trip start).
- **GoodsShipment** (1:1) — `goods_type`, `weight_kg`, dims, `needs_loading_help`,
  `load_type` (`full|part`), sender/receiver name+phone, stops (multi-drop, JSON),
  `pod_required`, `pickup_otp`, `delivery_otp`, POD fields (photos keys, receiver name,
  signed at).
- **DispatchOffer** — FK booking, FK driver, `status`
  (`offered|accepted|rejected|expired|revoked`), `offered_at`, `expires_at`,
  `responded_at`. One row per offer attempt; unique (booking, offer_seq).
- **BookingStatusHistory** — FK booking, `from_status`, `to_status`,
  `actor_type` (`customer|driver|system|ops`), actor id, reason, at.
- **LocationPing** — FK driver, `point` (PostGIS geography), `speed`, `heading`,
  `recorded_at`, `booking_id` (nullable). Retention: raw 72 h, aggregated longer.

### pricing / payments / money
- **PricingRule** — FK service_category, city, base fare, per_km, per_min,
  min_fare, waiting charge, night multiplier, surge multiplier, `valid_from/to`.
- **FareQuote** — booking FK (nullable pre-booking), breakdown JSON
  (base, distance, time, surge, tolls, waiting, discount, total), distance_m,
  duration_s, quoted_at.
- **Payment** — FK booking, method, gateway ref (Razorpay order/payment id),
  amount, status, failure reason, processed_at.
- **Wallet** — FK customer, balance (paise), currency.
- **WalletTransaction** — wallet FK, `credit|debit|refund|topup|payout|adjustment`,
  amount, reference (booking/payment id), balance_after, note.
- **CommissionRule** — service_category, city, `percent`, effective range.
- **CommissionEntry** — booking FK, platform_amount, driver_amount, rule snapshot.
- **Payout** — driver FK, amount, method (`bank|upi`), status
  (`pending|processing|paid|failed`), gateway ref, batch id, paid_at.
- **PromoCampaign** — code, type (`percent|flat`), value, max discount, min fare,
  usage limits, valid range, scope (category/city).
- **Referral** — referrer customer, referee, code, status, reward amounts.

### platform
- **Review** — booking FK, reviewer role, rating 1–5, comment, tags, created_at.
- **Notification** — user FK, type, title, body, data JSON, read_at, sent_at, channel.
- **SupportTicket** — customer FK, booking FK (nullable), category, subject, status
  (`open|pending|resolved|closed`), priority.
- **SupportMessage** — ticket FK, author, body, attachments, created_at.
- **AuditLog** — actor (user id + role), action, entity type + id, before/after
  snapshot (JSON), ip, at. Written by service layer on sensitive mutations.
- **SystemSetting** — key, value JSON (surge toggle, maintenance mode, feature flags).

## Booking lifecycle (events → transitions)

| Event | From | To | Notes |
|---|---|---|---|
| `create` | — | CREATED | validates address, customer active |
| `quote` | CREATED | PRICED | pricing service computes breakdown |
| `search` | PRICED | SEARCHING | dispatch loop begins offers |
| `offer_accepted` | SEARCHING | ASSIGNED | driver accepts; offer rows settle |
| `driver_arriving` | ASSIGNED | DRIVER_ARRIVING | driver taps "start trip" → OTP |
| `trip_start` | DRIVER_ARRIVING | IN_PROGRESS | OTP verified server-side |
| `trip_complete` | IN_PROGRESS | COMPLETED | fare settled; commission split |
| `cancel` | CREATED..DRIVER_ARRIVING | CANCELLED | fee rules by stage |
| `fail` | SEARCHING/… | FAILED | no_driver / payment_failed |

All illegal transitions raise `IllegalTransition` — client requests only.

## Indexes (high-traffic)

- `bookings(status, created_at)`, `bookings(customer_id, created_at DESC)`
- `dispatch_offers(driver_id, status)`, `location_pings(driver_id, recorded_at)`
- GIST on `location_pings.point`, `city.polygon`, address points
- `users(email)` unique; `vehicles(registration_number)` unique
