## Overview

Add a top-right close button to the Drop Marker chooser, matching the Peak Info popup affordance.
Keep chooser actions unchanged; only add a dismiss path and any small sizing tweak needed.

**Spec**: `task description` (quick plan; no spec file)

## Context

- **Structure**: feature-first Flutter app; map UI in `lib/screens`; shared popup cards in `lib/screens/map_screen_panels.dart`
- **State management**: Riverpod `Notifier` / provider; chooser visibility driven from `mapProvider`
- **Reference implementations**: `lib/screens/map_screen_panels.dart` (`PeakInfoPopupCard`, `MapTapActionPopupCard`), `lib/screens/map_screen.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/map_screen_waypoint_test.dart`, `test/robot/map/drop_marker_journey_test.dart`
- **Assumptions/Gaps**: chooser height clamp likely needs a small bump after adding the header row; no existing stable close selector on the chooser

## Plan

### Phase 1: Match peak-info dismiss affordance

- **Goal**: top-right close button on drop-marker chooser; dismiss only
- [x] `lib/screens/map_screen_panels.dart` - add `onClose` to `MapTapActionPopupCard`; keep only the close icon at the top right; keep action tiles unchanged
 - [x] `lib/screens/map_screen.dart` - pass a `mapProvider` dismiss callback into the chooser; bump chooser placement height/clamp so the added header does not clip near viewport edges
 - [x] `test/widget/map_screen_waypoint_test.dart` - TDD: close button is visible on the chooser and dismisses it without creating/changing a marker
 - [x] `test/robot/map/drop_marker_robot.dart` - add a stable selector/helper for the chooser close button
 - [x] `test/robot/map/drop_marker_journey_test.dart` - TDD: open chooser, close via button, popup disappears; existing drop-marker path still works
 - [ ] Verify: `flutter analyze` && `flutter test test/widget/map_screen_waypoint_test.dart test/robot/map/drop_marker_journey_test.dart` (blocked: repo-wide `flutter test` still fails in pre-existing `test/robot/settings/route_graph_refresh_journey_test.dart` and `test/robot/tasmap/tasmap_journey_test.dart`)

## Risks / Out of scope

- **Risks**: popup height may still need retuning if header spacing changes; chooser can clip at edges if clamp is left unchanged
- **Out of scope**: changing drop-marker semantics, popup copy, or Peak Info layout
