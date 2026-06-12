<goal>
Move trail rendering off the raw route-graph query/decode path by precomputing simplified trail display geometry during route-graph import and persisting it with each route-graph generation.
This improves map responsiveness for hikers and route-planning users who already use the `Show Trails` overlay, especially during repeated pan and zoom interactions.
</goal>

<background>
Flutter app using Riverpod, flutter_map, ObjectBox, and a bundled ObjectBox-backed route graph.
The current trail overlay works functionally, but `MapScreen` rebuilds visible trail polylines from raw route-graph chunk payloads during viewport updates. That path currently re-filters trail ways, selects intersecting chunks, decodes chunk JSON, rebuilds node maps, and creates styled `Polyline` objects inside the map build tree.

Relevant current behavior:
- `@lib/screens/map_screen.dart` calls `buildVisibleTrails(...)` from inside the viewport-driven `ValueListenableBuilder`.
- `@lib/services/route_graph_trail_service.dart` decodes raw chunk payloads and rebuilds trail geometry on each call.
- `@lib/services/route_graph_query_service.dart` already provides the trail filter and chunk bounds logic.
- `@lib/services/route_graph_import_service.dart` already performs route-graph generation preparation in an isolate, making it the right seam for one-time trail display preprocessing.

Files to examine:
- @lib/screens/map_screen.dart
- @lib/screens/map_screen_layers.dart
- @lib/providers/route_graph_trail_provider.dart
- @lib/services/route_graph_trail_service.dart
- @lib/services/route_graph_query_service.dart
- @lib/services/route_graph_import_service.dart
- @lib/services/route_graph_repository.dart
- @lib/services/track_display_cache_builder.dart
- @lib/models/route_graph_chunk.dart
- @lib/models/route_graph_manifest.dart
- @lib/models/route_graph_way_index.dart
- @test/services/route_graph_import_service_test.dart
- @test/services/route_graph_query_service_test.dart
- @test/services/route_graph_repository_test.dart
- @test/services/route_graph_trail_service_test.dart
- @test/widget/map_screen_layers_test.dart
- @test/robot/map/map_route_journey_test.dart
</background>

<discovery>
Before implementation, confirm the smallest reusable seam for simplification and encoded segment storage.
Answer this through code inspection before writing production code:
1. Whether `TrackDisplayCacheBuilder` can be extracted into a reusable geometry simplifier/encoder without forcing tracks and trails into an overly broad abstraction.

The rest of this spec assumes persisted way identity, chunk-level `RouteGraphChunk` bounds for viewport selection, and reuse of the existing generation/manifest flow with schema mismatch forcing rebuild rather than reuse.
</discovery>

<stages>
1. Add persisted trail display cache storage and generation metadata.
Verify with repository/storage tests that active-generation reads and stale-generation pruning include the new cache rows.
2. Precompute trail display cache rows during route-graph import.
Verify with import-service tests that only matching trail ways are cached, caches are created for each required zoom, and schema-bumped generations import successfully.
3. Switch runtime trail rendering to cached rows.
Verify with query/trail-service tests that viewport reads use cached rows only, preserve dedupe, and build the same styled polylines.
4. Keep map UX unchanged while removing runtime raw-graph rebuilds.
Verify with widget and robot coverage that enabling trails, panning, zooming, and refresh behavior still work from the user perspective.
</stages>

<user_flows>
Primary flow:
1. User enables `Show Trails` from the existing map UI.
2. App loads cached trail display geometry for the active route-graph generation, current zoom, and visible chunk bounds.
3. User pans and zooms the map and trails remain visible without rebuilding geometry from raw route-graph payloads.

Alternative flows:
- Returning user: previously enabled trails restore and render from the cached trail display generation without additional import-time work unless the route graph changes.
- Route graph refresh: app replaces the active generation and the trail overlay transparently switches to the new generation's cached display data.
- Empty viewport: trails stay enabled but no visible trail polylines are returned for the current chunk set.

Error flows:
- Route graph import fails: the previous active generation and its trail display cache remain active if one exists.
- Cached trail display rows are missing or malformed for the active generation: trails fail closed for that frame/query only, and the rest of the map stays interactive.
- Route graph unavailable: while the route graph is preloading, the existing trail controls remain enabled under the current readiness rules but trails do not render until readiness becomes ready; if route graph loading fails, the existing trail controls remain disabled and continue showing the current helper text.
</user_flows>

<requirements>
**Functional:**
1. Add a persisted trail display cache model stored in ObjectBox and keyed to route-graph generation.
2. Store trail display cache rows separately from raw `RouteGraphChunk` payloads so raw route-graph data and simplified display geometry remain independent.
3. Each persisted trail display cache row must be keyed strongly enough to support active-generation reads and stale-generation pruning.
4. The persisted cache shape must be by zoom plus chunk, not by zoom for the whole network.
5. Precompute trail display cache rows during `RouteGraphImportService` generation preparation, inside the existing background preparation path.
6. Apply the exact existing trail source filter when deciding which ways enter the cache:
   - include `highway=footway` rows with `lengthMeters > 500` and `tagCount > 1`
   - include all `highway=path` rows
   - exclude `access=private`, `surface=concrete`, `surface=asphalt`, `surface=paved`, `surface=paving_stones`, `footway=sidewalk`, `foot=no`, and `route=mtb`
   - do not include `highway=track` in this iteration
7. Precompute simplified trail geometry for a bounded zoom range of 6 through 18, matching the current track display cache range unless code inspection proves a better fit.
8. Runtime trail rendering must resolve visible chunk keys from active `RouteGraphChunk` bounds metadata and read persisted trail display cache rows for geometry by active generation, effective cache zoom, and visible chunk keys.
9. The normal visible-trails path must not scan all active `RouteGraphWayIndex` rows or decode `RouteGraphChunk.payloadJson` during pan/zoom rendering.
10. Runtime trail rendering must continue to dedupe overlapping trail geometry where the same way appears in multiple overlapping chunks.
11. The cache format must retain enough identity to support deterministic dedupe at runtime without falling back to raw chunk payload inspection.
12. Each cached trail payload must preserve way-level identity.
   - The default contract is a row payload containing one or more cached way records.
   - Each cached way record must include `osmWayId` and its simplified point list for that zoom.
   - Runtime dedupe must operate on that persisted way identity before styling expands the way into two polylines.
13. Trail styling must remain the current dual-stroke green-plus-dashed-black visual unless a small cache-driven adjustment is explicitly documented and tested.
14. `MapScreen` must pass both visible bounds and effective zoom into the trail display path, and runtime cache selection must use `effectiveCacheZoom = zoom.round().clamp(minSupportedZoom, maxSupportedZoom)` unless code inspection proves a different rule is required.
15. `RouteGraphImportService.bootstrapIfNeeded()` must compare `manifest.schemaVersion` to the importer schema version before reusing an active generation and must rebuild through the normal import path instead of reusing a mismatched generation.
16. Route graph schema version must be bumped so existing stored generations are rebuilt with the new cache shape instead of silently reusing incomplete older generations.
17. Route graph generation pruning must remove stale trail display cache rows alongside stale chunks and stale way-index rows.

**Error Handling:**
18. If import-time trail cache generation fails, the overall route-graph import must fail rather than silently activating a partially cached generation.
19. If bundled refresh fails after a usable generation exists, keep the previous active generation and its trail cache active, matching existing refresh safety behavior.
20. If a runtime trail cache row cannot be decoded, fail closed for trails only and keep the rest of the map interactive.
21. If no trail cache rows exist for the active generation and requested viewport, return an empty trail layer rather than throwing.

**Edge Cases:**
22. Chunk overlap must not cause duplicate visible trail strokes when adjacent chunks are selected together.
23. Zoom changes must choose a stable cache zoom using explicit rounded-then-clamped selection within the supported trail cache zoom range.
24. Rapid pan/zoom updates must not trigger regeneration, JSON decode of raw chunks, or stale-generation mixing.
25. Route graph refresh must not mix cache rows from multiple generations in a single visible trail result.
26. Trail cache storage must scale with the existing chunking strategy; avoid a design that requires the full trail network to be materialized for every viewport read.

**Validation:**
27. The implementation must include baseline automated coverage for import-time cache generation, repository/query behavior, runtime trail rendering behavior, and the user-visible trail overlay journey.
28. The implementation must follow vertical-slice TDD: one failing behavior at a time, minimum code to pass, refactor only after green.
29. Tests must exercise public seams such as repository reads, query services, trail services, and map UI behavior rather than private helper internals.
</requirements>

<boundaries>
Edge cases:
- Active generation exists but a requested zoom has no cache rows: clamp or return empty consistently; do not regenerate at runtime.
- Cache rows include the same full simplified way geometry from neighboring chunks: dedupe by persisted identity before building visible polylines.
- Empty or filtered-out trail dataset: import succeeds, cache may be empty, and the overlay remains usable but renders nothing.

Error scenarios:
- Schema mismatch with previously stored route graph: importer bootstrap/reuse logic must detect the mismatch before reusing the active generation and must rebuild through the normal import/bootstrap path.
- Partial cache decode failure at runtime: contain the failure to trails only and avoid crashing map interactions.
- Refresh failure with an existing active generation: preserve the current generation and its trail cache exactly as today.

Limits:
- Do not add a second external trail data source or live Overpass dependency.
- Do not implement a backward-compatibility path for pre-cache stored generations; the schema bump is the reset mechanism.
- Do not adopt a whole-network-at-each-zoom cache because it shifts too much geometry back into runtime rendering and memory pressure.
- Do not change the existing `showTrails`-triggered route-graph prefetch unless implementation work shows that it directly conflicts with the cached visible-trails path; removing raw route-graph decode from that toggle-triggered warmup is out of scope for this spec.
</boundaries>

<implementation>
Files to create or modify:
- `./lib/models/route_graph_trail_display_chunk.dart` or a similarly named dedicated cache entity
- `./lib/models/route_graph_manifest.dart` if schema-handling helpers or manifest comparisons need to be made explicit there
- `./lib/services/route_graph_repository.dart`
- `./lib/services/route_graph_import_service.dart`
- `./lib/services/route_graph_query_service.dart`
- `./lib/services/route_graph_trail_service.dart`
- `./lib/providers/route_graph_trail_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/objectbox.g.dart` after model regeneration
- `./test/services/route_graph_import_service_test.dart`
- `./test/services/route_graph_repository_test.dart`
- `./test/services/route_graph_query_service_test.dart`
- `./test/services/route_graph_trail_service_test.dart`
- `./test/widget/map_screen_layers_test.dart`
- `./test/robot/map/map_route_journey_test.dart` or a neighboring robot test if that is where the trail journey belongs

Patterns to use:
- Keep generation preparation in the existing isolate-based route-graph import path.
- Persist display cache rows as first-class route-graph generation data.
- Reuse the existing chunk grid and bounds query pattern so trail viewport loading stays aligned with the route graph.
- Extend the existing `RouteGraphPreparedGeneration` and `RouteGraphStorage` seam rather than bypassing it with repository-only special cases.
- Update both `ObjectBoxRouteGraphStorage` and `InMemoryRouteGraphStorage` so production and test persistence paths stay aligned.
- Expose trail display cache query fields as first-class persisted columns so active-generation reads can query by `generation`, `cacheZoom`, and `chunkKey` without full-box scans or payload inspection.
- Prefer a small shared simplification helper only if it clearly reduces duplication without obscuring the current track cache code.

Recommended data shape:
- One trail display cache row per `generation`, `chunkKey`, and cache zoom.
- Each row stores a list of cached way records, where each cached way record includes `osmWayId` plus the encoded simplified points for that zoom.
- When a way is duplicated into overlapping chunks, each cached record stores the full simplified geometry for that way at that zoom rather than a chunk-clipped fragment.
- Keep encoded payloads compact and decode-friendly for map runtime use.

Runtime expectations:
- Query visible chunk keys using the existing viewport/buffer logic against active `RouteGraphChunk` bounds metadata.
- Convert the current map zoom into `effectiveCacheZoom = zoom.round().clamp(minSupportedZoom, maxSupportedZoom)` before reading cache rows.
- Use active `RouteGraphChunk` bounds metadata only to resolve visible chunk keys; do not decode raw chunk payload JSON in the visible trail path.
- Fetch matching trail display cache rows directly by active generation, effective cache zoom, and visible chunk keys.
- Do not scan all active `RouteGraphWayIndex` rows in the normal visible trail path.
- Dedupe by persisted trail identity.
- Convert cached points into the existing dual-stroke `Polyline` output.

What to avoid:
- Avoid re-reading raw route-graph chunk payloads during pan/zoom because that is the current performance problem.
- Avoid storing trail display cache inside `RouteGraphChunk.payloadJson`; mixing raw graph and display cache makes import, testing, and future maintenance harder.
- Avoid broad new abstraction layers unless they are clearly justified by reuse with the existing track cache builder.
</implementation>

<validation>
Follow vertical-slice TDD.
Each slice must start with one failing test, then the minimum implementation, then refactor after green.

Behavior-first slices:
1. Repository/storage slice: active-generation route graph reads include the new trail display cache rows and stale generations are pruned.
2. Import slice: matching trail ways are transformed into persisted zoom-plus-chunk display cache rows during generation preparation.
3. Query slice: viewport and zoom queries return only active-generation trail display cache rows and preserve chunk/buffer behavior.
4. Dedupe/render slice: runtime trail service builds styled polylines from cached rows only and removes overlap duplicates deterministically.
5. UI/journey slice: enabling trails still shows the overlay, and pan/zoom continues to show trails through the cached path.

Required automated coverage:
- Unit tests for route-graph import preparation covering trail filter inclusion/exclusion, zoom cache creation, stable identity persistence, and malformed input handling.
- Import-service tests covering schema-version mismatch detection in `RouteGraphImportService.bootstrapIfNeeded()` and rebuild-on-mismatch behavior.
- Repository/storage tests covering active-generation reads and pruning of trail display cache rows.
- Query-service tests covering bounds selection, zoom clamping, empty results, and generation isolation.
- Trail-service tests covering cache decode, dedupe, style preservation, and the absence of raw chunk decode dependency in the normal path.
- Widget tests covering trail layer presence and removal through the existing `show-trails` UI.
- Robot-driven coverage for at least one critical journey using stable keys such as `show-trails-fab`, `show-trails-switch`, and `trail-polyline-layer`.

Testability seams:
- Keep in-memory route-graph storage usable for the new cache entity so service tests stay deterministic.
- Keep generation preparation injectable through the existing `generationPreparer` seam for import tests.
- Require importer test doubles that emit prepared-generation maps to either include the new trail cache list or rely on parser logic that explicitly defaults a missing trail cache list to empty during early TDD slices.
- Require route-graph test stores, fake repositories, and robot fixtures that exercise trail rendering to seed trail display cache rows directly rather than relying on raw chunk decode behavior.
- If a shared simplification helper is extracted, keep it pure and synchronous so it can be exercised directly in unit tests.

Focused UI assertion scope:
- Keep `map_screen_layers_test.dart` limited to deterministic layer-construction assertions such as stable keys and direct polyline output.
- Put screen-level behavior such as enable, disable, pan, zoom, and refresh into existing map-screen widget tests or robot journeys rather than overloading the layer helper test.

Residual risk to report explicitly if not covered:
- Very large trail networks at the highest supported zoom may still be paint-heavy even after runtime decode work is removed.
- If dashed overlay rendering cost dominates after caching, a later follow-up may need a tile-based or rasterized trail overlay strategy.
</validation>

<done_when>
- Trail display geometry is precomputed during route-graph import and persisted in ObjectBox by generation, chunk, and zoom.
- The active trail overlay no longer depends on raw route-graph chunk decode during normal pan/zoom rendering.
- Trail filter behavior and trail styling remain functionally equivalent to the current overlay.
- Generation refresh and stale-generation pruning handle trail display cache rows correctly.
- Automated tests cover import, repository/query behavior, runtime trail rendering, and at least one end-to-end trail overlay journey.
- The spec can be implemented without adding backward-compatibility support for older pre-cache stored route-graph generations.
</done_when>
