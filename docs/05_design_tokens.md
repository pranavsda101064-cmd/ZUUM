# Zuum Design Tokens

Source of truth for all three apps (`packages/design_system`).
**Palette v2 — "Obsidian Monochrome & Lime Volt"** (bold, tech-forward, minimalist).
Light-first. One action color (Obsidian) per screen; Volt Lime is reserved for
live/rating/surge/PIN signals and value moments — never decoration.

## Color tokens

| Token | Hex | Role |
|---|---|---|
| `primary` | `#111827` | Obsidian Black — primary CTAs, active mode pill, route line, links |
| `primaryPressed` | `#1F2937` | pressed primary |
| `onPrimary` | `#FFFFFF` | text/icons on primary (16.9:1) |
| `dark` | `#090D16` | Carbon Ink — headings, dark surfaces, splash, tracking signboard |
| `accent` | `#F3F4F6` | Light Neutral — selected card fill (with 2dp `#111827` border) |
| `background` | `#F9FAFB` | Off-White canvas |
| `highlight` | `#84CC16` | Volt Lime — ratings, surge, PIN, radar pulse, live markers |
| `surface` | `#FFFFFF` | cards, sheets, inputs |

### Semantic / functional

| Token | Hex | Notes |
|---|---|---|
| `error` | `#B91C1C` | validation, destructive |
| `success` | `#15803D` | completed, verified, paid |
| `textPrimary` | `#090D16` | = dark |
| `textSecondary` | `#4B5563` | 7.0:1 on canvas |
| `textTertiary` | `#6B7280` | 4.8:1 (WCAG AA for small text) |
| `divider` | `#E5E7EB` | hairlines |
| `scrim` | `#090D16` @ 40% | modals |
| `disabled` | `#D1D5DB` | disabled fills |
| `skeleton` | `#F3F4F6` | skeleton base |
| `onDark` | `#FFFFFF` | text on dark |
| `onDarkSecondary` | `#9CA3AF` | meta on dark |
| `darkRaised` | `#1F2937` | chips/rows inside dark cards |
| `darkSurface` / `darkOutline` | `#111827` / `#374151` | dark-scheme scaffolding |
| `shadow` / `shadowSoft` / `shadowStrong` | `#090D16` @ 8/4/20% | elevation |

Tints: `primaryTint #F3F4F6` · `highlightTint #F3FBE4` · `errorTint #FEE9E7`
· `successTint #E8F5EC`.

**Rule:** no hex literals exist outside `colors.dart` — verified by audit.

## Typography — Inter (+ Noto Sans Kannada for brand moments)

| Style | Size/Height/Weight | Tracking | Use |
|---|---|---|---|
| `display` | 28/34/700 | −0.5 | Splash, hero |
| `titleLg` | 22/28/700 | −0.3 | Screen titles |
| `titleMd` | 17/24/600 | −0.1 | Section headers |
| `body` / `bodyStrong` | 15/22/400·600 | 0 | Body |
| `caption` | 13/18/400 | +0.1 | Secondary text |
| `overline` | 11/16/600 | +0.4 | Labels (uppercase) |
| `numeric` | 15/22/600 tabular | — | Fares, ETAs, plates, PINs |

Kannada companion (Noto Sans Kannada, 13sp) renders in **Carbon Ink** —
the cultural accents stay quiet; lime is reserved for live signals.

## Spacing / Radius / Motion
`space: 4, 8, 12, 16, 20, 24, 32, 40, 48, 64` · radius `8 / 12 / 16 / 24 / pill`
· motion `fast 150 · base 250 · slow 400`, curve `cubic(0.2, 0, 0, 1)`.
Elevation: `0 1px 2px shadow, 0 4px 12px shadowSoft` (no gradients, no glass).

## Components
`ZButton` (primary=obsidian / secondary=light-neutral / ghost / danger),
`ZTextField`, `ZCard`, `ZChip` (selected = ink fill), `ZBadge`,
`ZStatusBadge`, `ZSheet`, `ZSkeleton` (lime-free shimmer),
`ZEmptyState`, `ZErrorState`, `ZAppBar`, `ZDivider`, `ZAvatar`,
`ZFareBreakdown`, `ZDriverCard`, `ZRatingStars` (lime stars),
`ZIconButton`, `ZToggle`, `ZListTile`, `ZStepper`,
`ZSegmentedSwitch`, `ZOdometerText`, `ZPlateBadge`, `ZPinPill` (lime,
ink text), `ZTicketCard`, `ZCouponCard`, `ZRouteTimeline`,
`ZRadarPulse` (lime rings), `ZQuickVehicleCard`, `ZMapView` (CartoDB
Positron tiles, obsidian route, lime driver marker).

## Illustrations
18 monoline SVGs remapped to the palette: stroke `#090D16`, fill
`#F3F4F6`, single `#84CC16` focal detail, white bodies. No teal/marigold
remains anywhere in the system.

## Per-app emphasis
- **Customer** — off-white canvas, obsidian CTAs, lime live signals only.
- **Partner** — carbon ink header, lime online dot/earnings.
- **Admin** — carbon shell, dense rows, lime live-data accents.
