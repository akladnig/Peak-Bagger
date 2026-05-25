<goal>
Add nearest-edge on-track detection to `trip_routing` and update `peak_bagger` route drafting so off-track taps become a normal straight-line/rejoin state instead of a permanent routing-error fallback.
Users drafting a route should be able to leave the routable graph temporarily, keep drawing straight segments until they rejoin, and then resume snapped routing automatically on the following segment without seeing a false routing error.
</goal>

<background>
`peak_bagger` is a Flutter app that drafts routes through `MapNotifier` state in `./lib/providers/map_provider.dart`, presents route controls in `./lib/widgets/map_route_bottom_sheet.dart`, and adapts `trip_routing` through `./lib/services/route_planner.dart`.

Map interaction and route-draft rendering also flow through `./lib/screens/map_screen.dart` and `./lib/screens/map_screen_layers.dart`. Any control-endpoint versus display-marker split in state must be reflected explicitly in those rendering files.

The app uses a separate local `trip_routing` path dependency declared in `./pubspec.yaml`, so this slice spans two workspaces: `peak_bagger` and the local `trip_routing` dependency checkout.

`peak_bagger` stores raw Overpass JSON snapshots and rebuilds the routing graph from those snapshots through `RouteGraphStore` and the local `trip_routing` dependency's `TripService.loadOverpassJson(...)` path. This slice must keep that app snapshot format compatible; any new source-edge provenance required for projected-anchor routing should be derived during graph construction from raw Overpass way/node relationships rather than by introducing a new persisted graph snapshot format. This slice also preserves backward-readable compatibility for `trip_routing`'s existing `Graph.loadGraph/saveGraph()` JSON format: older saved graph JSON without provenance fields must remain loadable with backward-compatible defaults, but loaders may normalize legacy edge records into the corrected in-memory graph representation rather than preserving legacy duplicate-edge behavior.

Current behavior conflates three different outcomes:
- true infrastructure/data failures
- graph-loaded but unroutable `noPath` results
- taps that are simply off the route graph and should enter temporary straight-line mode

Current `MapNotifier.routeDraftStraightLineFallback` is sticky: once a segment fails, every later tap stays straight forever. This must be replaced with state that means the draft is currently off-track and is probing each new tap for rejoin eligibility.

The active routing-mode buttons in the bottom sheet currently do not provide the requested `inactive` / `active` / `selected` state model. This spec adds `active` purple and `selected` green button states, while route geometry remains the existing red route colour.

This slice is scoped to a dedicated two-waypoint segment-routing API used by `peak_bagger`. It does not redesign mixed-status aggregation for generic multi-waypoint `trip_routing` `Trip` calls.

Files to examine:
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/services/route_planner.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`
- `./lib/core/constants.dart`
- `./test/providers/route_draft_state_test.dart`
- `./test/services/route_planner_test.dart`
- `./test/widget/map_screen_route_sheet_test.dart`
- `./test/harness/test_map_notifier.dart`
- `./test/robot/map/map_route_robot.dart`
- `./test/robot/map/map_route_journey_test.dart`
- `trip_routing: lib/trip_routing.dart`
- `trip_routing: lib/src/models/trip.dart`
- `trip_routing: lib/src/services/trip_service.dart`
- `trip_routing: lib/src/models/graph.dart`
- `trip_routing: test/trip_routing_test.dart`
</background>

<user_flows>
Primary flow:
1. User enters route drafting in `snapToTrail` mode and taps a start point and a second point.
2. `trip_routing` classifies each endpoint against the nearest graph edge, not just the nearest node.
3. If the segment start point is within `RouteConstants.maxSnapDistanceMeters` of a graph node, snap that start point to the nearest node, move the draft marker to that node, and start the segment from that anchored marker position.
4. Otherwise, if the start point is on-track but not within threshold of a node, anchor it to a new projected point on the nearest edge at the shortest distance, create a synthetic marker at that anchor, and start the segment from that anchor.
5. Apply the same anchoring rules to the segment end point: if it is within threshold of a node, snap it to that node and move the end marker there; otherwise, if it is on-track but not within node threshold, anchor it to the nearest projected edge point and move the end marker to a synthetic marker at that anchor.
6. If both endpoints are within `RouteConstants.maxSnapDistanceMeters`, the segment routes normally and is appended as snapped geometry from the chosen anchors.
7. Internal routed vertices returned by snapped routing remain geometry-only in this slice; they must not appear as route-draft markers or become next-segment control endpoints.
8. While a segment request is in flight, the provisional route UI keeps the raw tapped endpoint marker and provisional straight line visible; committed anchor-based marker movement happens only when the request resolves.
9. For `RouteMode.routeToPeak`, the visible peak marker remains fixed at the peak coordinate throughout loading and must not jump to a nearby anchor while the request is in flight.
10. User taps a later point that is farther than the threshold from the nearest graph edge.
11. App treats that segment as `offTrack`, appends a straight segment, keeps the route draft active, and enters temporary off-track mode without setting `routeDraftError`.
12. While off-track mode is active, each new tap is still classified against the graph.
13. If a later tap is still off-track or produces `noPath`, app appends another straight segment and stays in off-track mode.
14. When a tap is back within threshold, that rejoin segment is still appended as a straight segment, and if the endpoint is on-track because of that tap, the straight segment must end at the chosen anchor and the tapped marker must move to that anchor.
15. After appending that rejoin segment, app exits off-track mode.
16. The next segment after rejoin uses snapped routing again.

Alternative flows:
- `RouteMode.routeToPeak` uses the same classification rules for the snapped portion of the segment. If the destination marker is on a peak, that peak marker must not move from the peak coordinate. When a route-to-peak segment needs an on-track anchor near the peak, the routed portion ends at the chosen anchor and the committed segment appends a straight terminal leg from that anchor to the actual peak coordinate.
- If a `routeToPeak` segment is `offTrack` or `noPath`, app still completes that single segment as straight geometry without surfacing a routing error, then resets back to `snapToTrail` as it does today.
- If the user starts in `straightLine` mode, this spec does not change that explicit mode; only snap-to-trail behavior gains temporary off-track/rejoin state.
- If the graph is loaded and the segment is classified on-track but the snapped endpoints still have no path between them, app treats that as normal `noPath` fallback, appends a straight segment, and keeps rejoin probing active.

Error flows:
- If the route graph cannot be loaded or the routing service fails for infrastructure/data reasons, app preserves the current route draft, removes any provisional segment, keeps off-track state unchanged, and surfaces the existing route error path.
- If a stale async segment result arrives after cancel, save, route-mode exit, or a newer request, ignore it completely.
- If the user taps the same point twice for a segment, keep the current recoverable validation failure path and do not classify it as `offTrack`.
</user_flows>

<requirements>
**Functional:**
1. Add nearest-edge endpoint classification in `trip_routing: lib/src/services/trip_service.dart` so each waypoint can be measured against the closest graph edge in meters.
2. Add `RouteConstants.maxSnapDistanceMeters` to `./lib/core/constants.dart` and set it to `50` meters.
3. If a segment start point is within `RouteConstants.maxSnapDistanceMeters` of a graph node, snap that start point to the nearest node before route calculation.
4. When a start point snaps to a node, move the corresponding draft marker to that node and start the segment at that anchored marker position.
5. If a segment start point is not within threshold of a node but is still on-track, anchor it to a new projected point on the nearest edge at the shortest distance and start the segment from that anchor.
6. `peak_bagger` must always pass `RouteConstants.maxSnapDistanceMeters` on every segment-routing request. For this app, the threshold is not optional.
7. `trip_routing` must expose a dedicated exactly-two-waypoint API for this slice, for example `findAnchoredSegment(...)`, instead of overloading the generic multi-waypoint `findTotalTrip(...)` contract.
8. The dedicated two-waypoint API and its segment-result model must be public exports from the local `trip_routing` dependency so `peak_bagger` can depend on them without reaching into package internals.
9. `trip_routing.findTotalTrip(...)` must remain available for existing generic multi-waypoint callers; this slice must not redesign that API.
10. The dedicated segment result surface must distinguish, at minimum, `routed`, `offTrack`, `noPath`, and infrastructure/data-unavailable failure.
11. The dedicated segment result must expose enough minimal anchor metadata for the adapter to keep marker state and next-segment starts consistent.
12. The minimum anchor metadata surface must identify the anchor point and anchor type for each endpoint, with anchor type constrained to `raw`, `node`, or `edgeProjection`.
13. `trip_routing` must also expose a dedicated endpoint-probe API for off-track rejoin evaluation, for example `probeEndpointAnchor(...)`, that classifies only the newly tapped endpoint and returns whether it is on-track plus any anchor metadata needed for a straight rejoin segment.
14. The package-side graph model must retain stable source-edge provenance sufficient to support projected-anchor routing, temporary edge splitting, and same-original-edge detection.
15. Source-edge provenance must be derived during graph construction from raw Overpass way/node relationships; existing raw Overpass JSON snapshots and bundled route-graph JSON inputs used by `RouteGraphStore` and `TripService.loadOverpassJson(...)` must remain compatible without storage migration.
16. Each pair of directed edges derived from one adjacent-node OSM way segment must share a stable internal `originalSegmentId`, deterministically derived from the source way and segment index, so forward and reverse directions of the same physical segment can be matched reliably.
17. Source-edge provenance may remain an internal package implementation detail unless the dedicated segment API needs to expose part of it for deterministic adapter behavior.
17a. `trip_routing`'s existing `Graph.loadGraph/saveGraph()` JSON format must remain backward-readable for this slice; older saved graph JSON without provenance fields must still load successfully, and the loader may normalize legacy edge records into the corrected in-memory graph representation rather than preserving legacy duplicate-edge behavior.
18. Temporary edge splitting for projected anchors must be request-scoped and must not mutate the cached base graph held by `TripService`; any synthetic anchor vertices or edges must exist only for the lifetime of the current segment calculation.
19. For `status == routed`, the segment result geometry must contain the anchored routed geometry, `distance` must contain the routed distance in meters, `errors` must be empty, and both endpoint anchors must be present.
20. For `status == offTrack`, the segment result geometry must be empty, `distance` must be `0`, `errors` must be empty, the start anchor must be present, and the end anchor may be omitted when the endpoint is off-track.
21. For `status == noPath`, the segment result geometry must be empty, `distance` must be `0`, `errors` must be empty, and both endpoint anchors must be present when both endpoints are on-track.
22. For infrastructure/data-unavailable failure, the segment result geometry must be empty, `distance` must be `0`, and `errors` must contain the failure details.
23. Do not add broad waypoint metadata unless the app adapter truly needs it; if waypoint-level off-track information is required, keep it limited to the minimum shape needed for `peak_bagger`.
24. `peak_bagger` must update `TripRoutingClient`, `TripRoutingServiceClient`, and `LocalFileTripRoutingClient` to call the dedicated public two-waypoint package API instead of shaping app routing around `findTotalTrip(...)`.
25. Update `./lib/services/route_planner.dart` to remain the app-owned mapping boundary that converts package segment results into app planner results instead of using exceptions to model off-track behavior.
26. While route drafting is currently off-track, `peak_bagger` must use the dedicated endpoint-probe API to evaluate the newly tapped endpoint for rejoin eligibility instead of treating the current off-track start as a normal routed-segment input.
27. The planner result surface in `peak_bagger` must distinguish, at minimum, `routed`, `offTrack`, `noPath`, and `failed`.
28. `offTrack` and `noPath` must both provide enough data for `MapNotifier` to append a straight segment without using `routeDraftError`.
27. Route-draft behavior must flow only through the dedicated segment-result mapping path in `route_planner.dart`; legacy fallback abstractions must not remain as a second active route-draft decision path.
28. Route-draft state must separate control endpoints from display markers.
29. `MapState` must expose separate route-draft fields for `routeDraftControlEndpoints` and `routeDraftDisplayMarkers`, or equivalently named fields with those exact responsibilities.
30. `routeDraftControlEndpoints` must not be modeled as `List<LatLng>` alone; each control endpoint must carry a stable `id`, `point`, and enough kind metadata to distinguish at least tapped endpoints, snapped-node endpoints, projected-anchor endpoints, and any peak-target endpoint semantics used by the app.
30. Control endpoints are the only points allowed to seed the next segment start; they include tapped endpoints after any required anchor move, synthetic projected-edge anchor endpoints created from taps, and committed segment endpoints.
31. Display markers are the only route-draft markers rendered on the map.
32. `routeDraftDisplayMarkers` must not be modeled as `List<LatLng>` alone; each display marker must carry a stable `id`, `point`, marker `kind`, and enough state to distinguish provisional versus committed display behavior when both can exist.
33. For this slice, `routeDraftDisplayMarkers` must include the current control endpoints only; non-tapped internal routed vertices remain geometry-only and are out of scope for marker rendering.
34. Non-tapped internal routed vertices must never be stored in the control-endpoint collection or rendered as route-draft markers in this slice.
35. `routeDraftControlEndpoints.last` must be the sole source of truth for the next segment start.
36. `routeDraftDisplayMarkers` must preserve deterministic render order for tests by listing the control endpoints in committed journey order.
37. Route-draft marker keys/selectors must remain deterministic when raw taps, snapped-node endpoints, and synthetic projected anchors coexist.
38. Rendering non-tapped internal routed display markers is out of scope for this slice.
38. While `routeDraftStage == RouteDraftStage.routingSegment`, provisional route UI must keep the raw tapped endpoint marker and provisional straight line visible until the request resolves.
39. Provisional route UI must not show synthetic projected-anchor markers before the request resolves; control-endpoint movement and committed marker replacement happen only on resolution.
40. For `RouteMode.routeToPeak`, the visible peak marker must remain fixed at the peak coordinate throughout loading.
41. Replace `routeDraftStraightLineFallback` in `./lib/providers/map_provider.dart` with transient state that means the draft is currently off-track and still probing for rejoin.
42. While that state is active, each new tap must be reclassified against the graph; the app must not remain in straight-line mode forever after the first off-track or `noPath` segment.
43. When a tap re-enters the threshold, the current segment must still be appended as a straight segment, then the off-track state must clear so the following tap routes normally.
44. Real snapped routing must resume only on the segment after the rejoin segment.
45. `routeDraftError` must remain reserved for real validation or infrastructure/data failures and must not be populated for `offTrack` or `noPath`.
46. `MapNotifier` must continue using request-id or equivalent stale-result protection for all structured planner outcomes.
47. `MapNotifier.setRouteDraftMode(...)` must no-op while `routeDraftStage == RouteDraftStage.routingSegment`; this is a provider-level invariant, not just a button-disable rule.
48. `RouteMode.routeToPeak` must adopt the same on-track/off-track/noPath behavior for the snapped portion of the segment while preserving its existing one-segment completion semantics.
49. If the route-to-peak destination marker is on a peak, that peak marker must remain at the peak coordinate even when the snapped portion of the route terminates at a nearby anchor.
50. For `RouteMode.routeToPeak`, the committed segment endpoint must always be the actual peak coordinate, not merely the nearest on-track anchor.
51. Any snapped destination anchor used by `RouteMode.routeToPeak` must remain internal routing state unless a dedicated debug or test seam explicitly requires exposing it.
52. `RouteMode.routeToPeak` must remain disabled when no target peak exists; enabled/disabled behavior is separate from the `inactive` / `active` / `selected` visual-state model.
53. Update the route bottom sheet so route-mode buttons have three explicit visual states: `inactive`, `active`, and `selected`.
54. `active` must render purple and means contextually available but not the current mode.
55. `selected` must render green and means the current route mode.
56. `inactive` must retain the default non-selected styling.
57. The purple/green button-state styling must be independent from route geometry colour. Route lines and route markers stay red in this slice.
58. The bottom sheet must derive `inactive`, `active`, and `selected` styling from a single app-owned visual-state mapping helper or enum-driven mapping so state-to-color logic is not duplicated inline across buttons.
59. Route-mode button truth table:
| Mode | Condition | Enabled | Visual state |
| --- | --- | --- | --- |
| `snapToTrail` | normal drafting, not selected | Yes | `active` |
| `snapToTrail` | normal drafting, selected | Yes | `selected` |
| `snapToTrail` | `routeDraftStage == RouteDraftStage.routingSegment` | No | keep `selected` if current mode, otherwise `active` |
| `straightLine` | normal drafting, not selected | Yes | `active` |
| `straightLine` | normal drafting, selected | Yes | `selected` |
| `straightLine` | `routeDraftStage == RouteDraftStage.routingSegment` | No | keep `selected` if current mode, otherwise `active` |
| `routeToPeak` | no peak target | No | `inactive` |
| `routeToPeak` | peak target available, not selected | Yes | `active` |
| `routeToPeak` | peak target available, selected | Yes | `selected` |
| `routeToPeak` | `routeDraftStage == RouteDraftStage.routingSegment` with peak target | No | keep `selected` if current mode, otherwise `active` |
| `routeToPeak` | `routeDraftStage == RouteDraftStage.routingSegment` without peak target | No | `inactive` |

**Error Handling:**
59. If the graph cannot be loaded, or routing fails for infrastructure/data reasons, keep the current failure/error path and continue surfacing a user-visible route error.
60. If the planner returns `failed`, preserve previously committed geometry, clear provisional geometry, remove the just-added failed tap marker, and leave the last committed endpoint as the retry start.
61. If a segment is `offTrack`, append the straight segment, clear any provisional geometry, do not surface `routeDraftError`, and enter off-track probing state.
62. If a segment is `noPath`, append the straight segment, clear any provisional geometry, do not surface `routeDraftError`, and keep or enter off-track probing state.
63. Same-point segment validation remains a local validation failure in `MapNotifier`; do not route or classify it through the graph.

**Edge Cases:**
64. A tap near an edge but far from any graph node must still classify as on-track.
65. Classification must depend on nearest-edge distance only; nearest-node distance is used only to choose `node` vs `edgeProjection` after the endpoint is already classified on-track.
66. A start point within threshold of a graph node must snap to that node before route calculation even if the original tapped coordinate differs slightly.
67. An on-track start point that is not within threshold of a node must anchor to a projected edge point instead of snapping to a distant node.
68. End-point anchoring must follow the same rules as start-point anchoring so the stored end marker and the next segment start remain consistent.
69. Nearest-edge distance must use the shortest point-to-segment projection, clamped to the segment endpoints.
70. If both anchors lie on the same original edge, the routing algorithm must return the direct subsegment between those anchors without running a longer graph detour.
71. Internal routed vertices must not be allowed to become the next segment start merely because they are displayed as markers.
72. Existing raw Overpass JSON snapshots and bundled route-graph JSON assets must continue loading without migration through `RouteGraphStore` and `TripService.loadOverpassJson(...)`; any new provenance must be reconstructed during graph build.
73. `routeDraftDisplayMarkers` must never be repurposed as routing control state, even though in this slice it mirrors only the rendered control endpoints.
74. A rejoin tap that is back within threshold must not snap that same segment; only the following segment may snap.
75. `noPath` after an already off-track segment must remain straight and must not silently clear off-track probing state.
76. `offTrack` on the first routed segment after the start point must still append a valid straight segment and keep the draft usable.
77. `routeToPeak` must reset its special mode after a routed, off-track, or no-path completion, but not after true infrastructure/data failure.

**Validation:**
78. Validate that the route-planner adapter maps every dedicated segment-result status and payload shape into the correct app-owned planner result.
79. Validate that off-track classification depends on nearest-edge distance, not nearest-node distance.
80. Validate that a within-threshold start point is snapped to the nearest node before route calculation and that the draft marker moves to that node.
81. Validate that an on-track start point outside node threshold anchors to the nearest edge projection instead of a distant node.
82. Validate that end-point anchoring follows the same marker-move and anchor rules as start-point anchoring.
83. Validate that route-to-peak keeps the peak marker fixed at the peak coordinate while the snapped portion may terminate at a nearby anchor.
84. Validate that route-to-peak committed geometry always ends at the actual peak coordinate.
85. Validate that the temporary edge-splitting algorithm routes correctly for projected endpoints, including the same-edge case.
86. Validate that forward and reverse directed edges derived from the same adjacent-node OSM way segment share the same stable internal `originalSegmentId`.
87. Validate that request-scoped projected-edge routing does not mutate or accumulate synthetic nodes or edges in the cached base graph across repeated requests.
88. Validate that existing raw Overpass JSON snapshots and bundled route-graph JSON assets remain loadable without migration through `RouteGraphStore` and `TripService.loadOverpassJson(...)`.
88a. Validate that older `Graph.loadGraph()` JSON without provenance fields still loads successfully with backward-compatible defaults, even if the loader normalizes legacy duplicate-edge records into the corrected in-memory graph representation.
89. Validate that `routeDraftControlEndpoints.last` is the only next-segment start source.
90. Validate that route-draft control endpoints carry stable identity and endpoint-kind metadata rather than relying on raw coordinate lists alone.
91. Validate that route-draft display markers carry stable identity and marker-kind metadata rather than relying on raw coordinate lists alone.
92. Validate that `routeDraftDisplayMarkers` renders the control endpoints in deterministic committed-journey order.
93. Validate that non-tapped internal routed vertices remain geometry-only and never become control endpoints or route-draft markers in this slice.
94. Validate that during `routingSegment`, the raw tapped endpoint marker and provisional straight line remain visible until the request resolves.
95. Validate that synthetic projected-anchor markers are not shown during loading, and committed control-endpoint movement still happens only on resolution.
96. Validate that `RouteMode.routeToPeak` keeps the visible peak marker fixed at the peak coordinate throughout loading.
97. Validate that while route drafting is currently off-track, the app probes only the newly tapped endpoint for rejoin eligibility and still receives anchor metadata even when the current start remains off-track.
98. Validate that `MapNotifier` enters off-track probing state after `offTrack` or `noPath`, exits it only after a within-threshold rejoin tap has been appended as a straight segment ending at the chosen anchor, and resumes snapped routing on the following segment.
99. Validate that `MapNotifier.setRouteDraftMode(...)` no-ops during `routingSegment`.
100. Validate that a true `failed` planner result removes the just-added marker and restores the previous committed endpoint as the retry start.
101. Validate that route-to-peak `failed` results do not leave behind temporary anchor artifacts near the peak.
102. Validate that generic unexpected or infrastructure failures no longer fall back to accepted straight segments in provider, widget, and robot tests.
103. Validate that route-draft provider tests exercise real production `MapNotifier` transition logic rather than a forked harness reimplementation of the new status model.
104. Validate that `inactive`, `active`, and `selected` mode-button styling is produced through the single app-owned visual-state mapping helper and can be asserted deterministically in widget tests.
</requirements>

<mapping_table>
| Package outcome | App planner result | Accepted segment? | Marker handling | Geometry handling | `routeDraftError` |
| --- | --- | --- | --- | --- | --- |
| `status == routed` with valid geometry and valid distance | `routed` | Yes | Move tapped on-track control endpoints to their anchors. Keep peak markers fixed when the destination is a peak target. Non-tapped internal routed vertices remain geometry-only and must not become control endpoints or route-draft markers in this slice. | Commit routed geometry from anchored start to anchored end; if route-to-peak ends at a nearby anchor, append the terminal straight leg to the peak coordinate. | Clear |
| `status == offTrack` | `offTrack` | Yes | Keep the off-track tapped endpoint at the raw tap. | Commit straight geometry using the accepted straight-segment rule for the current state. | Clear |
| `status == noPath` | `noPath` | Yes | If the tapped endpoint is on-track, move it to the chosen anchor. Keep peak markers fixed when the destination is a peak target. | Commit straight geometry; for rejoin or route-to-peak on-track destinations, end the straight segment at the chosen anchor before any required terminal peak leg. | Clear |
| graph preload failure | `failed` | No | Remove the just-added marker and restore the prior committed endpoint as the retry start. | Do not append segment geometry. | Set |
| malformed or empty routed geometry for `routed` | `failed` | No | Remove the just-added marker and restore the prior committed endpoint as the retry start. | Do not append segment geometry. | Set |
| invalid or non-positive routed distance for `routed` | `failed` | No | Remove the just-added marker and restore the prior committed endpoint as the retry start. | Do not append segment geometry. | Set |
| unexpected package exception or infrastructure/data failure | `failed` | No | Remove the just-added marker and restore the prior committed endpoint as the retry start. | Do not append segment geometry. | Set |

Only `offTrack` and `noPath` are accepted straight-segment outcomes. All other failures use rollback plus error handling.
</mapping_table>

<boundaries>
Edge cases:
- Empty graph or graph load failure: treat as infrastructure/data failure, not as `offTrack`.
- On-track but disconnected snapped endpoints: treat as `noPath`, not as `offTrack`.
- Same-point segment: keep the current local validation path.
- Rejoin detection: classify the newly tapped endpoint before deciding whether the draft stays off-track or clears after appending the straight segment.

Error scenarios:
- Path dependency package API drift between `peak_bagger` and `trip_routing`: keep the adapter surface explicit and narrow so mismatches fail obviously in tests.
- Stale async planner result: ignore it completely.
- UI state drift after off-track completion: the selected routing mode button must still reflect the current mode and not appear as an error state.
- True failure rollback: marker and retry-start behavior must remain distinct from accepted `offTrack` and `noPath` segments.

Limits:
- Do not change explicit `straightLine` mode semantics in this slice.
- Do not refactor unrelated map rendering, elevation sampling, or route persistence behavior beyond what the new planner result shape requires.
- Do not turn `offTrack` or `noPath` into a bottom-sheet error message.
- Do not change route geometry colour from red in this slice; only the mode-button state styling changes to purple/green.
</boundaries>

<implementation>
Implement the change in two layers.

In the local `trip_routing` dependency declared in `./pubspec.yaml`:
- Add a dedicated segment-result model in `trip_routing: lib/src/models/` with a small structured status surface, preferably enum-backed.
- Add nearest-edge search and point-to-segment distance measurement in meters inside `trip_routing: lib/src/services/trip_service.dart`, using shortest projection clamped to segment endpoints.
- Add nearest-node snapping for the segment start point when it lies within the configured threshold.
- Add projected-edge anchoring for an on-track start point that is outside node threshold.
- Apply the same node-snap vs projected-edge anchoring rules to segment end points.
- Introduce a dedicated two-point API, for example `findAnchoredSegment({required LatLng start, required LatLng end, required double maxSnapDistanceMeters, ...})`.
- Introduce a dedicated endpoint-probe API for off-track rejoin evaluation, for example `probeEndpointAnchor({required LatLng point, required double maxSnapDistanceMeters, ...})`.
- Publicly export that dedicated API and its segment-result model from the package library surface.
- Keep `findTotalTrip(...)` unchanged for existing generic multi-waypoint callers during this slice.
- Keep `Graph.loadGraph/saveGraph()` backward-readable when provenance fields are added; loaders must tolerate older saved graph JSON that lacks those fields and may normalize legacy edge records on read.
- Classify each endpoint as on-track or off-track before normal pathfinding.
- Keep the new structured status semantics scoped to the dedicated two-waypoint segment-routing path used by `peak_bagger`; do not redesign multi-leg aggregate status behavior in this slice.
- Attach a stable internal `originalSegmentId` to both directed edges created from the same adjacent-node OSM way segment.
- Implement projected-endpoint routing by temporarily splitting each chosen source edge at the projection anchor, creating a synthetic anchor vertex when needed, and running pathfinding across that temporary graph.
- Ensure projected-endpoint routing uses a request-local overlay or copy and does not mutate the cached base graph stored on a shared `TripService` instance.
- If both projected anchors lie on the same original edge, return the direct anchored subsegment between them.
- When projected-edge anchors are created for tapped endpoints, also create corresponding synthetic endpoint markers in app state so the visible route endpoints and subsequent starts stay aligned with the routing anchors.
- If either endpoint is beyond threshold, return the dedicated segment result with `offTrack` status instead of adding an `errors` entry.
- If both endpoints are within threshold but no graph path exists, return the dedicated segment result with `noPath` status.
- Return minimal endpoint-anchor metadata with each dedicated segment result so the adapter can keep route markers and next-segment starts consistent.
- Reserve `errors` for actual infrastructure/data or malformed-input failures that are still exceptional for callers.

In `./lib/services/route_planner.dart` and `./lib/providers/map_provider.dart`:
- Replace the current `PlannedRouteSegment`-only success path plus exception-driven fallback with a structured planner result that includes status and, when routed, routed geometry and distance.
- Do not keep `RoutePlannerFallback`, `NoopRoutePlannerFallback`, or `OverpassRoutePlannerFallback` as a second behavior path for route drafting. If they are unused after the dedicated segment-result migration, remove them; if they are still referenced outside route drafting, leave them explicitly out of scope for this slice.
- Keep the route-planner public surface app-owned. Do not leak raw `trip_routing` segment-result status decisions into widget code.
- Update `TripRoutingClient`, `TripRoutingServiceClient`, and `LocalFileTripRoutingClient` to depend on the dedicated public two-waypoint package API rather than on `findTotalTrip(...)` for route drafting.
- Keep `peak_bagger` segment planning limited to exactly two waypoints per planner request.
- Maintain separate route-draft state for control endpoints and display markers.
- Replace the current single `routeDraftMarkers` responsibility with explicit `routeDraftControlEndpoints` and `routeDraftDisplayMarkers` state, or equivalently named fields with those exact responsibilities.
- Model `routeDraftControlEndpoints` and `routeDraftDisplayMarkers` as explicit view models with stable identity plus endpoint-kind or marker-kind metadata, rather than as bare `LatLng` lists.
- Update `MapNotifier.addRouteDraftMarker` and `_planRouteDraftSegment(...)` so `offTrack` and `noPath` append straight segments without setting `routeDraftError`.
- While route drafting is currently off-track, probe only the newly tapped endpoint for rejoin eligibility through the dedicated endpoint-probe API; do not route a normal two-point snapped segment from the off-track start during that probing step.
- When a routed segment ends on a node snap or edge projection anchor, update the stored end marker to that anchor so the next segment starts from the same point.
- Keep non-tapped internal routed vertices in routed geometry only; do not add them to route-draft display-marker state in this slice.
- On true `failed`, roll back the just-added marker so the retry start remains the last committed endpoint.
- Add explicit off-track probe state in `MapState`; name it for current behavior, not legacy fallback semantics.
- Clear that off-track state only after appending a rejoin segment whose tapped endpoint is back within threshold.
- Make `setRouteDraftMode(...)` no-op while `routeDraftStage == RouteDraftStage.routingSegment`, and also disable route-mode button changes in the UI.
- Route-draft provider and state-transition tests must instantiate and exercise real production `MapNotifier` logic for the new status model; do not validate `offTrack`/`noPath`/`failed` behavior through `TestMapNotifier` or any harness that reimplements those transitions.
- Leave request-id handling, provisional geometry, and route-to-peak completion protection in place.

In `./lib/widgets/map_route_bottom_sheet.dart`:
- Update the routing-mode button styling so `active` renders purple and `selected` renders green.
- Implement the route-mode truth table exactly so enabled/disabled behavior and visual state stay consistent across `snapToTrail`, `straightLine`, `routeToPeak`, and `routingSegment` lock conditions.
- Keep keys stable and add only the minimum extra selectors needed for deterministic tests of selected state.
- Keep `routeToPeak` disabled when no target peak exists, regardless of visual state naming.

In `./lib/screens/map_screen.dart` and `./lib/screens/map_screen_layers.dart`:
- Render route-draft markers from `routeDraftDisplayMarkers`, not from control-endpoint state directly.
- Ensure deterministic marker keying and ordering for tests when raw taps, snapped-node endpoints, and synthetic projected anchors coexist.

Use the smallest data-model expansion that satisfies both repos:
- Prefer enum status fields over free-form strings.
- Prefer a single adapter mapping layer in `route_planner.dart` instead of branching on package segment-result statuses throughout `MapNotifier`.
- Prefer anchored marker/state updates over raw tap preservation when a start point snaps to a node.
- Prefer the same anchored marker/state update rule for end points so each committed endpoint is also the next segment start.
- Prefer the same tapped-endpoint anchoring rule for accepted rejoin segments so the committed straight segment endpoint, marker position, and next segment start all match.
- Prefer a dedicated control-endpoint collection for next-segment behavior and a separate display-marker collection for rendered control endpoints.
- Prefer explicit render-layer ownership of `routeDraftDisplayMarkers` rather than deriving next-segment control behavior from whichever markers happen to be visible.
- Keep any optional waypoint-level metadata minimal and local to the routing adapter unless the UI truly needs it.

Avoid:
- Reusing `routeDraftError` to indicate temporary off-track state.
- Reintroducing permanent straight-line fallback after one miss.
- Treating a within-threshold rejoin tap as an immediately snapped segment.
- Coupling purple/green route-mode button styling to the persisted route colour.
- Allowing generic unexpected failures to continue using the accepted straight-line fallback path.
</implementation>

<stages>
Phase 1: `trip_routing` segment API and classification seam
- Add the dedicated two-point segment API, nearest-edge distance logic, nearest-node snap vs projected-edge anchoring rules, source-edge provenance support, temporary edge splitting for projected endpoints, and status mapping for `routed`, `offTrack`, `noPath`, and true failures.
- Keep temporary edge splitting request-scoped so repeated segment requests against the same preloaded service do not accumulate synthetic graph artifacts.
- Verify with focused package tests before changing the app adapter.

Phase 2: `peak_bagger` planner result seam
- Replace exception-driven off-track behavior in `./lib/services/route_planner.dart` with structured planner results.
- Prove result mapping with app-level unit tests using fake `TripRoutingClient` responses.

Phase 3: route-draft state behavior
- Replace sticky `routeDraftStraightLineFallback` with transient off-track probing state.
- Implement off-track, rejoin, and post-rejoin transitions in `MapNotifier`.
- Verify with provider tests that execute the real `MapNotifier` route-draft transitions before adjusting UI.

Phase 4: route-mode UI and journeys
- Update route-mode buttons to support `inactive`, `active` purple, and `selected` green styling.
- Update widget and robot coverage for the snapped -> off-track -> rejoin -> snapped-again journey.
</stages>

<illustrations>
Desired:
- First routed segments continue to use snapped geometry when taps are within threshold.
- A within-threshold tapped endpoint snap moves the marker to the snapped node before the segment begins.
- A projected-edge anchor creates a synthetic anchor marker at that projected point.
- Internal routed vertices remain routed geometry only in this slice and do not take over next-segment control.
- A later off-track tap creates a straight segment without an error message.
- Another off-track or `noPath` tap stays straight.
- A rejoin tap also stays straight, then clears off-track state.
- The next tap after rejoin uses snapped routing again.
- A highlighted but non-selected route-mode button is purple, and the selected route-mode button is green.

Undesired:
- One failed segment causes every later segment to stay straight forever.
- `offTrack` or `noPath` populates `routeDraftError`.
- A tap close to an edge but not close to a node is misclassified off-track.
- An on-track start point outside node threshold snaps to a distant node instead of projecting to the nearest edge.
- A routed end point remains at the raw tap while the next segment actually starts from a different anchor.
- Rejoin immediately snaps the rejoin segment itself.
- Route lines change from red to purple or green because the route-mode buttons changed state.
</illustrations>

<validation>
Use strict vertical-slice TDD for the logic-heavy slices:
- Start with one failing `trip_routing` classification test.
- Implement the minimum package code to pass it.
- Add one failing route-planner adapter test for status mapping.
- Implement the minimum adapter change to pass it.
- Add one failing `MapNotifier` state-transition test for off-track entry, then continue one behavior at a time through rejoin and snapped-resume behavior.
- Refactor only after each test is green.

Required automated coverage outcomes:
- `unit` in `trip_routing: test/...`: near-edge but far-from-node endpoint classifies on-track; beyond-threshold endpoint classifies off-track; within-threshold start and end points snap to the nearest node; on-track start and end points outside node threshold anchor to the nearest edge projection; within-threshold disconnected endpoints return `noPath`; rejoin-eligible endpoint returns non-off-track status.
- `unit` in `peak_bagger`: `route_planner.dart` maps dedicated segment-result statuses into app planner results and still surfaces graph/infrastructure failures through the failure path.
- `provider` in `./test/providers/route_draft_state_test.dart`: off-track tap enters straight-line probing mode without `routeDraftError`; later off-track or `noPath` taps remain straight; rejoin tap appends a straight segment and clears probing state; next tap after rejoin routes normally; true `failed` removes the just-added marker; route-to-peak follows the same status rules; non-tapped internal routed vertices remain geometry-only and do not alter the next control endpoint.
- Route-draft provider/state-machine coverage must use real `MapNotifier`; fake only external boundaries such as planner results, graph loading, and elevation sampling.
- `widget` coverage in `./lib/screens/map_screen.dart` and `./lib/screens/map_screen_layers.dart`: rendered route markers come from `routeDraftDisplayMarkers`, while next-segment behavior continues to come only from `routeDraftControlEndpoints`, and internal routed vertices remain geometry-only in this slice.
- `provider` coverage must explicitly rewrite any current expectation that a generic unexpected failure falls back to straight-line continuation; after this slice, only `offTrack` and `noPath` are accepted straight-segment outcomes.
- `widget` in `./test/widget/map_screen_route_sheet_test.dart`: route bottom sheet renders `inactive`, `active`, and `selected` mode-button states with the expected styling, and keeps `routeToPeak` disabled when no peak target exists.
- `robot` in `./test/robot/map/map_route_journey_test.dart`: update the current off-track fallback journey and add a critical journey covering snapped -> off-track straight -> rejoin straight -> snapped again.

Deterministic seams required:
- Keep `TripRoutingClient` and `RoutePlanner` injectable.
- Add only the minimum fake result types needed to queue `routed`, `offTrack`, `noPath`, and `failed` outcomes in tests.
- Keep stable keys for route-mode buttons and any selected-state assertions needed by widget and robot tests.
- Do not require real Overpass or real graph fetches in automated tests.
- Limit `./test/harness/test_map_notifier.dart` to non-route-draft scenarios unless it delegates route-draft behavior fully to production `MapNotifier`. Widget and robot fakes may queue planner results at the planner seam, but must not reimplement route-draft state transitions.

Robot test split:
- Use robot-driven widget journeys for the critical cross-screen map drafting happy path and rejoin path.
- Use widget tests for route-mode button selected-state styling and bottom-sheet rendering details.
- Use unit/provider tests for classification math, adapter mapping, and state transitions, with real `MapNotifier` owning the route-draft state machine.

Known testing risk to report if left unresolved:
- If selected button styling is asserted through deep theme internals rather than an app-owned seam, tests may become brittle. Prefer a narrow, deterministic assertion surface.
</validation>

<done_when>
1. The local `trip_routing` dependency can classify endpoints by nearest-edge distance, snap within-threshold start and end points to the nearest node, anchor on-track endpoints outside node threshold to the nearest edge projection, route projected endpoints through temporary edge splitting, and return dedicated two-point segment results plus minimal endpoint-anchor metadata across `routed`, `offTrack`, `noPath`, and real failures.
2. `peak_bagger` no longer uses planner exceptions to represent normal off-track behavior.
3. Route drafting no longer stays in straight-line fallback forever after one miss.
4. Off-track and `noPath` append straight segments without populating `routeDraftError`.
5. Rejoin uses one final straight segment, then the following segment snaps again.
6. `RouteMode.routeToPeak` follows the same off-track/no-path rules.
7. The route-mode buttons support `inactive`, `active` purple, and `selected` green states while route geometry remains red.
8. Automated coverage exists across package logic, app adapter logic, provider state transitions, explicit control-endpoint vs display-marker behavior, rendering-layer marker behavior, widget styling, and the critical robot journey.
</done_when>
