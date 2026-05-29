<goal>
Replace the monolithic bundled `assets/highway.json` route graph with an on-demand, bounds-based route-graph loader backed by a local Overpass-compatible data source that can be deployed alongside a local OSM tile stack.

This matters because the current route flow pays the cost of reading, decoding, and graph-building a `223 MB` statewide snapshot before route creation becomes available. Users should be able to create routes without waiting for a full Tasmania-wide graph to warm, while future local infrastructure should serve only the route area actually needed.
</goal>

<background>
Tech stack: Flutter, Riverpod, Dart IO, local file cache, custom `trip_routing` package.

Current architecture loads one full Overpass JSON snapshot and builds one in-memory `TripService` graph:
- `@./lib/services/route_graph_store.dart`
- `@./lib/providers/route_graph_readiness_provider.dart`
- `@./lib/providers/route_planner_provider.dart`
- `@./lib/services/route_planner.dart`
- `@./lib/services/route_graph_refresh_service.dart`
- `@../trip_routing/lib/src/services/trip_service.dart`
- `@../trip_routing/lib/src/models/graph.dart`

Relevant current constraints:
- `BundledRouteGraphStore` seeds a writable local snapshot from `assets/highway.json` and then reads the whole file into memory.
- `TripService.loadOverpassJson()` expects full Overpass-shaped JSON with `elements`.
- `TripService` currently owns one global `Graph` and closest-node lookup scans all loaded nodes.
- The map UI currently disables route creation until `routeGraphReadinessProvider` reports `ready`.

Assumptions for this spec:
- A future local OSM deployment will expose an Overpass-compatible API endpoint against the same data universe as the map tiles.
- Querying raster tiles directly for routing is out of scope.
- Replacing `trip_routing` with OSRM/GraphHopper/Valhalla is out of scope for this iteration.
</background>

<user_flows>
Primary flow:
1. User opens the map and starts route drafting without waiting for a statewide graph preload.
2. User taps the map to create one draft segment, and the app treats that segment request as the routing unit for this iteration.
3. App computes a buffered route corridor for that single segment, maps it to fixed cache tiles, loads cached tiles, and fetches any missing tiles from the configured local Overpass source.
4. App assembles a temporary routeable graph for that segment request from the selected tile payloads and plans the route.
5. User sees the routed segment with no dependency on the legacy bundled `highway.json` path.

Alternative flows:
- Cached route area: if all required tiles for the segment are already cached locally, the app plans the route without network access.
- Expanded search retry: if the initial segment corridor is too small to produce a route, the app expands the corridor in controlled steps and retries before falling back to the existing straight-line segment behavior.
- Local Overpass unavailable but cache sufficient: route planning succeeds from cached tiles only.
- Settings entry point: user opens Settings to validate the local route source or clear the cached route-graph tiles.

Error flows:
- Local Overpass unavailable and cache missing: route request fails with a route-graph availability error, no segment is committed, and the UI surfaces an inline retry path.
- Malformed Overpass payload for a tile: the tile is rejected, not persisted, and the user gets a route-graph load error instead of a silent straight-line fallback.
- No path found after bounded expansion on an otherwise valid assembled graph: the app preserves the current explicit straight-line segment fallback and marks the route draft as using fallback.
- Concurrent requests for the same tile set: the app deduplicates in-flight fetch/build work and shares the result.
- Cache corruption on disk: the corrupt tile is discarded and re-fetched when possible.
</user_flows>

<requirements>
**Functional:**
1. Introduce a `RouteGraphSource` abstraction under `./lib/services/` that fetches Overpass-shaped JSON by geographic bounds instead of loading one statewide asset.
2. Add a `LocalOverpassRouteGraphSource` implementation that posts Overpass queries to a configurable local endpoint and returns validated decoded JSON.
3. Replace the snapshot-oriented `RouteGraphStore` contract with a segment-scoped, bounds-oriented cache contract that can warm lightweight metadata, load cached route-area tiles, fetch missing tiles, and provide a temporary request-scoped `TripService` for one route-draft segment.
4. Keep the current route-planner product scope segment-based for this iteration. In `./lib/services/route_planner.dart`, compute route query bounds only from the active `planSegment(start, end)` request rather than redesigning the planner for full-draft multi-waypoint routing.
5. Cache fetched Overpass responses on disk under a dedicated route-graph cache directory keyed by fixed slippy-map tile coordinates at one chosen zoom level. For this iteration, use one deterministic tile scheme for storage, dedupe, and tests rather than raw bbox filenames or interchangeable key strategies.
6. Reuse cached chunks across route requests so repeated routing in nearby areas does not re-fetch the same graph data.
7. Add a bounded retry strategy that expands the requested route corridor when the initial assembled graph does not contain a valid path.
8. Preserve local-only routing as the default execution path; route planning must not call public Overpass endpoints during normal use.
9. Replace the current single refresh action in Settings with two explicit actions for this feature: `Validate Route Graph Source` and `Clear Route Graph Cache`.
10. `Validate Route Graph Source` must run a small deterministic local Overpass query against the configured endpoint, report success/failure, and not warm a statewide cache.
11. `Clear Route Graph Cache` must confirm with the user, delete cached route-graph tiles, and report how many cache entries were removed.
12. Support a transitional mode where legacy `highway.json` remains available only as a development-only migration seam behind an explicit injected boundary during Phase 1 if needed, then remove that dependency in the final stage.
13. Route creation from the map must remain enabled after app startup. The first segment request should show a route-loading state in the draft UI instead of gating the create-route button on statewide preload readiness.

**Error Handling:**
14. If a route-area fetch fails and no usable cached graph exists for that area, surface a `RouteGraphLoadException`-style error that keeps route creation available for retry but does not fabricate a straight-line route.
15. If a fetched payload is syntactically valid JSON but not valid Overpass-shaped routing data, reject it before it reaches `TripService` and do not persist it to cache.
16. If a cache file cannot be read or decoded, delete or quarantine that file, log the failure, and continue with a re-fetch attempt.
17. If the local Overpass endpoint returns non-200 responses, treat them as retriable source failures with clear logging and user-visible failure text when all retries are exhausted.
18. If the app successfully assembled a valid graph but no route is found after bounded expansion, raise `RoutePlanningException` and preserve the current explicit straight-line segment fallback behavior.
19. If the failure is a route-graph source/cache/load problem, raise `RouteGraphLoadException`, do not commit a segment, and show inline retry UI in the route draft surface.

**Edge Cases:**
20. Deduplicate overlapping fetches for the same cache key or tile set so multiple route requests do not stampede the local endpoint.
21. Handle partially overlapping bounds through the chosen fixed tile scheme, not ad hoc raw bbox filenames.
22. Ensure route planning near tile boundaries loads intersecting tiles plus a one-tile neighbor ring so routeability is not lost at chunk edges.
23. Keep in-memory graph growth bounded by assembling a fresh request-scoped graph per route request from selected tiles rather than accumulating a long-lived statewide graph in app memory.
24. Route requests with extremely large bounds must clamp or tile work rather than issuing one unbounded local Overpass query.

**Validation:**
25. All source responses must be validated for top-level object shape, `elements` presence, and non-empty usable routing content before caching or graph assembly.
26. Bounds computation must be deterministic and testable via injected expansion policy and cache key strategy.
27. Endpoint configuration for this iteration must use a hardcoded app default plus provider/constructor injection for tests and development overrides; persisted endpoint settings UI is out of scope.
28. All route-graph payload decode and graph-assembly work must run off the UI isolate. Only cache metadata and small control-flow bookkeeping may stay on the main isolate.
</requirements>

<boundaries>
Edge cases:
- First route after cold start: app may need to fetch route-area chunks, but it must not preload the whole Tasmania graph first.
- Rapid repeated route attempts in the same area: app should reuse in-flight or cached chunk results instead of duplicate fetch/build work.
- Route spanning a long distance: app should expand a segment corridor or stitch fixed tiles progressively, not request an unconstrained statewide graph.
- Route with endpoints near tile borders: graph assembly must include neighboring tiles needed for connectivity.

Error scenarios:
- Local Overpass offline: route creation remains enabled, the route request fails fast with a retryable route-graph error when cache is missing, and cached data continues to work where present.
- Corrupt cached tile: app removes or ignores the bad tile and re-fetches before failing the route request.
- Incomplete Overpass result: app rejects the tile rather than routing over a known-incomplete graph silently.
- No path after bounded expansion: app preserves the current explicit straight-line segment fallback and exposes the fallback state already tracked by the route-draft UI.

Limits:
- Query expansion must have explicit max attempts or max radius to prevent runaway local requests.
- Cache retention must define size or age limits so route-graph storage does not grow without bound.
- Background parsing and graph build work must always run off the UI isolate for route-graph payloads.
</boundaries>

<discovery>
Before implementation, confirm these code-level decisions through inspection and a small spike:
1. Lock the fixed tile zoom level and neighbor-ring policy used for cache selection and test fixtures.
2. Inspect `trip_routing` and implement request-scoped graph assembly from selected tiles without relying on naive `Graph.addNode()` merges that would wipe adjacency for duplicate node IDs.
3. Spike `Isolate.run` or equivalent background assembly around route-graph decode/build so the UI thread contract is proven before broad rollout.
4. Confirm the exact Settings copy and result dialogs for `Validate Route Graph Source` and `Clear Route Graph Cache`.
</discovery>

<implementation>
Modify or create the following files:
- `./lib/services/route_graph_source.dart` new abstraction for bounds-based Overpass fetches and source validation.
- `./lib/services/local_overpass_route_graph_source.dart` concrete local endpoint implementation.
- `./lib/services/route_graph_store.dart` replace snapshot semantics with tile-based cache/index management, request-scoped graph assembly, and in-flight deduplication.
- `./lib/services/route_graph_cache.dart` or adjacent helper for cache keying, file layout, retention, and corruption handling.
- `./lib/services/route_planner.dart` request graph data for segment bounds, apply expansion retry policy, and preserve the existing straight-line fallback only for `RoutePlanningException` no-path outcomes.
- `./lib/providers/route_graph_readiness_provider.dart` remove the startup full-graph gate or reduce it to lightweight cache/source health only; route creation must not be disabled by statewide preload work.
- `./lib/providers/route_planner_provider.dart` inject the new source/store dependencies.
- `./lib/screens/map_screen.dart` keep the create-route action enabled after startup, surface first-request loading in the draft UI, and surface inline retry for `RouteGraphLoadException` failures.
- `./lib/screens/settings_screen.dart` replace the current refresh tile with `Validate Route Graph Source` and `Clear Route Graph Cache`, including confirm/result/error states.
- `./lib/services/route_graph_refresh_service.dart` replace statewide refresh semantics with local source validation and cache maintenance as appropriate, or rename/remove the service if the old concept no longer matches the feature.
- `@../trip_routing/lib/src/services/trip_service.dart` add a clean public seam for assembling a request-scoped graph from multiple selected Overpass tile payloads without mutating one long-lived statewide graph.
- `@../trip_routing/lib/src/models/graph.dart` add any deduplication helpers needed so duplicate nodes or undirected edges from overlapping tiles do not erase previously attached edges.
- `./test/services/` add unit coverage for source fetch, cache behavior, bounds expansion, and failure handling.
- `./test/widget/` update route UI and settings tests for the new non-preload behavior.
- `./test/robot/` add or update critical routing/cache journeys.

Use the established patterns:
- Riverpod provider injection and constructor seams already used across services/providers.
- Local writable cache patterns used elsewhere in the repo for asset or support-directory storage.
- Existing `RouteGraphLoadException` error style for route-graph-specific failures.

Avoid:
- Querying raster tiles directly for routing data.
- Issuing public Overpass requests from normal route-planning flows.
- Reintroducing a silent straight-line or bbox-network fallback when local route graph loading fails. Straight-line fallback remains allowed only for explicit `RoutePlanningException` no-path results after bounded expansion.
- Keeping one unbounded global statewide graph in memory once bounds-based loading exists.
</implementation>

<stages>
Phase 1: Source abstraction and request-scoped loading.
- Add `RouteGraphSource` and `LocalOverpassRouteGraphSource`.
- Route one segment request by fetching an Overpass payload for computed bounds and building a temporary graph from that payload.
- Keep this phase intentionally simple even if it rebuilds the graph per request.
- If the legacy asset seam is temporarily retained for development migration, keep it injectable and non-default.
- Verify a route request can succeed without touching `assets/highway.json`.

Phase 2: Disk cache and bounds reuse.
- Add deterministic fixed-tile cache keying, on-disk tile storage, corruption handling, and in-flight request deduplication.
- Reuse cached tiles for repeated nearby route requests.
- Verify offline routing succeeds for previously cached areas.

Phase 3: Multi-chunk graph assembly and expansion retry.
- Add request-scoped graph assembly from multiple cached/fetched tiles and neighbor-aware coverage at tile boundaries.
- Deduplicate duplicate nodes and undirected edges during assembly before they enter `Graph`, and never rely on naive repeated `Graph.addNode()` calls for overlaps.
- Add bounded area expansion when the initial segment corridor is insufficient.
- Verify routes spanning multiple tiles succeed and edge-boundary routes no longer fail spuriously.

Phase 4: UI/settings migration and legacy path removal.
- Remove full-statewide preload assumptions from readiness/UI.
- Replace the old refresh action with local source validation and cache clearing flows.
- Remove or isolate the final dependency on bundled `assets/highway.json`.
- Verify the route UI no longer waits on a statewide graph warmup and the legacy bundle is no longer required for normal routing.
</stages>

<validation>
Use strict vertical-slice TDD. Implement one failing test at a time, then the minimal code to pass it, then refactor only after green. Prefer fakes over mocks except at true external boundaries such as HTTP.

Required unit/business-rule coverage:
1. Source fetch builds the correct Overpass query for normalized bounds and returns validated decoded payloads.
2. Non-200, malformed JSON, missing `elements`, and empty usable results fail with route-graph-specific errors.
3. Fixed-tile cache keys are deterministic for equivalent segment corridors and deduplicate overlapping requests as designed.
4. Cached tile read success, corruption recovery, and re-fetch behavior are covered.
5. Route bounds expansion policy retries in the expected order and stops at explicit limits.
6. Transitional legacy fallback seam, if retained during migration, is covered explicitly and removable once final stage is complete.
7. Request-scoped graph assembly is covered for duplicate nodes, duplicate edges, adjacent tiles, and boundary-crossing routes.
8. Failure taxonomy is covered explicitly:
   - `RouteGraphLoadException` yields no committed segment and retryable route-draft error UI.
   - `RoutePlanningException` after bounded expansion yields straight-line fallback and fallback state.

Required widget coverage:
9. Map route creation is no longer disabled by a full-graph preload state alone.
10. First segment request loading, retryable route-graph failure, no-path straight-line fallback, and success states are surfaced correctly in the route UI.
11. Settings route-graph management reflects the new source/cache semantics, including validate success/failure and clear-cache confirm/result/error flows.

Required robot-driven journey coverage:
12. Happy path: user opens map, starts route creation, app fetches or reuses local route-area graph data, and route planning succeeds.
13. Cached path: user repeats a nearby route and the journey succeeds without another source fetch.
14. Recovery path: user hits a route-graph source failure, sees the failure state, retries after source recovery, and route planning succeeds.

Required selectors and deterministic seams:
15. Add stable keys only where needed for new route-loading/error/cache-management UI states, including retry and validate/clear-cache actions.
16. Inject source endpoint, cache directory, clock, expansion policy, and any background parse/assembly seam so tests remain deterministic.
17. Keep robot tests key-first and avoid timers/network flakiness by using fake sources and explicit completion controls.

Performance validation:
18. Measure and report route-request latency from segment-request start to route-draft state update before and after Phase 1 and Phase 2.
19. Verify UI remains responsive during route-graph decode/build work by keeping those operations off the UI isolate.
</validation>

<done_when>
The work is done when normal route planning no longer depends on eagerly loading bundled `assets/highway.json`, one route-draft segment request fetches or reuses only the graph tiles needed for that segment, cached route areas can be reused offline, route-graph source/cache/load failures surface as retryable route-graph errors with no committed segment, no-path results after bounded expansion preserve the explicit straight-line fallback behavior, route creation no longer waits on a statewide preload, Settings exposes `Validate Route Graph Source` and `Clear Route Graph Cache`, and automated tests cover the logic, UI, and critical routing journeys described above.
</done_when>
