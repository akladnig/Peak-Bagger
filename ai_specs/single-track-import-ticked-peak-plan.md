## Overview

Single-track import should tick correlated peaks on `MapScreen` immediately.
Align import path with existing recalc behavior; add regression coverage.

**Spec**: bug report only; quick plan, no separate spec file.

## Context

- **Structure**: layered by type (`providers/`, `services/`, `screens/`, `widgets/`, `test/`)
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen_layers.dart`, `test/widget/tasmap_map_screen_test.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: `importGpxFiles` is the single-track import path; import dialog keys already exist; no open product gaps

## Plan

### Phase 1: Import refresh

- **Goal**: imported correlated peak visible without Settings recalc
 - [x] `test/providers/map_provider_import_test.dart` - TDD: single-track import with a matched peak refreshes `correlatedPeakIds` before map rebuild
 - [x] `lib/providers/map_provider.dart` - in `importGpxFiles`, call `_refreshCorrelatedPeakIds(allTracks)` before `state = ...`
 - [x] `test/widget/tasmap_map_screen_test.dart` - TDD: peak layer renders `peak_marker_ticked.svg` when notifier exposes refreshed correlated ids after import
 - [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Import journey

- **Goal**: user import flow proves ticked marker, no Settings detour
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add import-dialog helpers; key-first selectors for `import-tracks-fab`, `gpx-track-select-files`, `gpx-track-name-field-0`, `gpx-track-import-button`, `peak-marker-layer`
- [ ] `test/robot/gpx_tracks/single_track_import_journey_test.dart` - TDD: import one correlated GPX track and assert the green/ticked peak marker is present on the map
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: async import timing; temp GPX fixture setup; marker rebuild order if correlation refresh lands after state publish
- **Out of scope**: Settings UI copy; bulk-import behavior; peak refresh logic
