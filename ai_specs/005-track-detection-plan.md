## Overview

Track hover detection on the map: nearest visible segment, screen-space threshold, hover state + cursor.
Thin slice first: pure detector + map wiring; then harden clearing paths and journey tests.

**Spec**: `ai_specs/005-track-detection-spec.md` (read this file for full requirements)

## Context

- **Structure**: Layer-first: `lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `test/widget`, `test/robot`
- **State management**: Riverpod `NotifierProvider`; keep hover runtime state in `MapState`/`MapNotifier`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `test/harness/test_map_notifier.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: Follow current map render order for tie-breaks; use provider state for hover ownership, not widget-local state; codebase convention wins over adding a new controller layer

## Plan

### Phase 1: Detector Slice

- **Goal**: pure hit-test + minimal state path
- [x] `lib/services/track_hover_detector.dart` - add pure screen-space nearest-segment detector; threshold `8.0`; ignore one-point segments
- [x] `lib/providers/map_provider.dart` - add `hoveredTrackId`; add set/clear methods; keep selection/popup untouched
- [x] `test/gpx_track_test.dart` - add pure detector + hover-state slices if this remains the main track-focused unit file
- [x] TDD: outside-threshold -> no match; inside-threshold -> hovered track id; one-point ignored; nearest visible segment wins deterministically
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Map Wiring

- **Goal**: hover events drive cursor + state
- [x] `lib/screens/map_screen.dart` - share existing `onPointerHover` with MGRS updates; project active zoom geometry to screen space; update hover state; add stable map-region key
- [x] `lib/models/gpx_track.dart` - no extra helper needed; existing `getSegmentsForZoom()` already fits hover projection safely
- [x] `test/widget/gpx_tracks_recovery_test.dart` - extend widget coverage for visible hover, pointer exit, drag suppression, hidden tracks, recovery mode, and camera-change clearing
- [x] `test/harness/test_map_notifier.dart` - extend deterministic seam for hovered-track state and camera-change clearing
- [x] TDD: hover sets `hoveredTrackId` without changing `selectedLocation`; pointer exit clears; drag suppresses hover; hidden tracks/recovery disable hover; camera change clears stale hover
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey Hardening

- **Goal**: stable desktop hover journey coverage
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add key-first helpers for map interaction region hover assertions
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - robot journey: visible track -> hover enters -> state/cursor lane asserts -> move away -> hover clears
- [x] `lib/screens/map_screen.dart` - no extra seam beyond `map-interaction-region` key needed for deterministic pointer tests
- [x] TDD: happy-path visible-track hover journey stays stable with deterministic notifier seam; no filesystem import dependency in robot setup
- [x] Robot journey tests + selectors/seams for critical flows
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `flutter_map` projection/camera access in widget tests; desktop cursor assertions may need state-first assertions; hover clearing on camera updates can regress if derived from stale widget state
- **Out of scope**: hover highlight/tooltip/popup; touch interactions; persistence or analytics for hovered tracks
