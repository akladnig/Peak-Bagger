## Overview

Delegate 2d/3d distance formatting to `formatDistance`.
Keep the combined pair output; restore `m/km` behavior for all callers.

**Spec**: `ad hoc bug fix request`

## Context

- **Structure**: layer-first Flutter app; shared formatters in `lib/core/`
- **State management**: Riverpod elsewhere; no state change here
- **Reference implementations**: `lib/core/number_formatters.dart`, `test/widget/map_track_info_formatting_test.dart`, `test/services/latest_walk_summary_test.dart`
- **Assumptions/Gaps**: keep `formatDistance2d3d` API; update outputs/tests only, not callers

## Plan

### Phase 1: Delegate pair formatter

- **Goal**: `2d/3d` labels inherit `m/km` rules from `formatDistance`
- [x] `lib/core/number_formatters.dart` - change `formatDistance2d3d` to compose two `formatDistance(...)` calls; keep separator + `decimalPlaces`
- [x] `test/widget/map_track_info_formatting_test.dart` - TDD: mixed sub-km and km pairs render `850 m / 900 m` and `12.4 km / 12.7 km`
- [x] `test/services/latest_walk_summary_test.dart` - TDD: latest-walk summary still formats combined distance through shared helper
- [x] `test/widget/latest_walk_card_test.dart` - TDD: latest-walk card combined metadata line keeps distance text in sync
- [x] `test/widget/map_track_info_panel_test.dart` - TDD: track panel shows updated combined distance text for zero-3d path
- [x] `test/widget/map_route_info_panel_test.dart` - TDD: route panel shows updated combined distance text
- [x] `test/widget/map_screen_track_info_test.dart` - TDD: shared track panel screen still renders combined distance row
- [x] `test/widget/map_screen_route_info_test.dart` - TDD: shared route panel screen still renders combined distance row
- [x] `test/widget/map_screen_route_sheet_test.dart` - TDD: route draft text updates for mixed-unit and zero-3d cases
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_track_info_formatting_test.dart test/services/latest_walk_summary_test.dart test/widget/map_track_info_panel_test.dart test/widget/map_route_info_panel_test.dart test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_info_test.dart test/widget/map_screen_route_sheet_test.dart`

## Risks / Out of scope

- **Risks**: exact-string assertions will churn; zero-distance now shows `0 m` instead of `0.0 km`
- **Out of scope**: changing `formatDistance` semantics; renaming `formatDistance2d3d`; any track/route data model changes
