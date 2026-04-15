## Overview
Add GPX stats fields + shared recalculation flow.
Pure stats helper, importer/reset wiring, Settings action, journey coverage.

**Spec**: `ai_specs/005-add-gpx-stats-1-spec.md`

## Context
- **Structure**: layer-first (`lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `test/`)
- **State management**: Riverpod `MapNotifier`
- **Reference implementations**:
  - `lib/providers/map_provider.dart`
  - `lib/screens/settings_screen.dart`
  - `lib/services/gpx_importer.dart`
  - `lib/services/gpx_track_repository.dart`
  - `test/harness/test_map_notifier.dart`
  - `test/gpx_track_test.dart`
  - `test/widget/gpx_tracks_summary_test.dart`
  - `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: none; spec pins defaults, result contract, and success copy.

## Plan

### Phase 1: Stats engine + schema

- **Goal**: XML -> deterministic stats -> persisted fields
- [x] `lib/services/gpx_track_statistics_calculator.dart` - pure stats helper from stored GPX XML
- [x] `lib/models/gpx_track.dart` - add stats fields, map/JSON round-trip updates
- [x] `lib/objectbox-model.json` - regenerate schema
- [x] `lib/objectbox.g.dart` - regenerate bindings
- [x] `test/gpx_track_test.dart` - cover stats happy path, first-peak tie, zero defaults, malformed XML
- [x] TDD: one failing slice at a time for calculator math, edge cases, model serialization
- [x] Verify: `flutter analyze && flutter test test/gpx_track_test.dart`

### Phase 2: Import + recalc wiring

- **Goal**: shared calculator across import/reset and batch recalc
- [ ] `lib/services/gpx_importer.dart` - call calculator when building `GpxTrack`
- [ ] `lib/services/gpx_track_repository.dart` - minimal update/query support for batch recalc
- [ ] `lib/providers/map_provider.dart` - add recalc entry point, `TrackStatisticsRecalcResult`, reload `tracks`, preserve `showTracks`
- [ ] TDD: import/reset persists stats; recalc skips malformed rows and continues; result counts + warning; state reload after success
- [ ] Verify: `flutter analyze && flutter test test/gpx_track_test.dart test/widget/gpx_tracks_summary_test.dart`

### Phase 3: Settings UI + journeys

- **Goal**: expose recalc action with reset-style modal shell
- [ ] `lib/screens/settings_screen.dart` - add `Recalculate Track Statistics` tile, loading/disabled state, result dialog copy
- [ ] `test/widget/gpx_tracks_summary_test.dart` - verify summary surface for recalc counts/warnings
- [ ] `test/widget/gpx_tracks_shell_test.dart` - verify tile behavior, dialog copy, spinner/disable state
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - critical journey: open Settings -> recalc -> success/warning
- [ ] TDD: dialog title/body, warning rendering, disabled tap while busy
- [ ] Robot selectors/seams: `Key('recalculate-track-statistics-tile')`, recalc dialog close key, fake notifier/recalc result seam
- [ ] Verify: `flutter analyze && flutter test test/widget/gpx_tracks_summary_test.dart test/widget/gpx_tracks_shell_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

## Risks / Out of scope
- **Risks**: stale ObjectBox generation; stats math edge cases around peak ties and segment gaps; dialog/state reuse can regress `showTracks`
- **Out of scope**: new stats beyond the four fields in spec; map rendering changes; filesystem reorganization beyond existing import/reset behavior
