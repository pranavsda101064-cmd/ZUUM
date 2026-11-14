# Zuum — Development Progress

Legend: ⬜ not started · 🟨 in progress · ✅ done · ⛔ blocked

## Phase 0 — Discovery ✅
- [x] Workspace inspected (empty), toolchain verified (Flutter 3.47.2, Python 3.13, Git)

## Phase 1 — Architecture & Contracts
- [x] ADR-001 architecture (`01_architecture.md`)
- [x] Data model + booking state machine (`02_data_model.md`)
- [x] API contract — consumer surface (`03_api_contract.md`)
- [x] Realtime protocol (`04_realtime_protocol.md`)
- [x] Design tokens (`05_design_tokens.md`)
- [ ] Partner + admin API surfaces (before Phase 4/5)

## Phase 2 — Backend Foundation ⬜
- [ ] Django skeleton, module apps, settings (dev/prod), ASGI/Channels/Celery
- [ ] Postgres/PostGIS models + migrations, Redis wiring
- [ ] Auth (email+password, JWT, RBAC) + user/customer/driver/fleet/vehicle CRUD
- [ ] ServiceCategory + Bengaluru seed, pricing engine v1 + golden tests
- [ ] Booking state machine service + dispatch offer loop + audit log
- [ ] OpenAPI schema served; pytest green

## Phase 3 — Customer App (app-first with mock adapter)
- [x] Milestone A — foundation: core + design_system packages (tokens,
      components, bundled Inter/Noto Sans Kannada fonts, BLR map placeholder),
      app shell (theme, router, splash, onboarding, env/mock wiring)
- [x] Milestone B — auth (login/register/forgot, session restore, sign out)
- [x] Milestone C — booking core: location search (Mapbox geocoding + mock),
      per-category server quotes, fare breakdown sheet, payment method sheet
      (cash/UPI; wallet flagged), schedule picker, confirm → searching screen
      with cancel, real Activity feed. createBooking in ApiContract + mock,
      PlaceSearchService (Mapbox + Bengaluru mock).
- [x] Milestone D — live trip: RealtimeService + MockDispatchSimulator
      (compressed demo timings), tracking screen (live map + driver card +
      OTP + ETA + cancel/SOS/share), payment screen (cash/UPI/wallet + tip),
      rating & review, receipt. Tel/SMS launchers, share_plus.
- [x] Milestone E — goods: goods details flow (type/weight/dims/contacts,
      loading help +₹50), capacity-matched vehicles, proof-of-delivery
      (receiver prefill + delivery OTP + camera photo), delivered receipt.
- [x] Milestone F — wallet (top-up via mock gateway + ledger), offers &
      referrals, notifications, support (topics + tickets), safety (real
      helplines + SOS), settings/profile/addresses CRUD/payment methods,
      launcher icon + Zuum app name.

## Phase 3 — Testing & delivery
- [x] 50 tests green across all three packages (28 core + 11 design system
      + 11 app e2e) — flutter analyze clean everywhere.
- [x] Universal release APK: `builds/zuum-customer-mock.apk`
      (com.zuum.customer · label "Zuum" · minSdk 24 · ENV=mock)
- [x] Demo script: `docs/DEMO.md`

## Phase 4 — Partner App
- [x] Batch 1 — contract + scaffold: `apps/zuum_partner` (com.zuum.partner,
      "Zuum Partner"), carbon-header partner theme, router skeleton (splash →
      auth → 4-tab shell), env/mock wiring, `docs/06_partner_api.md`; 2 smoke
      tests green, analyze clean
- [x] Batch 2 — core partner layer: PartnerApiContract + MockPartnerApi
      (KYC state machine, vehicles, availability, offers, ride + goods trip
      lifecycle with OTP/POD, 20/80 commission, earnings ranges, payouts,
      fleet console data), DriverRealtimeService + offer simulator, partner
      models, providers; 16 new unit tests (44 core total), analyze clean
- [x] Batch 3 — partner design-system components: ZOnlineHero (lime live
      dot + big switch), ZOfferCard (countdown ring, surge pill, accept/
      decline, expired state), ZStatCard, ZCommissionBreakdown,
      ZDocumentTile (verified/pending/expired), ZLiveDot, ZFormat.shortDate;
      8 new widget tests (28 design-system total), analyze clean
- [x] Batch 4 — shell + onboarding/KYC: partner auth controller (email +
      password, session restore), router guards (splash → login → KYC wizard →
      pending → shell), 5-step wizard (details / licence / vehicle / documents
      with camera-gallery-demo picker / payout), KYC pending screen with review
      polling, iOS camera + photo permission strings; 4 e2e tests, analyze clean
- [x] Batch 5 — home + online status + offers: dashboard (online hero with
      server-authoritative toggle, simulated-GPS map card, net-today +
      acceptance stats, active-trip card), offer bottom sheet (live countdown,
      accept/decline, expired + error states), realtime simulator wired with
      provider-dispose cleanup, dev "Simulate offer" action; 7 partner e2e
      tests (44 core + 28 design-system green), analyze clean
- [x] Batch 6 — trip lifecycle (ride + goods POD): `TripController`
      (server-authoritative transitions), trip screen states (heading to
      pickup / at pickup OTP / in-trip / completed receipt), customer card with
      masked phone, cancel-with-reason dialog, goods POD delivery-OTP gate
      (`pod_missing` surfaced), completion receipt with commission breakdown;
      2 new e2e tests (9 partner total), analyze clean
- [x] Batch 7 — earnings + vehicles + fleet console: earnings tab (range
      segmented control, net/gross/commission/acceptance summary, latest
      payout, ledger filtered by range), vehicles tab (availability toggles,
      insurance expiry warnings, add-vehicle sheet with category chips), fleet
      console (overview stats, driver roster, assign-vehicle sheet); 3 new
      e2e tests (12 partner total), analyze clean
- [x] Batch 8 — account/polish → APK → install → docs → commit/push: account
      tab (profile header, rating/acceptance stats, KYC document tiles,
      notifications toggle, language/support/terms, environment badge, sign
      out with confirm), one-tap dev demo sign-in (+ `AUTO_DEMO` kiosk flag),
      INTERNET permission added to both release manifests (map tiles/search
      now work in release APKs), partner APK built/installed and home screen
      verified on device; 14 partner tests + 44 core + 28 design-system green,
      analyze clean


## Phase 5 — Admin Dashboard (Flutter Web) ⬜
- [ ] Live ops map, bookings, drivers, customers, finance, analytics, config, audit

## Phase 6 — Integration ⬜
- [ ] Swap mock→live APIs, WS end-to-end, payments/commission settlement, RBAC matrix

## Phase 7 — Testing & Deployment ⬜
- [ ] Test suites, security pass, Render deploy, CI, store readiness

## Phase 2 — Backend (Django) ✅ core
- [x] Scaffold: config (settings/env/asgi/channels/celery), 7 apps, SQLite dev
- [x] Auth: email+password JWT, rotating refresh + blacklist, logout, signed
      password reset, `{code, message, details?}` error envelope
- [x] Catalog + pricing: service categories, distance/surge/night/loading fare
      breakdown, commission rules, promos, referrals
- [x] Bookings + dispatch + lifecycle: quote → book → offers (15 s expiry) →
      accept → arrive → OTP start → complete, goods POD gate, cancel, history
- [x] Partner surface: profile promotion, KYC documents/submit, vehicles +
      availability, offers, trip actions, PODs, earnings/payouts/stats
- [x] Fleet console API: overview, roster, invite, detach, vehicles, assign,
      earnings breakdown
- [x] Money: wallet + ledger, mock Razorpay order/verify, commission entries,
      payouts
- [x] Platform: support tickets, SOS, notifications, reviews, audit, settings
- [x] Realtime: Channels consumer (JWT handshake, topic authz, hello/pong/
      resume, offer + status push, location/presence uplink)
- [x] OpenAPI via drf-spectacular (`schema.yml`, 0 errors) + Swagger UI
- [x] `seed_demo` personas (customer / partner / fleet) + 32 tests green
- [ ] Production swaps (Phase 6): Postgres+PostGIS, Redis, Razorpay live,
      Celery workers, admin dashboard consumption

## Open items
- [ ] Mapbox access token (mobile + web) — env-injected at Milestone C
- [ ] Razorpay account keys — Phase 6
- [ ] Partner + admin brand visual specs (design tokens already shared)
- [ ] App store assets / privacy policy (Phase 7)
- [x] Backend Phase 2 core — implemented in `backend/` (32 tests, `seed_demo`)

## Log
-- 2026-11-14 - Palette v2 'Obsidian Monochrome & Lime Volt' shipped: token remap (obsidian #111827 CTAs, carbon ink #090D16, volt lime #84CC16 signals), zero hex literals outside colors.dart, 18 SVGs remapped, launcher icon regenerated, dark-surface contrast fixes (splash progress + wallet CTA/chips), 60 tests green, APK rebuilt and reinstalled.
 2026-11-12 — ADR-001 locked (Bengaluru, Mapbox, Razorpay, email+password, fleet in MVP,
  customer app first with mock adapter, balanced Bengaluru identity, full IA).
- 2026-11-12 — Docs Phase 1 complete; monorepo scaffolded; Milestone A started.
- 2026-11-12 — Phase 1 docs complete (6 files incl. PROGRESS).
- 2026-11-12 — `packages/core` done: env, DTOs, ApiContract + Dio client
  (single-flight JWT refresh), AuthRepository, token/prefs storage, WS client,
  DEV-ONLY MockApiAdapter (Bengaluru catalog + fare mock). 12 tests.
- 2026-11-12 — `packages/design_system` done: full token set, 20+ components,
  bundled Inter + Noto Sans Kannada (no runtime font fetch), ZMapView abstraction,
  Bengaluru line-art SVGs. 11 tests.
- 2026-11-12 — `zuum_customer` Milestones A+B done: splash → onboarding → auth →
  4-tab shell, GoRouter auth redirects, Riverpod auth controller, ENV:MOCK banner.
  5 e2e widget tests. analyze clean on all three packages.
  Notes: Riverpod 3 `Override` is not publicly nameable (inline list literals);
  widget tests must load bundled fonts (Ahem breaks text metrics).
- 2026-11-12 — Milestone C done: booking core end-to-end against mock API
  (search → quotes → breakdown → payment → confirm → searching → cancel),
  goods mode switch, schedule picker, Activity feed with real bookings.
  Core: createBooking (contract + Dio + mock), PlaceSearchService (Mapbox
  Geocoding + curated Bengaluru mock), ZFormat.shortDateTime/dayDateTime.
  Tests: 15 core + 11 design system + 7 app = 33, all green, analyze clean.
  Gotchas: fare quote provider must `select()` only route fields (else every
  selection refetches and shifts layout mid-tap); test viewport needs scrolling
  past the fixed bottom bar before tapping list rows.
- 2026-11-13 — Milestones D+E+F complete: RealtimeService + mock dispatch
  simulator (compressed demo timeline, events mirrored into stored bookings),
  tracking screen with live flutter_map/OSM map, payment (cash/UPI/wallet +
  tips) via mock PaymentGateway, rating, receipt, goods details + POD
  (receiver prefill, delivery OTP, camera photo), wallet top-up + ledger,
  offers, notifications, support tickets, safety (real helplines + SOS),
  settings/profile/addresses CRUD, Nominatim place search, launcher icon,
  app name "Zuum". 50 tests green (28+11+11), analyze clean. APK:
  builds/zuum-customer-mock.apk (kotlin.incremental=false needed on Windows).
  Lessons: widget tests must ensureVisible/drag before tapping below-fold
  controls; POD receiver prefills from booking; trip OTP is ride-only.
- 2026-11-14 — Gemini UI spec implemented end-to-end; 60 tests green; APK
  rebuilt (58.4MB) and reinstalled on device.
  Incident: tracking_screen.dart had ONE stray `}` (line 87) that closed the
  State class early, orphaning every method → 40+ cascading analyzer errors
  (undefined ref/context/setState, missing build, duplicate _launch). Removed
  the brace and all errors vanished. Also: POD signature rasterization
  (RenderRepaintBoundary.toImage) is unavailable under flutter_test — made it
  non-fatal so delivery confirmation never blocks on optional evidence.

## Log — 2026-11-14 (Phase 2 backend)
- Django 5 + DRF + Channels backend: auth/JWT, catalog+pricing, dispatch offers, full trip state machine (ride + goods POD), wallet/mock payments/commission/payouts, promos/referrals, support/SOS/notifications/reviews, fleet console, websocket topics. 32 tests green; `seed_demo` creates customer/partner/fleet personas; OpenAPI schema 0 errors.
