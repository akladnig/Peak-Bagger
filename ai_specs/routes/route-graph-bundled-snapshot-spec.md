<goal>
Use the bundled `assets/highway.json` route graph as the only route-graph source, keep route creation enabled at startup, and validate that snapshot from Settings without any endpoint configuration or network fetches.
</goal>

<background>
Tech stack: Flutter, Riverpod, Dart IO, custom `trip_routing` package.

Current architecture:
- `@./lib/services/route_graph_store.dart` seeds and loads the bundled `assets/highway.json` snapshot.
- `@./lib/providers/route_graph_readiness_provider.dart` no longer blocks route creation on preload.
- `@./lib/providers/route_planner_provider.dart` reads the bundled store through the route planner.
- `@./lib/services/route_planner.dart` maps route results and preserves the existing no-path straight-line fallback behavior.
- `@./lib/services/route_graph_refresh_service.dart` validates the bundled route graph snapshot from Settings.
- `@../trip_routing/lib/src/services/trip_service.dart` owns the graph load and routing primitives.

Relevant constraints:
- `TripService.loadOverpassJson()` still expects Overpass-shaped JSON with `elements`.
- The map UI must remain usable before any graph warmup completes.
- Settings validation should not introduce endpoint configuration, persisted source settings, or network requirements.
</background>

<user_flows>
Primary flow:
1. User opens the map and can start route drafting immediately.
2. The first route segment request loads the bundled route graph if needed.
3. The route UI shows a loading state while that segment is being planned.
4. If route planning succeeds, the segment is committed.
5. If route graph loading fails, the draft remains editable and exposes inline retry.

Settings flow:
1. User opens Settings and taps `Validate Route Graph Snapshot`.
2. The app validates the bundled `assets/highway.json` snapshot.
3. The app shows success or failure without requiring any route-graph endpoint.
</user_flows>

<requirements>
1. The bundled `assets/highway.json` snapshot remains the default route-graph source.
2. No route-graph code may reference configurable endpoint URLs or localhost services.
3. `RouteGraphStore` continues to own loading and validation of the bundled snapshot.
4. Route creation stays enabled at startup.
5. The first route segment may show loading, but the create-route button itself must not be gated on preload readiness.
6. `RouteGraphLoadException` failures must keep the draft editable and show an inline retry path.
7. `RoutePlanningException` no-path outcomes still preserve the explicit straight-line fallback behavior.
8. Settings must provide a validate action that confirms the bundled snapshot can be loaded.
9. Validation success and failure copy must be stable and covered by tests.
</requirements>

<validation>
1. Route creation works without a startup preload gate.
2. Route graph loading failures surface as retryable draft errors.
3. No-path still falls back to straight-line behavior.
4. Settings validation reports success and failure for the bundled snapshot.
5. Robot journeys cover the map route flow and the settings validation flow.
</validation>

<done_when>
The work is done when the app uses only the bundled `assets/highway.json` snapshot for route planning, route creation is enabled at startup, Settings validates that bundled snapshot, no route-graph code references configurable endpoints or localhost services, and the test suite covers the route and settings journeys.
</done_when>
