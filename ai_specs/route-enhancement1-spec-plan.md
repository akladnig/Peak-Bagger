## Overview

Warm the route graph at startup; block route entry until ready; drop lazy asset/env loading.
Add manual Settings refresh to rewrite the snapshot and rebuild the cached graph.

**Spec**: `ai_specs/route-enhancement1-spec.md`

## Context

- **Structure**: layer-first (`lib/services`, `lib/providers`, `lib/screens`, `test/widget`, `test/robot`)
- **State management**: Riverpod
- **Reference implementations**: `lib/services/route_elevation_sampler.dart`, `lib/screens/settings_screen.dart`, `lib/widgets/map_action_rail.dart`, `test/widget/peak_refresh_settings_test.dart`, `test/robot/peaks/peak_refresh_journey_test.dart`
- **Assumptions/Gaps**: `path_provider` + `assets/highway.json` already exist; no dependency add expected

## Plan

### Phase 1: Warm graph bootstrap

- **Goal**: preload graph, gate route entry, remove lazy parse path
- [x] `lib/services/route_graph_store.dart` - new support-dir snapshot store; seed from asset; cache `TripService`; `preload()` + `reload()`
- [x] `lib/services/route_planner.dart` - remove env/asset on-demand loader; delegate to store-backed cache; typed `RouteGraphLoadException`
- [x] `lib/providers/route_planner_provider.dart` - wire store-backed client
- [x] `lib/providers/route_graph_readiness_provider.dart` - `preloading` / `ready` / `failed`
- [x] `lib/providers/map_provider.dart` - surface graph-load failure distinctly; no straight-line fallback for `RouteGraphLoadException`
- [x] `lib/screens/map_screen.dart` - gate `_beginRouteDraft()` / `onCreateRoute` until readiness is `ready`; keep route action disabled on preload failure
- [x] `lib/main.dart` - equivalent boot path via provider bootstrap before route entry unlocks
- [x] `test/services/route_graph_store_test.dart` - seed missing file; preload; reload; snapshot validation failure; preserve prior cache on reload failure
- [x] `test/providers/route_graph_readiness_provider_test.dart` - preloading -> ready -> failed transitions; retry to ready after refresh
- [x] `test/services/route_planner_test.dart` - load from cached graph; malformed graph error; no on-demand parsing
- [x] `test/widget/map_screen_route_entry_test.dart` - `create-route-fab` disabled while preloading; enabled when ready; stays disabled on failed preload
- [x] TDD: seed-support-dir file; preload-ready transition; preload-failed transition; route-load error type; route entry stays disabled until ready
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Refresh + journeys

- **Goal**: manual refresh rewrites snapshot and rehydrates cache
- [x] `lib/services/route_graph_refresh_service.dart` - exact query; write snapshot; reload cached graph; preserve prior graph on failure
- [x] `lib/screens/settings_screen.dart` - add `Refresh Route Graph` tile/dialog/status; mirror peak refresh UX
- [x] `test/services/route_graph_refresh_service_test.dart` - success, empty-result, write-fail, reload-fail, prior-graph-preserved cases
- [x] `test/widget/route_graph_refresh_settings_test.dart` - confirm/cancel/loading/result/failure/busy-state/retry recovery
- [x] `test/robot/settings/route_graph_refresh_robot.dart` - helper with stable keys: `refresh-route-graph-tile`, `route-graph-refresh-confirm`, `route-graph-refresh-cancel`, `route-graph-refresh-status`, `route-graph-refresh-result-close`, `route-graph-refresh-error-close`
- [x] `test/robot/settings/route_graph_refresh_journey_test.dart` - Settings refresh end-to-end; route action usable after reload
- [x] TDD: refresh writes support-dir file; refresh rebuilds cache; failure preserves prior graph; Settings flow states; robot journey after refresh
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: startup preload can delay first paint; cache invalidation must hit the same in-memory `TripService`; robot timing around async dialogs/load
- **Out of scope**: route rendering changes, color picker, background auto-refresh, alternate route sources
