<goal>
Add a walking-trails overlay to the map screen so route planners can quickly see likely footpath corridors while planning routes.
This is for hikers and route-planning users who already use the map view; the feature should feel like the existing Tracks/Routes controls, restore its previous visibility, and render a clearly distinguishable dual-stroke trail style.
</goal>

<background>
Flutter app using Riverpod, flutter_map, ObjectBox, and the bundled route graph store.
The existing map control patterns, layer stack, and route graph plumbing already exist and should be reused rather than duplicated.

Files to examine:
- @lib/screens/map_screen.dart
- @lib/screens/map_screen_layers.dart
- @lib/widgets/map_action_rail.dart
- @lib/widgets/map_tracks_routes_drawer.dart
- @lib/providers/map_provider.dart
- @lib/providers/route_graph_readiness_provider.dart
- @lib/providers/route_planner_provider.dart
- @lib/services/route_graph_query_service.dart
- @lib/services/route_graph_repository.dart
- @lib/theme.dart
- @test/widget/map_action_rail_grouping_test.dart
- @test/widget/map_screen_track_info_test.dart
- @test/widget/map_screen_route_info_test.dart
- @test/services/route_graph_query_service_test.dart
</background>

<discovery>
Before implementing, confirm the smallest reusable seam for trail lookup and rendering.
Answer these through code inspection:
- How to map the source overpass-style trail filter onto active ObjectBox route-graph rows and viewport chunks.
- Whether trail geometry can reuse existing route-graph payload handling, or needs a small companion service that decodes active chunks into drawable polylines.
- Whether trail visibility should persist beside `showTracks` and `showRoutes` using the same shared-preferences pattern.
</discovery>

<stages>
1. Add trail visibility state, persistence, and UI controls.
Verify with a widget test that the new toggle restores and changes state.
2. Add route-graph query/filter support and map-layer rendering.
Verify with a service test and a map-layer widget test.
3. Add styling and journey coverage.
Verify with a robot-driven map flow test and a focused styling assertion.
</stages>

<user_flows>
Primary flow:
1. User taps `Show Trails` from the map action rail or opens the Tracks/Routes drawer and enables trails there.
2. App marks trails visible, keeps the drawer/rail state in sync, and queries the active route graph for matching ways in the current viewport.
3. App renders the trails as a thick green line with a dashed black line over it, above the base map and below the other map overlays.

Alternative flows:
- Returning user: previously enabled trails restore automatically on startup.
- Route graph unavailable: the trail control is disabled.
- Route graph loading: the trail control is disabled while preloading.
- Empty viewport match: the control stays usable, but the map renders no trail geometry.

Error flows:
- Route graph refresh/bootstrap failure: trails stay disabled until the graph becomes usable again.
- Trail query/render failure for the current viewport: fail closed for trails only; keep the rest of the map interactive.
</user_flows>

<requirements>
**Functional:**
1. Add a new `Show Trails` FAB under `Show Tracks/Routes` in `MapActionRail` with key `show-trails-fab`, a distinct `heroTag`, tooltip/message `Show Trails`, and icon `Icons.hiking_outlined`.
2. Add a trail toggle entry in `MapTracksRoutesDrawer`, matching the existing list-tile/switch pattern and using a stable key such as `show-trails-switch`.
3. Persist trail visibility in shared preferences under the `show_trails` key, using the same restore/override behavior used for tracks and routes.
   - Restore trails independently of `show_tracks` and `show_routes`.
4. Render trail geometry as a dedicated map layer above the base map/tasmap layers and below routes, tracks, peaks, and labels.
   - Use a green base stroke plus a black dashed overlay for the trail visual.
   - If a native dashed polyline is not available in the chosen `flutter_map` API, render the dash effect by drawing short black polyline segments over the green base stroke.
5. Resolve trail geometry from the active ObjectBox route graph, not a live Overpass request.
6. Introduce a small trail-display service if needed so filtered route-graph rows/chunks can be decoded into deduped drawable `LatLng` segments.
   - The service must decode active chunk payloads into stable polyline segments suitable for `flutter_map` rendering.
   - The service must dedupe overlapping geometry where chunks share the same way data.
   - The service must fail closed for malformed or empty chunk payloads without breaking the rest of the map.
7. Apply the source trail filter exactly:
   - include `highway=footway` rows with `lengthMeters > 500` and `tagCount > 1`
   - include all `highway=path` rows
   - exclude `access=private`, `surface=concrete`, `surface=asphalt`, `surface=paved`, `surface=paving_stones`, `footway=sidewalk`, `foot=no`, and `route=mtb`
   - do not include `highway=track` in this iteration
8. Keep trail rendering gated by the route-graph readiness state so the user cannot enable an overlay when the graph is unavailable.
   - `preloading`: disable the FAB and drawer row, and show `Loading route graph...`.
   - `failed`: disable the FAB and drawer row, and show `Route graph unavailable. Use Refresh Route Graph to retry.`
   - `ready`: enable the FAB and drawer row.
9. Derive trail viewport bounds from the current `flutter_map` camera/visible bounds on `MapScreen`, and refresh on the same debounced viewport-change pattern used for route-graph prefetch.
10. Trigger an immediate trail refresh when trails are enabled or restored, using the current visible bounds, before relying on the debounced viewport-change updates.

**Error Handling:**
1. If trail data cannot be resolved for the active viewport, the app must continue rendering the rest of the map and overlays.
2. If persistence fails, keep the in-memory toggle state and do not surface a blocking error.
3. If route-graph loading fails, leave the trail control disabled until the graph is successfully refreshed.

**Edge Cases:**
1. Repeated taps on the trail FAB or drawer row must not duplicate state transitions or re-open an already-open drawer.
2. Turning trails off while visible must remove the overlay immediately.
3. Trail rendering must remain stable during rapid pan/zoom updates.
4. If the current viewport contains no matching ways, render an empty trail layer rather than an error.
5. Trail styling must not obscure routes, tracks, or peak markers.
6. Trail styling constants should live in `theme.dart` so the map layer and tests can share a single source of truth.
7. Trail viewport queries should use a buffer around the visible bounds so trails remain present near the map edge during normal navigation.

**Validation:**
1. Add behavior-first tests for trail state and persistence, following red-green-refactor one slice at a time.
2. Add service-level tests for the route-graph filter/query logic covering matching ways, excluded tags, length-tag filtering, viewport chunk selection, buffered bounds behavior, and trail geometry decode/dedup/failure handling.
3. Add widget tests for the action rail and drawer covering the new FAB, toggle row, and disabled state.
4. Add a map-screen widget test or robot journey test that proves the trail overlay appears and disappears through the real user flow.
5. Verify trail layer ordering and styling with a focused widget assertion or equivalent deterministic check.
6. Baseline automated coverage must include logic/state, UI behavior, and the critical user journey from control activation to visible overlay.
7. Use deterministic seams for route-graph data, shared preferences, and viewport state so tests do not depend on live network or mutable global state.
</requirements>

<boundaries>
Edge cases:
- Rapid pan/zoom while trails are visible: recompute safely and avoid stale exceptions.
- Empty graph or no visible matches: keep the toggle usable and render nothing.
- Loading vs failure: preserve the existing readiness distinction in disabled state.

Error scenarios:
- Route graph unavailable: disable the trail control.
- Query or decode failure: contain the error and leave the rest of the map interactive.
- Persistence write failure: ignore the write failure for UI purposes.

Limits:
- Use the existing route-graph storage and query infrastructure only; do not add a second source of truth for trail geometry.
- Do not add compatibility shims unless the new trail visibility state must coexist with already-persisted keys.
</boundaries>

<implementation>
Files to create or modify:
- `./lib/providers/map_provider.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/map_tracks_routes_drawer.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/services/route_graph_query_service.dart`
- `./lib/services/trail_display_service.dart` or a similar small companion service if needed
- `./lib/theme.dart`
- `./test/services/route_graph_query_service_test.dart`
- `./test/services/trail_display_service_test.dart` if a new service is added
- `./test/widget/map_action_rail_grouping_test.dart`
- `./test/widget/map_screen_*.dart`
- `./test/robot/map/*.dart` if a robot journey gives the clearest end-to-end coverage

Patterns to use:
- Mirror the existing tracks/routes visibility pattern for state, persistence, and controls.
- Keep the new trail layer isolated from route-planning logic.
- Centralize trail colors and widths in `theme.dart`.

What to avoid:
- Avoid a second query stack or a live Overpass dependency because the app already has the needed route-graph data locally.
- Avoid implementation details that leak into private helpers when public seams already exist.
</implementation>

<validation>
Follow vertical-slice TDD: one failing test at a time, then minimal implementation, then refactor only after green.
Keep tests public-interface driven.

Required coverage:
- Logic/state: trail visibility state, restore, persistence, and readiness gating.
- UI behavior: action rail FAB, drawer row, and disabled state.
- Critical journey: enable trails from the map UI and confirm the overlay appears in the correct layer order, then disable trails and confirm it disappears.

Test seams:
- Use in-memory route-graph storage/repositories for query tests.
- Use mock/shared-preference loaders or test overrides for persistence tests.
- Use stable keys for the new trail FAB, switch, drawer row, and trail layer.

Robot coverage:
- Add one robot-driven map journey for the critical happy path if widget tests do not already cover the full interaction chain.
- Keep selector usage key-first and deterministic.

If a dashed polyline cannot be expressed with a native `flutter_map` primitive, require an explicit test for the chosen visual equivalent.
</validation>

<done_when>
- The map screen exposes a working `Show Trails` control in both the action rail and the Tracks/Routes drawer.
- Trail visibility persists across app restarts.
- Trails render from the active route graph with the specified filter and styling.
- Trails appear in the correct layer order and do not break existing routes/tracks/peak overlays.
- Automated tests cover the query logic, UI toggle, readiness gating, and the critical map journey.
</done_when>
