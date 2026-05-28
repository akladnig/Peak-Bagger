## Overview

Route hover placement affordances.
Use one draft-hover state seam so the existing draft-marker highlight plus the transient placement preview, cursor state, and inserted target state rebuild together; suppress persisted route hover/select while drafting.

**Spec**: `ai_specs/route-hover-spec.md` (read this file for full requirements)

## Context

- **Structure**: layered Flutter app; screen/provider/widget split
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/widgets/route_marker.dart`, `lib/providers/map_provider.dart`, `test/widget/route_marker_test.dart`, `test/widget/route_marker_layer_test.dart`, `test/robot/map/map_route_journey_test.dart`
- **Assumptions/Gaps**: one hovered placement id in `MapState` likely needed so outer `Marker` size/hitbox, cursor state, and inserted target state stay in sync; preview insertion must splice into the ordered draft chain and recompute numbering

## Plan

### Phase 1: Hover seam

- **Goal**: route hover state can render a movable placement marker + insert target state
- [x] `lib/providers/map_provider.dart` - add hovered placement id + set/clear APIs; clear on draft end and click commit; support insert-into-segment draft transition with a visual-only preview state
- [x] `lib/providers/map_provider.dart` - splice inserted preview points into the ordered draft chain and recompute numbering from list order
- [x] `lib/screens/map_screen_layers.dart` - pass hovered placement id into route build; update cursor state and marker tracking with pointer movement
- [x] `lib/widgets/route_marker.dart` - render hovered placement and target variants using circle style at numbered size
- [x] `lib/core/constants.dart` - use `RouteUI.markerZoom = 1.2`
- [x] TDD: hovered placement marker follows the cursor; pointer becomes a hand; map pointer-up inserts into segment, recomputes numbering, and becomes target
- [x] Verify: `flutter analyze` && `flutter test test/widget/route_marker_test.dart test/widget/route_marker_layer_test.dart`

### Phase 2: Draft-hover routing

- **Goal**: route drafting suppresses persisted route hover/select handling
- [x] `lib/screens/map_screen.dart` - bypass `_handleRouteHover` and route hover/select handling while `routeChrome.isRouteDrafting`; clear draft hover on pointer exit/cancel and click commit
- [x] `lib/screens/map_screen.dart` - ensure placement preview does not commit itself and map pointer-up owns the insert transition
- [x] `lib/providers/map_provider.dart` - clear draft-hover state on teardown, pointer exit/cancel, and click commit paths
- [x] `lib/providers/map_provider.dart` - keep drafting anchored to the last committed endpoint after each insert
- [x] TDD: route-drafting hover path does not set persisted route hover/select; normal map view still does
- [x] Verify: `flutter analyze` && `flutter test test/providers/map_provider_route_draft_hover_test.dart test/widget/map_screen_route_hover_test.dart`

### Phase 3: Journey coverage

- **Goal**: desktop hover journey stays stable with key-first selectors
- [x] `test/robot/map/map_route_journey_test.dart` - add create draft -> hover segment -> track cursor -> click insert -> verify ordered chain/numbering/target -> move away clears
- [x] `test/robot/map/map_route_robot.dart` - stable hover-only journey helpers/selectors added to the shared map route robot
- [x] TDD: one hover assertion at a time; verify marker root, hover shell, target state, segment hover state, ordered numbering, and clear state
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: flutter_map marker hover hit-testing may need tuning; hover/size sync may need one extra state seam if the marker box cannot rebuild cleanly; ordered insertion may need careful numbering recomputation
- **Out of scope**: persisted route hover/select redesign; route storage/export/planning changes; touch hover synthesis; unrelated route sheet layout
