## Overview

Map MGRS readout polish. Keep `MapState.currentMgrs` format unchanged; change the map-screen presentation and center-based name lookup only.

**Spec**: chat request

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `widgets/`
- **State management**: Riverpod `NotifierProvider`; `MapScreen` already owns the live readout
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/services/tasmap_repository.dart`, `test/widget/map_screen_persistence_test.dart`, `test/robot/map/map_camera_journey_test.dart`
- **Assumptions/Gaps**: map name should follow current camera center (live drag state if present); fallback `Unknown` if no map hit; `currentMgrs` internal newline format stays as-is

## Plan

### Phase 1: Single-Line Readout

- **Goal**: one-line MGRS + tabular figures
- [x] `lib/screens/map_screen_panels.dart` - add `mapName` prop to `MapMgrsReadout`; render map name above MGRS; flatten MGRS to one line; insert space between `55G` and the 100k id; apply `const TextStyle(fontFeatures: [FontFeature.tabularFigures()])`
- [x] `lib/screens/map_screen.dart` / `lib/providers/map_provider.dart` - pass current map name and current display MGRS into the readout; expose repo-backed map-name lookup on the notifier
- [x] `test/widget/map_screen_persistence_test.dart` - update the live-readout assertion to expect the new single-line text shape
- [x] TDD: `map-mgrs-readout` shows map name above `55G FN 00000 00000` and uses tabular figures, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Center-Based Name Lookup

- **Goal**: map name tracks the camera center
- [x] `lib/screens/map_screen.dart` / `lib/providers/map_provider.dart` - derive map name from the live camera center / current center, not the cursor or goto readout
- [x] `test/widget/map_screen_persistence_test.dart` - assert map name changes with center, while cursor/goto MGRS only changes the line below
- [x] `test/robot/map/map_camera_journey_test.dart` - keep key-first coverage on `Key('map-mgrs-readout')`; add a plain-text assertion for the new stacked readout
- [x] TDD: center lookup resolves the visible map name independently from the displayed cursor/goto MGRS, then implement
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: no map match at some centers; top-left readout may get taller on small screens; font support for tabular figures may vary
- **Out of scope**: changing stored MGRS state format; altering MGRS parsing/search behavior; other popup MGRS formatting
