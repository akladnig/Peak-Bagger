## Overview
ObjectBox-backed route graph: seed once from bundled `highway.json`, store chunked generations, query by viewport/corridor, refresh from Settings.
Keep startup usable; route drafting reads only active chunks, never the whole asset.

**Spec**: `ai_specs/routes/route-graph-objectbox-cache-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first services/providers/screens
- **State management**: Riverpod
- **Reference implementations**: `lib/services/peak_refresh_service.dart`, `lib/screens/settings_screen.dart`, `lib/providers/map_provider.dart`, `test/widget/route_graph_refresh_settings_test.dart`, `test/robot/settings/route_graph_refresh_robot.dart`
- **Assumptions/Gaps**: bootstrap worker via built-in isolate primitives; no new network/dependency layer; keep current provider seams where possible

## Plan

Status: Phase 1 complete. Phase 2 complete. Phase 3 complete.

### Phase 1: ObjectBox graph seed

- **Goal**: active generation + chunk store; first-launch bootstrap only
- [x] `lib/models/route_graph_manifest.dart` - new ObjectBox entity
- [x] `lib/models/route_graph_chunk.dart` - new ObjectBox entity
- [x] `lib/objectbox.g.dart` - regenerate bindings
- [x] `lib/services/route_graph_repository.dart` - active gen CRUD, chunk fetch, prune stale gens
- [x] `lib/services/route_graph_import_service.dart` - off-UI-isolate import, atomic swap, first-launch bootstrap only
- [x] `lib/services/route_graph_store.dart` - convert file snapshot facade to repo-backed compatibility layer
- [x] `lib/providers/route_graph_readiness_provider.dart` - bootstrap/ready/failed state
- [x] `lib/app.dart` - trigger bootstrap provider on app start without blocking UI
- [x] `lib/main.dart` - open ObjectBox, wire route-graph overrides, keep startup non-blocking
- [x] TDD: first launch with no active graph bootstraps; later launch skips import; partial/failed import keeps no-graph or prior-good state
- [x] TDD: successful refresh activates new generation then prunes stale generations
- [x] `test/services/route_graph_store_test.dart` - compatibility layer preload/reload behavior
- [x] Verify: `flutter analyze` && `flutter test test/services/route_graph_repository_test.dart test/services/route_graph_import_service_test.dart test/services/route_graph_store_test.dart`

### Phase 2: Query + planner

- **Goal**: route planning from chunked store only; visible-area prefetch
- [x] `lib/services/route_graph_query_service.dart` - 5 km grid selection, 1 km overlap, viewport/corridor expansion, OSM dedupe
- [x] `lib/services/route_planner.dart` - build transient `TripService` from chunk payloads; route failure on missing coverage
- [x] `lib/providers/route_planner_provider.dart` - inject query/store seam
- [x] `lib/providers/map_provider.dart` - prefetch trigger seam; keep create-route enabled while bootstrap pending
- [x] `lib/screens/map_screen.dart` - call prefetch on camera movement; preserve existing route draft UX
- [x] TDD: viewport/corridor selects intersecting chunks; duplicate OSM input merges cleanly
- [x] TDD: planner waits for in-flight bootstrap or returns retryable loading; never consumes partial data
- [x] TDD: empty coverage returns failure without clearing an active draft
- [x] Verify: `flutter analyze` && `flutter test test/services/route_graph_query_service_test.dart test/services/route_planner_test.dart test/widget/map_screen_route_entry_test.dart test/robot/routes/route_graph_journey_test.dart`

### Phase 3: Refresh UX + journeys

- **Goal**: manual refresh in Settings; critical journeys covered
- [x] `lib/services/route_graph_refresh_service.dart` - rebuild/import path; no validation wording; preserve last-good graph on failure
- [x] `lib/screens/settings_screen.dart` - `Refresh Route Graph`, subtitle, retry banner, dialog/result copy
- [x] `test/widget/route_graph_refresh_settings_test.dart` - update confirm/cancel/loading/success/failure assertions
- [x] `test/robot/settings/route_graph_refresh_robot.dart` - key-first helpers for refresh flow
- [x] `test/robot/settings/route_graph_refresh_journey_test.dart` - Settings refresh journey
- [x] `test/robot/map/map_route_journey_test.dart` - route creation after bootstrap/refresh (covered by `test/robot/routes/route_graph_journey_test.dart`)
- [x] TDD: settings copy matches refresh language; retry banner uses refresh wording
- [x] TDD: failed first-launch bootstrap shows no-graph state; manual refresh recovers
- [x] Robot journey tests + selectors/seams: `refresh-route-graph-tile`, `route-graph-refresh-confirm`, `route-graph-refresh-status`, `create-route-fab`
- [x] Verify: `flutter analyze` && `flutter test test/services/route_graph_refresh_service_test.dart test/widget/route_graph_refresh_settings_test.dart test/robot/settings/route_graph_refresh_journey_test.dart test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope

- **Risks**: isolate/bootstrap timing; chunk-edge correctness; ObjectBox generation + pruning mistakes
- **Out of scope**: network/local Overpass source; rollback history beyond active generation; unrelated ObjectBox entities/migrations
