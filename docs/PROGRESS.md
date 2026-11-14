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

## Phase 4 — Partner App ⬜
- [ ] Onboarding/KYC, vehicles, availability, offers, trip flow, earnings, fleet console

## Phase 5 — Admin Dashboard (Flutter Web) ⬜
- [ ] Live ops map, bookings, drivers, customers, finance, analytics, config, audit

## Phase 6 — Integration ⬜
- [ ] Swap mock→live APIs, WS end-to-end, payments/commission settlement, RBAC matrix

## Phase 7 — Testing & Deployment ⬜
- [ ] Test suites, security pass, Render deploy, CI, store readiness

## Open items
- [ ] Mapbox access token (mobile + web) — env-injected at Milestone C
- [ ] Razorpay account keys — Phase 6
- [ ] Partner + admin brand visual specs (design tokens already shared)
- [ ] App store assets / privacy policy (Phase 7)
- [ ] Backend Phase 2 (Django) — contract frozen in `03_api_contract.md`

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
