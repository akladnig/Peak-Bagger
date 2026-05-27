<goal>
Add a one-shot `Out and Back` action to the route draft sheet so a user can mark the current draft endpoint as a waypoint, mirror the outbound path back to the start, and save/export that waypoint metadata with the route.
This is for hikers using the route editor to build turn-around routes without manually tracing the return leg.
</goal>

<background>
Current route drafting already supports `Snap to Trail`, `Straight Line`, and `Route to Peak` in `./lib/widgets/map_route_bottom_sheet.dart` and `./lib/providers/map_provider.dart`.
Routes are persisted through ObjectBox in `./lib/models/route.dart`, `./lib/services/route_repository.dart`, and `./lib/providers/route_repository_provider.dart`.
Route GPX export is built in `./lib/services/gpx_export_service.dart`; current waypoint XML is derived from correlated peaks, not explicit route waypoints.
Relevant tests and harnesses live in `./test/widget/map_screen_route_sheet_test.dart`, `./test/providers/route_draft_state_test.dart`, `./test/services/gpx_export_service_test.dart`, `./test/services/route_repository_test.dart`, `./test/robot/map/map_route_robot.dart`, and `./test/robot/map/map_route_journey_test.dart`.
</background>

<discovery>
Inspect the current route-draft state machine, save flow, and export path before coding.
Confirm how the active draft endpoint is represented, how mirrored geometry should be appended, and where explicit waypoint metadata should be stored in the route entity.
Verify the route sheet button layout and existing key-first test conventions before adding selectors.
</discovery>

<user_flows>
Primary flow:
 1. User starts or continues a route draft.
 2. User builds an outbound route to a chosen turnaround point.
 3. User taps `Out and Back`.
 4. The app records a waypoint at the current draft endpoint, mirrors the outbound geometry back to the start, updates distance/elevation summaries, and leaves the draft ready to continue or save.
 5. User saves the route and the stored route/exported GPX serialize waypoint metadata that was computed when the draft was saved.

Source-of-truth note:
- The authoritative turnaround point is the final committed geometry vertex in `routeDraftCommittedPoints`; if any draft control endpoint diverges from that committed vertex, treat the draft as inconsistent and do not create a waypoint from the divergent control state.

Alternative flows:
 - Peak turnaround: if the current endpoint is a peak target or peak-derived location, the waypoint label uses the peak name.
 - Non-peak turnaround: if the endpoint is not a peak, the waypoint label is generated as `Waypoint 1` for the first such waypoint on that route.
 - Existing route waypoints: if a route already contains stored waypoints, the next generated generic label must continue the numbering sequence using only non-peak-derived waypoints as the counter.
 - Returning users: re-exporting an existing saved route must preserve previously saved waypoint metadata unchanged.

Error flows:
- No committed outbound geometry: `Out and Back` stays disabled and does nothing.
- Draft is currently routing or saving: the button stays disabled and no state changes occur.
- Mirrored return cannot be produced from the current draft state: leave the draft unchanged and surface a route-draft error rather than saving partial geometry.

Layout note:
- Place the new control inside the existing horizontally scrollable route control strip, immediately after `Straight Line` and before the route name field; keep the name field at its existing fixed width so the strip scrolls on narrow screens instead of shrinking the field.
</user_flows>

<requirements>
**Functional:**
1. Add a visible `Out and Back` control to `./lib/widgets/map_route_bottom_sheet.dart` between `Straight Line` and the route name field, using `Icons.sync_alt`, a tooltip of `Out and Back`, and a stable key suitable for widget/robot tests. Use the same `FilledButton` family and visual weight as the existing route mode buttons, but without a selected state. Enable it only when there is a valid outbound draft to mirror: once `routeDraftCommittedPoints.length >= 2`.
2. Implement the control as a one-shot draft action in `./lib/providers/map_provider.dart`; it must not become a new persistent route mode.
3. The action must use the current committed draft endpoint as the turnaround waypoint and mirror the outbound committed geometry back to the route start without re-planning the return leg.
4. The draft state must persist explicit waypoint metadata on the route so the saved route and GPX export can distinguish peak turnarounds from generic waypoints.
5. Save/export must preserve the existing route geometry behavior and add GPX `<wpt>` output for stored route waypoints, using the peak name when the waypoint is peak-derived and `Waypoint x` otherwise. Waypoint metadata is computed when saving the draft, persisted on the route, and later exports serialize the stored metadata unchanged.
5a. Explicit stored route waypoints and correlated peaks must be merged into a single export list. When two candidates resolve to the same normalized coordinate, correlated peaks take precedence and suppress the explicit waypoint.
5b. Define a concrete persisted waypoint schema in `./lib/models/route_waypoint.dart` and a JSON-backed route field in `./lib/models/route.dart`; each waypoint must store `latitude`, `longitude`, `label`, `sequence`, `isPeakDerived`, `peakOsmId?`, and `peakName?`, and legacy routes must decode to an empty waypoint list by default.

**Error Handling:**
6. Disable the action while the route draft is invalid for turnaround, while a segment is being routed, or while a save is in progress.
7. If the action is invoked from an inconsistent draft state, do not mutate committed geometry or waypoint metadata; surface a route-draft error and keep the draft recoverable.
8. Preserve the existing save failure path: route save errors must leave the draft open, keep the current geometry intact, and show failure feedback.
9. Expose the action as a dedicated public `MapNotifier` method such as `applyRouteDraftOutAndBack()` so widget and robot tests can drive the contract through the public API.
10. The out-and-back action must bump the geometry/elevation version exactly once and trigger the same resampling path used after other committed-geometry edits; it must leave the active route mode unchanged because the action is one-shot.
11. Generic waypoint labels are assigned at creation time and persisted unchanged; peak-derived waypoints still occupy ordered waypoint slots but do not consume generic `Waypoint x` numbering or advance the generic counter.
12. Peak identity precedence must be explicit: if the active turnaround point is the current `routeDraftPeakTarget` or a waypoint record already marked `isPeakDerived`, use that peak's name; otherwise fall back to a generic waypoint label.

**Edge Cases:**
9. The first generic waypoint label on a route is `Waypoint 1`; later labels must increment based on existing stored waypoints.
10. If the turnaround point is a peak target already represented in the draft, use the peak's display name rather than a generic label.
11. The mirrored geometry must not duplicate the turnaround point in the return leg; the waypoint is metadata, not a repeated polyline vertex.
12. Existing saved routes without waypoint metadata must still load and export successfully with backward-compatible defaults.
13. Existing peak-correlated waypoint export should not duplicate an explicit stored waypoint at the same location.

**Validation:**
14. Add behavior-first tests for route-waypoint model persistence, mirrored geometry creation, label selection, and export XML generation.
15. Keep tests deterministic by injecting route repository/storage and by exercising the action through the public `MapNotifier` and route export APIs, not private helpers.
16. Use robot-driven coverage for the critical user journey: build an outbound draft, tap `Out and Back`, verify the draft UI/state updates, then save and confirm the saved route is present.
17. Use widget tests for selector presence, enable/disable states, tooltip text, and route sheet layout placement.
18. Use unit/service tests for route model round-tripping, waypoint numbering, correlated-peak precedence, and GPX serialization at `GpxConstants.precision`.
19. Validation must cover baseline automated outcomes for logic, UI behavior, and the critical journey, with any remaining gaps called out explicitly.
</requirements>

<boundaries>
Edge cases:
- If the route draft has fewer than two committed points, the action does nothing.
- If the current endpoint is already the start point, treat the action as invalid instead of creating a degenerate loop.
- If the route already contains saved waypoints, numbering continues from the stored list rather than resetting.
- Existing peak-correlated waypoint export should not duplicate an explicit stored waypoint at the same normalized coordinate; emit the correlated peak first and suppress the explicit waypoint.
- For export dedupe, compare coordinates after normalizing both explicit and correlated points to `GpxConstants.precision` decimal places.
- Use `sequence` as a 1-based stable order field for the stored waypoint list; the label text remains immutable after save.

Error scenarios:
- Invalid draft state: show a route-draft error and keep the draft editable.
- Save failure: preserve the draft geometry and surface the existing save snackbar/error; waypoint metadata is recomputed on retry from the current draft state.
- Export failure: fail the export operation without mutating the saved route.

Limits:
- Manual waypoint editing/creation UI is out of scope for this slice.
- No route-planning algorithm changes are required beyond reusing the already-committed outbound geometry for the return leg.
- Do not change unrelated route modes, peak correlation rules, or existing export file naming behavior.
</boundaries>

<implementation>
Files to update are expected to include `./lib/widgets/map_route_bottom_sheet.dart`, `./lib/providers/map_provider.dart`, `./lib/models/route.dart`, `./lib/models/route_waypoint.dart`, `./lib/core/constants.dart`, `./lib/services/gpx_export_service.dart`, `./lib/services/route_repository.dart`, and `./lib/providers/route_repository_provider.dart`.
Add a small persisted route-waypoint model or equivalent JSON-backed field so route waypoints survive ObjectBox save/load and GPX export.
Preserve the current peak-correlation export path for routes that still rely on it, but de-duplicate any point that is already represented by explicit waypoint metadata using `GpxConstants.precision`-normalized coordinates.
Set `GpxConstants.precision` to `6` in `./lib/core/constants.dart` and use it for GPX coordinate formatting.
Keep the button and state changes minimal: reuse the current route draft state machine, add only the seam needed for the one-shot action, and avoid introducing a second route-draft mode.
Use a dedicated `MapNotifier.applyRouteDraftOutAndBack()`-style public method for the button action so widget and robot tests can drive the exact contract without reaching into private helpers.
When no explicit waypoints exist on a legacy route, keep the current peak-correlation export behavior unchanged and emit no explicit route-waypoint `<wpt>` entries.
Regenerate `./lib/objectbox.g.dart` and verify `./lib/services/objectbox_schema_guard.dart` accepts the updated model definition without breaking legacy route reads.
Recompute waypoint metadata from the current committed draft state at save time rather than caching draft-side waypoint records in `MapState`.
Update test coverage in `./test/widget/map_screen_route_sheet_test.dart`, `./test/providers/route_draft_state_test.dart`, `./test/services/gpx_export_service_test.dart`, `./test/services/route_repository_test.dart`, `./test/robot/map/map_route_robot.dart`, and `./test/robot/map/map_route_journey_test.dart`.
</implementation>

<validation>
Use TDD slices in this order:
1. Add failing tests for route waypoint persistence and route model round-trip.
2. Add failing tests for the one-shot out-and-back action and mirrored geometry.
3. Add failing widget tests for button placement, tooltip, and enabled/disabled states.
4. Add failing GPX export tests for explicit waypoint XML and label selection.
5. Add a failing robot journey for build -> out-and-back -> save.
6. Regenerate the ObjectBox model artifacts and verify the schema guard still accepts legacy route rows.
7. Add a widget test for the horizontal scroll strip at a narrow viewport and a robot journey at a desktop-width viewport.

Expected behavior by test layer:
- Unit/model tests: route waypoints persist through save/load and generic numbering increments predictably.
- Provider tests: the one-shot action mutates draft geometry exactly once, mirrors the outbound path back to the start, increments the geometry/elevation request version once, and leaves the active route mode unchanged.
- Provider tests: the one-shot action rejects inconsistent draft state and uses the final committed vertex as the turnaround source.
- Widget tests: the button is visible in the correct place, uses the correct icon/tooltip, matches the route mode button family, and disables at the right times.
- Service tests: exported GPX includes `<wpt>` entries for stored route waypoints with the correct names and correlated-peak precedence.
- Robot tests: the user can complete the visible journey without relying on private helpers or unstable selectors.

Required seams:
- A deterministic route storage fake for persistence tests.
- A deterministic route export verification seam that inspects generated GPX text.
- Stable key-first selectors for the new button and any status text used by the journey test.
</validation>

<stages>
Phase 1: Add the route waypoint model and persistence fields, then verify save/load round-trips with tests.
Phase 2: Implement the one-shot `Out and Back` action in the route draft state machine and verify mirrored geometry with provider tests.
Phase 3: Add the route sheet control and verify placement, tooltip, and enablement with widget tests.
Phase 4: Extend GPX export to emit explicit route waypoints and verify peak-name versus generic-label output with service tests.
Phase 5: Add the robot journey that exercises the full visible route drafting flow end to end.
Phase 6: Verify the narrow-viewport control strip scrolls instead of compressing the route name field.
</stages>

<done_when>
The route sheet exposes an `Out and Back` button in the requested position.
Tapping it on a valid draft records waypoint metadata, mirrors the outbound geometry back to the start, and keeps the draft saveable.
Peak turnarounds export with the peak name; non-peak turnarounds export as numbered `Waypoint x` entries.
Routes without stored waypoint metadata continue to export through the existing peak-correlation path with no migration breakage.
Existing routes still load and export without migration breakage.
All required automated tests pass.
</done_when>
