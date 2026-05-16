## Overview

Extract shared summary-card foundations from Elevation, then add Distance as a thin metric adapter.

**Spec**: `ai_specs/distance-card-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/screens`, `lib/widgets`, `lib/services`, `lib/providers`, `lib/models`
- **State management**: Riverpod; dashboard reads `mapProvider`, layout via `dashboardLayoutProvider`
- **Reference implementations**: `lib/widgets/dashboard/elevation_card.dart`, `lib/widgets/dashboard/elevation_chart.dart`, `lib/services/elevation_summary_service.dart`
- **Assumptions/Gaps**: shared control keys intentionally duplicated; tests scope them via card root; Peaks Bagged reuse only, not implemented here

## Plan

### Phase 1: Shared Foundations

- **Goal**: preserve Elevation; extract reusable primitives
- [x] `lib/core/number_formatters.dart` - move `formatDistance` here; keep `formatElevationMetres`; update exports/imports
- [x] `lib/screens/map_screen_panels.dart` - remove local `formatDistance`; consume shared helper
- [x] `lib/services/latest_walk_summary.dart` - replace screen-helper import with shared formatter path; reduce service-to-screen coupling
- [x] `lib/services/summary_card_service.dart` - extract neutral `Summary*` types + numeric-only timeline math from elevation service
- [x] `lib/widgets/dashboard/summary_card.dart` - extract shared shell: loading/empty/populated, controls, scroll callbacks, visible-summary callback, shared control keys
- [x] `lib/widgets/dashboard/summary_chart.dart` - extract shared chart primitives: hover, tooltip placement, column/line behavior, scroll surface
- [x] `lib/widgets/dashboard/elevation_card.dart` - convert to Elevation adapter over shared shell/chart/service; preserve metric-local keys
- [x] `lib/services/elevation_summary_service.dart` - delete, shrink to adapter wrapper, or rename during migration; avoid parallel generic/elevation logic long-term
- [x] `lib/screens/dashboard_screen.dart` - migrate header summary wiring to neutral shared summary types without changing current Elevation behavior
- [x] TDD: shared `formatDistance` keeps `840 m` / `12.4 km`; latest-walk + map-panel output unchanged; then extract helper
- [x] TDD: neutral `Summary*` math matches current Elevation bucket/window/average behavior; then extract service/types
- [x] TDD: Elevation still reports header summary, preserves tooltip/bucket behavior, preserves scoped selectors after shell/chart extraction; then refactor adapter
- [x] Robot journey tests + selectors/seams for critical flows: scope shared control keys within `dashboard-card-elevation`; keep deterministic `now`/provider seams
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Distance Vertical Slice

- **Goal**: real Distance card; end-to-end dashboard integration
- [x] `lib/widgets/dashboard/distance_card.dart` - add thin metric adapter: `distance2d`, distance empty copy, `distance-*` local keys, shared summary callback
- [x] `lib/screens/dashboard_screen.dart` - render `DistanceCard` in `distance` slot; add Distance header summary behavior matching Elevation
- [x] `lib/providers/dashboard_layout_provider.dart` - no logic change expected; confirm existing `distance` id/ordering contract still fits
- [x] `test/services/summary_card_service_test.dart` - add distance adapter coverage for filtering, buckets, totals, zero totals
- [x] `test/widget/distance_card_test.dart` - add loading/empty/populated, shared controls, header-summary behavior, tooltip/bucket selectors, compact layout
- [x] `test/widget/dashboard_screen_test.dart` - add scoped shared-key interactions for Distance card + header summary assertions
- [x] TDD: Distance loading/empty/populated states mirror Elevation behavior; then implement adapter wiring
- [x] TDD: Distance buckets sum `distance2d`, header summary uses `formatDistance`, active-window updates match Elevation timing; then implement dashboard integration
- [x] TDD: shared control keys work only via card-scoped descendant lookups; Distance keeps `{keyPrefix}-bucket-*` / `{keyPrefix}-tooltip`; then finalize selectors
- [x] Robot journey tests + selectors/seams for critical flows: add Distance card presence + scoped control access under `dashboard-card-distance`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Regression Hardening

- **Goal**: lock refactor safety; prep Peaks Bagged reuse
- [ ] `test/widget/elevation_card_test.dart` - refresh/assert preserved Elevation control keys, tooltip, header-summary behavior under shared shell
- [ ] `test/services/elevation_summary_service_test.dart` - migrate or replace with neutral-summary coverage if generic service fully subsumes old file
- [ ] `test/robot/dashboard/elevation_journey_test.dart` - update to scoped shared-key lookup; keep Elevation metric-local assertions
- [ ] `test/robot/dashboard/dashboard_journey_test.dart` - harden shared-control selector helpers for multiple summary cards on one board
- [ ] `lib/widgets/dashboard/summary_card.dart` - final cleanup for reusable adapter seams needed by future Peaks Bagged card; no Peaks Bagged feature work yet
- [ ] TDD: Elevation and Distance can coexist with duplicated shared control keys on one dashboard without selector ambiguity; then finalize robot/widget helpers
- [ ] TDD: generic summary layers expose only neutral `Summary*` types; then remove leftover shared `Elevation*` type leakage
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: shared-key duplication causing flaky tests; generic type migration touching many Elevation tests; shell/chart extraction may sprawl if not kept vertical-slice small
- **Out of scope**: implementing Peaks Bagged card; changing dashboard layout behavior; changing distance display rules away from current `m/km`
