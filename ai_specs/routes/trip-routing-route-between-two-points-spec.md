<goal>
Add a route-drafting flow on the map screen that uses `trip_routing` to calculate and display a pedestrian route between selected points.
The user should be able to enter route mode, tap a start point, tap a second point to create a routed segment, and continue extending the route with additional taps that append more segments.
<background>

The app is a Flutter project using `flutter_map` on the main map screen. Current map state and movement live in `./lib/providers/map_provider.dart`, map layers live in `./lib/screens/map_screen_layers.dart`, and the screen shell lives in `./lib/screens/map_screen.dart`.

The route entry control already exists as in `./lib/widgets/map_action_rail.dart` with key `create-route-fab` and asset `assets/route.svg`. The route entry surfaces a bottom sheet which lives in `./lib/widgets/map_route_bottom_sheet.dart`

This feature must use `trip_routing: ^0.0.13`. The package fetches OSM data over the network, so production code needs an app-owned adapter and deterministic test seam.

Files to examine:
- `./pubspec.yaml`
- `./lib/main.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/providers/map_provider.dart`
- `./lib/widgets/map_action_rail.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/tasmap_map_screen_test.dart`
- `./test/widget/map_screen_route_entry_test.dart` as a camera/navigation persistence reference, not as a route-feature precedent
- `./test/harness/test_map_notifier.dart`
- `./test/robot/map/map_camera_journey_test.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`
</background>

<discovery>
Before implementing, confirm the smallest code change that supports the chosen route flow in the existing map UI.

Questions to answer through code inspection:
- How should route mode integrate with the existing `onPointerUp` click path without regressing non-route interactions when route mode is inactive?
- What is the smallest render seam for route endpoint markers, provisional segment lines, and committed route polylines?

Patterns to identify:
- How `MapNotifier` uses optional constructor injection with fallback provider resolution.
- How `flutter_map` layers are assembled and ordered.
- How current tests override `mapProvider` or construct `MapNotifier(...)` with injected dependencies.
- Are the current route draft markers and lines in map-screen to be replaced so all route visuals derive from `route.colour`?
    if (routeChrome.isRouteDrafting) {
      notifier.addRouteDraftMarker(tappedLocation);
      return;
    }
</discovery>

<user_flows>
Primary flow:
1. User presses the existing `create-route-fab` control in `./lib/widgets/map_action_rail.dart`.
2. App enters route mode.
3. User taps the map to choose a start point; app shows a route-coloured circular endpoint marker.
4. User taps a second point; app shows a second route-coloured endpoint marker, draws a solid provisional line in `route.colour` between the last committed point and the new point, and requests a routed segment from `trip_routing`.
5. When the segment succeeds, app replaces the provisional segment with the routed polyline segment using the same `route.colour`, shows cumulative route distance in km with one decimal place in the bottom sheet, and keeps route mode active.
6. User taps a third point; app appends another segment from point 2 to point 3 using the same provisional-line then routed-segment behavior.
7. User presses `Save` in the bottom sheet to finalize the drafted route, exit route mode, restore normal map click behavior, set `showRoutes = true`, and keep the saved route visible.

Alternative flows:
- User presses `Cancel` before choosing a second point: discard the start point, clear route draft UI, exit route mode, and restore normal map click behavior.
- User presses `Cancel` after one or more successful segments: clear the drafted route and all route markers, exit route mode, and restore normal map click behavior.
- User uses View-group actions during route mode: route mode remains active unless the user later presses `Cancel` or `Save`.

Error flows:
- Routing fails or returns no usable segment: keep the chosen route markers visible, keep the last successful routed polyline visible, remove any stale provisional segment, and surface an error message.
- The network is unavailable: fail gracefully with a clear route error and leave the rest of the map usable.
- A segment request completes after `Cancel`, `Save`, route-mode exit, or a later retry attempt has already advanced draft state: ignore the stale result and keep only the current route draft state.
</user_flows>

<requirements>
**Functional:**
2. Add an explicit route-drafting state machine in `MapState` and `MapNotifier` with, at minimum, `inactive`, `awaitingStart`, `awaitingNextPoint`, `routingSegment`, and `segmentFailure` states.
3. Route mode must remain active after each successful segment so a third tap appends another segment from the current route endpoint to the newly tapped point.
4. Route endpoints must use dedicated route state and must not reuse `selectedLocation`.
6. Each route endpoint tap must render a route-coloured circular marker. The first tap creates the first marker. Each subsequent accepted tap adds another route-coloured marker.
7. After each new endpoint tap beyond the first, app must draw a solid provisional line in `route.colour` between the last committed route point and the newly tapped point while the segment request is in flight.
8. On segment success, app must replace the provisional line with the routed polyline segment returned by `trip_routing`.
9. Segment calculation must call `trip_routing` through an app-owned adapter that validates the installed `trip_routing: ^0.0.13` API and maps it to a narrow `RoutePlanner` contract.
10. Show cumulative route distance in km with one decimal place after a successful route or route extension. Duration is out of scope.
11. `Save` finalizes the current route draft, exits route mode, restores normal map click behavior, sets `showRoutes = true`, and keeps the saved route visible.
12. `Cancel` is the clear action: it exits route mode and clears any in-progress or drafted route state.
13. The route name is entered into the text box. On `Save`, the app trims leading and trailing whitespace, preserves the human-readable name, and saves it to the ObjectBox entity `Route`.
14. The existing `Straight Line` button remains visible in the bottom sheet during this slice but must be disabled. `trip_routing` is the only route-calculation implementation in scope.
15. After a successful segment, persist cumulative route distance into `Route.distance2d` in meters when the draft is saved, and format that stored value to km with one decimal place in the bottom sheet UI.
16. `Save` must persist the committed routed polyline geometry into `Route.gpxRoute` and build `displayRoutePointsByZoom` from that committed routed geometry rather than from tapped endpoint markers.
17. Route endpoint markers, provisional segment lines, committed routed lines, and the final saved route must all use `route.colour`. For this slice `route.colour` remains hardcoded to red; a future route-colour picker is out of scope.

**Interaction Rules:**
17. While route mode is active, primary taps on empty map space, peaks, or tracks must be interpreted only as route-point selection; they must not open peak popups, select tracks, clear tracks, or update `selectedLocation`.
18. Existing hover behavior may remain active during route mode, but hover must not commit route state or open new popups.
19. Secondary tap/right-click on the map must not change route state and must not trigger selected-location recentering while route mode is active.
20. Route mode must not add any new keyboard shortcuts. `Esc` must not exit route mode or mutate route draft state, but it may continue dismissing unrelated higher-priority surfaces such as drawers.
21. Pressing `create-route-fab` enters route mode.

**Error Handling:**
22. If routing fails, preserve the chosen route markers, keep the last successful routed polyline visible, and surface a non-blocking inline route error in the bottom sheet.
23. If the returned trip or segment is empty, treat it as a routing failure unless the product explicitly chooses to allow zero-length segments.
24. If the user selects an identical start and end point for a segment, reject it as a recoverable segment failure, keep the previous successful route visible, remove any provisional segment, and surface the same inline route error affordance used for other segment failures.
25. Route requests must use a monotonically increasing request id or equivalent token so late async results cannot commit after `Cancel`, `Save`, route-mode exit, or a later retry has already advanced state.
26. Do not mutate persisted camera state, track selection, or peak-selection state as a side effect of route calculation.

**Persistence And Exit Behavior:**
27. Route state must survive widget rebuilds and navigation within the current app session through `mapProvider`, but must not be persisted across app restarts.
28. Draft route geometry, provisional lines, request ids, and inline route errors are transient session state only.
29. `Save` persists the final committed routed geometry and metadata to the `Route` entity.
30. Normal map click behavior must resume only when the user presses `Cancel` or `Save`.
31. Cancelling after only one selected point must discard that start point.

**Validation:**
32. Validate that each route segment request receives exactly two waypoints in the expected order: the last committed route point followed by the newly tapped point.
33. Validate that route state updates are deterministic and do not require the real Overpass API in tests.
34. Validate that user-visible route errors are recoverable by retrying with a new point or pressing `Cancel`.
35. Validate that the saved route persists the cumulative routed distance into `Route.distance2d`.
36. Validate that the saved route persists the committed routed polyline into `Route.gpxRoute` and derives `displayRoutePointsByZoom` from that routed geometry.
</requirements>

<interaction_matrix>
When route mode is inactive:
- Existing map interaction behavior stays unchanged.

When route mode is `awaitingStart`:
- Primary map tap: set first route-coloured endpoint marker and move to `awaitingNextPoint`.
- Peak tap: treat as route-point selection only.
- Track tap: treat as route-point selection only.
- Hover: may remain active.
- Secondary tap/right-click: no-op for route state.
- `Esc`: may dismiss unrelated higher-priority surfaces but must not exit route mode or mutate route draft state.
- `Cancel`: clear draft and exit route mode.

When route mode is `awaitingNextPoint`:
- Primary map tap: create next route-coloured endpoint marker, draw provisional line in `route.colour` from the last committed point, and move to `routingSegment`.
- Peak tap: treat as route-point selection only.
- Track tap: treat as route-point selection only.
- Hover: may remain active.
- Secondary tap/right-click: no-op for route state.
- `Esc`: may dismiss unrelated higher-priority surfaces but must not exit route mode or mutate route draft state.
- `Cancel`: clear draft and exit route mode.
- `Save`: disabled until the trimmed route name is non-empty and at least one successful routed segment exists, then finalizes the current drafted route and exits route mode.

When route mode is `routingSegment`:
- Ignore additional route-point taps until the in-flight segment resolves, fails, or route mode exits.
- Keep View-group actions available.
- `Esc`: may dismiss unrelated higher-priority surfaces but must not exit route mode or mutate route draft state.
- `Cancel`: clear draft and exit route mode.
- `Save`: disabled until the trimmed route name is non-empty and the in-flight segment resolves.

When route mode is `segmentFailure`:
- Keep the last successful routed polyline visible.
- Keep route markers visible.
- Next primary tap retries by attempting a new next segment from the last committed point.
- `Esc`: may dismiss unrelated higher-priority surfaces but must not exit route mode or mutate route draft state.
- `Cancel`: clear draft and exit route mode.
- `Save`: finalize only the last successful route state and exit route mode, but remain disabled if the trimmed route name is empty or there is no successful routed geometry yet.
</interaction_matrix>

<boundaries>
Edge cases:
- Same start and end point: reject it as a recoverable segment failure; do not treat it as a zero-length segment in this slice.
- Very short routes: ensure the route overlay still renders if the service returns only a few points.
- Empty or malformed segment output: keep the previous good route visible, remove the provisional segment, and show the new failure state.
- Third and later taps: append one segment at a time from the current route endpoint to the newly tapped point; do not attempt multi-waypoint batch routing in a single request.

Error scenarios:
- Overpass or package failure: show a route error and leave the rest of the map usable.
- Package-level exception: catch and convert it to app-level route failure state instead of surfacing an uncaught exception.
- Route request finishes after cancel/exit/retry has already advanced state: ignore the stale result completely.

Limits:
- Do not add driving, cycling, or transit routing.
- Do not implement a functional straight-line route-calculation path in this slice; keep the existing control visible but disabled.
- Do not add a route-colour picker in this slice; `route.colour` stays hardcoded to red for now.
- Do not persist unsaved draft geometry; only `Save` persists the final committed routed geometry to `Route`.
- Do not refactor unrelated map layers, peak rendering, or track rendering.
</boundaries>

<implementation>
Implement the feature in small layers:
- Add `trip_routing: ^0.0.13` to `./pubspec.yaml` and verify the installed `0.0.13` API from code before wiring the adapter.
- Add a routing abstraction under `./lib/services/` that owns the `trip_routing` dependency.
- Add a `routePlannerProvider` for app wiring.
- Extend `MapNotifier` with optional constructor injection `MapNotifier({RoutePlanner? routePlanner})`, then resolve `injected ?? ref.read(routePlannerProvider)` in `build()` to match current repo patterns.
- Extend `MapState` and `MapNotifier` in `./lib/providers/map_provider.dart` with route mode, endpoint markers, provisional segment state, committed route polyline state, bottom sheet metadata state, `showRoutes` enable-on-save behavior, and request-id handling.
- Add route polylines and endpoint markers in `./lib/screens/map_screen_layers.dart` or a small adjacent helper.
- Keep all route visuals derived from `route.colour`; for this slice reuse the existing hardcoded red route colour and do not add colour-selection UI.
- Wire the FAB behavior in `./lib/widgets/map_action_rail.dart`, disable the existing `Straight Line` control in `./lib/widgets/map_route_bottom_sheet.dart`, and route-point tap handling in `./lib/screens/map_screen.dart`.
- Route behavior should be triggered from route state changes and exposed with stable keys for loading, distance, error, cancel, and save elements.
- Replace the current hard-coded bottom-sheet metric placeholders with real routed distance text and explicit loading/error states; do not continue showing fake ascent/descent values.

Use the existing map/provider patterns already in the app:
- Keep external network calls behind injectable interfaces.
- Keep route rendering separate from route calculation.
- Prefer the smallest state surface that supports the journey.
- Align test seams with current notifier construction and provider override patterns used in `./test/harness/test_map_notifier.dart`, `./test/widget/map_screen_route_entry_test.dart`, and `./lib/main.dart`.

Avoid:
- Calling `trip_routing` directly from the widget tree.
- Baking network access into widget or robot tests.
- Replacing the human-readable route name with a dashed slug in persisted `Route.name`.
</implementation>

<layer_order>
Inside `FlutterMap`, order route visuals explicitly:
1. Existing non-route overlays such as selected peaks, Tasmap polygons, tracks, peak markers, and labels remain below route visuals.
2. Route provisional line and committed routed polyline render above selected-location marker position, selected peaks, Tasmap polygons, tracks, peak markers, and labels.
3. Route endpoint markers render above the route lines and above peaks and tracks.

Outside `FlutterMap`, route metadata/actions are shown via bottom sheet UI and are not part of map-layer ordering.
</layer_order>

<stages>
Phase 1: Service and state seam
- Add `RoutePlanner`, provider wiring, constructor injection, and request-id handling.
- Add the explicit route state machine and prove it with fake-driven tests.

Phase 2: Route-mode interaction
- Implement the route interaction matrix, including `Esc` preserving route draft state while still allowing unrelated higher-priority surface dismissal, and right-click no-op.

Phase 3: Visual route drafting
- Add route-coloured endpoint markers, a provisional line in `route.colour`, and committed routed polyline rendering.

Phase 4: Continuation and recovery
- Support third and later taps appending one segment at a time.
- Preserve the last successful route on failure.
- Finalize save/cancel semantics and route-mode exit behavior.

Phase 5: Test stabilization
- Add deterministic unit, widget, and robot coverage.
- Verify no regressions in existing map click and overlay behavior when route mode is inactive.
</stages>

<illustrations>
Desired:
- First tap shows one route-coloured start marker.
- Second tap shows a second route-coloured marker, a provisional segment in `route.colour`, then the routed segment once loaded in the same colour.
- Third tap extends the route from point 2 to point 3 rather than restarting the draft.
- `Save` exits route mode and leaves the route visible.
- `Cancel` clears the draft or current drafted route and restores normal map behavior.

Undesired:
- Route mode silently reuses the amber `selectedLocation` marker as an endpoint.
- Peak popups or track selection fire while the user is drafting a route.
- `Esc` dismisses route mode.
- A failed later segment wipes out the last successful route.
</illustrations>

<validation>
Use TDD discipline for the route state machine and service boundary:
- Start with one failing unit test for the route-planner adapter.
- Add one failing notifier or widget test for the route-mode state machine.
- Implement the minimum code to pass each test before moving to the next slice.
- Prefer fakes over mocks for the routing service boundary.

Required automated coverage outcomes:
- `unit` or logic: route planner adapter, request-id stale-result handling, state-machine transitions, two-point segment request ordering, and error-to-state mapping.
- `widget`: map screen route-mode entry, enabled View group, route-coloured endpoint markers, provisional line in `route.colour`, committed routed polyline, loading/distance/error states, and save/cancel behavior.
- `robot`: a critical map journey that enters route mode, creates at least two segments via three taps, and finalizes with `Save`.

Deterministic seams required:
- Injectable `RoutePlanner` interface.
- `routePlannerProvider` override support.
- Stable keys for `create-route-fab`, `route-loading-text`, `route-distance-text`, `route-error-text`, `route-cancel-button`, `route-save-button`, and any route-clear state the tests must observe.
- A fake route response for tests with fixed points and distance.

Robot coverage location:
- Add or extend robot coverage under `./test/robot/map/`.
- Preferred files: `./test/robot/map/map_route_robot.dart` and `./test/robot/map/map_route_journey_test.dart`.

Recommended test split:
- Robot: happy-path route drafting with continuation from point 2 to point 3 and final save.
- Widget: cancel-before-second-point, route-mode interaction matrix, bottom sheet loading/error/save-disabled state changes, disabled action groups, and empty-route handling.
- Unit: service wrapper, request-id handling, state transitions, `Route.distance2d` persistence, and committed routed-geometry persistence.

- Verify with the relevant Flutter test subset for the route feature, then run the broader map test lane if the pointer interaction or overlay ordering changes.
- Include `./test/widget/map_screen_keyboard_test.dart` in the route-feature test subset because `Esc` behavior and route-name focus are part of the route-mode contract.
</validation>

<done_when>
The feature is complete when the app can enter route mode from the existing route FAB, draft a route through successive taps using `trip_routing` one segment at a time, show route-coloured endpoint markers and provisional/committed route lines, use bottom sheet based save/cancel metadata UI, preserve the last successful route on later failure, restore normal map behavior only on save or cancel, and pass new unit/widget/robot coverage without using the live routing service in tests.
</done_when>
