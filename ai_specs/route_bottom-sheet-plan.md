## Overview

Placeholder route sheet on Map; provider-backed draft state + shell wiring.
Desktop-only; keep to current map shell conventions.

**Spec**: `ai_specs/route_bottom-sheet-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first Flutter app; map shell + shared router
- **State management**: Riverpod `MapNotifier` / `MapState`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/widgets/map_action_rail.dart`, `lib/router.dart`, `test/widget/map_screen_keyboard_test.dart`, `test/widget/map_screen_peak_info_test.dart`
- **Assumptions/Gaps**: desktop shell only; route draft model explicit in provider; route taps must bypass existing map-tap selection logic

## Plan

### Phase 1: Draft model + sheet slice

- **Goal**: open/close sheet; draft state visible; no routing persistence
- [x] `lib/providers/map_provider.dart` - add route draft fields/methods: draft mode, draft name, ordered draft markers, clear/reset
- [x] `lib/core/constants.dart` - add `RouteConstants.sheetHeight = 320.0`
- [x] `lib/widgets/map_route_bottom_sheet.dart` - build sheet UI: header groups, metrics, mode toggles, route name field, blank elevation box, cancel/save
- [x] `lib/screens/map_screen.dart` - sheet host + dismiss/reset wiring; scaffold entry point
- [x] TDD: route draft state opens default mode, appends markers in order, clears on cancel/save/dismiss
- [x] TDD: sheet renders default mode, fields, placeholder content, closes on cancel/save
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_route_sheet_test.dart`

### Phase 2: Map shell integration

- **Goal**: Create Route entry clears conflicting UI, disables bad interactions, places draft markers
- [x] `lib/widgets/map_action_rail.dart` - enable Create Route FAB; trigger sheet entry
- [x] `lib/screens/map_screen.dart` - map tap routing for draft markers; ignore peak/select-track tap behavior while drafting
- [x] `lib/screens/map_screen.dart` - keyboard gating; route-name focus must not leak shortcuts
- [x] `lib/screens/map_screen.dart` - dismiss-surface priority / escape handling for route sheet
- [x] TDD: route taps add temporary markers without selected-location / peak-info side effects
- [x] TDD: route-name focus suppresses map shortcut handling; allowed shortcuts still work when map has focus
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_keyboard_test.dart test/widget/map_screen_route_entry_test.dart`

### Phase 3: Navigation + robot coverage

- **Goal**: side-menu warning flow; critical journeys covered end-to-end
- [ ] `lib/router.dart` - intercept shell navigation while route drafting active; show danger confirm before `goBranch(...)`
- [ ] `lib/widgets/side_menu.dart` - keep selection wiring stable; no duplicate confirm logic
- [x] `test/robot/tasmap/tasmap_journey_test.dart` - Create Route -> sheet opens from the map shell and the rail remains reachable
- [ ] `test/robot/map/map_route_journey_test.dart` - Create Route -> mode toggle -> draft marker -> cancel reset
- [ ] `test/robot/map/map_route_journey_test.dart` - Create Route -> side menu -> warning -> Continue -> navigate
- [ ] TDD: router-level guard blocks branch switch until confirm resolves
- [ ] Robot: stable `Key` selectors for sheet root, mode buttons, route name field, cancel/save, draft marker layer, confirm button
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: map tap precedence vs current peak/track selection; focus handling in route name field; route reset timing on dismissal
- **Out of scope**: route persistence/save backend; elevation graph data; mobile-responsive shell changes
