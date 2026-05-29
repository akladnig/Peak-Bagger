## Overview
Content-sized peak popup; close on Drop Marker; same behavior on main map + shared mini-map.

**Spec**: `ai_specs/peak-info-popup-spec.md` (full requirements)

## Context

- **Structure**: feature-first screens/services/providers; popup UI in screens, shared data in services, journey tests in `test/robot/...`
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/screens/map_screen.dart`, `lib/screens/peak_lists_screen.dart`, `test/widget/peak_lists_screen_test.dart`, `test/robot/peaks/peak_info_journey_test.dart`, `test/harness/test_map_notifier.dart`
- **Assumptions/Gaps**: keep `UiConstants.peakInfoPopupSize` as deterministic placement hint; both main map and shared mini-map are in scope

## Plan

### Phase 1: Main popup slice

- **Goal**: shrink-wrap popup body; close on Drop Marker from main map
- [x] `lib/screens/map_screen_panels.dart` - replace fixed-height peak popup shell with content-sized card + bounded scroll body; preserve existing rows/labels/order
- [x] `lib/screens/map_screen.dart` - make main-map Drop Marker update selection then close popup
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: height row still uses `formatElevationMetres(...)`; Drop Marker closes popup; close icon unchanged; no fixed blank reserve
- [x] `test/widget/peak_info_popup_placement_test.dart` - keep placement assertions green against the size-hint strategy; adjust only if needed
- [x] `test/robot/peaks/peak_info_journey_test.dart` - TDD: replace stay-open assertion with close-after-drop journey
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Shared mini-map parity

- **Goal**: same popup behavior on peak-lists mini-map
- [x] `lib/screens/peak_lists_screen.dart` - make mini-map Drop Marker update selection then clear popup
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: mini-map popup closes on Drop Marker; selected-location marker appears; shared popup behavior matches main map
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: content-sized popup may expose edge-placement assumptions; stale journey test still expects popup to remain open; mini-map callback path must match main-map close semantics
- **Out of scope**: peak data model changes, selector renames, camera/recenter behavior, new dependencies
