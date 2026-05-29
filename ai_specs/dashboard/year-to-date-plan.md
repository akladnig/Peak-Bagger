## Overview

Add a year-summary dashboard card driven from `mapProvider.tracks`.
Build the yearly aggregation first, then the card UI and dashboard wiring, then robot coverage.

**Spec**: `ai_specs/year-to-date-spec.md`

## Context

- **Structure**: feature-first Flutter dashboard widgets + pure service layer
- **State management**: Riverpod + `mapProvider` / `dashboardLayoutProvider`
- **Reference implementations**: `./lib/widgets/dashboard/distance_card.dart`, `./lib/widgets/dashboard/peaks_bagged_card.dart`, `./lib/widgets/dashboard/summary_card.dart`, `./lib/screens/dashboard_screen.dart`, `./lib/providers/dashboard_layout_provider.dart`
- **Assumptions/Gaps**: selected year stays local to the card; tile wrapper keyed at dashboard boundary; `ascent == null` counts as zero; no persisted year state

## Plan

### Phase 1: Year math

- **Goal**: pure yearly totals, counts, and peak chronology
- [x] `./lib/services/year_to_date_summary_service.dart` - yearly aggregation from tracks; local year boundaries; distance, ascent, walk count, peaks climbed, new peaks climbed
- [x] `./lib/services/peaks_bagged_summary_service.dart` - reuse or extract peak chronology rule if needed to avoid a second definition of first-occurrence ordering
- [x] `./test/services/year_to_date_summary_service_test.dart` - TDD: current year default, prev/next year shift, null `trackDate`, null `ascent` as zero, duplicate peak ids, deterministic first-occurrence peaks
- [x] Verify: `flutter test test/services/year_to_date_summary_service_test.dart && flutter analyze`

### Phase 2: Card + dashboard

- **Goal**: card UI, stable keys, dashboard slot, default order
- [x] `./lib/widgets/dashboard/year_to_date_card.dart` - body title `My Walks in YYYY`, prev/next controls, metric rows, responsive single-line layout, loading/zero states
- [x] `./lib/screens/dashboard_screen.dart` - render `year-to-date` card; key tile boundary so state survives reorder; pass `now` seam and tracks through
- [x] `./lib/providers/dashboard_layout_provider.dart` - register `year-to-date` id/title; update default order and sanitization expectations
- [x] `./test/widget/year_to_date_card_test.dart` - TDD: current-year render, prev/next update, loading, zero-year, compact-width layout, stable selectors
- [x] `./test/widget/dashboard_screen_test.dart` - add dashboard-slot and reorder regressions for the new card
- [x] `./test/providers/dashboard_layout_provider_test.dart` - update default/sanitized/persisted order expectations
- [x] Verify: `flutter test test/widget/year_to_date_card_test.dart test/widget/dashboard_screen_test.dart test/providers/dashboard_layout_provider_test.dart && flutter analyze`

### Phase 3: Journey coverage

- **Goal**: stable robot selectors and end-to-end dashboard behavior
- [x] `./test/robot/dashboard/dashboard_robot.dart` - add year-to-date card helpers/selectors scoped by card root
- [x] `./test/robot/dashboard/dashboard_journey_test.dart` - TDD: open dashboard, locate year card, move years backward/forward, verify metric updates, confirm reorder does not break selection
- [x] `./test/robot/dashboard/dashboard_journey_test.dart` - keep selectors key-first; avoid text-only selection for card controls
- [x] Verify: `flutter test test/robot/dashboard/dashboard_journey_test.dart && flutter analyze`

## Risks / Out of scope

- **Risks**: state reuse across dashboard reorder; peak chronology mismatch if first-occurrence logic diverges; dense 4:3 layout overflow on smaller widths
- **Out of scope**: persisting the selected year; chart/map navigation; GPX import or ObjectBox schema changes
