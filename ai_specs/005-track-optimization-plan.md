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
- [ ] `lib/services/track_display_cache_builder.dart` - add pure Web Mercator + RDP cache builder; zooms `6..18`; deterministic JSON-ready output
- [ ] `lib/models/gpx_track.dart` - replace persisted `trackPoints` with `gpxFile` + `displayTrackPointsByZoom`; add zoom decode/validation helpers
- [ ] `lib/services/gpx_importer.dart` - persist raw GPX XML unchanged; build caches during import/reset; keep current hash/classification/counting semantics
- [ ] `lib/screens/map_screen.dart` - render rounded/clamped zoom cache; drop legacy raw-point rendering path
- [ ] `lib/objectbox-model.json` - regenerate schema
- [ ] `lib/objectbox.g.dart` - regenerate bindings
- [ ] `test/gpx_track_test.dart` - extend entity/import slices for cache decode, raw XML persistence, endpoint preservation, zoom clamp
- [ ] TDD: dense segmented GPX -> caches `6..18`; raw XML stored byte-faithful; active zoom renders cached geometry, not legacy full points
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - keep key-first selectors stable for import/show flows after storage change
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - Robot journey: startup import -> tracks visible -> toggle hides/shows
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Startup Migration

- **Goal**: one-time legacy wipe; later corruption stays recovery-only
- [ ] `lib/services/track_migration_marker_store.dart` - add small `SharedPreferences` seam for one-time post-ship marker
- [ ] `lib/providers/map_provider.dart` - first-start marker check; non-empty box wipe; empty-box mark; later invalid optimized rows -> existing recovery path
- [ ] `lib/services/gpx_track_repository.dart` - add minimal startup validation helpers if needed for legacy/corrupt checks
- [ ] `test/gpx_track_test.dart` - add startup validation/service slices where pure logic fits
- [ ] `test/widget/gpx_tracks_recovery_test.dart` - cover legacy wipe vs corrupt-row recovery vs empty-box first start
- [ ] TDD: first post-ship startup with legacy rows wipes, marks, rebuilds; first startup with empty box marks only; later corrupt optimized rows trigger recovery, not wipe
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Recovery And Reset UX

- **Goal**: reset/retry flows stable after storage swap
- [ ] `lib/screens/settings_screen.dart` - add/retain stable keys for Reset Track Data tile + confirm actions; keep destructive rebuild UX intact
- [ ] `lib/router.dart` - adjust only if startup/manual surfaces need copy tweaks for legacy-vs-corrupt distinction
- [ ] `lib/providers/map_provider.dart` - ensure reset rebuild clears recovery and preserves current snackbar/banner contract
- [ ] `test/robot/gpx_tracks/recovery_robot.dart` - add selectors for reset tile, dialog actions, recovery affordances if missing
- [ ] `test/robot/gpx_tracks/recovery_journey_test.dart` - Robot journey: recovery state -> Settings -> Reset Track Data -> rebuild -> return to map
- [ ] TDD: reset rebuild clears recovery; no-files-after-wipe stays empty without fake recovery; startup/manual error surfaces remain deterministic
- [ ] Robot journey tests + selectors/seams for critical flows
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: ObjectBox schema regen + generated binding drift; startup wipe/marker ordering bugs; visual fidelity/perf tradeoff on very large GPX files
- **Out of scope**: GPX export; changing existing route/non-Tasmanian/duplicate semantics except storage internals; preserving pre-optimization persisted rows
