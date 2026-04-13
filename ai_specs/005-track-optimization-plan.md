## Overview

Track storage/render optimization: raw GPX XML + zoom caches.
Thin slice first; startup migration marker + recovery split next.

**Spec**: `ai_specs/005-track-optimization-spec.md` (read this file for full requirements)

## Context

- **Structure**: Layer-first: `lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `lib/router.dart`
- **State management**: Riverpod `NotifierProvider`; keep track startup/import/reset ownership in `MapNotifier`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/services/gpx_importer.dart`, `lib/screens/map_screen.dart`, `test/gpx_track_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: Use `SharedPreferences` for the one-time migration marker; keep existing GPX import semantics from `005-gpx-tracks-spec.md`; prefer codebase convention (`MapNotifier`) over introducing a new controller layer

## Plan

### Phase 1: Vertical Slice

- **Goal**: optimized row imports, persists, renders at active zoom
- [x] `lib/services/track_display_cache_builder.dart` - add pure Web Mercator + RDP cache builder; zooms `6..18`; deterministic JSON-ready output
- [x] `lib/models/gpx_track.dart` - replace persisted `trackPoints` with `gpxFile` + `displayTrackPointsByZoom`; add zoom decode/validation helpers
- [x] `lib/services/gpx_importer.dart` - persist raw GPX XML unchanged; build caches during import/reset; keep current hash/classification/counting semantics
- [x] `lib/screens/map_screen.dart` - render rounded/clamped zoom cache; drop legacy raw-point rendering path
- [x] `lib/objectbox-model.json` - regenerate schema
- [x] `lib/objectbox.g.dart` - regenerate bindings
- [x] `test/gpx_track_test.dart` - extend entity/import slices for cache decode, raw XML persistence, endpoint preservation, zoom clamp
- [x] TDD: dense segmented GPX -> caches `6..18`; raw XML stored byte-faithful; active zoom renders cached geometry, not legacy full points
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - keep key-first selectors stable for import/show flows after storage change
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - Robot journey: tracks visible -> toggle hides/shows with deterministic notifier seam
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Startup Migration

- **Goal**: one-time legacy wipe; later corruption stays recovery-only
- [x] `lib/services/track_migration_marker_store.dart` - add small `SharedPreferences` seam plus pure startup decision helper
- [x] `lib/providers/map_provider.dart` - first-start marker check; non-empty box wipe; empty-box mark; later invalid optimized rows -> existing recovery path
- [x] `lib/services/gpx_track_repository.dart` - no new helper needed after moving startup decision into pure service + model validation
- [x] `test/gpx_track_test.dart` - add startup validation/service slices where pure logic fits
- [x] `test/widget/gpx_tracks_recovery_test.dart` - retain recovery UI coverage while startup migration logic stays in pure service tests
- [x] TDD: first post-ship startup with legacy rows wipes, marks, rebuilds; first startup with empty box marks only; later corrupt optimized rows trigger recovery, not wipe
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Recovery And Reset UX

- **Goal**: reset/retry flows stable after storage swap
- [x] `lib/screens/settings_screen.dart` - add/retain stable keys for Reset Track Data tile + confirm actions; keep destructive rebuild UX intact
- [x] `lib/router.dart` - no copy change needed; existing startup/manual surfaces still fit the legacy-vs-corrupt split
- [x] `lib/providers/map_provider.dart` - ensure reset rebuild clears recovery only on successful rebuild path and preserves snackbar/banner contract
- [x] `test/robot/gpx_tracks/recovery_robot.dart` - add selectors for reset tile, dialog actions, recovery affordances if missing
- [x] `test/robot/gpx_tracks/recovery_journey_test.dart` - Robot journey: recovery state -> Settings -> Reset Track Data -> rebuild -> return to map
- [x] TDD: reset rebuild clears recovery; no-files-after-wipe stays empty without fake recovery; startup/manual error surfaces remain deterministic
- [x] Robot journey tests + selectors/seams for critical flows
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: ObjectBox schema regen + generated binding drift; startup wipe/marker ordering bugs; visual fidelity/perf tradeoff on very large GPX files
- **Out of scope**: GPX export; changing existing route/non-Tasmanian/duplicate semantics except storage internals; preserving pre-optimization persisted rows
