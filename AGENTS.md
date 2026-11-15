# Zuum — agent instructions

## Product
Mobility + logistics platform for Bengaluru: customer app, partner (driver/fleet)
app, Django API, admin web later. Monorepo: `apps/`, `packages/`, `backend/`.

## Current focus
Visual production pass on both Flutter apps. Visual work only — do not change
backend, live-client, release/signing, or deployment unless asked.

## Visual constitution (authoritative)
- **Uber-like monochrome.** Black / white / greys only for brand and UI.
  No lime or bright accent colors. Photography stays neutral duotone.
- Semantic colors only where meaning requires it: `success` green, `error` red,
  `warning` amber. Never decorative color.
- Tokens live only in `packages/design_system/lib/src/tokens/`. No hex values in
  feature code. If a needed token is missing, add it to the token files.
- Components: extend `packages/design_system`; do not create competing one-off
  variants when a DS component exists.
- Typography: Inter + Noto Sans Kannada, bundled. No new fonts.
- Layout: 4/8pt spacing, radii 8/12/16/20/28, consistent elevation/border
  matrix, generous whitespace, strong section hierarchy.
- Photography: bundled assets from `packages/design_system/assets/photos`
  (Wikimedia Commons, credits in `docs/PHOTO_CREDITS.md`). Always use a scrim
  for text on photos; never place text on raw images.
- Motion: 150/250/400 ms, purposeful, interruptible, reduced-motion honored.
  No infinite decorative animations on screens used with `pumpAndSettle`.
  Haptics on high-intent actions.
- Accessibility: AA contrast, 48dp touch targets, semantics labels, text scale
  1.3 and 2.0, reduce-motion support, no color-only meaning.
- Responsive: phone-first; check 360×800, 412×915, tablet/landscape.

## Skills
Installed under `.agents/skills` (registered in `opencode.json`).
Use `flutter-design`, `flutter-audit`, `flutter-design-system`,
`flutter-implementation`, `flutter-motion`, `flutter-accessibility`,
`flutter-visual-qa`, `flutter-responsive-layout`.
They are advisory; the visual constitution, existing design system, and repo
conventions win on conflict. Restart opencode after config/skill changes.

## Dev commands
```bash
cd packages/design_system && flutter analyze && flutter test
cd packages/core && flutter analyze && flutter test
cd apps/zuum_customer && flutter analyze && flutter test
cd apps/zuum_partner && flutter analyze && flutter test
cd backend && .venv\Scripts\python.exe manage.py test apps.api.tests
```
Widget tests must not `pumpAndSettle` on screens with maps, live dots or
skeletons; use bounded `pump()` loops. Builds use `ENV=mock` for visual QA.

## Known constraints
- Physical device screenshots depend on the phone being connected; Android
  emulators (Pixel 8 / Medium Phone) are available as fallback.
- Mock build for visual QA: `--dart-define=ENV=mock`.
- Do not commit secrets (`keys/`, `key.properties`, `.env`).
