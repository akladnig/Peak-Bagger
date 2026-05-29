<goal>
Add Route edit and delete capability to ObjectBox Admin so maintainers can correct persisted route data without leaving the admin browser.
This matters because route records are part of the app's visible map data and need a fast, low-risk way to inspect, fix, view, and remove bad rows in place.
</goal>

<background>
The app is a Flutter/Riverpod map application.
Route rows already load through `./lib/services/objectbox_admin_repository.dart` and the admin shell already supports selection, search, sort, and row refresh through `./lib/providers/objectbox_admin_provider.dart`.
Existing admin patterns for Peak and GpxTrack already cover inline editing, confirm-delete dialogs, stable keys, and success dialogs in `./lib/screens/objectbox_admin_screen.dart`, `./lib/screens/objectbox_admin_screen_details.dart`, `./lib/screens/objectbox_admin_screen_table.dart`, and `./lib/widgets/dialog_helpers.dart`.
The map screen already has a shared `CameraFit.bounds`-based extent workflow for track/map zooming in `./lib/screens/map_screen.dart`, and route visibility/selection refresh already flows through `routeRevisionProvider` in `./lib/providers/route_repository_provider.dart`.

Assumption: all persisted Route properties except the primary key are editable inline, including the technical JSON-backed fields.
The spec keeps schema, export, and route-draft behavior unchanged.

Files to examine:
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/screens/objectbox_admin_screen_details.dart`
- `./lib/screens/objectbox_admin_screen_table.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/providers/objectbox_admin_provider.dart`
- `./lib/providers/route_repository_provider.dart`
- `./lib/screens/map_screen.dart`
- `./test/harness/test_objectbox_admin_repository.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/widget/objectbox_admin_browser_test.dart`
- `./test/robot/objectbox_admin/objectbox_admin_robot.dart`
- `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
</background>

<discovery>
Verify the current Route field order and which fields should be read-only versus editable in the admin pane.
Confirm the smallest route-mutation seam that can save and delete Route rows through `RouteRepository` while leaving `ObjectBoxAdminRepository` read-only.
Check how route selection should be reconciled after save/delete so the map, route drawer, and admin browser stay in sync through `routeRevisionProvider`.
Confirm whether route bounds should be fit from the route's stored geometry or from the rendered polyline geometry, and reuse the existing `CameraFit.bounds` pattern rather than duplicating camera math.
</discovery>

<user_flows>
Primary flow:
1. User opens ObjectBox Admin and selects the `Route` entity.
2. User selects a route row and inspects the route fields in the right-side details pane.
3. User clicks `View Route on Main Map` to jump to MapScreen, see the route, and have the camera fit the route bounds.
4. User clicks the edit action, updates route fields inline, and saves.
5. User sees `Update Successful`, closes the dialog, and the row remains selected if it still exists.
6. User can then delete the route from the table or continue browsing without losing sort/search state.

Alternative flows:
- Search/sort flow: user filters Route rows or changes sort order, then edits or deletes the currently visible row.
- Non-selected delete flow: user deletes a different Route row and keeps the current selection intact.
- Re-open flow: user closes the details pane, reselects the row, and sees the saved values.
- Empty-geometry flow: user views a Route with 0 or 1 point and still reaches MapScreen without a crash.

Error flows:
- Invalid inline input keeps the edit form open and surfaces field errors instead of saving partial data.
- Backend save failure shows a blocking error dialog and preserves the user's edits.
- Delete cancel closes the dialog and leaves the table and selection unchanged.
- Stale route selection after save/delete is reconciled by the existing route-revision refresh path.
</user_flows>

<requirements>
**Functional:**
1. Add Route-specific details-pane actions in `./lib/screens/objectbox_admin_screen_details.dart`.
   Render a `visibilityOutlined` icon button with tooltip `View Route on Main Map` to the left of the edit action, and keep the edit action to the left of the close icon.
   The action row must use stable app-owned keys, including `objectbox-admin-route-view-on-map`, `objectbox-admin-route-edit`, and the existing close key.
2. Render Route details inline in edit mode, not in a modal dialog.
   The edit state must stay inside the details pane and expose inline form controls for the editable Route fields, with the primary key shown read-only.
   Editable fields include `name`, `desc`, `colour`, `distance2d`, `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, and `highestElevation`.
   The technical route payload fields `gpxRouteJson` and `displayRoutePointsByZoom` must remain visible as read-only, selectable text with scroll/cap behavior, using the same shared helper pattern already used for long `GpxTrack` text fields.
3. Persist Route edits through the real `RouteRepository` and refresh the admin data after save.
    After a successful save, increment `routeRevisionProvider`, refresh the admin rows while keeping the selected row by primary key when it still exists, and show `showSingleActionDialog` with title `Update Successful` and content `<route name> updated.` using the saved Route name.
    Use stable dialog keys `objectbox-admin-route-update-success-close` and `objectbox-admin-route-save-error-close` for the save success and save failure close actions.
    Saving Route metadata must preserve the existing route geometry, waypoint payload, and display cache fields unchanged.
    Save must load the existing Route by id and update only the editable scalar fields before persisting.
4. Add a Route-only delete action column in `./lib/screens/objectbox_admin_screen_table.dart`.
   The delete icon must be pinned in the actions column for Route data rows and use stable keys like `objectbox-admin-route-delete-<id>`.
   Keep the existing table paging, horizontal scroll, and non-Route browsing behavior unchanged.
5. Use the same confirm-delete pattern as the other destructive admin flows.
   The confirmation dialog must use title `Delete Route?` and message `This will permanently delete the <route name>. Do you want to proceed?`.
   The dialog must use stable `cancel-delete` and `confirm-delete` keys.
6. Deleting a Route must refresh the admin rows and keep selection stable.
   If the deleted row was not selected, preserve the current selected row.
   If the deleted row was selected, clear the selection only after the delete completes.
   The delete path must also increment `routeRevisionProvider` so the map and route drawer observe the updated store.
7. Viewing a Route on the main map must open MapScreen and center the camera on the Route geometry.
    Route visibility must be enabled, the Route must be selected by id, and any selected track must be cleared to avoid conflicting selection before the camera fit runs.
    The camera should fit the route bounds using the same `CameraFit.bounds` approach used elsewhere in MapScreen.
    Add a public `MapNotifier` route-focus request seam that selects the Route by id so MapScreen can resolve the loaded Route and perform the bounds fit without depending on private screen helpers.
    Use a safe fallback for empty or single-point geometry.
8. Preserve the existing browse/search/sort/detail-pane behavior for all current admin entities.
   This change must not alter Peak, GpxTrack, PeakList, Tasmap50k, or PeaksBagged browsing behavior.

**Error Handling:**
9. Invalid edit input must not mutate stored data.
    Keep the form open, show field errors, and prevent save until the form is valid.
10. Route names must be non-empty after trimming.
    Block save and show a clear validation error when the name field is blank or whitespace only.
11. Save failures must be explicit.
    Show a blocking `Save Failed` dialog, keep the user's edits in place, and do not refresh the row list until the save succeeds.
12. Missing Route geometry must not crash the map jump.
    If bounds cannot be computed, fall back to a reasonable center/zoom behavior and still navigate to the map.
13. Canceling delete must be a no-op.
    The row list, current selection, and route revision state must remain unchanged.
14. Unsaved Route edits must follow the existing Peak admin lifecycle.
    Changing the selected row, switching entities, or closing the details pane discards unsaved Route edits and reloads the selected row state without a discard confirmation.
15. While a Route save is in progress, disable the edit, view-on-map, and close actions and keep the pane stable until the save completes.

**Required Keys:**
16. The Route save success dialog close button must use `objectbox-admin-route-update-success-close`.
17. The Route save failure dialog close button must use `objectbox-admin-route-save-error-close`.

**Edge Cases:**
18. If a saved rename no longer matches the current search filter, the row may disappear after refresh and the selection should clear because the row is no longer visible.
19. If the Route row is edited while another row is selected, the selected row should remain selected after refresh when it still exists.
20. Long route JSON/text fields must stay copyable/selectable and must not expand the details pane vertically without bound.
21. Add Route delete behavior without changing the existing Peak or GpxTrack delete columns.

**Validation:**
22. Use behavior-first TDD slices: repository/data mapping tests first, widget tests for the details pane and table behavior second, robot journey coverage last.
23. Keep tests deterministic by using `RouteRepository.test(...)`, `TestObjectBoxAdminRepository`, and a test map notifier or route-revision seam instead of real ObjectBox or map services.
24. Require baseline automated coverage outcomes for logic/business rules, UI behavior, and the critical admin journey.
25. For widget and robot tests, use stable key-first selectors for the route actions, edit fields, delete button, and dialog buttons.
</requirements>

<boundaries>
Edge cases:
- Preserve current search, sort, pagination, and selection behavior while switching the details pane into edit mode.
- Keep Route view-on-map behavior separate from row selection changes in the admin table.
- Treat long JSON fields as admin text, not as a separate editor subsystem.

Error scenarios:
- Invalid field input, failed persistence, or a missing row during refresh must fail cleanly without corrupting the selected row state.
- If a route is deleted while selected on the map, the existing route-revision reconciliation path should clear the stale selection.

Limits:
- No ObjectBox schema migration is in scope.
- No route-draft editing or export-format changes are in scope.
- No new admin entity type is in scope.
- No modal editor is in scope for Route editing.
</boundaries>

<implementation>
Modify `./lib/screens/objectbox_admin_screen_details.dart` to add Route-specific read-only and inline-edit views, plus the view-on-map and edit actions.
Modify `./lib/screens/objectbox_admin_screen_table.dart` to add the Route delete action column and stable delete keys.
Modify `./lib/screens/objectbox_admin_screen.dart` to wire Route save/delete/view-on-map behavior, route-revision refreshes, and selection retention.
Modify `./lib/providers/map_provider.dart` and `./lib/screens/map_screen.dart` to expose and consume the public route-focus request seam used by `View Route on Main Map`.
Use `./lib/services/route_repository.dart` and `./lib/providers/route_repository_provider.dart` for Route persistence, and keep `./lib/services/objectbox_admin_repository.dart` focused on read/query mapping.
Update `./lib/screens/map_screen.dart` only if a shared route-bounds helper or camera-fit seam is needed for the map jump.
Update `./test/harness/test_objectbox_admin_repository.dart` and `./test/services/objectbox_admin_repository_test.dart` if the Route row mapping or field order helpers need explicit coverage.
Update `./test/widget/objectbox_admin_shell_test.dart` and `./test/widget/objectbox_admin_browser_test.dart` for inline edit, save, delete, and selection behavior.
Add or extend `./test/robot/objectbox_admin/objectbox_admin_robot.dart` and `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` for the end-to-end route admin journey.
</implementation>

<validation>
Follow one test at a time and keep each red-green-refactor cycle small.

Provider/data slices:
1. Add a failing test for Route row mapping and field exposure in `objectbox_admin_repository_test.dart` if new helper ordering is introduced.
2. Add a failing test for Route save/delete refresh behavior if route-revision or selection retention logic is extracted.

Widget slices:
3. Add a failing test that the Route details pane shows the view-on-map action, edit action, and close icon in the requested order.
4. Add a failing test that Route edit mode renders inline form controls instead of a modal dialog.
5. Add a failing test that long Route JSON/text fields are capped and scrollable in read-only mode.
6. Add a failing test that a successful save shows `Update Successful` and `<route name> updated.` with the saved name.
7. Add a failing test that Route delete shows `Delete Route?`, uses `cancel-delete` / `confirm-delete`, and preserves or clears selection correctly.
8. Add a failing test that view-on-map navigates to MapScreen and requests a route-bound camera fit.

Robot slices:
9. Add a failing robot journey for browse Route -> open details -> view on map -> edit inline -> save -> delete -> verify the table and map state refresh.
10. Use stable selectors for the Route row delete icon, view-on-map action, edit action, save action, long-field editors, and confirm/cancel delete buttons.
11. Keep the route-admin robot deterministic with a test Route repository and explicit map-state seams rather than real persistence or asynchronous map services.

Expected coverage outcomes:
- Logic/business rules: Route row mapping, selection retention, route-revision refresh, and delete bookkeeping behave predictably.
- UI behavior: the Route details pane action row, inline edit controls, long-field scrolling, and delete confirmation dialog match the requested layout and keys.
- Critical journey: a maintainer can inspect a Route, jump to it on the main map, edit it inline, save it, and delete it without leaving the admin flow.

Required seams:
- `RouteRepository.test(...)` for deterministic persistence.
- `TestObjectBoxAdminRepository` for deterministic admin rows and entity metadata.
- Stable key-first selectors for Route actions, delete dialog buttons, and edit form controls.
- A map-state seam that can observe route revision refreshes without relying on real map services.
- A public route-focus request seam from `MapNotifier` into `MapScreen` that selects a Route by id for route-bounds fit behavior.
</validation>

<stages>
Phase 1: Wire Route persistence and row-mapping behavior.
Verify with repository/data tests that Route rows load, save, and delete through the expected seams.

Phase 2: Add Route details-pane actions and inline editing.
Verify with widget tests that the action order, form controls, validation, and success dialog behave correctly.

Phase 3: Add Route table delete actions and map navigation.
Verify with widget tests that delete confirmation, selection retention, and view-on-map camera fitting work as requested.

Phase 4: Add the end-to-end robot journey.
Verify a user can complete the full Route admin flow and the map/admin state stays synchronized.
</stages>

<done_when>
Route rows in ObjectBox Admin can be viewed, edited inline, saved, and deleted.
The Route details pane exposes the requested view-on-map and edit actions in the requested order.
Route delete uses the requested confirmation dialog and stable keys.
Route save and delete refresh the admin list and route visibility state through the route revision path.
The required automated tests pass.
</done_when>
