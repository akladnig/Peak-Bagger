## Overview

Add GPX time stats from filtered XML, with raw fallback when needed.
Thin slice: model/calculator -> import/recalc wiring -> admin/regression.

**Spec**: `ai_specs/005-add-gpx-stats-3-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`models/`, `services/`, `providers/`, `screens/`, `test/`)
- **State management**: Riverpod `MapNotifier` + providers
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/services/gpx_importer.dart`, `test/gpx_track_test.dart`, `test/widget/gpx_tracks_shell_test.dart`, `test/robot/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: staleness tracking out of scope; filter-setting dependent stats; partial timestamp gaps skip missing points only; raw+filtered unusable => skip row + warn

## Plan

### Phase 1: Core time stats

- **Goal**: seconds-based UTC time math; schema fields
- [x] `lib/models/gpx_track.dart` - add `movingTime`, `restingTime`, `pausedTime`; keep `totalTimeMillis`; map round-trip fields
- [x] `lib/services/gpx_track_statistics_calculator.dart` - extend stats result; compute UTC timestamps, whole-second intervals, segment-local rest clusters, segment-gap `pausedTime`
- [x] `lib/objectbox-model.json` - regenerate schema for new fields
- [x] `lib/objectbox.g.dart` - regenerate ObjectBox bindings
- [x] `test/gpx_track_test.dart` - TDD: calculator happy path, partial missing timestamps, UTC round-trip, model round-trip for new fields
- [x] TDD: one failing slice at a time, start with `totalTimeMillis`/pause math, then partial-gap handling, then model serialization
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`

### Phase 2: Import + recalc wiring

- **Goal**: persist time stats from filtered XML, raw fallback on failure
- [x] `lib/services/gpx_importer.dart` - apply time stats to imported/replaced tracks; raw fallback when filtered XML missing/invalid; skip row if raw also unusable
- [x] `lib/providers/map_provider.dart` - copy time fields during manual recalc; preserve peak correlation, `showTracks`, status/warning flow
- [x] `test/services/gpx_importer_filter_test.dart` - TDD: filtered import path, raw fallback, invalid-filter skip/warn, partial-gap handling
- [x] `test/widget/gpx_tracks_shell_test.dart` - keep Settings dialog/loading assertions; cover warning/status copy if fallback text changes
- [x] `test/robot/gpx_tracks_journey_test.dart` - keep existing import/reset/recalc journeys green; reuse existing keys (`import-tracks-fab`, `reset-track-data-tile`, `recalculate-track-statistics-tile`)
- [x] TDD: import path first, then recalc path, then warning path
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Admin + regression finish

- **Goal**: expose new fields in ObjectBox admin; lock regressions
- [x] `lib/services/objectbox_admin_repository.dart` - add new time fields to admin rows/descriptors
- [x] `test/services/objectbox_admin_repository_test.dart` - assert new fields visible in schema inspection and row output
- [x] `test/widget/objectbox_admin_browser_test.dart` - verify admin browser shows new fields when schema changes
- [x] TDD: admin exposure first, then browser assertion, then any copy updates
- [x] Verify: `flutter analyze && flutter test`

## Risks / Out of scope

- **Risks**: timestamp/time math drift if UTC conversion or second rounding differs between import and recalc; filter-setting changes can alter derived stats; raw+filtered unusable rows skipped with warning
- **Out of scope**: staleness markers/versioning for derived stats; new user-facing screens or selectors; changing existing peak-correlation behavior
