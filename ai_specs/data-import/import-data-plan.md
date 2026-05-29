## Overview
Generic GPX import split: raw track fast path, point-based route pipeline, route persistence, generic dialog.

**Spec**: `ai_specs/import-data-spec.md`

## Context

- **Structure**: hybrid widgets / services / providers
- **State management**: Riverpod
- **Reference implementations**: `lib/widgets/peak_list_import_dialog.dart`, `lib/services/gpx_importer.dart`, `lib/services/gpx_track_filter.dart`, `lib/providers/route_repository_provider.dart`, `lib/services/route_elevation_sampler.dart`, `lib/services/import/gpx_track_import_models.dart`
- **Assumptions/Gaps**: route mode bypasses track selective import/Tasmanian/managed-storage path; `Route.desc` needs ObjectBox schema regen; route import selection stays unchanged unless tests force otherwise

## Plan

### Phase 1: Generic dialog

- **Goal**: route-aware dialog + shared contract
- [x] `lib/widgets/gpx_import_dialog.dart` - rename/migrate dialog, generic keys, `importAsRoute` prop, route-aware label/validation
- [x] `lib/widgets/map_action_rail.dart` - wire generic dialog + route toggle
- [x] `lib/services/import/gpx_track_import_models.dart` - generalize result/item contract for both modes
- [x] `test/widget/gpx_import_dialog_test.dart` - rename/update for generic keys, route copy, switch state, cancel/progress
- [x] `test/widget/map_action_rail_grouping_test.dart` - update import tooltip/copy
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - generic selectors; remove `gpx-track-*` assumptions
- [x] TDD: default track copy -> route copy on toggle; generic keys stable; shared result types compile
- [x] Robot: open dialog, toggle route mode, assert generic dialog surface
- [x] Verify: `flutter analyze` && `flutter test test/widget/gpx_import_dialog_test.dart test/widget/map_action_rail_grouping_test.dart` (focused dialog/provider/schema tests passed; `map_action_rail_grouping_test` now passed; analyze completed)

### Phase 2: Point Pipeline

- **Goal**: point-based generic filter/build path
- [x] `lib/services/gpx_point_sample.dart` - neutral sample model
- [x] `lib/services/gpx_filter.dart` - generic filter over `trkpt`/`rtept`; time optional
- [x] `lib/services/gpx_track_filter.dart` - refactor/shim to generic filter or retire track-only assumptions
- [x] `lib/services/gpx_importer.dart` - raw track fast path; route build from filtered samples
- [x] `test/services/gpx_importer_filter_test.dart` - track raw path, route samples, no-time simplify, route geometry output
- [x] `test/services/gpx_filter_test.dart` - route-only filter coverage without timestamps
- [x] TDD: `trkpt`/`rtept` share one filter path; no-time route still simplifies; unchanged track bypasses filter
- [x] Verify: `flutter analyze` && `flutter test test/services/gpx_importer_filter_test.dart test/services/gpx_filter_test.dart`

### Phase 3: Route Persistence

- **Goal**: dedicated route pipeline + refresh
- [x] `lib/providers/map_provider.dart` - branch route-mode import away from track plan/Tasmanian placement; save `Route`; bump `routeRevisionProvider`
- [x] `lib/models/route.dart` - add `desc` persistence + JSON/schema wiring
- [x] `lib/providers/route_repository_provider.dart` - confirm route list refresh path remains revision-driven
- [x] `lib/services/objectbox_schema_guard.dart` - add `Route.desc` to signature
- [x] `lib/objectbox.g.dart` - regenerate model
- [x] `test/providers/map_provider_import_test.dart` - route import saves `Route`, skips track repo, refreshes route list/revision
- [x] `test/services/objectbox_schema_guard_test.dart` - schema signature includes new Route field
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - critical route-mode journey via `GpxTracksRobot`
- [x] TDD: route pipeline bypasses track-only selective import/Tasmanian/managed storage; route desc persists; route revision refreshes route list; result summary stays generic
- [x] Verify: `flutter analyze` && `flutter test test/providers/map_provider_import_test.dart test/services/objectbox_schema_guard_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart` (focused provider/schema tests passed; route journey test now passed; analyze completed)

## Risks / Out of scope

- **Risks**: ObjectBox regeneration; route-mode branch accidentally hits track-only path; route sample simplification edge cases when timestamps absent
- **Out of scope**: unrelated route draft/export/editor changes; settings UI beyond fixed defaults; visual redesign beyond import dialog copy/keys
