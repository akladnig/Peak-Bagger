<goal>
Move the bundled `assets/highway.json` route graph into the app's ObjectBox store so routing data is immediately available as local app data, not loaded as one giant runtime asset.
The app should seed and rebuild the route graph from the bundled asset, then serve routing from ObjectBox-backed chunks with a refresh action in Settings that matches the existing maintenance flows.
This matters because the current single-file route graph is too large to load eagerly, and the app needs faster first-route response without adding network dependencies.
</goal>

<background>
Flutter app with Riverpod, ObjectBox, `flutter_map`, and the local `trip_routing` package.

Relevant files to examine:
- `./lib/services/route_graph_store.dart`
- `./lib/services/route_planner.dart`
- `./lib/services/route_graph_refresh_service.dart`
- `./lib/providers/route_graph_readiness_provider.dart`
- `./lib/providers/route_planner_provider.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/main.dart`
- `./lib/models/peak.dart`
- `./lib/models/route.dart`
- `./lib/models/gpx_track.dart`
- `./lib/models/tasmap50k.dart`
- `./lib/services/tasmap_repository.dart`
- `./lib/services/peak_refresh_service.dart`
- `./test/services/route_graph_store_test.dart`
- `./test/services/route_planner_test.dart`
- `./test/widget/route_graph_refresh_settings_test.dart`
- `./test/widget/map_screen_route_entry_test.dart`
- `./test/robot/settings/route_graph_refresh_journey_test.dart`
- `./test/robot/map/map_route_journey_test.dart`

Current constraints:
- `trip_routing.TripService` still consumes Overpass-shaped JSON payloads.
- `trip_routing.TripService.loadOverpassTilePayloads()` already exists and is the intended merge seam.
- The app already uses ObjectBox for peaks, routes, tracks, and Tasmap data.
- Settings already has confirm/loading/result/failure patterns for peak refresh, route-graph validation, map reset, and track reset.
- Route-graph bootstrap is one-time only: import on first launch when no active route graph exists, or when the user manually refreshes. Do not auto-reimport on later launches, including after app updates.
- Startup bootstrap begins only when no active route graph exists. If a usable graph is already present, startup does not re-import or refresh it.
- Bootstrap/import/chunking must run off the UI isolate or an equivalent background worker so the map stays usable while the route graph is being prepared.

Settings copy requirements:
- Replace the existing route-graph validation tile with `Refresh Route Graph`.
- Use the subtitle `Refresh Route Graph Overpass Data`.
- Use `Refresh` for the confirm action copy and reuse the app's existing loading/result/failure pattern.
- Update the failed-state banner copy to `Route graph unavailable. Use Refresh Route Graph to retry.`

Chunking requirements:
- Use a fixed geographic grid for route-graph chunks, not map zoom tiles.
- Use a deterministic chunk key derived from the grid cell coordinates, such as `latBand_lonBand`.
- Use a grid cell size of approximately `5 km x 5 km`.
- Each chunk must include approximately `1 km` of spatial overlap/buffer on every side so routes crossing cell boundaries can still be reconstructed.
- Query by viewport or route corridor expanded by the same `1 km` buffer.
- Deduplicate merged graph input by OSM element identity, not by chunk membership.

Compatibility requirements:
- `schemaVersion` must describe whether the stored graph can be read by the current app code.
- If the stored route graph is incompatible, the app must surface a clear failure and require manual refresh; it must not auto-reimport on startup.
- If a compatible active generation exists, startup continues to use it even after app updates.
</background>

<discovery>
Before implementation, inspect the current route graph size, element distribution, and the best chunking strategy for the bundled graph.
Confirm how the map viewport bounds and route endpoints should drive chunk selection.
Confirm the least disruptive way to seed the ObjectBox route graph during startup while keeping the map usable.
</discovery>

<user_flows>
Primary flow:
1. App starts with no active route-graph generation.
2. Bootstrap imports the bundled `assets/highway.json` into ObjectBox as route-graph chunks and a manifest.
3. The map screen remains usable while bootstrap is running.
4. When the user starts route drafting before bootstrap finishes, the planner waits for the in-flight bootstrap or returns a retryable loading state instead of reading partial data.
5. After bootstrap completes, the planner loads the relevant chunks from ObjectBox and builds a transient `TripService` from those chunks.

Alternative flows:
- Returning user: ObjectBox already contains a ready manifest and chunks, so routing starts from local storage without reimporting the bundled asset.
- Settings maintenance: the user taps `Refresh Route Graph` and the app rebuilds the ObjectBox route data from the bundled asset.
- Map prefetch: moving around the map warms chunks for the visible bounds plus padding, so the next route request is faster.
- App update: the app continues using the existing active route graph after upgrade and does not reimport automatically.

Error flows:
- First-launch import failure: there is no previous generation to preserve, so the app stays in a no-graph failed state, keeps route creation visible, and requires manual refresh from Settings before route planning can succeed.
- Import failure on later launches: the app keeps the previous known-good route graph generation and surfaces a retryable failure in Settings.
- Missing/corrupt route graph records after startup: the app surfaces a failure and requires manual refresh from Settings.
- Partial chunk availability: the planner must not use incomplete graph generations.
- Route request while a rebuild is in progress: use the last active generation or await the current bootstrap if no active generation exists.
</user_flows>

<requirements>
**Functional:**
1. Keep `assets/highway.json` bundled as the seed source for the initial route-graph import and manual rebuilds.
2. Add ObjectBox entities for a route-graph manifest and route-graph chunks.
3. The manifest must store the active generation, schema/version hash, import timestamp, counts, and readiness state needed to identify the current usable graph.
4. Each chunk must store a stable chunk key, the active generation it belongs to, its spatial bounds, and the chunk payload needed to recreate Overpass-shaped input.
5. Route-graph data must be readable by querying only the chunks relevant to a viewport or route corridor, not by loading the full asset on every startup.
6. Route planning must build a transient `TripService` from the selected ObjectBox chunks using `loadOverpassTilePayloads()` or an equivalent merge path.
7. Map viewport movement must prefetch chunks for the visible bounds plus a small buffer, using the same store/repository boundary as route planning.
8. Settings must expose a `Refresh Route Graph` action with the same confirm/loading/result/failure pattern used elsewhere in the app.
9. Refresh must be atomic from the user perspective: if the rebuild fails, the previous active generation remains available.
10. Route creation must stay enabled at startup; route-graph readiness must not gate the create-route button.
11. The route-graph readiness state should describe bootstrap/ready/failed states for Settings and retry UX, not app-wide feature gating.
12. Route-graph import must be deterministic and idempotent for the same bundled asset version.
13. The importer must validate decoded payloads before marking a generation active.
14. Startup must only bootstrap route data when no active generation exists; it must not re-import because the bundled asset version changed.
15. Route planning during bootstrap must either await the in-flight bootstrap or return a retryable loading state; it must never consume partial graph data.
16. After a successful refresh, prune all non-active route-graph generations unless a specific rollback window is explicitly added later.
17. `schemaVersion` must be used to detect read incompatibility; incompatible stored data requires manual refresh and must not trigger automatic startup reimport.
18. Bootstrap/import/chunking must not block the UI isolate.

**Error Handling:**
14. If the bundled asset cannot be decoded or chunked during initial bootstrap or manual refresh, keep the previous generation active and report a readable failure.
15. If the ObjectBox store is empty on first launch, bootstrap from the bundled asset; if it becomes empty or partially populated later, surface a failure and require manual refresh rather than silently rebuilding at startup.
16. If a chunk query returns no usable coverage for a requested route corridor, surface a routing failure that preserves the current draft state.
17. If a refresh is cancelled, make no store changes.

**Edge Cases:**
18. A viewport may intersect multiple chunks; the query layer must merge all intersecting chunks and deduplicate the resulting graph payloads as needed.
19. A route corridor may extend beyond the map viewport; route planning must request additional chunks beyond the prefetch set when required.
20. First launch must not require network access or a local Overpass service.
21. The implementation must not store the entire statewide graph as one ObjectBox string/blob row and call that lazy loading.
22. The implementation must not introduce configurable route-graph endpoints.

**Validation:**
23. Add coverage for the manifest/chunk model, the importer, the chunk query logic, the route-planning integration, and the Settings flow.
24. Keep tests deterministic by using temp directories, fake asset loaders, and in-memory or fake ObjectBox-backed repositories where possible.
25. Use vertical-slice TDD for the new storage and routing behavior so each test fails before its implementation lands.
</requirements>

<boundaries>
Edge cases:
- Empty store on first launch: bootstrap from the bundled asset and expose progress/failure state without disabling route creation.
- Existing store on later launches: keep the current active generation, even if the bundled asset has changed since the previous app version.
- Multiple route-graph generations: only the active generation may be queried for routing.
- Large map pans: chunk prefetch should debounce with camera movement and avoid repeated rebuilds for every frame.
- Refresh during active route drafting: do not discard the current draft state just because the route graph is rebuilding.

Error scenarios:
- Asset decode failure: keep the prior good generation and show a retryable Settings error.
- Chunk validation failure: do not activate the new generation.
- First-launch bootstrap failure: keep route creation visible, surface a no-graph failed state, and require manual refresh from Settings before routing can succeed.
- Store corruption after startup: surface a clear failure in Settings and require manual refresh.
- App update with a newer bundled graph: do not auto-rebuild; require manual refresh if the user wants the newer graph.
- Successful refresh: remove stale generations after the new generation becomes active.
- Incompatible stored schema: keep the app usable where possible and surface a manual refresh requirement in Settings.

Limits:
- No network dependency for route-graph import or refresh.
- No new configurable endpoint URLs or localhost service assumptions.
- No full-state graph rewrite into a single ObjectBox record.
- No automatic route-graph reimport during startup after the first successful bootstrap.
</boundaries>

<implementation>
Create or update these files:
- `./lib/models/route_graph_manifest.dart`
- `./lib/models/route_graph_chunk.dart`
- `./lib/services/route_graph_repository.dart`
- `./lib/services/route_graph_import_service.dart`
- `./lib/services/route_graph_query_service.dart`
- `./lib/services/route_graph_refresh_service.dart`
- `./lib/services/route_planner.dart`
- `./lib/providers/route_graph_readiness_provider.dart`
- `./lib/providers/route_planner_provider.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/main.dart`
- `./test/services/route_graph_repository_test.dart`
- `./test/services/route_graph_import_service_test.dart`
- `./test/services/route_graph_query_service_test.dart`
- `./test/services/route_planner_test.dart`
- `./test/widget/route_graph_refresh_settings_test.dart`
- `./test/widget/map_screen_route_entry_test.dart`
- `./test/robot/settings/route_graph_refresh_journey_test.dart`
- `./test/robot/map/map_route_journey_test.dart`

Recommended data model:
- `RouteGraphManifest`: one row per import generation, with `sourceHash`, `schemaVersion`, `activeGeneration`, `importedAt`, `chunkCount`, `nodeCount`, `edgeCount`, and a ready/failed state marker.
- `RouteGraphChunk`: one row per spatial chunk, with `chunkKey`, `generation`, bounds (`minLat`, `minLon`, `maxLat`, `maxLon`), payload, and element counts.

Implementation approach:
- Treat the bundled asset as the import source only.
- Build chunks during seed/refresh into a new generation first, then switch the manifest pointer to the new active generation only after validation succeeds.
- Query chunks by visible bounds or route corridor, then merge payloads into a transient `TripService` for each routing request.
- Keep route-graph warmup separate from route-creation gating.
- Reuse existing confirm/loading/result/failure UI patterns in Settings.

What to avoid:
- Avoid loading `assets/highway.json` directly in the route planner.
- Avoid a single huge ObjectBox blob for the entire graph.
- Avoid tying route drafting enablement to route-graph readiness.
- Avoid adding network configuration to solve an offline storage problem.
- Avoid startup version checks that trigger an automatic route-graph rebuild.
</implementation>

<stages>
1. Add the ObjectBox route-graph entities and repository. Verify the model can represent generations and chunk bounds.
2. Implement the importer and validation path from `assets/highway.json` into a new generation. Verify failure does not activate broken data and that startup bootstraps only when no active generation exists.
3. Implement chunk queries and route-planner integration. Verify a route request loads only relevant chunks and builds a transient `TripService`.
4. Wire viewport prefetch into the map screen and the refresh action into Settings. Verify the UI keeps route creation enabled and reports refresh status correctly.
5. Add coverage for the critical journeys. Verify route drafting still works before and after a route-graph rebuild.
</stages>

<validation>
Use vertical-slice TDD:
- Write one failing test at a time.
- Keep each green step minimal.
- Refactor only after the current behavior is green.

Baseline automated coverage outcomes:
- Logic/business rules: unit tests for manifest/chunk modeling, importer generation switching, and chunk query selection.
- UI behavior: widget tests for the Settings refresh flow, loading state, success/failure dialog copy, and map prefetch seams.
- Critical journeys: robot-driven coverage for rebuilding the route graph from Settings and then creating a route from the map.

Required test slices:
1. Model slice: add tests for manifest/chunk serialization or construction rules.
2. Import slice: add tests that the bundled asset is chunked into a new active generation, that a failed rebuild leaves the previous generation active, and that startup does not reimport when a usable generation already exists.
3. Query slice: add tests that visible bounds or route corridors select the expected chunk set.
4. Planner slice: add tests that the route planner builds a transient `TripService` from queried chunks and reports a useful failure when no usable coverage exists.
5. Settings slice: add widget tests for the route-graph refresh confirm dialog, loading state, success dialog, and failure dialog.
6. Map slice: add widget coverage for viewport-triggered prefetch behavior and ensure route creation remains enabled while route graph bootstrap is pending.
7. Journey slice: add or extend robot tests under `./test/robot/settings/` and `./test/robot/map/` that rebuild the route graph, return to the map, and create a route successfully.

Stable selectors and seams:
- Keep stable keys for the route-graph settings tile(s), confirm buttons, loading indicator, and status text.
- Keep the route create button key stable so the journey test can prove route creation is still enabled.
- Add constructor injection for the asset loader, ObjectBox store/repository, and any generation clock/hash seams needed for deterministic tests.
- Add a bootstrap guard seam so startup can distinguish `missing graph` from `existing graph` without comparing bundle versions.
- Use fakes and temp stores instead of real bundled-asset reads where the behavior under test is the importer or planner logic.

Expected behavior per test type:
- Unit tests should prove the storage model and generation switching are correct without UI.
- Widget tests should prove the settings flow and viewport prefetch/UI state do not regress.
- Robot tests should prove the user can rebuild the route graph and still draft a route from the map afterward.
</validation>

<done_when>
The app stores route-graph data in ObjectBox as an active manifest plus spatial chunks, seeded from the bundled `assets/highway.json` source.
Routing reads from ObjectBox-backed chunks, map movement can prefetch the visible area, and Settings provides a working refresh path that preserves the last good graph on failure.
After the first successful bootstrap, startup never auto-reimports the route graph, even when the app updates; the user must use the manual refresh action to replace the stored graph.
The automated test suite covers storage, query, planner, UI, and end-to-end route-graph refresh journeys.
</done_when>
