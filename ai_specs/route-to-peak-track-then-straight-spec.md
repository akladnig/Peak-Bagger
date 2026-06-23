<goal>
Update route creation and route editing so `RouteMode.routeToPeak` can handle peaks that are not directly on a track.
When the user starts on a track, the route should follow the track as far as the planner can route toward the peak, then add a straight-line terminal leg to the peak coordinate.

This matters because peak targets are often near, but not exactly on, track geometry. The user should get a useful route without having to manually add the terminal leg themselves.
</goal>

<background>
Flutter/Riverpod map app with an existing route-drafting flow, peak-target routing mode, and route save/edit support.

Relevant code paths:
- `@./lib/providers/map_provider.dart` - route draft state machine, route-to-peak entry points, segment planning, and route save geometry.
- `@./lib/screens/map_screen.dart` - create-route entry point and route draft initiation.
- `@./lib/widgets/map_route_bottom_sheet.dart` - route mode controls, draft status, and route summary UI.
- `@./lib/services/route_planner.dart` - planner contract, anchors, and route-planning results.
- `@./lib/models/route.dart` - saved route geometry contract.
- `@./test/providers/route_draft_state_test.dart` - route draft behavior coverage, including route-to-peak flows.
- `@./test/widget/map_screen_route_sheet_test.dart` - route sheet UI coverage.
- `@./test/robot/map/map_route_journey_test.dart` - end-to-end route creation journey coverage.
- `@./test/harness/test_map_notifier.dart` - deterministic route-planning fake used by widget journeys.

Current behavior to preserve:
- Route creation still begins in `RouteMode.snapToTrail`.
- Switching to `RouteMode.routeToPeak` still uses the current start point when one already exists.
- Existing same-point validation still blocks a peak route when start and peak coordinates are identical.
- Existing save/edit behavior, undo/redo, and route draft UI state should remain intact.

Implementation note:
- Treat the planner-provided track anchor or last routed point as the terminal on-track point.
- Do not add a separate geometric nearest-neighbour search unless the existing planner API cannot express the anchored terminal point.
</background>

<discovery>
Before implementation, confirm these points in code:
1. Where `RouteMode.routeToPeak` currently commits routed points so the new terminal-leg behavior can be added without breaking existing draft state updates.
2. Whether the planner result already exposes enough anchor information to identify the last on-track point before the peak.
3. Whether the route draft fake in `test/harness/test_map_notifier.dart` needs a small update to mirror the hybrid geometry path for robot/widget tests.
4. Which existing test slice should be extended first so the new behavior is driven by a single failing provider test before UI and journey coverage are added.
</discovery>

<user_flows>
Primary flow:
1. User taps Create Route.
2. User selects `Route to peak`.
3. User taps a start point that is on a track.
4. The app routes along the track toward the peak.
5. If the peak is off-track, the app appends a straight-line segment from the last routable on-track point to the peak coordinate.
6. The draft remains saveable and the saved route contains the hybrid geometry.

Alternative flows:
- Peak already on track: the route may end at the peak without an extra straight-line terminal leg.
- Route editing: reopening an existing route in `RouteMode.routeToPeak` uses the same hybrid behavior when the route is extended or recalculated.
- Switching modes after a start point is already placed: switching into `RouteMode.routeToPeak` immediately recomputes the peak leg using the existing start point.

Error flows:
- Planner cannot route the on-track leg: complete the route with the straight-line fallback instead of leaving the draft in a failure state.
- Start and peak coordinates are identical: keep the existing validation error and do not create a zero-length route.
- Route planning becomes stale while the user continues editing: ignore stale results and keep the latest draft geometry only.
</user_flows>

<requirements>
**Functional:**
1. In `RouteMode.routeToPeak`, when the peak is not on a track but the start point is on a track, build a hybrid route geometry: routed track segment first, then a straight-line terminal leg to the peak.
2. Use the route planner's returned anchored endpoint or last routed point as the on-track terminal point for the hybrid route.
   The terminal straight segment must start at that point and end at the exact peak coordinate.
3. If the planner already returns a route that ends exactly at the peak, do not append a duplicate terminal leg.
4. Apply the same hybrid behavior in both create-route and edit-route flows.
5. If the planner can provide a usable routed or partially routed on-track segment, preserve that segment and append the straight-line terminal leg to the peak.
   Only fall back to a pure straight-line route from the start point when no usable on-track anchor or partial geometry is available.
6. Keep the existing draft lifecycle after the segment is committed, including the current mode reset behavior and saveability of the route.
7. Preserve existing geometry saving in `Route.gpxRoute` so the final saved route contains the routed segment plus the terminal straight segment.
8. Make the hybrid leg flow through the same draft state updates as any other segment: committed points, markers, control endpoints, distance, and elevation resampling must all stay in sync with the drawn path.

**Error Handling:**
9. If the planner returns `noPath`, `offTrack`, or another non-routed result, complete the draft using the best available anchored geometry when present; only use a pure straight-line fallback when no usable anchor exists.
10. If the planner fails because the route graph cannot be loaded, the user should still get the straight-line fallback for the peak leg when the route draft can be completed safely.
11. If the route target changes or a newer draft request starts before the planner result returns, discard the stale result and leave the current draft state unchanged.

**Edge Cases:**
12. If the peak is already the last routed point, skip the terminal straight-line segment.
13. If the start point is already the peak coordinate, keep the current same-point validation and do not create a hybrid route.
14. Do not change non-`routeToPeak` modes; `snapToTrail` and `straightLine` should keep their current behavior.
15. Do not infer the terminal point from filename, peak metadata, or a separate nearest-point search when the planner already provides an anchored point.
</requirements>

<boundaries>
Edge cases:
- The feature only changes the route drafting path for peak-targeted routes.
- Existing undo/redo, marker drag, and save validation behavior stay as-is unless the new geometry needs the same state updates.
- The user still cannot route to an identical start/peak point.
- If the user starts off-track, keep the existing route-to-peak fallback behavior and do not introduce a new hybrid search path for that case.

Error scenarios:
- Unroutable track leg: use the straight-line fallback and keep the draft usable.
- Stale planner response: ignore it.
- Missing planner anchor data: fall back to the planner's returned geometry if available, otherwise use the straight-line fallback.

Limits:
- No new routing engine, graph search, or nearest-neighbour algorithm.
- No persistence migration.
- No change to map selection, peak lookup, or route export behavior beyond the geometry produced by this draft path.
</boundaries>

<implementation>
Likely files to update:
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`
- `./test/providers/route_draft_state_test.dart`
- `./test/widget/map_screen_route_sheet_test.dart`
- `./test/robot/map/map_route_journey_test.dart`
- `./test/harness/test_map_notifier.dart`

Implementation shape:
- Extend the route-to-peak branch in `MapNotifier` so it can append a straight terminal leg after the routed on-track geometry when the peak target is off-track.
- Keep the hybrid path deterministic by using the planner result's existing route points and anchors rather than recomputing geometry in the UI.
- Update the test harness fake only as needed so widget and robot tests can observe the same hybrid geometry and draft-state transitions.
- Prefer the smallest possible change in the planner/state machine rather than introducing a new route planning abstraction.
</implementation>

<stages>
1. Behavior slice.
   - Add a focused provider test for the off-track-peak hybrid path with a start point that is on a track.
   - Verify the draft commits routed points plus the terminal straight leg and stays saveable.

2. Fallback slice.
   - Add a provider test for planner `noPath`/failure fallback.
   - Verify the route still completes with a straight-line terminal leg and does not remain in a failure-only state.

3. UI slice.
   - Update widget coverage if any route-sheet copy or state indicator changes are required by the new behavior.
   - Verify the route sheet still shows the draft as routable and saveable during the hybrid flow.

4. Journey slice.
   - Extend the robot route-creation journey so it exercises `RouteMode.routeToPeak` with an off-track peak target and confirms the saved route geometry is hybrid.

5. Refactor slice.
   - Clean up any duplicated geometry handling only after the behavior is green.
</stages>

<illustrations>
Desired:
- Start on a track, peak off-track: route follows the track to the last routable point, then draws a straight line to the peak.
- Peak already on-track: the route ends cleanly at the peak without a duplicate last leg.
- Switching into `RouteMode.routeToPeak` after placing a start point immediately recomputes the peak leg.

Counter-examples:
- Drawing a straight line for the whole route when a routed track segment is available.
- Failing the draft when the track leg cannot be found, even though a straight-line fallback is available.
- Adding the peak coordinate twice when the routed geometry already ends there.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: provider tests cover hybrid route construction, fallback behavior, same-point validation, and stale-result handling.
- UI behavior: widget tests cover route-sheet state, draft saveability, and any copy or control-state changes needed for the new mode behavior.
- Critical journey: a robot-driven route-creation flow covers create route -> route to peak -> on-track start -> hybrid geometry -> save.

TDD expectations:
- Write one failing provider test slice at a time: hybrid geometry first, fallback second, stale-result handling third.
- Keep the implementation minimal for each slice and only refactor after the slice is green.
- Prefer public state transitions and fake planners over private-method assertions.

Robot-testing expectations:
- Use stable app-owned `Key` selectors already present in the route flow, including `create-route-fab`, the route mode buttons, and the route summary/draft roots.
- Keep route-planning deterministic with in-memory fakes or controlled planner outcomes.
- Verify the saved route geometry, not just the visible mode button state.

Recommended test split:
- Provider tests: hybrid route geometry, fallback behavior, and stale-result handling.
- Widget tests: route sheet state and save controls.
- Robot tests: end-to-end create-route journey for `RouteMode.routeToPeak`.
</validation>

<done_when>
1. Route creation and route editing both produce a hybrid route when the peak is off-track and the start is on-track.
2. The route follows track geometry as far as possible and then appends a straight line to the peak.
3. Unroutable peak legs still complete through the straight-line fallback.
4. The saved route geometry matches the drafted hybrid path.
5. The focused provider, widget, and robot tests pass for the new route-to-peak behavior.
</done_when>
