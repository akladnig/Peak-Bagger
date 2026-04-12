## Overview

GPX track import/render rewrite for macOS map flow.
Thin slice first; deterministic import semantics + recovery/reset UX next.

**Spec**: `ai_specs/005-gpx-tracks-spec.md` (read this file for full requirements)

## Context

- **Structure**: Layer-first: `lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `lib/router.dart`
- **State management**: Riverpod `NotifierProvider`; keep track ownership in `MapNotifier`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/router.dart`, `lib/screens/settings_screen.dart`, `lib/models/peak.dart`
- **Assumptions/Gaps**: Release build must drop App Sandbox; debug already aligns. Gap: persisted multi-row logical-match winner still unspecified in spec; assume highest `gpxTrackId` unless clarified before execution.

## Plan

### Phase 1: Vertical Slice

- **Goal**: one Tasmanian GPX imports, persists, renders, toggles
- [x] `pubspec.yaml` - add `crypto`; keep existing `xml`/ObjectBox stack
- [x] `lib/models/gpx_track.dart` - retrofit schema; add `contentHash`, `trackDate`, `endDateTime`, nullable markers, segmented decode API
- [x] `lib/services/gpx_track_repository.dart` - content-hash lookup; metadata-date logical lookup; baseline add/get/deleteAll
- [x] `lib/services/gpx_importer.dart` - parse GPX metadata, filename fallback, Tasmania classify, fixed pre-move scan snapshot, minimal `TrackImportResult`
- [x] `lib/providers/map_provider.dart` - add track state/import state/toggle path; empty-db auto-import; startup load behavior
- [x] `lib/router.dart` - wire import/show FABs, tooltip/semantics, progress/disable states, stable keys
- [x] `lib/screens/map_screen.dart` - render segmented polylines; info popup track row; `t` shortcut obeying FAB rules
- [x] `lib/objectbox-model.json` - regenerate schema
- [x] `lib/objectbox.g.dart` - regenerate bindings
- [x] `test/gpx_track_test.dart` - unit/domain slices for entity, repository, one-file import happy path
- [x] TDD: one Tasmanian GPX with metadata imports, persists, auto-shows on first load, toggles off/on, and survives analyze/test
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add key-first selectors for import/show/info controls
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - Robot journey: import happy path -> tracks visible -> toggle hides/shows
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Deterministic Import Semantics

- **Goal**: duplicate/replacement/counting correctness
- [x] `lib/services/gpx_importer.dart` - identical-content grouping, canonical name/date, non-Tasmanian counting, unchanged collision/manual-review rules, import log writes
- [x] `lib/services/gpx_track_repository.dart` - metadata-date-only replacement; same-operation conflict handling; persisted logical-match winner rule per clarified assumption
- [x] `lib/providers/map_provider.dart` - surface result summary + warning state from importer
- [x] `test/gpx_track_test.dart` - extend importer/repository slices for duplicate groups, no-date rules, manual-review warnings, mixed counters
- [x] TDD: identical-content duplicates collapse deterministically; non-Tasmanian files affect only `nonTasmanianCount`; no-date changed tracks do not replace; same-operation logical-match conflict losers stay at source path and count as `errorSkippedCount`
- [x] `test/widget/gpx_tracks_summary_test.dart` - widget coverage for mixed-result summary text
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Recovery And Reset UX

- **Goal**: legacy detection, banner/snackbar, reset recovery path
- [x] `lib/providers/map_provider.dart` - recovery detection from persisted rows; one-shot snackbar gate; reset clears recovery; track visibility lock during recovery
- [x] `lib/router.dart` - route-shell snackbar + persistent banner, Settings navigation action, recovery selectors
- [x] `lib/screens/settings_screen.dart` - `Reset Track Data` tile, confirmation dialog, dedicated Tracks status/warning area, busy/disable states
- [x] `lib/screens/map_screen.dart` - recovery-mode info popup swap; hide track rendering while recovery active
- [x] TDD: persisted invalid rows trigger recovery; reset rebuild clears recovery; import/show controls restore; `showTracks` resets to false after reset
- [x] `test/robot/gpx_tracks/recovery_robot.dart` - selectors for banner, snackbar action, reset tile/dialog, status area
- [x] `test/robot/gpx_tracks/recovery_journey_test.dart` - Robot journey: recovery snackbar/banner -> Settings -> Reset Track Data -> back to map -> controls restored
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Platform And Hardening

- **Goal**: release build path + failure/rollback coverage
- [ ] `macos/Runner/Release.entitlements` - remove App Sandbox for unsandboxed direct-distribution release path
- [ ] `macos/Runner/DebugProfile.entitlements` - verify unchanged unsandboxed debug assumptions
- [ ] `lib/services/gpx_importer.dart` - finalize overwrite rollback, fatal folder access handling, startup-vs-manual log warning split
- [ ] `test/gpx_track_test.dart` - add rollback, overwrite verification, recurring manual-review duplicate, startup/manual log-write slices
- [ ] `test/widget/gpx_tracks_shell_test.dart` - shell coverage for no-GPX snackbar precedence, persistent banner, mixed warnings
- [ ] TDD: overwrite rollback restores files; startup log-write failure stays silent; manual log-write failure warns; release-path prerequisite documented by tests/checks where practical
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: release distribution model change; ObjectBox schema regeneration + legacy recovery semantics; deterministic file-system behavior under duplicate/collision cases
- **Out of scope**: sandboxed/App-Store-style macOS distribution; stable source-file provenance/history; file renaming/manual GPX metadata reconciliation
