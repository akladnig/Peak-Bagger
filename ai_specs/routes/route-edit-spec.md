<goal>
Add in-place editing to the existing route draft workflow so a user can move draft markers, delete draft markers, and undo/redo any route edit without restarting the draft.
This matters because route creation is iterative: hikers need to correct points quickly while keeping the current draft and its save state intact.
</goal>

<background>
The app is a Flutter/Riverpod map application with an existing route draft editor.
Route drafting already lives in `./lib/providers/map_provider.dart`, `./lib/widgets/map_route_bottom_sheet.dart`, `./lib/screens/map_screen.dart`, `./lib/screens/map_screen_layers.dart`, and `./lib/widgets/route_marker.dart`.
Current route draft controls already support point placement, `Route to Peak`, `Snap to Trail`, `Straight Line`, `Out and Back`, and `Close Loop`.
Relevant tests and harnesses live in `./test/providers/route_draft_state_test.dart`, `./test/widget/map_screen_route_sheet_test.dart`, `./test/widget/map_screen_route_hover_test.dart`, `./test/widget/route_marker_layer_test.dart`, and `./test/robot/map/map_route_robot.dart`.
</background>

<discovery>
Inspect the current route-draft state machine, marker hit testing, mouse cursor selection, and route sheet control strip before coding.
Confirm how drag gestures are detected on marker widgets, how transient popups are dismissed, and how stale async route-planner responses are ignored during live marker movement.
Identify the smallest public `MapNotifier` contract that supports move, delete, undo, and redo without introducing a parallel editing subsystem.
</discovery>

<user_flows>
Primary flow:
1. User starts or continues a route draft.
2. User places draft points as usual.
3. User presses and holds a draft marker, then drags it to a new location.
4. The marker follows the pointer, the cursor becomes `SystemMouseCursors.grabbing`, and the affected route preview updates live during the drag.
5. User single-clicks a draft marker to open a transient delete popup and chooses `Delete Point` when needed.
6. User taps `Undo` or `Redo` to step through any prior route edit.
7. User saves the route with the edited geometry intact.

Alternative flows:
- Start marker edit: the first draft marker can be moved or deleted the same way as any other marker.
- End marker edit: the current terminal marker can be moved or deleted the same way as any other marker.
- History recovery: after an undo, a new edit truncates redo history and starts a new branch.
- Draft reset: closing or saving the draft clears edit history so reopening starts clean.
- Loop recovery: if a user moves or deletes either terminal marker on a closed-loop or out-and-back route, the route reopens into a normal editable draft and undo restores the previous closed/returned topology.
- Interior marker recovery: if a user moves a middle marker, the route reroutes both adjacent segments around the new position; if a user deletes a middle marker, the route removes that waypoint and reconnects its neighboring markers into a single path.
Open-route endpoint recovery: if a user moves the first marker on an open draft, that marker becomes the new route start; if a user moves the last marker, that marker becomes the new terminal waypoint; deleting either endpoint removes it and leaves the draft open with the remaining geometry intact. If the draft had a peak target, terminal edits keep the target only while the edited endpoint still represents the same peak-derived waypoint; otherwise the active draft target is cleared and `Route to Peak` becomes unavailable until a new valid target exists, with no fallback to `peakInfoPeak` or `selectedLocation` until the user explicitly picks a new target.

Error flows:
- Drag, delete, undo, and redo stay disabled while the draft is routing or saving.
- If an edit produces an inconsistent draft state, keep the last valid geometry recoverable and surface a route-draft error.
- If a drag triggers stale async route-planner responses, ignore the stale results and keep only the latest geometry.
- If deleting the final remaining marker empties the draft, keep route drafting active in an empty start-ready state rather than forcing cancellation.
</user_flows>

<requirements>
**Functional:**
1. Add marker drag editing for route draft markers in the map layer and provider contract.
   The hovered marker cursor must be `grab` when idle and `grabbing` while a drag is active.
   The dragged marker must follow pointer movement and update the visible draft route live while moving.
2. Add a single-click delete popup for draft markers.
   The popup must be transient, anchored near the clicked marker, show a red `Icons.deleteForever`, and include the red label `Delete Point`.
   Any draft marker may be deleted, including the first and last markers.
3. Add `Undo` and `Redo` controls to the right of `Close Loop` in `./lib/widgets/map_route_bottom_sheet.dart` with one icon-width gap between controls.
   `Undo` must use `Icons.undo` with tooltip `Undo (⌘ Z)`.
   `Redo` must use `Icons.redo` with tooltip `Redo (⌘ ⇧ Z)`.
   `Undo` and `Redo` must respond to `⌘Z` and `Shift+⌘Z` while the route draft editor is active, except when the route name field has focus, in which case native text undo/redo wins.
4. Undo/redo must cover all route edit actions, including point placement, marker moves, marker deletes, `Out and Back`, and `Close Loop`.
   A new edit after undo must discard redo history.
   A complete drag gesture counts as one history entry; intermediate drag positions are transient and must not create extra undo steps.
5. Expose the edit contract through public `MapNotifier` methods so widget and robot tests can drive the feature without private helpers.
   The notifier must provide public entry points for drag start/update/end as needed, delete, undo, and redo.
6. Keep route save, export, and route persistence behavior unchanged.
   This feature edits the active draft only and must not require schema changes or export-format changes.
7. Preserve the existing route point limit, route draft mode rules, and save gate conditions while editing.
   Edit actions must remain disabled when the draft is routing or saving.
8. Maintain exactly one visible source of truth for route draft geometry.
   Live drag updates, delete actions, undo, redo, `Out and Back`, and `Close Loop` must all flow through the same draft state machine and geometry versioning.
   Undo/redo must restore the full draft snapshot, including route geometry, routeDraftMode, routeDraftStage, routeDraftPeak, routeDraftNextMarkerId, and transient loading/error flags, while keeping request/version counters monotonic so stale async responses remain stale after history navigation.

**Error Handling:**
9. If a drag or delete action would create an inconsistent draft state, do not commit partial geometry.
    Surface a route-draft error and keep the last valid state recoverable.
10. If a delete action removes the last remaining marker, leave the draft open and reset it to an empty, start-ready draft.
    Undo must restore the removed marker.
11. During live drag routing, a `routed` response must accept the routed geometry, `noPath` and `offTrack` must fall back to the direct segment, and `failed` must preserve the last valid geometry and surface a route-draft error.
12. If route-planner responses arrive out of order during live drag, ignore stale responses using the existing request/version guard pattern.
13. If an edit is attempted while routing or saving, do nothing and keep the current draft unchanged.
14. If the draft is in `segmentFailure`, the route remains visible and editable so the user can recover with undo, redo, delete, or a new edit.

**Edge Cases:**
15. Dragging a marker must not open the delete popup.
    Use a drag threshold so click and hold can be distinguished from tap-to-delete.
16. The first marker and the last marker must be editable and deletable.
17. Undo/redo must restore route geometry, marker ordering, and marker display state consistently after move/delete/loop actions.
18. Existing `Out and Back` and `Close Loop` actions must still work and must participate in history.
19. The route-action strip must use the same square icon-button visual family for `Out and Back`, `Close Loop`, `Undo`, and `Redo`, rather than the current circular `FloatingActionButton.small` treatment.
20. The delete popup must use map-relative anchoring near the clicked marker and dismiss itself if it cannot be anchored or if the view changes enough to invalidate its placement.
21. The delete popup must include a close icon in the top-right corner, matching the route/track info popup pattern, and must dismiss on outside click, Escape, or any draft/view mutation.
22. Clicking a draft marker must consume the event so it opens the delete popup without also falling through to the map tap path that adds a new point.

**Validation:**
23. Use behavior-first TDD slices: provider history/state tests first, then widget tests for controls and popup behavior, then robot journey coverage last.
24. Keep tests deterministic by driving the public `MapNotifier` contract and by using route-planner and route-repository fakes instead of real services.
25. Require baseline automated coverage outcomes for logic/business rules, UI behavior, and the critical route-edit journey.
26. For the widget and robot lanes, use stable key-first selectors for the undo/redo buttons, the delete popup, the delete action, and the route draft marker hitboxes.
</requirements>

<boundaries>
Edge cases:
- Single-click versus drag: a click on a marker opens the delete popup; a press-and-drag moves the marker.
- Empty draft: after deleting the final point, the draft stays open but has no points until the user adds one.
- History branch: if the user undoes and then performs a new edit, redo history is discarded.
- History scope: history exists only for the active draft session and is cleared when the draft is saved, cancelled, or reset.

Error scenarios:
- Inconsistent draft state: preserve the current editability and show a route-draft error instead of mutating partial geometry.
- Stale async routing: ignore outdated route-planner results instead of applying them over newer edits.
- Disabled actions: ignore drag, delete, undo, and redo while the draft is routing or saving.

Limits:
- No route persistence migration is in scope.
- No GPX export or saved route schema changes are in scope.
- No new route mode is in scope.
- No separate marker-management screen or route editor subsystem is in scope.
</boundaries>

<implementation>
Modify or create files under `./lib/providers/map_provider.dart`, `./lib/screens/map_screen.dart`, `./lib/screens/map_screen_layers.dart`, and `./lib/widgets/map_route_bottom_sheet.dart`.
Update `./lib/widgets/route_marker.dart` only if a small interaction or cursor seam is required.
Keep the route editing history inside the existing route draft state machine rather than adding a parallel editor model.
Add stable keys for the new undo/redo controls and delete popup actions.
Preserve the existing marker hitbox keys so current hover and robot coverage keeps working.
Update tests under `./test/providers/route_draft_state_test.dart`, `./test/widget/map_screen_route_sheet_test.dart`, `./test/widget/map_screen_route_hover_test.dart`, `./test/widget/route_marker_layer_test.dart`, `./test/robot/map/map_route_robot.dart`, and `./test/robot/map/map_route_journey_test.dart`.
</implementation>

<validation>
Follow a one-test-at-a-time red-green-refactor cycle.

Provider/state slices:
1. Add a failing test for undo/redo history after a point placement.
2. Add a failing test for marker move history.
3. Add a failing test for marker delete history, including deleting the first or last marker.
4. Add a failing test that `Out and Back` and `Close Loop` participate in the same history stack.
5. Add a failing test for stale async result handling during live drag.

Widget slices:
6. Add a failing test for the undo/redo buttons, placement after `Close Loop`, tooltips, icon choice, and spacing.
7. Add a failing test for the delete popup appearance, destructive action label, and dismissal behavior.
8. Add a failing test for cursor state changes while hovering and dragging route markers.
9. Add a failing test for disabled states while routing or saving.
10. Add a failing keyboard test for `⌘Z` and `Shift+⌘Z` route-editor shortcuts.

Robot slices:
11. Add a failing robot journey for create route -> place points -> move a marker -> delete a marker -> undo -> redo -> save.
12. Use stable selectors for the route draft marker hitboxes, undo/redo buttons, delete popup, and delete action.
13. Keep the robot journey deterministic with route-planner fakes and explicit waits only where the UI contract requires them.

Expected behavior by layer:
- Logic/business rules: history stacks, draft geometry mutation, and branch truncation behave predictably.
- UI behavior: the marker cursor, delete popup, and undo/redo controls match the requested layout and enablement rules.
- UI behavior: the route-action strip uses the requested square icon-button family, the marker cursor wins over segment hover, and the delete popup dismisses predictably.
- Critical journey: a user can edit a draft route in-place and still save the edited route successfully.

Required seams:
- Deterministic route-planner fake for drag-driven route recomputation.
- Deterministic route-repository fake for save verification.
- Stable key-first selectors for route markers, edit controls, and delete popup actions.
</validation>

<stages>
Phase 1: Add route-edit history and public notifier methods.
Verify with provider tests that move/delete/undo/redo mutate the draft predictably.

Phase 2: Add marker drag and delete interactions in the map layer.
Verify with widget tests that the cursor, popup, and gesture split behave correctly.

Phase 3: Add undo/redo controls to the route sheet.
Verify the controls render in the requested position and participate in the history stack.

Phase 4: Add the robot journey for full in-place editing.
Verify a user can complete the edit flow end to end and save the edited route.
</stages>

<done_when>
The route draft editor can move any draft marker by drag, delete any draft marker through a transient popup, and undo or redo any route edit.
The route sheet shows the requested undo/redo controls in the requested position.
The route draft remains saveable after edits, and the existing route save/export behavior still works.
All required automated tests pass.
</done_when>
