<goal>
Add a one-shot `Close Loop` action to the route draft sheet so hikers can close an in-progress route back to its starting point with one tap. The control should prefer a real routed loop when the graph supports it, fall back to the existing `Out and Back` behavior when no loop exists, and fall back to straight-line closure when the draft is off track.
This benefits route editors who want a looped hike without manually tracing the return leg or learning separate recovery steps.
</goal>

<background>
Current route drafting already supports `Snap to Trail`, `Straight Line`, `Route to Peak`, and `Out and Back` in `./lib/widgets/map_route_bottom_sheet.dart` and `./lib/providers/map_provider.dart`.
Route planning is handled by `./lib/services/route_planner.dart`, which distinguishes `routed`, `offTrack`, `noPath`, and `failed` results.
Existing draft-action patterns, enablement rules, and robot/widget test coverage live in `./test/providers/route_draft_state_test.dart`, `./test/widget/map_screen_route_sheet_test.dart`, and `./test/robot/map/map_route_journey_test.dart`.
Use `route-out-and-back-spec.md` and `route-out-and-back-plan.md` as the closest reference for button placement, one-shot state changes, and test structure.
</background>

<discovery>
Before coding, verify:
1. How the current one-shot `Out and Back` action appends geometry and resamples elevation.
2. How `RoutePlanningStatus.routed`, `offTrack`, and `noPath` should map to the requested close-loop fallback behavior.
3. Whether the route sheet strip already scrolls cleanly on narrow screens after adding another action button.
4. Which public `MapNotifier` seam should own the new action so tests do not reach into private helpers.
</discovery>

<user_flows>
Primary flow:
1. User starts or continues a route draft.
2. User builds a partial route and reaches the point they want to return from.
3. User taps `Close Loop`.
4. The app attempts to route from the current committed endpoint back to the starting point.
5. If routing succeeds, the draft closes as a loop, updates distance/elevation state, and remains saveable.

Alternative flows:
- No loop available: the planner returns `noPath`, so the app falls back to the existing `Out and Back` geometry instead of leaving the draft stranded.
- Off track: the planner returns `offTrack`, so the app closes the route with straight-line return geometry for that one action.
- Existing closed loop: if the draft is already closed, the control stays disabled and the tap is ignored.
- Returning users: reopening an in-progress draft should not require any extra loop state; the action is still available whenever the draft is valid.

Error flows:
- Inconsistent draft state: do not mutate committed geometry; surface a route-draft error and keep the draft editable.
- Planner failure: leave the draft unchanged, show failure feedback, and preserve the user's ability to retry or cancel.
- Save failure after a successful close: keep the draft open with the closed geometry intact so the user can retry save.
</user_flows>

<requirements>
**Functional:**
1. Add a visible `Close Loop` control to `./lib/widgets/map_route_bottom_sheet.dart` between `Out and Back` and the route name field, using `Icons.refresh`, a tooltip of `Close Loop`, and a stable key suitable for widget and robot tests.
2. Use the same compact action-button family and visual weight as the existing `Out and Back` control, but do not make `Close Loop` a persistent route mode.
3. Implement the action as a one-shot `MapNotifier` method such as `applyRouteDraftCloseLoop()` in `./lib/providers/map_provider.dart` so tests can drive the exact contract through the public API.
4. When the route planner can route back to the start, append the routed return leg to the committed geometry, update `routeDraftControlEndpoints` and `routeDraftMarkers`, update distance/elevation summaries, and ensure the final committed point exactly matches the starting point so closed-loop checks succeed.
5. When the planner returns `noPath`, fall back to the existing `Out and Back` behavior by reusing the existing one-shot action path or a shared helper rather than reimplementing it.
6. When the planner returns `offTrack`, fall back to straight-line return geometry by reusing the existing straight-line append path rather than duplicating logic.
7. Preserve the current route mode selection after the action completes; the button must remain one-shot.
8. Keep the save flow unchanged except for the updated geometry; closed-loop drafts must still save and export like any other route.

**Error Handling:**
9. Enable the control whenever the draft is active, has at least two committed points, and is not already closed; disable it only while a segment is routing, while save is in progress, while in `segmentFailure`, or after the loop is already closed.
10. If the action is invoked from an inconsistent draft state, do not mutate committed geometry or waypoint metadata; surface a route-draft error and keep the draft recoverable.
11. If the planner fails, leave the draft unchanged and preserve the existing error recovery path.
12. Do not introduce a second route-planning mode or any new persistence schema for this feature.

**Edge Cases:**
13. Treat the final committed point as the authoritative current endpoint.
14. Do not duplicate the start point when closing the loop; the final committed point must equal the first committed point exactly.
15. Keep route-name input width fixed so the added button causes horizontal scrolling on narrow screens instead of compressing the field.
16. If the draft is already closed, all route-close actions should stay disabled.

**Validation:**
17. Add behavior-first provider tests for routed closure, `noPath` fallback, `offTrack` straight-line fallback, invalid-state rejection, and no-op behavior after the loop is already closed.
18. Add widget tests for button presence, icon, tooltip, enabled/disabled states, placement between `Out and Back` and the name field, and narrow-viewport horizontal scrolling.
19. Add a robot-driven journey test for the critical path: build a draft, tap `Close Loop`, verify the visible draft updates, save, and confirm the route persists.
20. Keep tests deterministic with injected route-planner fakes, in-memory route storage, and stable key-first selectors.
21. Require baseline automated coverage for logic, UI behavior, and the critical user journey.
22. Use TDD in vertical slices: provider behavior first, then widget behavior, then robot journey.
</requirements>

<boundaries>
Edge cases:
- Drafts with fewer than two committed points cannot close.
- A route that is already closed must not add a second loop.
- The control should work from any active route mode, but it must not mutate the selected mode.
- The close-loop action should reuse existing geometry-edit resampling behavior; it should not create a separate resampling path.

Error scenarios:
- Route planner `failed`: show a route-draft error and keep the draft editable.
- Inconsistent control-endpoint chain: refuse the action and leave geometry untouched.
- Save retry after failure: recompute from the current committed draft state, not stale cached loop data.

Limits:
- No new route data model or export format changes are required for this feature.
- No changes to unrelated route modes, peak handling, or route persistence behavior should be introduced.
- Manual waypoint editing remains out of scope.
</boundaries>

<implementation>
Files expected to change:
- `./lib/widgets/map_route_bottom_sheet.dart`
- `./lib/providers/map_provider.dart`
- `./test/providers/route_draft_state_test.dart`
- `./test/widget/map_screen_route_sheet_test.dart`
- `./test/robot/map/map_route_robot.dart`
- `./test/robot/map/map_route_journey_test.dart`

Patterns to follow:
- Reuse the existing one-shot action pattern used by `Out and Back`.
- Reuse the current route planner and draft resampling flow instead of introducing a new planner abstraction.
- Use a public notifier seam for the button action so widget and robot tests stay implementation-agnostic.

What to avoid:
- Avoid adding a persistent `Close Loop` route mode.
- Avoid private-helper-only logic that cannot be reached by tests.
- Avoid changing persistence or export layers unless a regression is discovered while closing the loop.
</implementation>

<validation>
Use TDD slices in this order:
1. Add failing provider tests for close-loop routing success, `noPath` fallback, `offTrack` fallback, and invalid-state rejection.
2. Add failing widget tests for selector presence, button family, tooltip, placement, and enablement.
3. Add a failing robot journey for build -> close loop -> save.
4. Verify the closed route still saves and reopens as a normal persisted route.

Expected coverage outcomes:
- Logic tests prove the one-shot action mutates geometry exactly once and leaves the selected mode unchanged.
- Widget tests prove the control is visible, correctly labeled, correctly positioned, and disabled in the right states.
- Robot tests prove the visible user journey works end to end with stable selectors.

Required seams:
- Deterministic route-planner fake that can return `routed`, `noPath`, `offTrack`, and `failed`.
- In-memory route repository/storage for save verification.
- Stable keys for the new button and any status text asserted by the robot test.
</validation>

<stages>
Phase 1: Define the `Close Loop` button and public notifier seam, then verify the button renders and is disabled/enabled correctly.
Phase 2: Implement routed closure, `noPath` fallback, and `offTrack` fallback in the draft state machine, then verify geometry and resampling behavior.
Phase 3: Add the robot journey and verify the closed route still saves successfully.
Phase 4: Verify narrow-screen layout still scrolls horizontally without shrinking the route name field.
</stages>

<done_when>
The route sheet shows a `Close Loop` control in the requested position.
The action closes a valid draft back to its start point using routed geometry when available.
When routing is unavailable, the action falls back to `Out and Back` or straight-line closure as specified.
Closed-loop drafts remain editable and saveable, and all required automated tests pass.
</done_when>
