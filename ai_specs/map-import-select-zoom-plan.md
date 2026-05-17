## Overview

Import from map screen should promote the new GPX track into the selected-track focus path.
Reuse current `selectedTrackFocusSerial`; no new camera state.

**Spec**: bug report only; quick plan, no separate spec file.

## Context

- **Structure**: feature-first, `providers/`, `screens/`, `widgets/`, `services/`, `test/`
- **State management**: Riverpod `MapNotifier`
- **Reference implementations**:
  - `lib/providers/map_provider.dart` - import pipeline + selected-track state
  - `lib/screens/map_screen.dart` - selected-track zoom consumer
  - `test/providers/map_provider_import_test.dart` - import pipeline regression
  - `test/robot/gpx_tracks/gpx_tracks_robot.dart` - import-dialog journey harness
- **Assumptions/Gaps**:
  - batch import focus target = first successful add
  - no extra chooser after import

## Plan

### Phase 1: Provider handoff

- **Goal**: imported track survives import as current selection
- [x] `test/providers/map_provider_import_test.dart` - TDD: one imported track sets `selectedTrackId`, keeps `showTracks` true, increments `selectedTrackFocusSerial`; empty/error import leaves selection untouched
- [x] `lib/providers/map_provider.dart` - stop clearing selection on successful import; publish imported track id + focus serial in final state; keep current counts/status/recovery handling intact
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Map-screen journey

- **Goal**: real map import selects + zooms
- [ ] `test/robot/gpx_tracks/single_track_import_journey_test.dart` - import one GPX through the map screen; assert track panel visible and camera centers/zooms to the imported track
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: batch-focus choice may need product call; zoom timing may need extra settle; empty/failed imports must not leave stale selection
- **Out of scope**: chooser for multiple imported tracks; import dialog UX redesign; track geometry/model refactor
