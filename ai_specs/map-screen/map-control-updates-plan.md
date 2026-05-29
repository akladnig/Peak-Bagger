## Overview

Desktop trackpad map-gesture update. Thin vertical-zoom slice first; prefer `MapScreen` seam, add pure helper only if `flutter_map` config is insufficient.

**Spec**: `ai_specs/map-control-updates-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `widgets/`
- **State management**: Riverpod `NotifierProvider`; `MapScreen` drives `mapProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `test/widget/gpx_tracks_recovery_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: disable rotate via `flutter_map` config if possible; keep gesture ownership in `MapScreen`; extract pure classifier only for deterministic tests or if config path fails

## Plan

### Phase 1: Vertical Zoom Slice

- **Goal**: prove trackpad vertical gesture -> zoom; center stable; state sync intact
- [x] `test/widget/map_screen_trackpad_gesture_test.dart` - add focused happy-path trackpad coverage; assert zoom changes, center stable, `mapProvider` sync updates
- [x] `lib/screens/map_screen.dart` - evaluate `InteractionOptions`; disable rotate; add minimal trackpad-only gesture interception or config for vertical zoom
- [x] `lib/services/map_trackpad_gesture_classifier.dart` - add only if needed; pure vertical-vs-horizontal translation seam
- [x] `lib/providers/map_provider.dart` - keep `updatePosition` contract; touch only if stable center/zoom sync needs a narrow seam
- [x] TDD: `PointerDeviceKind.trackpad` vertical gesture changes zoom without moving center, then implement
- [x] TDD: trackpad pinch zoom still changes zoom after the new path lands, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Edge Cases And Regressions

- **Goal**: finish gesture policy; remove old trackpad-pan assumptions; lock journey coverage
- [x] `test/widget/map_screen_trackpad_gesture_test.dart` - add horizontal no-op, diagonal vertical-dominant, clamp, cancel, fail-safe ambiguity coverage
- [x] `test/widget/gpx_tracks_recovery_test.dart` - replace `trackpad pan moves the map camera` with new expected behavior
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - rename or replace `panMap()` with helper matching new trackpad semantics; keep key-first selector use
- [x] `test/robot/gpx_tracks/selection_journey_test.dart` - update journey to use the new helper; assert selection survives the trackpad gesture
- [x] TDD: horizontal trackpad motion leaves center and zoom unchanged, then implement
- [x] TDD: diagonal motion uses vertical component; cancelled or ambiguous gesture fails safe; zoom clamps at bounds, then implement
- [x] Robot journey tests + selectors/seams for critical flows: `Key('map-interaction-region')`; deterministic `PointerDeviceKind.trackpad` gesture helper; no extra network/time seams
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `flutter_map` may not expose trackpad-only hooks; simulated trackpad gestures may differ from macOS runtime; old helper semantics may leak into adjacent robot tests
- **Out of scope**: mobile touch support; tile/overlay/rendering refactors; persisted map-state schema changes
