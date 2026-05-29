## Overview

Peak Lists mini-map peak popup reuse.
Shared popup resolver, shared peak hit-testing, local mini-map overlay popup.

**Spec**: `ai_specs/peak-list-mini-map-peak-info.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`screens/`, `services/`, `widgets/`, `tests/`)
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/providers/map_provider.dart`, `lib/services/peak_hover_detector.dart`, `lib/screens/peak_lists_screen.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/services/peak_hover_detector_test.dart`
- **Assumptions/Gaps**: popup state stays local to Peak Lists; main-map popup refresh path must also use the shared resolver; mini-map uses map-level hit test, not marker callbacks

## Plan

### Phase 1: Shared popup content

- **Goal**: one source of truth for peak popup content
- [ ] `lib/services/peak_info_content_resolver.dart` - new resolver for `PeakInfoContent` from `Peak`, `PeakListRepository`, `TasmapRepository`
- [ ] `lib/providers/map_provider.dart` - delegate `openPeakInfoPopup()` and `_refreshedPeakInfo(...)` to resolver
- [ ] `test/services/peak_info_content_resolver_test.dart` - `TDD:` name/map/list fallback, alt-name trim, `Height: —`, `Map: Unknown`, empty list names
- [ ] `test/widget/map_screen_peak_info_test.dart` - keep main-map popup behavior green after resolver refactor
- [ ] Verify: `flutter analyze` && `flutter test test/services/peak_info_content_resolver_test.dart test/widget/map_screen_peak_info_test.dart`

### Phase 2: Shared hit-test flow

- **Goal**: reuse main-map peak hit-test logic for mini-map taps
- [ ] `lib/services/peak_hover_detector.dart` - expose shared candidate-builder inputs used by both screens; keep `PeakHoverDetector.findHoveredPeak(...)` as the decision point
- [ ] `lib/screens/map_screen.dart` - switch to shared helper; preserve current pointer-up popup behavior
- [ ] `lib/screens/peak_lists_screen.dart` - use shared hit test for mini-map marker taps; sync selected row/highlight
- [ ] `test/services/peak_hover_detector_test.dart` - `TDD:` same threshold/tie behavior with shared candidate builder inputs
- [ ] Verify: `flutter analyze` && `flutter test test/services/peak_hover_detector_test.dart`

### Phase 3: Mini-map popup overlay + journeys

- **Goal**: mini-map popup, close, row sync, no stale state
- [ ] `lib/screens/peak_lists_screen.dart` - local popup state, `Stack` overlay, outside-tap close, row/highlight sync, render popup card in mini-map host
- [ ] `test/widget/peak_lists_screen_test.dart` - `TDD:` marker tap opens popup, row selected, fallback text, close button, stale popup on list change
- [ ] `test/robot/peaks/peak_lists_mini_map_peak_info_journey_test.dart` - critical journey: open Peak Lists, tap marker, verify popup, close popup
- [ ] `test/robot/peaks/peak_lists_mini_map_robot.dart` - stable keys/seams for mini-map popup host, close action, selected row, markers
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: mini-map popup placement on small screens; hit-test accuracy vs `FlutterMap` layout; stale popup after list switch
- **Out of scope**: main-map UX changes beyond resolver wiring; peak search/detail-table behavior; global popup state
