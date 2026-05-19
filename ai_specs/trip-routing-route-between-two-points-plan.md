## Overview

Route drafting on map: `trip_routing`, one-segment-at-a-time, save to persisted `Route`.
Approach: thin vertical slice first; keep state in existing `mapProvider` stack.

**Spec**: `ai_specs/trip-routing-route-between-two-points-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `providers/`, `screens/`, `widgets/`, `services/`, `models/`
- **State management**: Riverpod `NotifierProvider`; constructor DI + provider fallback
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `test/widget/map_screen_route_sheet_test.dart`
- **Assumptions/Gaps**: keep route state inside existing `map_provider.dart`; `route.colour` hardcoded red; `Route.distance2d` stored meters, UI shows km

## Plan

### Phase 1: Thin Routed Save Slice

- **Goal**: one successful 2-point routed segment; visible draft; save persists routed geometry
- [x] `pubspec.yaml` - add `trip_routing: ^0.0.13`
- [x] `lib/services/route_planner.dart` - add narrow contract/result model; wrap `trip_routing`; map package errors/empty output
- [x] `lib/providers/route_planner_provider.dart` - app wiring seam; override-friendly
- [x] `lib/providers/map_provider.dart` - add route draft state machine, request token, route-colour field, committed geometry, provisional geometry, persisted distance meters, save using routed geometry + `showRoutes = true`
- [x] `lib/screens/map_screen.dart` - route-mode tap interception; route-mode right-click no-op; stop `selectedLocation`/track/peak side effects while drafting
- [x] `lib/screens/map_screen_layers.dart` - add minimal draft marker/polyline render helpers; keep saved route render path unchanged
- [x] `lib/widgets/map_route_bottom_sheet.dart` - disable `Straight Line`; add `route-loading-text`, `route-distance-text`, `route-error-text`; save gating from trimmed name + successful geometry + no in-flight request
- [x] TDD: adapter success/failure mapping for exactly two waypoints -> then implement
- [x] TDD: FAB -> first tap -> second tap -> routed success -> distance shown -> save persists `Route.gpxRoute`, `displayRoutePointsByZoom`, `distance2d`, `colour` -> then implement
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - align existing saved-route visibility journey with forced `showRoutes = true` behavior
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Continuation And Failure Recovery

- **Goal**: append segments; preserve last good route; deterministic stale-result handling
- [ ] `lib/providers/map_provider.dart` - append from current endpoint; segment-failure state; identical-point rejection; retry semantics; cancel clears transient route state only
- [ ] `lib/screens/map_screen_layers.dart` - route-colour markers, provisional line, committed routed lines; explicit layer ordering above existing overlays
- [ ] `test/harness/test_map_notifier.dart` - fake planner injection; deterministic async/result control
- [ ] `test/providers/route_draft_state_test.dart` - extend beyond marker-only draft behavior
- [ ] `test/widget/map_screen_route_sheet_test.dart` - cover loading/error/save-disabled transitions, route-colour draft state, saved visibility
- [ ] TDD: third tap appends from point 2, not restart -> then implement
- [ ] TDD: identical point / empty segment / package failure / stale late result preserve last successful geometry -> then implement
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Interaction Guards And Journey Lane

- **Goal**: route-mode shell behavior solid; critical journey covered by robot tests
- [ ] `lib/screens/map_screen.dart` - preserve View-group actions during route mode; keep `Esc` dismissing unrelated surfaces only; keep hover passive
- [ ] `lib/widgets/map_route_bottom_sheet.dart` - finalize selector contract; remove metric placeholders; route-colour-consistent UI copy
- [ ] `test/widget/map_screen_keyboard_test.dart` - route-mode `Esc`/drawer behavior; route-name focus; no route-state mutation
- [ ] `test/widget/map_screen_route_entry_test.dart` - no regression in map shell entry/persistence seams
- [ ] `test/robot/map/map_route_robot.dart` - robot helpers; stable key-first selectors; deterministic waits
- [ ] `test/robot/map/map_route_journey_test.dart` - happy-path 3-tap route draft + save
- [ ] TDD: route mode blocks peak popup, track selection, selected-location recenter, right-click mutation -> then implement
- [ ] Robot journey tests + selectors/seams for critical flow: `create-route-fab`, `route-loading-text`, `route-distance-text`, `route-error-text`, `route-cancel-button`, `route-save-button`, draft marker/polyline keys; fake planner responses only
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `trip_routing` API mismatch vs spec version; async race bugs in notifier; map-layer ordering regressions
- **Out of scope**: route-colour picker; straight-line routing; elevation/ascent/descent metrics; unrelated map/track refactors
