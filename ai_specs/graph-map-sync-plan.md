## Overview
Chart hover -> transient map dot for selected route/track.
Small Riverpod seam + resolver + layered marker; keep route-draft chart excluded.

**Spec**: `ai_specs/graph-map-sync-spec.md` (read this file for full requirements)

## Context
- **Structure**: layer-first
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/screens/map_screen_layers.dart`, `test/robot/map/map_route_robot.dart`
- **Assumptions/Gaps**: dedicated transient hover provider preferred; track source precedence `gpxFileRepaired` > `gpxFile`; robot hover journey only if chart hover is deterministic with stable keys

## Plan

### Phase 1: Chart seam

- **Goal**: stable chart hover payload; route slice first
- [ ] `lib/services/elevation_profile_series_builder.dart` - carry track identity fields in samples
- [ ] `lib/services/gpx_track_statistics_calculator.dart` - keep `segmentIndex` / `pointIndex` in profile JSON
- [ ] `lib/widgets/elevation_profile_chart.dart` - hover enter/move/exit; emit sample index; clear on exit
- [ ] `lib/screens/map_screen_panels.dart` - wire route/track panels to chart hover callback; exclude route-draft sheet
- [ ] `test/services/elevation_profile_series_builder_test.dart` - TDD: track sample identity preserved from profile JSON
- [ ] `test/widget/elevation_profile_chart_test.dart` - TDD: hover emits stable sample; empty series no hover; axis toggle keeps identity
- [ ] `test/widget/map_route_info_panel_test.dart` - TDD: route panel receives hover updates
- [ ] `test/widget/map_track_info_panel_test.dart` - TDD: track panel receives hover updates
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Transient dot

- **Goal**: provider-owned transient hover state; raw-geometry dot on map
- [ ] `lib/providers/map_chart_hover_provider.dart` - new transient hover state; clear on exit / stale target / selection change
- [ ] `lib/services/map_chart_hover_resolver.dart` - new resolver; route index -> `route.gpxRoute`; track identity -> raw GPX source
- [ ] `lib/services/gpx_track_geometry.dart` - reuse parser; expose any small helper needed for point lookup
- [ ] `lib/screens/map_screen.dart` - read hover provider; clear on panel close; keep existing map hover behavior untouched
- [ ] `lib/screens/map_screen_layers.dart` - add hover marker layer above route/track polylines; stable marker key
- [ ] `test/services/map_chart_hover_resolver_test.dart` - TDD: route point lookup, track raw-source precedence, stale target ignore
- [ ] `test/widget/map_screen_chart_hover_test.dart` - TDD: dot appears, moves, clears; repaired XML wins over raw
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey proof

- **Goal**: critical flow proof; harden selectors and regressions
- [ ] `test/robot/map/map_route_robot.dart` - add hover helper only if pointer-over-chart is deterministic with stable keys
- [ ] `test/robot/map/map_chart_hover_journey_test.dart` - critical route/track hover journey; fallback to widget-only if harness flakes
- [ ] `test/widget/map_screen_route_hover_test.dart` - regression guard; chart hover must not disturb existing map hover logic
- [ ] `Key('elevation-profile-chart')`, `Key('map-chart-hover-marker')` - stable selectors for chart + dot
- [ ] TDD: one robot journey or explicit widget-only fallback; clear on panel close / selection change / pointer exit
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: wrong track XML source or stale sample mapping; robot hover flakiness; marker/source mismatch if raw geometry lookup diverges from profile identity
- **Out of scope**: route-draft chart hover sync; zoom-simplified dot remap; persistence / camera state changes; broader chart crosshair features
