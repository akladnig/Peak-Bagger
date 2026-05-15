## Overview
Elevation dashboard card, derived from current tracks.
fl_chart renderers, rolling windows, total + average, hover, scroll, mode toggle.

**Spec**: `ai_specs/elevation-card-spec.md` (read this file for full requirements)

## Context
- **Structure**: dashboard cards + shared services, feature-first under `lib/widgets/dashboard/` and `lib/services/`
- **State management**: Riverpod (`mapProvider`, `dashboardLayoutProvider`)
- **Reference implementations**: `lib/services/latest_walk_summary.dart`, `lib/widgets/dashboard/latest_walk_card.dart`, `lib/screens/dashboard_screen.dart`, `test/widget/latest_walk_card_test.dart`, `test/robot/dashboard/dashboard_journey_test.dart`
- **Assumptions/Gaps**: flat widget tests under `test/widget/*.dart`; no persisted summary store; average uses all visible buckets incl zero buckets, Dart `round()`; weekly buckets in 3/6-month views repeat month labels per bucket

## Plan

### Phase 1: Summary engine + shell

- **Goal**: thin end-to-end slice; one window, one chart shell, loading/empty states
- [x] `lib/services/elevation_summary_service.dart` - derive buckets from `mapProvider.tracks`; date seams; right-anchored windows; totals; averages; half-window stepping; clamp rules; ignore missing date/ascent
- [x] `test/services/elevation_summary_service_test.dart` - TDD: happy path bucket math -> zero buckets -> missing data exclusion -> `round()` average -> boundary clamp -> period change preserves scroll offset
- [x] `lib/widgets/dashboard/elevation_card.dart` - card shell; title row; period dropdown; prev/next; loading vs empty vs data states; stable keys
- [x] `lib/screens/dashboard_screen.dart` - wire `elevation` card into existing dashboard grid
- [x] `test/widget/elevation_card_test.dart` - TDD: render in dashboard; loading placeholder; empty state; dropdown preserves viewport; title metrics update with scroll/period
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: fl_chart interactions + journeys

- **Goal**: chart renderers; hover; smooth line/bar toggle; robot coverage
- [ ] `pubspec.yaml` - add `fl_chart`
- [ ] `lib/widgets/dashboard/elevation_chart.dart` - bar + smoothed-line renderers; horizontal scroll; hover popup; top-right FAB; bucket keys
- [ ] `lib/widgets/dashboard/elevation_card.dart` - connect chart state, period presets, mode toggle, and arrow transitions
- [ ] `test/widget/elevation_card_test.dart` - TDD: mode toggle; hover popup; weekly labels for 3/6-month views; initial right-edge anchor; no-hover touch fallback
- [ ] `test/robot/dashboard/elevation_journey_test.dart` - critical journey with stable keys/seams: open dashboard -> change period -> scroll -> verify total/avg -> toggle mode -> hover inspect -> arrow clamp
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: fl_chart hover/touch parity; scroll/animation determinism; timezone boundary handling
- **Out of scope**: persisted elevation aggregates; second bucket selector; non-dashboard analytics
