## Overview

Desktop map ETA popup from local route-graph hit -> fresh GPS -> ORS summary.
Thin end-to-end slice first; follow existing `MapScreen` + Riverpod seams.

**Spec**: `ai_specs/map-screen/openrouteservice-road-track-eta-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `widgets/`, `models/`
- **State management**: Riverpod `NotifierProvider`; `MapScreen` drives `mapProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/services/route_graph_trail_service.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/map/map_route_robot.dart`
- **Assumptions/Gaps**: use provider-backed popup coordination over screen-local state; use repository-backed route-graph robot store override; start with in-memory viewport/chunk cache, not persisted cache

## Plan

### Phase 1: Thin ETA Slice

- **Goal**: valid desktop click -> loading popup -> ORS success popup
- [x] `lib/core/constants.dart` - add `MapConstants.driveEtaMinZoom = 6`
- [x] `lib/providers/map_provider.dart` - add shared anchored ETA popup state + close/open coordination with peak popup
- [x] `lib/services/route_graph_query_service.dart` - add qualifying drive-ETA way query helper
- [x] `lib/services/route_graph_drive_eta_hit_service.dart` - add minimal viewport-scoped hit test, snap point result, screen-threshold reuse
- [x] `lib/services/open_route_service.dart` - add ORS client seam + summary model + injected HTTP/config path
- [x] `lib/providers/route_graph_readiness_provider.dart` - keep existing readiness model; expose only narrow read path if ETA orchestration needs it
- [x] `lib/screens/map_screen.dart` - insert ETA click path at required precedence point; suppress selected-location/route/track updates on consumed ETA click
- [x] `lib/screens/map_screen_panels.dart` - add ETA popup presentation with peak-style chrome, ETA-specific keys, loading/success rows
- [x] `test/widget/map_screen_drive_eta_test.dart` - add happy-path widget slice with repository-backed route graph, fake location, fake ORS, immediate loading then success
- [x] TDD: valid qualifying road click opens loading popup immediately, then renders formatted distance + duration, then implement
- [x] TDD: ETA click consumes the event; selected location / route / track state stay unchanged, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Hit Geometry And Service Failures

- **Goal**: harden filter, snap, cache, ORS/location errors
- [x] `test/services/route_graph_query_service_test.dart` - add qualifying drive-ETA metadata filter coverage
- [x] `test/services/route_graph_drive_eta_hit_service_test.dart` - add decode, nearest-point projection, threshold reject, zoom gate, cache reuse coverage
- [x] `test/services/open_route_service_test.dart` - add success mapping, missing key, non-200, malformed payload, timeout coverage
- [x] `lib/services/route_graph_drive_eta_hit_service.dart` - expand geometry decode + viewport/chunk cache behavior to satisfy service tests
- [x] `lib/services/open_route_service.dart` - finish error mapping + missing-key fail-closed behavior
- [x] `lib/screens/map_screen.dart` - surface readiness/coverage/location/ORS failures as inline ETA popup error states; keep no-hit silent
- [x] `test/widget/map_screen_drive_eta_test.dart` - add GPS failure, ORS failure, missing-key, readiness unavailable, no-hit silent-noop cases
- [x] TDD: click outside qualifying geometry opens nothing while route-graph coverage exists, then implement
- [x] TDD: readiness unavailable vs no-hit follow different user outcomes, then implement
- [x] TDD: ORS and location failures keep popup anchored with inline error state, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Popup Coordination And Async Invalidation

- **Goal**: lock popup coexistence, dismissal, pan/zoom, stale result handling
- [x] `lib/providers/map_provider.dart` - finalize ETA/peak mutual exclusion helpers; keep hover/pinned peak behavior stable
- [x] `lib/screens/map_screen.dart` - add stale-request invalidation, repeat-click replacement, invalid-click dismissal, offscreen/anchorability close behavior
- [x] `lib/screens/map_screen_panels.dart` - finalize close button, error/loading keys, title/fallback name rendering
- [x] `test/widget/map_screen_drive_eta_test.dart` - add second-click invalidates first result, background click dismisses ETA, peak popup closes ETA and vice versa, pan/zoom anchor loss closes ETA
- [ ] `test/widget/map_screen_peak_info_test.dart` - add or adjust regression coverage where ETA/peak popup coordination shares the anchored-popup seam
- [x] TDD: second valid click suppresses stale first response and only newest result renders, then implement
- [x] TDD: opening peak popup closes ETA popup; ETA open closes hovered/pinned peak popup, then implement
- [x] TDD: invalid click dismisses pinned ETA; offscreen anchor after viewport change closes ETA, then implement
- [x] Verify: `flutter analyze` && `flutter test`
- Blocker: popup coordination regression coverage is currently proven in `test/widget/map_screen_drive_eta_test.dart`; decide whether to duplicate/move that coverage into `test/widget/map_screen_peak_info_test.dart`.

### Phase 4: Robot Journey And Cleanup

- **Goal**: key-first desktop journey; deterministic harness
- [x] `test/robot/map/drive_eta_robot.dart` - add robot on top of `MapRouteRobot` patterns; repository-backed route-graph store override; fake location + fake ORS seams
- [x] `test/robot/map/drive_eta_journey_test.dart` - add critical desktop journey: click qualifying road -> loading -> success -> repeat click replacement / dismiss path if high value
- [x] `lib/screens/map_screen_panels.dart` - add any remaining stable selectors required by robot lane only
- [x] `test/robot/map/map_route_robot.dart` - extract shared helper only if ETA robot can reuse it without widening unrelated responsibilities; no extraction needed in this run
- [x] TDD: robot happy path uses app-owned keys only and no live platform/network calls, then implement
- [x] Robot journey tests + selectors/seams for critical flows: `Key('map-interaction-region')`, ETA popup root/close/loading/error/duration/distance keys, repository-backed route-graph store, fake location seam, fake ORS seam
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: raw chunk decode cost may force broader cache seam; popup coordination may regress peak hover/pin behavior; widget hit testing may be brittle without repository-backed map fixtures
- **Out of scope**: touch/mobile ETA flows; Google services; turn-by-turn navigation or travel-mode switching
