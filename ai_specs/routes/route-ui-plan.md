## Overview
Split route drafting into two `OverlayEntry` surfaces owned by `MapScreen`.
Keep route behavior intact; migrate all `route-bottom-sheet` consumers to new overlay roots.

**Spec**: `ai_specs/route-ui-spec.md` (read this file for full requirements)

## Context

- **Structure**: map shell + route widget layer; `lib/screens`, `lib/widgets`, `lib/providers`, `lib/services`
- **State management**: Riverpod `MapNotifier`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/robot/map/map_route_robot.dart`
- **Assumptions/Gaps**: overlay host lives in `MapScreen`; `route-bottom-sheet` retired; all references must move to `route-graph-overlay-root` / `route-controls-overlay-root`

## Plan

### Phase 1: Overlay host

- **Goal**: create/remove both overlays with route draft state
- [x] `lib/screens/map_screen.dart` - add overlay host; create `route-graph-overlay-root` + `route-controls-overlay-root`; sync on `isRouteDrafting`; remove on end/dispose
- [x] `lib/widgets/map_route_bottom_sheet.dart` - split current sheet into graph overlay + controls overlay widgets; preserve existing content
- [x] `test/widget/map_screen_route_entry_test.dart` - TDD: opening draft shows both roots; cancel/save remove both roots
- [x] `test/widget/map_screen_keyboard_test.dart` - TDD: escape/dismiss path keeps draft active until overlays removed
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_route_entry_test.dart test/widget/map_screen_keyboard_test.dart`

### Phase 2: Layout + responsive shell

- **Goal**: preserve UI while changing composition/placement
- [x] `lib/widgets/map_route_bottom_sheet.dart` - keep distance/elevation content; align route name + Cancel/Save with icon buttons; right inset `88`; horizontal scroll on narrow widths
- [x] `test/widget/map_screen_route_sheet_test.dart` - TDD: split-panel placement, shared padding, bottom-left/bottom-right anchoring, narrow viewport, overlay root selectors
- [x] `test/robot/map/map_route_robot.dart` - update selectors to overlay roots; keep helper API stable
- [x] `test/robot/map/map_route_journey_test.dart` - TDD: critical route draft journey still visible with new overlay roots
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_route_sheet_test.dart test/robot/map/map_route_journey_test.dart`

### Phase 3: Consumer migration

- **Goal**: remove every `route-bottom-sheet` reference
- [x] `test/widget/map_screen_route_entry_test.dart` - switch to overlay root keys
- [x] `test/widget/map_screen_keyboard_test.dart` - switch to overlay root keys
- [x] `test/robot/routes/route_graph_robot.dart` - switch to overlay root keys
- [x] `test/robot/tasmap/tasmap_journey_test.dart` - switch to overlay root keys
- [x] Any remaining helper/test/harness reference found by search - switch to overlay root keys
- [x] TDD: route graph/loading/error helpers still assert the same behavior via new roots
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: overlay rebuild sync; selector churn; narrow-width clipping; paired remove on cancel/save/dispose
- **Out of scope**: route planning, persistence, export, new route state, behavior changes outside route draft UI
