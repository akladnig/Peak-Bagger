## Overview

Expose combined 2D/3D distance on latest walk, saved track/route panels, route draft.
Reuse current formatter path; add tiny shared presentation seam; extend focused widget/robot coverage.

**Spec**: `ai_specs/tracks/distance3d-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first Flutter app; UI in `lib/screens/` + `lib/widgets/`; pure formatting in `lib/core/` and small services in `lib/services/`
- **State management**: Riverpod (`flutter_riverpod` in `pubspec.yaml`; route draft state in `lib/providers/map_provider.dart`)
- **Reference implementations**: `lib/services/latest_walk_summary.dart`, `lib/screens/map_screen_panels.dart`, `lib/widgets/map_route_bottom_sheet.dart`
- **Assumptions/Gaps**: reuse `Key('route-distance-text')`; no new latest-walk key unless tests prove necessary

## Plan

### Phase 1: Latest Walk Vertical Slice

- **Goal**: combined distance seam; dashboard metadata line
- [x] `lib/core/number_formatters.dart` - add tiny combined-distance formatter, or equivalent pure seam, for `2d/3d` display; keep `formatDistance` unchanged
- [x] `lib/services/latest_walk_summary.dart` - switch `distanceText` to combined `2d/3d` output from track `distance2d` + `distance3d`
- [x] `lib/widgets/dashboard/latest_walk_card.dart` - replace 3-column metadata row with left-aligned dot-separated `date • distance • ascent` line; keep paging + minimap unchanged
- [x] `test/services/latest_walk_summary_test.dart` - add mixed-unit and equal-value cases for combined distance
- [x] `test/widget/latest_walk_card_test.dart` - assert combined distance text and retained ascent on metadata line
- [x] TDD: combined latest-walk distance formats `12.4/12.7 km` and `850 m/0.9 km` before widget edits
- [x] TDD: latest-walk card renders `date • 2d/3d distance • ascent` without regressing empty state or paging
- [x] Verify: `flutter analyze` && `flutter test test/services/latest_walk_summary_test.dart test/widget/latest_walk_card_test.dart`

### Phase 2: Saved Panel Summaries

- **Goal**: saved track/route summary swap; no layout churn
- [ ] `lib/screens/map_screen_panels.dart` - replace saved track `Distance` metric with `Distance (2d/3d)` combined value; keep `Ascent` + `Total Time`
- [ ] `lib/screens/map_screen_panels.dart` - replace saved route `Distance` metric with `Distance (2d/3d)` combined value; keep `Ascent` + `Descent`
- [ ] `test/widget/map_track_info_panel_test.dart` - add summary assertion for combined track distance label/value
- [ ] `test/widget/map_route_info_panel_test.dart` - add summary assertion for combined route distance label/value
- [ ] TDD: saved track panel shows combined metric with zero-3d path still visible
- [ ] TDD: saved route panel shows combined metric without breaking existing summary layout
- [ ] Verify: `flutter analyze` && `flutter test test/widget/map_track_info_panel_test.dart test/widget/map_route_info_panel_test.dart`

### Phase 3: Route Draft Summary + Journey

- **Goal**: route-draft success-state combined distance; loading/error intact
- [ ] `lib/widgets/map_route_bottom_sheet.dart` - in success branch, replace bare 2D distance text with combined `Distance (2d/3d)` value; preserve existing loading/error priority and reuse `route-distance-text` if practical
- [ ] `test/widget/map_screen_route_sheet_test.dart` - assert combined distance in success state; assert loading/error branches still suppress combined output
- [ ] `test/robot/map/map_route_robot.dart` - keep selector seam stable around `route-distance-text`; add helper/assertion only if needed for combined text readability
- [ ] `test/robot/map/map_route_journey_test.dart` - extend happy-path route draft journey to assert combined distance after elevation sampling succeeds
- [ ] TDD: route draft success state shows combined 2D/3D distance only when `routeDraftElevationSummary` exists
- [ ] TDD: route draft loading/error states keep current message priority and omit combined distance
- [ ] Robot journey tests + selectors/seams for critical flows: route draft happy path through existing `route-distance-text`; deterministic existing route-elevation fake queue
- [ ] Verify: `flutter analyze` && `flutter test test/widget/map_screen_route_sheet_test.dart test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope

- **Risks**: combined text width in saved panels; route-draft success branch shares selector with current bare value; latest-walk text assertions may need a key if truncation makes them brittle
- **Out of scope**: distance3d calculation/persistence/import changes; broader dashboard redesign; generic map-panel spacing refactor
