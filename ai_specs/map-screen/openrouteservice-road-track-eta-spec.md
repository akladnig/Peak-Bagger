<goal>
Add a driving ETA popup on the map screen that appears only when the user clicks a qualifying route-graph road/track backed by the local route graph, then queries OpenRouteService for car travel time and distance from the user's live GPS location.

This feature is for desktop map users planning access to roads and formed tracks. The result should feel like the existing peak info popup styling and placement behavior, ignore non-road clicks for ETA purposes, and avoid any dependency on Google Maps.
</goal>

<background>
Tech stack: Flutter, Riverpod, `flutter_map`, `latlong2`, `http`, `geolocator`, and the bundled ObjectBox-backed route graph.

Current architecture and constraints:
- `./lib/screens/map_screen.dart` already owns map pointer-up handling and converts click positions into `LatLng`.
- The visible basemap is a raster `TileLayer`, so roads drawn by the basemap are not directly hit-testable.
- The app already has route-graph metadata in `RouteGraphWayIndex`, visible-bounds querying in `RouteGraphQueryService`, trail display chunk decoding, and popup placement/surface patterns used by the peak info popup.
- The ETA popup must use OpenRouteService, not Google Maps.
- Preserve existing peak, route, track, and route-drafting interactions unless this spec explicitly says otherwise.
- Treat driving ETA as a single anchored-map-popup feature. Only one anchored popup may be visible at a time.
- This feature is desktop-only. Touch and mobile input support are explicitly out of scope.

Files to examine:
- @lib/core/constants.dart
- @lib/screens/map_screen.dart
- @lib/screens/map_screen_panels.dart
- @lib/providers/map_provider.dart
- @lib/providers/route_graph_readiness_provider.dart
- @lib/models/route_graph_way_index.dart
- @lib/models/route_graph_chunk.dart
- @lib/services/route_graph_query_service.dart
- @lib/services/route_hover_detector.dart
- @lib/services/route_graph_repository.dart
- @lib/services/route_graph_trail_service.dart
- @lib/services/track_hover_detector.dart
- @lib/widgets/map_action_rail.dart
- @test/widget/map_screen_peak_info_test.dart
- @test/widget/map_screen_trail_overlay_test.dart
- @test/widget/map_screen_route_hover_test.dart
- @test/services/route_graph_query_service_test.dart
- @test/services/route_graph_trail_service_test.dart
- @test/robot/map/map_route_robot.dart

Output paths:
- Modify `./lib/core/constants.dart`
- Modify `./lib/screens/map_screen.dart`
- Modify `./lib/screens/map_screen_panels.dart`
- Modify `./lib/providers/map_provider.dart` to add the shared anchored-popup coordination seam required for ETA and peak popup coexistence
- Modify `./lib/services/route_graph_query_service.dart`
- Add `./lib/services/open_route_service.dart`
- Add `./lib/services/route_graph_drive_eta_hit_service.dart` or a similarly focused route-graph hit-test service
- Add or update focused tests under `./test/services/`, `./test/widget/`, and `./test/robot/map/`
</background>

<user_flows>
Primary flow:
1. User opens the map screen in normal desktop browsing mode.
2. User primary-clicks on a qualifying route-graph road/track that is backed by route-graph geometry matching the allowed metadata filter.
3. App projects the click to the nearest point on the matched line, immediately opens a pinned popup anchored to that snapped point using peak-info popup placement behavior and visual styling, and shows a loading state such as `Calculating Route`.
4. App fetches the user's live GPS position.
5. App queries OpenRouteService using `driving-car` from the live GPS origin to the snapped destination.
6. App replaces the loading state with distance and duration in the popup.

Alternative flows:
- Repeat valid click: clicking a different valid road/track replaces the current ETA request and popup content with the new destination.
- Named road: if route-graph metadata includes a road/track name, show it in the popup title or subtitle; otherwise use a neutral ETA title.
- Existing map click behavior: clicks that do not qualify for ETA continue to preserve existing map interactions such as selection or popup dismissal, but they do not open a driving ETA popup.

Error flows:
- Route graph unavailable: show an ETA error popup/message instead of silently ignoring the click. Treat route graph as unavailable when readiness is `failed`, when no `RouteGraphRepositoryProvider`-backed repository is available, or when there is no usable active generation or route-graph coverage available to query for the clicked area. `preloading` alone must not force an ETA error when repository-backed route-graph data is already usable.
- GPS permission denied or unavailable: show an inline error state in the ETA popup and offer a clear dismiss path.
- OpenRouteService failure, timeout, or rate limit: keep the popup anchored, show an inline error state, and allow retry via a repeated valid click.
- No qualifying road/track hit: do not open the ETA popup.
</user_flows>

<discovery>
Before implementation, confirm the smallest reliable seam for road/track hit testing from the local route graph.

Answer these through code inspection:
- Whether the ETA hit service should decode qualifying road/track geometry directly from active route-graph chunks on demand, or whether a cached viewport-scoped decoded representation is needed for acceptable click performance.
- How best to reuse existing popup placement logic from `resolvePeakInfoPopupPlacement` and existing peak popup visual styling patterns without duplicating layout rules.
- Which provider/service seam should own live GPS lookup so widget tests do not call `Geolocator` directly.
- Which existing robot or widget harness already provides the cleanest way to drive map clicks and fake route-graph data, with `MapRouteRobot` as the default reference pattern.
</discovery>

<requirements>
**Functional:**
1. Add a driving ETA interaction that activates only when a map click hits qualifying route-graph road/track geometry.
   - Scope note: this feature is desktop-only. Only primary mouse click / pointer-up interactions may open driving ETA. Touch and mobile input support are out of scope.
2. Only one anchored map popup may be visible at a time. Opening a driving ETA popup closes any pinned or hovered peak popup, and opening a peak popup closes any driving ETA popup.
3. `MapScreen` owns ETA click orchestration, but ETA popup coordination state must live in a shared anchored-popup seam in `mapProvider` / `MapState` so it can coordinate cleanly with existing peak hover and pinned popup behavior.
4. Define the qualifying metadata filter from `RouteGraphWayIndex` as:
   - include `highway` values `secondary`, `tertiary`, `unclassified`, `residential`, `motorway`, `motorway_link`, `service`, `trunk`, `secondary_link`, `trunk_link`, and `track`
   - exclude any row with `access=private`
   - for `highway=track`, exclude rows where `surface` is explicitly `dirt` or `earth`
   - treat `surface=null` for `track` as allowed unless another exclusion blocks it
   - this filter is intentionally limited to metadata already stored in `RouteGraphWayIndex` and may be expanded later if the local route-graph index stores more driving-relevant tags
5. Restrict ETA hit testing to app-owned route-graph geometry derived from active ObjectBox route-graph data; do not attempt to infer hits from raster basemap pixels.
6. Query the visible route graph for qualifying road/track ways using the current map viewport plus a modest buffer so line hits remain stable near the screen edge.
7. Driving ETA hit-testing is active only at or above a new `MapConstants.driveEtaMinZoom` constant set to `6`.
8. Project a successful click to the nearest point on the matched road/track polyline and use that snapped point as the route destination.
9. Use a screen-space line-hit threshold comparable to existing route hover behavior so a click must be meaningfully on the road/track, not merely nearby.
10. On a valid ETA click candidate, surface the ETA popup immediately in a loading state with progress copy such as `Calculating Route`, before GPS lookup and OpenRouteService completion.
11. On a valid hit, keep the ETA popup pinned and anchored to the snapped point using the same placement behavior, card size, shape, background, padding, close affordance, and typography style as the peak info popup, while keeping ETA-specific content and keys.
12. The ETA popup must at minimum show:
   - driving duration
   - driving distance
   - loading copy `Calculating Route`
   - a loading state while GPS/ORS work is in progress
    - an inline error state when GPS or ORS fails
13. If a route-graph row supplies a non-empty name, display that road/track name in the ETA popup; otherwise show a fallback title such as `Drive ETA`.
14. Use the app's existing distance and duration formatting conventions where available, rather than introducing a new formatting style.
15. Use a fresh GPS reading for each valid ETA click rather than reusing `selectedLocation`.
16. Query OpenRouteService with the `driving-car` profile and map the returned summary into app-friendly duration and distance display values.
17. Keep the ETA request local to the current click. If the user clicks a second valid road/track before the first request finishes, cancel or invalidate the older result so only the newest click can update the popup.
18. Clicking elsewhere on the map must dismiss a pinned ETA popup if the click does not open a new ETA popup.
19. Preserve existing map interactions outside this new feature, including route drafting, peak popup behavior, track/route selection, and existing selected-location handling.
20. Click-precedence order for `MapScreen` pointer-up handling must be explicit:
   - route drafting and route-draft marker interactions consume the click first
   - peak hits and peak-popup interactions consume the click before ETA
   - saved route and GPX track selection interactions consume the click before ETA when the same click could satisfy both behaviors
   - driving ETA handling runs before generic selected-location updates and consumes the click when a valid ETA target is found
   - if a click opens driving ETA, that same click must not also update selected location, select a route/track, or clear selection

**Error Handling:**
21. If route-graph readiness is `failed`, if no `RouteGraphRepositoryProvider`-backed repository is available, or if there is no usable active generation or route-graph coverage available to query for the clicked area, a driving ETA click attempt must show an ETA error popup/message indicating that route-graph data is unavailable, rather than silently failing. `preloading` alone must not trigger this error when repository-backed route-graph data is already usable.
22. If live location services are disabled, permission is denied, permission is denied forever, or GPS lookup fails, show a non-crashing inline ETA popup error instead of a success result.
23. If OpenRouteService returns an error, timeout, malformed payload, or no route summary, show a non-crashing inline ETA popup error.
24. If the local route graph has no qualifying road/track geometry in the hit area while route-graph readiness is available, treat the click as a silent no-op for ETA and do not surface a false positive popup.
25. If the ORS API key is missing, fail closed with a clear developer-visible error path and a user-safe popup error state; do not hardcode secrets in source.

**Edge Cases:**
26. Ignore ETA clicks entirely while route drafting is active.
27. Rapid repeated clicks across multiple road/track targets must not leave stale popup content or race older responses onto the screen.
28. If the snapped road/track destination lies outside loaded route-graph coverage after a viewport change, the current click should fail gracefully without breaking the map.
29. Qualifying `track` rows with unknown `surface` remain eligible, but explicit `dirt` and `earth` tracks are never eligible.
30. The popup must remain visually consistent with peak info popup sizing, padding, close affordance, typography, and anchored placement, while using its own stable keys and content rows. Once opened, it also follows the same anchoring dismissal rules as the peak info popup when pan/zoom or equivalent viewport change makes the anchor no longer anchorable.
31. The ETA feature must not require the road/track geometry to be visibly styled as a new overlay unless implementation needs an invisible or transparent hit layer for determinism.
32. Clicks that miss qualifying geometry while route-graph readiness is available remain silent no-ops.

**Validation:**
33. Add behavior-first coverage for qualifying-way filtering, geometry decode, nearest-point projection, hit-threshold acceptance/rejection, request invalidation, popup loading/success/error states, and dismissal.
34. Keep the new ETA feature deterministic in tests by routing GPS and ORS access through injectable seams rather than calling platform or network APIs from widget code.
35. Add stable, app-owned keys for the ETA popup root, close button, loading state, error state, duration row, and distance row.
</requirements>

<boundaries>
Edge cases:
- ETA applies only to route-graph road/track geometry, not arbitrary raster basemap roads.
- Non-road clicks are ignored for ETA purposes only; they do not disable unrelated existing click behavior.
- ETA is a point-in-time driving estimate from OpenRouteService and is not traffic-aware in the Google Maps sense.
- Immediate loading popup behavior improves perceived responsiveness, but does not remove the requirement to keep hit-testing bounded and cached.
- `preloading` route-graph readiness alone does not surface an ETA error when repository-backed route-graph data is already usable.

Error scenarios:
- No valid geometry hit: no popup opens.
- GPS failure: popup shows inline error.
- ORS failure or API-key misconfiguration: popup shows inline error and does not crash the map.
- Stale async completion after a newer click: ignore the stale result.

Limits:
- Desktop only: do not add touch or mobile ETA interaction behavior in this slice.
- Do not introduce Google Maps or Google Routes dependencies.
- Do not hardcode ORS API keys; prefer a configuration seam such as `String.fromEnvironment` or another explicit app-owned config path.
- Do not broaden this feature into general turn-by-turn navigation, route saving, or travel-mode switching.
- Do not change the existing peak info popup behavior beyond any shared styling extraction needed to support ETA.
- A persisted companion road/track hit-display cache or chunk index is acceptable when it is derived entirely from the active route graph and mirrors the existing trail-display pattern.
</boundaries>

<implementation>
Files to create or modify:
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/providers/map_provider.dart`
- `./lib/services/route_graph_query_service.dart`
- `./lib/services/open_route_service.dart`
- `./lib/services/route_graph_drive_eta_hit_service.dart` or equivalent
- `./test/services/route_graph_query_service_test.dart`
- `./test/services/route_graph_drive_eta_hit_service_test.dart`
- `./test/services/open_route_service_test.dart`
- `./test/widget/map_screen_drive_eta_test.dart`
- `./test/robot/map/drive_eta_robot.dart`
- `./test/robot/map/drive_eta_journey_test.dart`

Implementation expectations:
- Add a small query helper in `RouteGraphQueryService` for the qualifying drive-ETA way filter rather than duplicating ad hoc metadata filtering in widgets.
- Add a new `MapConstants.driveEtaMinZoom` constant in `lib/core/constants.dart` set to `6`, and use it as the single source of truth for ETA zoom gating in implementation and tests.
- Add a focused route-graph hit service that can:
  - obtain qualifying ways for the active viewport
  - decode or reconstruct their polylines from route-graph chunk payloads
  - project a clicked screen/map coordinate onto the nearest eligible segment
  - return enough metadata for popup anchoring and display, including snapped point, matched way ID, and optional way name
- Keep the hit service separate from the trail display service unless a truly shared geometry-decoding seam is obvious.
- Cache decoded qualifying road/track geometry per visible chunk set and reuse it while the viewport's relevant chunk membership is unchanged.
- The feature must not rescan and fully decode all active road/track geometry on every click when the viewport has not materially changed.
- If raw route-graph chunk decoding is too expensive for reliable click latency, implementation may add a persisted companion road/track hit-display cache or chunk index similar in role to `RouteGraphTrailDisplayChunk`.
- Add a focused ORS client service that accepts origin/destination `LatLng`, calls the configured OpenRouteService directions endpoint for `driving-car`, and returns a typed summary object with `distanceMeters` and `durationSeconds`.
- Wrap GPS access behind a concrete injectable seam or provider so tests can fake location success and failure deterministically.
- Back the ORS client with a concrete app-owned seam that supports deterministic testing of success, missing-key, timeout, non-200, and malformed-payload cases without live network calls. An injected HTTP client or equivalent request seam is acceptable.
- Keep `MapScreen` as the owner of click orchestration, while the anchored popup coordination state lives in the shared popup seam in `mapProvider` / `MapState`. Move ETA popup presentation into `map_screen_panels.dart` if that preserves the existing panel/popup split.
- Reuse the peak popup placement rules and visual styling wherever practical. If a shared generic popup shell extraction is cleaner than duplicating styling glue, keep the extraction minimal and preserve peak popup behavior.
- Use app-owned keys instead of text-only selectors for ETA popup assertions.

Configuration expectations:
- Configure the ORS API key through an explicit app-owned configuration seam, preferably `--dart-define=OPENROUTESERVICE_API_KEY=...` read via `String.fromEnvironment`, or another equally explicit non-hardcoded mechanism already accepted by the project.
- Surface missing-key behavior in a way tests can cover without making live ORS calls, using the same app-owned service seam rather than widget-local logic.

Avoid:
- Avoid calling OpenRouteService or `Geolocator` directly from widgets.
- Avoid relying on raster tile imagery for road hit detection.
- Avoid broad provider redesign, but allow a small derived persisted helper structure if it is the cleanest fit for click-hit performance.
- Avoid adding a visible road overlay solely for aesthetics if an invisible hit-target path is sufficient.
</implementation>

<stages>
Phase 1: Define query and geometry seams.
- Add the qualifying road/track query helper and the viewport-scoped road/track hit service.
- Verify with failing service tests for include/exclude metadata, geometry decode, snapped nearest-point projection, zoom gating, and cache reuse behavior.

Phase 2: Add ORS and location seams.
- Introduce the ORS client and the injectable live-location seam.
- Verify with failing service tests for success mapping, malformed payloads, HTTP failures, and missing API key behavior.

Phase 3: Wire map clicks to popup state.
- Add ETA popup state, async request invalidation, valid-hit orchestration, invalid-click dismissal, and popup rendering.
- Verify with failing widget tests for loading, success, error, dismissal, and stale-response suppression.

Phase 4: Add journey coverage.
- Add a robot-driven map journey that clicks a valid road/track, waits through the loading state, and verifies the final distance/duration popup.
- Verify selector stability and deterministic fake seams.
</stages>

<validation>
Follow vertical-slice TDD: one failing test at a time, minimal implementation to green, then refactor only after the slice passes.

Behavior-first TDD slices:
1. Add a failing service test for the qualifying road/track metadata filter.
2. Add a failing service test for decoding eligible way geometry and snapping a click to the nearest point.
3. Add a failing service test for hit rejection outside the click threshold.
4. Add a failing ORS client test for a successful `driving-car` summary response.
5. Add a failing ORS client test for missing key or non-200 failure mapping.
6. Add a failing widget test for valid hit -> loading popup -> success popup with distance and duration rows.
7. Add a failing widget test for valid hit -> GPS or ORS error popup.
8. Add a failing widget test for invalid click not opening ETA.
9. Add a failing widget test for second valid click invalidating the first result.
10. Add a failing robot journey for the critical happy path.

Baseline automated coverage outcomes:
- Logic/business rules: qualifying-way filtering, geometry decode, nearest-point projection, stale-request invalidation, and ORS response mapping.
- UI behavior: ETA popup loading/success/error/dismiss flows, anchored popup presence, and non-opening behavior for invalid clicks.
- UI behavior: ETA popup must render `Calculating Route` immediately on a valid candidate click, then transition to success or error.
- Critical user journey: full click-on-valid-road -> fetch -> show ETA path, using stable selectors and fake services.

Required deterministic seams:
- Fake route-graph repository or prepared route-graph fixture data for qualifying-way and geometry tests.
- Fake location service for current-position success and failure.
- Fake ORS client or HTTP seam for route summary responses.
- Stable app-owned keys for popup and row assertions.

Robot coverage expectations:
- Put robot coverage under `./test/robot/map/`.
- Keep selectors key-first.
- Reuse `MapRouteRobot` patterns, repository-backed route-graph store overrides, and existing map click helpers where possible rather than inventing a second journey harness or building on `RouteInfoRobot`. Do not rely on a ready-only store that lacks `RouteGraphRepositoryProvider` when exercising ETA hit-testing.

Recommended commands:
- `flutter test test/services/route_graph_query_service_test.dart`
- `flutter test test/services/route_graph_drive_eta_hit_service_test.dart`
- `flutter test test/services/open_route_service_test.dart`
- `flutter test test/widget/map_screen_drive_eta_test.dart`
- `flutter test test/robot/map/drive_eta_journey_test.dart`
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- Clicking a qualifying route-graph road/track opens a peak-style pinned ETA popup anchored to the snapped clicked line.
- The popup shows loading first, then driving duration and distance from the user's fresh GPS location via OpenRouteService.
- Clicking outside a qualifying road/track does not open ETA and dismisses any existing ETA popup.
- GPS, ORS, and configuration failures render safe inline popup errors without breaking the map.
- Existing peak, route, track, and route-drafting behaviors still work.
- The required service, widget, and robot tests pass.
</done_when>
