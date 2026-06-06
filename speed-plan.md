## Overview
Add track speed summary end-to-end: GPX stats/import/recalc -> `GpxTrack` -> track info panel.
Keep route UI unchanged; reuse the existing Riverpod + ObjectBox pipeline.

**Spec**: `./speed-spec.md` (read this file for full requirements)

## Context
- **Structure**: layer-first
- **State management**: Riverpod
- **Reference implementations**: `./lib/services/gpx_track_statistics_calculator.dart`, `./lib/services/gpx_importer.dart`, `./lib/providers/map_provider.dart`, `./lib/screens/map_screen_panels.dart`, `./test/widget/map_screen_track_info_test.dart`
- **Assumptions/Gaps**: legacy tracks stay at `0.0` until `Recalculate Track Statistics`; null formatter path only for calculator edge tests

## Plan

### Phase 1: Speed pipeline + panel slice

- **Goal**: stats, persistence, panel, core tests
- [x] `./lib/core/number_formatters.dart` - add `formatSpeedKmh(...)`
- [x] `./lib/services/gpx_track_statistics_calculator.dart` - add avg/moving/max km/h on 2D parsed trackpoint stream; 30s/1m/3m/5m helper
- [x] `./lib/models/gpx_track.dart` - add `averageSpeedKmh`, `movingSpeedKmh`, `maxSpeedKmh`; map round-trip
- [x] `./lib/services/gpx_importer.dart` - populate speed fields on import
- [x] `./lib/providers/map_provider.dart` - refresh speed fields in `recalculateTrackStatistics()`
- [x] `./lib/screens/map_screen_panels.dart` - add Speed section under Time; keep route panel unchanged
- [x] `./test/core/number_formatters_test.dart` - formatter/null/defaults
- [x] `./test/services/gpx_track_statistics_calculator_test.dart` - avg/moving/max window behavior, short track, repeated timestamps, segment gaps, zero duration
- [x] `./test/gpx_track_test.dart` - model round-trip for new fields
- [x] `./test/widget/map_screen_track_info_test.dart` - Speed section order/values/defaults
- [x] `./test/widget/map_screen_route_info_test.dart` - route panel omits Speed
- [x] TDD: formatter -> avg/moving -> max-window -> panel rows -> route regression
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: ObjectBox + journey coverage

- **Goal**: admin visibility + critical journey
- [x] `./lib/objectbox-model.json` - regenerate for new `GpxTrack` fields
- [x] `./lib/objectbox.g.dart` - regenerate bindings
- [x] `./lib/services/objectbox_admin_repository.dart` - expose speed fields in `gpxTrackToAdminRow()`
- [x] `./test/services/objectbox_admin_repository_test.dart` - row/schema expectations for speed fields
- [x] `./test/widget/objectbox_admin_browser_test.dart` - browser list/detail shows speed fields
- [x] `./test/robot/gpx_tracks/single_track_import_journey_test.dart` - open track, assert panel + Speed section
- [x] TDD: admin row values -> browser assertions -> robot journey selectors
- [x] Robot selectors: `track-info-panel`, optional speed row keys if added
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: max-speed window semantics; stale `0.0` on legacy tracks until recalc; ObjectBox regen churn
- **Out of scope**: route panel changes; raw GPX payload changes; new dependencies; separate backfill migration
