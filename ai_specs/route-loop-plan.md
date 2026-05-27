## Overview

One-shot `Close Loop` draft action. Reuse current route planner + one-shot route editing flow.

**Spec**: `ai_specs/route-loop-spec.md`

## Context

- **Structure**: feature-first by screen/provider/service
- **State management**: Riverpod `Notifier` + repository providers
- **Reference implementations**: `./lib/providers/map_provider.dart`, `./lib/widgets/map_route_bottom_sheet.dart`, `./test/providers/route_draft_state_test.dart`, `./test/widget/map_screen_route_sheet_test.dart`, `./test/robot/map/map_route_robot.dart`
- **Assumptions/Gaps**: no new schema/export work; close-loop uses existing planner statuses and current out-and-back / straight-line draft mechanics

## Plan

### Phase 1: Draft action

- **Goal**: one-shot close-loop state machine
- [x] `./lib/providers/map_provider.dart` - add `applyRouteDraftCloseLoop()`; routed path, `noPath` fallback, `offTrack` straight-line fallback, exact closed-loop endpoint, control/marker updates, resample/elevation bump, mode unchanged
- [x] `./test/providers/route_draft_state_test.dart` - TDD: routed closure; `noPath` fallback; `offTrack` fallback; inconsistent state; already-closed no-op; `segmentFailure` disabled/recoverable
- [x] Verify: `flutter analyze` && `flutter test test/providers/route_draft_state_test.dart`

### Phase 2: Route sheet control

- **Goal**: visible action in strip
- [ ] `./lib/widgets/map_route_bottom_sheet.dart` - add `Close Loop` action between `Out and Back` and name field; `Icons.refresh`; tooltip/key; enablement; narrow scroll
- [ ] `./test/widget/map_screen_route_sheet_test.dart` - TDD: presence, icon/tooltip, enabled/disabled states, placement, closed-loop disable, narrow viewport scroll
- [ ] `./test/robot/map/map_route_robot.dart` - add stable selector helper for `Close Loop`
- [ ] Verify: `flutter analyze` && `flutter test test/widget/map_screen_route_sheet_test.dart`

### Phase 3: End-to-end journey

- **Goal**: visible close-loop save flow
- [ ] `./test/robot/map/map_route_journey_test.dart` - TDD: build draft -> tap `Close Loop` -> verify draft update -> save -> persisted route
- [ ] `./test/robot/map/map_route_robot.dart` - drive close-loop tap + assertions with key-first selectors
- [ ] Verify: `flutter analyze` && `flutter test test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope

- **Risks**: helper reuse between close-loop / out-and-back; horizontal strip overflow on narrow screens; exact closed-loop equality
- **Out of scope**: new persistence schema, export changes, manual waypoint editing, route-planner algorithm changes
