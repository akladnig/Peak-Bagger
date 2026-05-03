## Overview

Peak hover/click popup on map. Central screen-space hit testing; separate peak popup state.

**Spec**: `ai_specs/010-peak-info-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-based: `screens/`, `providers/`, `services/`, `widgets/`, `models/`
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/services/track_hover_detector.dart`, `lib/widgets/peak_list_peak_dialog.dart`
- **Assumptions/Gaps**: none; follow codebase conventions over broader provider cleanup style

## Plan

### Phase 1: Peak Hit Slice

- **Goal**: hover/click peak opens basic anchored popup
- [x] `lib/services/peak_hover_detector.dart` - screen-space peak candidates; threshold; nearest/tie by rendered order
- [x] `lib/providers/map_provider.dart` - `hoveredPeakId`, peak popup state, open/close methods, center-info mutual exclusion
- [x] `lib/screens/map_screen.dart` - central peak hit test before track/map logic; cursor; non-peak hover clear; non-peak click fallback
- [x] `lib/screens/map_screen_layers.dart` - keyed peak markers; keyed hitbox; hover halo overlay; preserve ticked/unticked assets
- [x] `lib/screens/map_screen_panels.dart` - `PeakInfoPopupCard`; initial placement helper seam
- [x] TDD: peak hit nearest/tie/no-hit → implement detector
- [x] TDD: hover peak sets click cursor + halo; moving off clears hover only → implement state/UI
- [x] TDD: click peak opens popup; does not select location/track; closes center popup → implement pointer path
- [x] TDD: non-peak click preserves existing selected-location behavior → guard regression
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Content And Providers

- **Goal**: map name + memberships; shared peak-list providers
- [x] `lib/providers/peak_list_provider.dart` - move peak-list repository/import/bagged providers from screen
- [x] `lib/screens/peak_lists_screen.dart` - import shared providers; remove screen-local definitions
- [x] `lib/main.dart` - update provider overrides/imports
- [x] `test/widget/peak_lists_screen_test.dart` - update provider override imports
- [x] `test/robot/peaks/peak_lists_robot.dart` - update provider override imports
- [x] `lib/services/peak_list_repository.dart` - skip malformed payloads in membership lookup
- [x] `lib/providers/map_provider.dart` - peak popup content model; membership names; MGRS/lat-lng map-name fallback
- [x] `lib/screens/map_screen_panels.dart` - name/height/map/list rows; `—` height; omit empty memberships
- [x] TDD: complete MGRS map name, lat/lng fallback, `Unknown` fallback → implement resolver
- [x] TDD: sorted memberships, no memberships omitted, malformed list skipped → implement lookup
- [x] TDD: popup content rows match spec → implement card
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Placement And Cleanup

- **Goal**: deterministic placement; popup lifecycle integration
- [x] `lib/screens/map_screen_panels.dart` - pure placement helper: right, flip left, clamp, unanchorable state
- [x] `lib/screens/map_screen.dart` - re-anchor/close on pan/zoom, offscreen, zoom < 8, peak removed, background click, shortcuts
- [x] `lib/widgets/map_action_rail.dart` - close peak popup in transient UI cleanup
- [x] `lib/router.dart` - close peak popup in shell navigation cleanup
- [x] `test/widget/map_screen_keyboard_test.dart` - shortcut cleanup coverage
- [x] `test/widget/map_screen_peak_info_test.dart` - placement + lifecycle widget coverage
- [x] TDD: right placement, left flip, clamp, offscreen unanchorable → implement helper
- [x] TDD: showPeaks false, zoom below threshold, removed peak, navigation/action/search/goto close popup → implement cleanup
- [x] TDD: center info popup and peak popup mutually exclusive → implement lifecycle guards
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Robot Journey

- **Goal**: critical user journey with stable selectors
- [x] `test/robot/peaks/peak_info_robot.dart` - map harness; selectors: `map-interaction-region`, `peak-marker-6406`, `peak-marker-hitbox-6406`, `peak-info-popup`, `peak-info-popup-close`
- [x] `test/robot/peaks/peak_info_journey_test.dart` - hover, click, content, close, background click path
- [x] `test/harness/test_map_notifier.dart` - deterministic peak/popup helpers if needed
- [x] TDD: robot hover shows click cursor/halo → implement robot + UI seam
- [x] TDD: robot click opens popup with content and close button → implement journey
- [x] TDD: robot non-peak click keeps map selection behavior and no peak popup → implement journey
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `flutter_map` pointer coordinates in widget tests; SVG marker child wrapping breaking existing asset tests; provider move touching dirty unrelated work
- **Out of scope**: changing peak search behavior; changing track hover semantics outside peak precedence; recenter/select peak on click
