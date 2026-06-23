## Overview

Hybrid `RouteMode.routeToPeak` path. Preserve routed track segment, append straight terminal leg to peak, keep draft/save state consistent.

**Spec**: `./ai_specs/route-to-peak-track-then-straight-spec.md`

## Context

- **Structure**: feature-first Riverpod state + widget overlays + robot journeys
- **State management**: Riverpod `MapNotifier`
- **Reference implementations**: `./lib/providers/map_provider.dart`, `./test/providers/route_draft_state_test.dart`, `./test/robot/map/map_route_journey_test.dart`
- **Assumptions/Gaps**: planner anchors/partial geometry available via existing `RoutePlanningResult` fields; no planner API change expected

## Plan

### Phase 1: Core hybrid draft

- **Goal**: route-to-peak geometry + state sync
 - [x] `./lib/providers/map_provider.dart` - preserve routed anchor/partial segment; append peak terminal leg; pure straight fallback only when no usable anchor/geometry
 - [x] `./test/providers/route_draft_state_test.dart` - TDD: hybrid on-track start/off-track peak; partial/noPath/offTrack fallback; edit-mode start-already-tapped; stale result ignored
 - [x] `./test/harness/test_map_notifier.dart` - mirror hybrid/fallback route-to-peak outcomes for deterministic widget/robot flows
 - [x] `./test/widget/map_screen_route_sheet_test.dart` - smoke: route sheet stays saveable while hybrid draft active
 - [x] Verify: `flutter analyze && flutter test test/providers/route_draft_state_test.dart test/widget/map_screen_route_sheet_test.dart`

### Phase 2: Critical journey

- **Goal**: end-to-end create-route proof
 - [x] `./test/robot/map/map_route_journey_test.dart` - route-to-peak journey with off-track peak target; save hybrid route; selectors: `create-route-fab`, `route-mode-route-to-peak`, `route-save-button`
 - [x] TDD: robot flow saves hybrid geometry, not just mode state
 - [x] TDD: route-to-peak remains stable after route-sheet reopen/edit path
 - [x] Verify: `flutter analyze && flutter test test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope

- **Risks**: planner `noPath` anchor semantics; harness drift from provider rules; robot fixture needs deterministic planner outcomes
- **Out of scope**: new routing engine; nearest-point search implementation; off-track-start behavior changes; route export / map selection changes
