## Overview
Add route timing persistence, route-time helpers, import/export wiring, and route info UI updates.
Use existing Riverpod/ObjectBox patterns; keep timing logic centralized.

**Spec**: `ai_specs/routes/route-timing-spec.md`

## Context

- **Structure**: feature-first, `lib/services`, `lib/providers`, `lib/screens`, `test/*`
- **State management**: Riverpod + ObjectBox
- **Reference implementations**: `./lib/services/gpx_track_statistics_calculator.dart`, `./lib/services/gpx_export_service.dart`, `./lib/providers/map_provider.dart`, `./lib/services/route_admin_editor.dart`, `./lib/screens/map_screen_panels.dart`
- **Assumptions/Gaps**: timing profile is current route timeline only; full recompute on edit; `hh:mm:ss` display at UI/export boundary

## Plan

### Phase 1: Model + timing core

- **Goal**: persist route timing fields; add shared route-time helpers
- [x] `./lib/models/route.dart` - add `estimatedTime` + `routeTimingProfileJson`
- [x] `./lib/core/constants.dart` - add Naismith constants in metres/seconds units
- [x] `./lib/services/route_timing_service.dart` - add `scarfDistance`, `scarfTime`, `naismithTime`
- [x] `./lib/objectbox-model.json` / `./lib/objectbox.g.dart` - regenerate schema
- [x] `./lib/services/objectbox_admin_repository.dart` - expose new route field
- [x] TDD: route helper math; route JSON round-trip; schema/admin row includes timing field
- [x] Verify: `flutter test test/services/route_timing_service_test.dart test/services/route_repository_test.dart test/services/objectbox_schema_guard_test.dart test/services/objectbox_admin_repository_test.dart && flutter analyze`

### Phase 2: Import/export/edit wiring

- **Goal**: compute timing on import; recompute on edit; synthesize export `<time>` tags
- [x] `./lib/services/gpx_importer.dart` - derive timing from GPX timestamps or Naismith
- [x] `./lib/providers/map_provider.dart` - save imported route timing; recompute on route draft save
- [x] `./lib/services/route_admin_editor.dart` - carry timing through admin rebuild, full recompute on edit
- [x] `./lib/services/gpx_export_service.dart` - write deterministic point `<time>` tags from timing profile
- [x] TDD: timestamped import path; untimed import path; edit recompute path; export timing path; null timing fallback
- [x] Verify: `flutter test test/services/gpx_importer_filter_test.dart test/providers/map_provider_import_test.dart test/services/gpx_export_service_test.dart test/services/route_admin_editor_test.dart && flutter analyze`

### Phase 3: UI + journeys

- **Goal**: show estimated time and revised labels in route/track panels; cover critical journeys
- [x] `./lib/screens/map_screen_panels.dart` - route `Estimated Time` row, route Time section, `Ascent`/`Descent` labels, dash fallback
- [x] `./test/widget/map_route_info_panel_test.dart` - panel copy, null-state, label assertions
- [x] `./test/widget/map_screen_route_info_test.dart` - route panel render/update/legacy safety
- [x] `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - import-as-route journey coverage
- [x] `./test/robot/map/route_info_journey_test.dart` - open/edit/close route panel coverage
- [x] TDD: panel text and layout; missing estimate dash; robot journey selectors for route time content
- [x] Verify: `flutter test test/widget/map_route_info_panel_test.dart test/widget/map_screen_route_info_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart test/robot/map/route_info_journey_test.dart && flutter analyze`

## Risks / Out of scope

- **Risks**: timing profile serialization shape; export-time synthesis drift; legacy routes with null timing
- **Out of scope**: route planning algorithm changes, map interaction changes, top-level GPX format changes
