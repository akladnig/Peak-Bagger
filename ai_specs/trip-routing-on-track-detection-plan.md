## Overview

Nearest-edge anchored segment routing in local `trip_routing`; structured status mapping in `peak_bagger`.
Replace sticky straight-line fallback with off-track probe/rejoin state; keep UI/tests deterministic.

**Spec**: `ai_specs/trip-routing-on-track-detection-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first Flutter app; app seam in `lib/services/route_planner.dart`; state machine in `lib/providers/map_provider.dart`; local path dependency at `/Users/adrian/Development/mapping/trip_routing`
- **State management**: Riverpod `MapNotifier` / `MapState`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/services/route_planner.dart`, `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/robot/map/map_route_journey_test.dart`, `../trip_routing/lib/src/services/trip_service.dart`, `../trip_routing/lib/src/models/graph.dart`
- **Assumptions/Gaps**: keep app-owned planner abstraction; remove route-draft reliance on `RoutePlanningException`; follow existing key-first widget/robot tests; if fallback classes are referenced outside route drafting, leave those call sites untouched in this slice

## Plan

### Phase 1: Package Vertical Slice

- **Goal**: dedicated anchored 2-point package seam; nearest-edge classification proven
- [x] `/Users/adrian/Development/mapping/trip_routing/lib/src/models/edge.dart` - add stable source-segment provenance shape; preserve current callers
- [x] `/Users/adrian/Development/mapping/trip_routing/lib/src/models/graph.dart` - keep `loadGraph/saveGraph()` backward-readable while persisting/normalizing provenance
- [x] `/Users/adrian/Development/mapping/trip_routing/lib/src/models/` - add public anchored segment result + endpoint anchor model; enum status `routed/offTrack/noPath/failed`
- [x] `/Users/adrian/Development/mapping/trip_routing/lib/src/services/trip_service.dart` - add nearest-edge probe math, node snap vs edge projection anchoring, request-local edge splitting, same-original-edge fast path, `findAnchoredSegment(...)`, `probeEndpointAnchor(...)`
- [x] `/Users/adrian/Development/mapping/trip_routing/lib/trip_routing.dart` - export new public API/models without changing `findTotalTrip(...)`
- [x] `/Users/adrian/Development/mapping/trip_routing/test/trip_routing_test.dart` - TDD: nearest-edge on-track vs off-track, node snap, edge projection, `noPath`, same-edge routing, graph JSON backward-read, request-local overlay stability
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Planner Adapter Slice

- **Goal**: app-owned structured planner results; no exception-driven off-track path
- [x] `lib/core/constants.dart` - add `RouteConstants.maxSnapDistanceMeters = 50`
- [x] `lib/services/route_planner.dart` - replace `PlannedRouteSegment`-only success contract with planner result enum/model; add client methods for anchored segment + endpoint probe; always pass max snap distance; map package `routed/offTrack/noPath/failed` into app-owned results
- [x] `lib/providers/route_planner_provider.dart` - keep DI at the planner seam with updated client surface
- [x] `test/services/route_planner_test.dart` - TDD: each package status maps to correct app result; malformed routed payload still becomes `failed`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Route Draft State Slice

- **Goal**: control/display marker split; off-track probe, rejoin, snapped-resume transitions
- [ ] `lib/providers/map_provider.dart` - replace `routeDraftMarkers` + `routeDraftStraightLineFallback` with explicit control-endpoint, display-marker, and off-track probe state; make `setRouteDraftMode(...)` no-op during `routingSegment`
- [ ] `lib/providers/map_provider.dart` - use `routeDraftControlEndpoints.last` as sole next-start source; keep provisional raw tap marker/line during in-flight requests; move committed endpoints to anchors on resolution; keep route-to-peak visible endpoint at actual peak
- [ ] `lib/screens/map_screen.dart` - watch/render new display-marker state; preserve existing provisional polyline behavior
- [ ] `lib/screens/map_screen_layers.dart` - replace bare `List<LatLng>` marker builder with keyed display-marker model; deterministic order/keys across raw/node/projection markers
- [ ] `test/providers/route_draft_state_test.dart` - TDD: off-track entry without error, repeated off-track/`noPath`, straight rejoin then clear probe state, snapped resume on following segment, route-to-peak one-shot semantics, failed rollback, next-start sourced only from committed control endpoint
- [ ] `test/harness/test_map_notifier.dart` - limit route-draft use or delegate fully to production notifier; avoid duplicate state-machine logic
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Route Mode UI And Journeys

- **Goal**: explicit inactive/active/selected buttons; critical snapped-offtrack-rejoin journey covered
- [ ] `lib/widgets/map_route_bottom_sheet.dart` - add single visual-state mapping helper/enum; render `inactive` default, `active` purple, `selected` green; keep truth table aligned with `routeToPeak` availability and `routingSegment` lock
- [ ] `test/widget/map_screen_route_sheet_test.dart` - TDD: assert helper-driven styling, selected-state color, disabled `routeToPeak` without target, locked buttons during `routingSegment`
- [ ] `test/robot/map/map_route_robot.dart` - update queued planner seam for structured `routed/offTrack/noPath/failed` outcomes; keep key-first selectors stable
- [ ] `test/robot/map/map_route_journey_test.dart` - TDD: snapped -> off-track straight -> rejoin straight -> snapped again; true `failed` does not silently accept a segment
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: projected-edge overlay correctness in `trip_routing`; legacy `Graph.saveGraph()` edge duplication interactions during backward-read normalization; brittle widget assertions if button-color checks bypass an app-owned seam
- **Out of scope**: generic multi-waypoint `findTotalTrip(...)` redesign; rendering internal routed vertices as markers; route color changes; unrelated route persistence/elevation refactors
