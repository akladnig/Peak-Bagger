## Overview
Add elevation summary/profile fields to GPX tracks; wire the same XML-derived stats through import, reset, and manual recalc.

**Spec**: `ai_specs/005-add-gpx-stats-2-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `test/`)
- **State management**: Riverpod `MapNotifier`
- **Reference implementations**: `lib/services/gpx_track_statistics_calculator.dart`, `lib/services/gpx_importer.dart`, `lib/providers/map_provider.dart`, `lib/screens/settings_screen.dart`, `test/harness/test_map_notifier.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`, `test/widget/objectbox_admin_browser_test.dart`
- **Assumptions/Gaps**: none blocking; spec now pins endpoint rule + gap-preserving profile shape

## Plan

### Phase 1: Stats shape + schema

- **Goal**: pure elevation math + persisted model
- [x] `lib/services/gpx_track_statistics_calculator.dart` - add `ascent`/`descent`/`startElevation`/`endElevation`/`elevationProfile`; preserve gaps; normalize `<ele> < -100` to `0`
- [x] `lib/models/gpx_track.dart` - add fields, `fromMap()`/`toMap()` round-trip, defaults
- [x] `lib/objectbox-model.json` / `lib/objectbox.g.dart` - regenerate schema
- [x] `test/gpx_track_test.dart` - TDD: first/last `> -100` endpoint rule; gap-preserving profile; no-elevation + single-point defaults; `-100m` normalization; map round-trip
- [x] Verify: `flutter analyze && flutter test test/gpx_track_test.dart`

### Phase 2: Import/recalc wiring

- **Goal**: one stats path from stored XML through persistence
- [x] `lib/services/gpx_importer.dart` - populate new elevation fields from calculator
- [x] `lib/providers/map_provider.dart` - write new fields in import/reset/manual recalc; keep `showTracks`; keep warning/status flow
- [x] `test/widget/gpx_tracks_shell_test.dart` - recalc dialog/loading regression
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - Settings recalc journey stays green; reuse existing keys (`recalculate-track-statistics-tile`, `reset-track-data-confirm`)
- [x] TDD: importer writes new fields from stored XML; recalc updates in place from `gpxFile`; malformed XML skips row and continues
- [x] Verify: `flutter analyze && flutter test test/gpx_track_test.dart test/widget/gpx_tracks_shell_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

### Phase 3: Admin exposure + coverage

- **Goal**: surface new fields in ObjectBox admin and lock regressions
- [ ] `lib/services/objectbox_admin_repository.dart` - add new `GpxTrack` fields to row values
- [ ] `test/services/objectbox_admin_repository_test.dart` - assert new schema fields visible
- [ ] `test/widget/objectbox_admin_browser_test.dart` - assert detail pane renders new fields; keep export/details flows intact
- [ ] TDD: admin field list includes new fields; browser detail values render; export behavior unchanged
- [ ] Verify: `flutter analyze && flutter test test/services/objectbox_admin_repository_test.dart test/widget/objectbox_admin_browser_test.dart`

## Risks / Out of scope

- **Risks**: stale ObjectBox regeneration; profile JSON shape drift; keeping gap markers/time-null handling consistent across import + recalc
- **Out of scope**: elevation chart UI; route-vs-track logic; map rendering changes
