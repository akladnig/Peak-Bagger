<goal>
Own the route graph snapshot locally. Load the packaged snapshot during app startup, keep a parsed `TripService`/graph cached in memory for the session, and let Settings refresh that snapshot from a dedicated route-graph Overpass source so route planning can use updated data without restarting the app.
This matters because the first route creation must feel immediate, so the app needs a warm in-memory graph instead of parsing `highway.json` on demand.
</goal>

<background>
The app is a Flutter/Riverpod map application.

Relevant files to examine and align with:
@./lib/services/route_planner.dart
@./lib/providers/route_planner_provider.dart
@./lib/providers/map_provider.dart
@./lib/screens/settings_screen.dart
@./lib/services/route_elevation_sampler.dart
@./lib/services/peak_refresh_service.dart
@./lib/services/overpass_service.dart
@./lib/main.dart
@./assets/highway.json
@./pubspec.yaml
@./test/services/route_planner_test.dart
@./test/widget/peak_refresh_settings_test.dart
@./test/robot/peaks/peak_refresh_journey_test.dart

Current state:
- `TripRoutingRoutePlanner` currently loads `assets/highway.json` and `OverpassRoutePlannerFallback` still exists in `./lib/services/route_planner.dart`.
- `lib/providers/route_planner_provider.dart` already wires `TripRoutingRoutePlanner` with `NoopRoutePlannerFallback`, so production behavior is already local-only; the remaining gap is graph lifecycle, refresh, and cache invalidation.
- `SettingsScreen` already has the confirm -> loading -> result/failure pattern for `Refresh Peak Data`.
- `BundledDemRouteElevationSampler` shows the app pattern for copying a bundled asset into writable local storage.
- `MapNotifier` injects and caches the route planner, so refresh must update the store that the planner reads from.
- The route-graph path should preload the parsed graph once at startup and reuse that warm in-memory service for the whole session.
- Route creation must remain disabled until preload completes so the first route action never pays the parse cost.
- The app needs an explicit route-graph readiness state so the UI can gate route actions without guessing from planner initialization timing.
- `MapNotifier._planRouteDraftSegment()` currently turns some planning failures into straight-line fallback, so graph-load failures need a dedicated error path instead of generic exception handling.
</background>

<discovery>
Before implementing, confirm the route-graph storage lifecycle and the reload seam.

Questions to answer through code inspection:
- Where should the mutable runtime copy of `highway.json` live so Settings can refresh it without touching the bundled asset directly?
- What startup seam should eagerly load the parsed route graph so the first route creation does not pay the parse cost?
- What is the smallest seam to reload the cached route graph after a successful refresh?
- What full-snapshot Overpass source should generate the packaged route graph, and how does it differ from the start/end bbox query used by route-segment fallback?
</discovery>

<user_flows>
Primary flow:
1. App starts and loads the local route-graph snapshot.
2. User opens Settings and taps `Refresh Route Graph`.
3. App asks for confirmation.
4. User confirms and sees a loading state.
5. App fetches the route graph from Overpass using the dedicated full-snapshot route-graph query.
6. App validates the response, writes `highway.json`, and reloads the route-graph cache.
7. Success feedback appears, and later route planning requests use the refreshed data.

Alternative flows:
- User cancels the confirmation dialog: no fetch, no write, no cache reload.
- User reopens Settings after a successful refresh: the tile is idle and the refreshed data remains active.
- Local graph is missing or invalid at startup: route planning fails with a clear route-graph error, but the rest of the app remains usable.

Error flows:
- Network unavailable, non-200 response, malformed JSON, empty graph, write failure, or cache reload failure all leave the previous valid graph untouched and surface a refresh failure.
</user_flows>

<requirements>
**Functional:**
1. Remove the bbox-based Overpass fallback path from route planning. `TripRoutingRoutePlanner` must use only local graph data and must not try a network fallback when planning a route.
2. Add a local route-graph storage abstraction under `./lib/services/` that persists the runtime copy at `getApplicationSupportDirectory()/route_graph/highway.json`, loads that file on startup, and seeds it from the bundled asset if the file does not exist.
3. Bundle the seed `highway.json` with the app so the local snapshot is available on first launch.
4. Add `Refresh Route Graph` to `SettingsScreen` using the same confirmation, loading, result, and failure pattern as `Refresh Peak Data`.
5. Refresh must use this exact full-snapshot route-graph query:

   ```sql
   [out:json];
   way["highway"](-43.643,143.833,-39.579,148.482);
   out body;
   >;
   out skel qt;
   ```

   This query must be the source of truth for the bundled snapshot shape and the refresh path.
6. The route-graph store must own the cached decoded graph or `TripService`, preload it during startup, and refresh must call a concrete `reload()`/`refresh()` seam after a successful write so future route requests see the updated graph.
7. Route creation must remain disabled until preload completes so the first route action cannot trigger lazy parsing.
8. Add an explicit route-graph readiness provider/state that exposes `preloading`, `ready`, and `failed` states and is the source of truth for gating route actions.
9. Remove any on-demand env-var or bundled-asset loading path from normal route planning. The route-graph store must be the only source of route graph data after startup preload completes.
10. If the local snapshot is missing, invalid, or cannot be parsed, route planning must fail with a clear `RouteGraphLoadException` (or equivalent typed route-graph error) instead of silently falling back to Overpass or straight-line routing.
11. If refresh fetches zero usable graph elements, treat it as a failure and keep the previous graph.

**Error Handling:**
12. Refresh failures must not clear the previous valid graph.
13. If refresh succeeds but write or reload fails, surface that as a failure and keep the previous graph.
14. `MapNotifier._planRouteDraftSegment()` must not convert a route-graph load failure into a straight-line fallback; that error must surface distinctly.

**Edge Cases:**
15. Repeated taps on the refresh tile while a refresh is in progress must be ignored.
16. A route computation already in flight when refresh completes may finish against the snapshot it started with; later route requests use the refreshed snapshot.
17. If startup preload fails, route actions remain disabled, the route-graph readiness state becomes `failed`, and Settings refresh remains available as the recovery path.

**Validation:**
18. Validate the route planner never calls Overpass during normal route requests.
19. Validate the refresh flow uses the exact route-graph query, writes the snapshot, and reloads the cache.
20. Validate startup loads the local snapshot path and handles malformed data deterministically.
21. Validate a malformed or missing graph does not get downgraded to straight-line routing.
22. Validate failed startup preload keeps route actions disabled until a successful refresh or reload.
</requirements>

<boundaries>
Edge cases:
- First launch without a writable local snapshot: seed from the bundled asset before route planning starts.
- Route creation before preload finishes: keep route controls disabled and do not accept route actions.
- Malformed `highway.json`: show a route-graph error and keep the rest of the app usable.
- Empty refresh result: no overwrite.
- Refresh in progress: disable the tile and ignore extra taps.

Error scenarios:
- Network unavailable: show refresh failure dialog.
- Overpass returns non-200 or malformed JSON: refresh fails and the local graph stays unchanged.
- Cache reload fails after write: refresh fails and the local graph stays unchanged.
- Route graph load failure while drafting a route: surface a clear error instead of inserting a straight line.
- Startup preload still in progress: route controls remain disabled until the graph is warm.

Limits:
- Do not keep the old bbox-based Overpass fallback in any route-planning path.
- Do not add automatic background refresh.
- Do not change route rendering or map interaction behavior in this slice.
- Do not alter the peak refresh flow beyond reusing its UI pattern.
</boundaries>

<implementation>
Modify or create the following files:
- `./lib/services/route_planner.dart` remove the bbox fallback from `TripRoutingRoutePlanner`; keep the local graph loading path explicit and deterministic.
- `./lib/providers/route_planner_provider.dart` stop wiring the removed fallback and keep the local-only wiring.
- `./lib/providers/map_provider.dart` add or route through a concrete route-graph error state so graph-load failures are not converted into straight-line fallback. Distinguish `RouteGraphLoadException` from ordinary routing failures.
- `./lib/providers/route_graph_readiness_provider.dart` or an adjacent provider/state seam to expose `preloading`, `ready`, and `failed` states to the route UI.
- `./lib/screens/settings_screen.dart` add the Refresh Route Graph tile, status state, and confirmation/result/failure dialogs.
- `./lib/services/route_graph_refresh_service.dart` or similar new service that uses the full route-graph Overpass source and persists the refreshed graph.
- `./lib/services/route_graph_store.dart` or similar new storage/cache abstraction for the local `highway.json` snapshot, including a concrete `preload()` and `reload()`/`refresh()` seam owned by the store. The store should be the single owner of the cached `TripService` and must clear/rebuild that cache on refresh.
- `./lib/main.dart` or the route-graph provider build path if startup needs to preload the graph before the app becomes interactive.
- `./pubspec.yaml` only if an asset or storage dependency path needs to be declared.
- `./test/services/route_planner_test.dart` update for the no-bbox-fallback behavior and graph-error behavior.
- `./test/services/route_graph_refresh_service_test.dart` add service coverage.
- `./test/widget/route_graph_refresh_settings_test.dart` add Settings UI coverage.
- `./test/robot/settings/route_graph_refresh_journey_test.dart` add the critical user journey.

Use the established app patterns:
- `PeakRefreshService` and the Settings refresh tile pattern for confirmation and status handling.
- `BundledDemAssetCache` as the reference for copying a bundled asset into writable local storage.
- `LocalFileTripRoutingClient` should not be used as an on-demand loader path for the app’s route graph once the startup preload/store path exists.
- Riverpod provider injection and test overrides already used across the repo.

Avoid:
- Direct Overpass calls from widgets.
- Silent runtime fallback to the network when the local graph is missing.
- Introducing a second, parallel route format.
</implementation>

<stages>
Phase 1: Route graph storage and planner loading.
- Add the local snapshot abstraction, seed-copy behavior, startup preload, and no-bbox-fallback planner path.
- Add a dedicated route-graph error state so malformed or missing graph data does not get converted to straight-line routing.
- Verify unit tests cover startup loading and malformed-data failure.

Phase 2: Refresh service and Settings UI.
- Add the refresh service, wire the Settings tile, and reload the route graph cache after a successful refresh.
- Verify widget tests cover confirm/cancel/loading/success/failure states.

Phase 3: End-to-end validation.
- Add robot coverage for the Settings refresh journey.
- Verify a route request after refresh uses the updated graph.
</stages>

<validation>
Use behavior-first TDD slices for the storage and refresh logic.

Required automated coverage outcomes:
- Logic/business rules: local graph load, malformed JSON handling, refresh success/failure, cache reload, no bbox fallback on route requests, and route gating while preload is pending.
- Logic/business rules: local graph load, malformed JSON handling, refresh success/failure, cache reload, no bbox fallback on route requests, route gating while preload is pending, and readiness state transitions.
- UI behavior: the Settings tile, confirm dialog, loading state, success dialog, failure dialog, and busy-state disabling.
- Critical journeys: refresh route graph from Settings and then use the updated graph in a route-planning request.

Test expectations:
1. Start with a failing unit test for loading the local graph without network access.
2. Add a failing unit test for startup preload so the parsed graph is ready before the first route request.
3. Add a failing unit test for refresh success writing the graph and invalidating or reloading cache state.
4. Add a failing unit test for refresh failure preserving the previous graph.
5. Add a failing unit test or widget test that proves a graph-load failure does not get turned into a straight line.
6. Add widget tests for the Settings flow before wiring the final implementation.
7. Add a robot-driven journey that opens Settings, confirms refresh, waits for success, and verifies the new status.
8. Prefer fakes or injected services over mocks for the graph store and Overpass boundary.
9. Keep tests deterministic by injecting the storage path, HTTP client, startup preload seam, readiness seam, and any cache invalidation seam.
10. Add stable keys for `refresh-route-graph-tile`, `route-graph-refresh-cancel`, `route-graph-refresh-confirm`, `route-graph-refresh-status`, `route-graph-refresh-result-close`, and `route-graph-refresh-error-close`.

Do not consider the work complete unless tests verify that normal route requests never contact Overpass and refresh updates the live local graph.
</validation>

<done_when>
The work is done when route planning loads only from a local `highway.json` snapshot, that snapshot is preloaded into a warm in-memory graph during startup, route creation stays disabled until preload completes, startup failure leaves route actions disabled but retryable from Settings, Overpass is used only by the manual Settings refresh action, the refresh action updates the live graph without restarting the app, route-graph load failures surface as errors instead of straight-line fallback, and the new Settings journey is covered by automated tests.
</done_when>
