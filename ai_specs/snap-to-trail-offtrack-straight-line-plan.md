## Overview

Snap-to-trail fallback for off-track taps.
If routing cannot stay on trail, commit a straight segment from the previous point to the tap point; keep the draft saveable.

**Spec**: `this request`

## Context

- **Structure**: layer-first Flutter app; `providers/` + `screens/` + `widgets/`
- **State management**: Riverpod `MapNotifier` / `MapState`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/robot/map/map_route_journey_test.dart`
- **Assumptions/Gaps**: treat `RoutePlanningException('No path found.')` as the off-track signal; leave manual straight-line mode disabled; if exact on-track hit detection is needed, add a separate tap seam in `MapScreen`

## Plan

### Phase 1: Snap-to-trail fallback

- **Goal**: off-track tap still yields a usable 2-point segment
- [x] `lib/providers/map_provider.dart` - on snap-to-trail planning failure, append direct `[start, end]` geometry, add straight-line distance, clear provisional/error, advance to `awaitingNextPoint`
- [x] `test/providers/route_draft_state_test.dart` - TDD: no-path tap falls back to a straight segment; save stays enabled; last good geometry remains intact
- [x] `test/widget/map_screen_route_sheet_test.dart` - TDD: route sheet shows distance, no inline error, save enabled after off-track tap
- [x] `test/robot/map/map_route_journey_test.dart` - TDD: route journey with a failing planner still renders the draft, saves the route, and persists direct geometry
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: planner failure vs true off-track signal; distance changes from routed to direct segment; async completion timing in route drafting tests
- **Out of scope**: enabling manual straight-line mode; map-wide on-track hit testing seam; route save/storage changes
