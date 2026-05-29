## Overview
Export selected track/route from the tracks/routes drawer to GPX.
Track uses `gpxFile`; route serializes `gpxRoute` to GPX 1.1 with author/elevation metadata and confirm-before-overwrite.

**Spec**: `ai_specs/tr-export-spec.md`

## Context
- **Structure**: feature-first; `lib/widgets`, `lib/services`, `lib/providers`
- **State management**: Riverpod
- **Reference implementations**: `lib/services/objectbox_admin_repository.dart`, `lib/services/peak_csv_export_service.dart`, `lib/widgets/dialog_helpers.dart`, `lib/widgets/map_tracks_routes_drawer.dart`, `lib/providers/map_provider.dart`, `lib/providers/route_repository_provider.dart`
- **Assumptions/Gaps**: `xml` already in `pubspec.yaml`; unresolved selected entity disables export; route filename stem == GPX `<name>`

## Plan

### Phase 1: Export core
- **Goal**: deterministic plan/write API + GPX route serializer
- [x] `lib/services/gpx_export_service.dart` - plan-then-write export service; path resolution; filename sanitizing; track `gpxFile` payload; route `gpxRoute` -> GPX 1.1; `<author>` metadata; optional `<ele>`; overwrite precheck seam
- [x] `lib/providers/gpx_export_provider.dart` - thin provider wrapper if needed for widget/test injection
- [x] `test/services/gpx_export_service_test.dart` - unit coverage for track plan, route serializer, blank/empty failure, filename normalization, overwrite plan vs write split
- [x] TDD: route GPX shape; blank/empty route failure; track payload selection; filename normalization; overwrite planning without file writes
- [x] Verify: `flutter analyze && flutter test test/services/gpx_export_service_test.dart`

### Phase 2: Drawer integration
- **Goal**: wire export UI to current selection state
- [x] `lib/widgets/map_tracks_routes_drawer.dart` - bottom export control; disable when no resolvable selection; resolve via `mapProvider` ids + `gpxTrackRepositoryProvider` / `routeRepositoryProvider`; overwrite confirm/cancel; snackbar feedback
- [x] `test/widget/map_tracks_routes_drawer_test.dart` - disabled state, track export, route export, unresolved selection disabled, overwrite confirm/cancel, success/failure snackbars
- [x] TDD: one red-green slice per behavior: disabled state, track export, route export, overwrite prompt, cancel path, snackbar path
- [x] Verify: `flutter analyze && flutter test test/widget/map_tracks_routes_drawer_test.dart`

### Phase 3: Journey regressions
- **Goal**: critical export flows end to end
- [x] `test/robot/map/tr_export_robot.dart` - robot helper for drawer export flow; stable selectors: `tracks-routes-drawer`, `tracks-routes-export-button`, `tracks-routes-export-confirm`, `tracks-routes-export-cancel`
- [x] `test/robot/map/tr_export_journey_test.dart` - track + route happy paths; selection -> drawer -> export -> snackbar
- [x] TDD: robot journey one assertion at a time; track and route branches; unresolved-selection no-op
- [x] Verify: `flutter analyze && flutter test test/robot/map/tr_export_journey_test.dart`

## Risks / Out of scope
- **Risks**: GPX escaping/serialization correctness; stale selection drift; overwrite collision handling
- **Out of scope**: bulk export, background jobs, persistent export preferences, map selection changes
