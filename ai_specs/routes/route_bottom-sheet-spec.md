<goal>
Add a placeholder Create Route experience on the Map screen so a user can open a bottom sheet, edit a draft route name, toggle routing mode, and place temporary route markers on the map.
This matters because the route workflow is the first step toward route creation and needs to fit the existing map shell without breaking navigation, shortcuts, or the current map action rail.
</goal>

<background>
The app is a Flutter/Riverpod map application with an existing map shell, end drawers, keyboard shortcuts, and transient popups.
Relevant files to examine and align with:
@lib/screens/map_screen.dart
@lib/widgets/map_action_rail.dart
@lib/providers/map_provider.dart
@lib/core/constants.dart
@lib/widgets/side_menu.dart
@lib/widgets/dialog_helpers.dart
@test/widget/map_screen_route_entry_test.dart
@test/widget/map_screen_keyboard_test.dart
@test/widget/map_screen_peak_info_test.dart
@test/widget/objectbox_admin_shell_test.dart

The implementation should reuse the current map-shell patterns, selector keys, and provider-driven state rather than introducing a parallel route framework.
</background>

<discovery>
Examine the existing map action rail, end drawer handling, keyboard routing, and dialog helpers before implementing.
Confirm how the Map screen currently clears transient surfaces, how it opens drawers, and how widget tests locate stable keys.
Use those patterns for the route sheet and avoid inventing a separate navigation path.
</discovery>

<user_flows>
Primary flow:
1. The user taps Create Route on the Map screen.
2. The app clears transient map surfaces, closes any open popups or drawers, and enters route drafting mode.
3. A persistent, non-blocking bottom sheet slides up from the bottom with a fixed height and shows the header, placeholder elevation graph, route name field, and route actions.
4. The default routing mode is Snap to Trail.
5. The user clicks on the map to place temporary green route markers.
6. The user can switch between Snap to Trail and Straight Line, with only one mode selected at a time.
7. The user closes the sheet with Cancel or Save.

Alternative flows:
- Returning user with existing map state: opening Create Route must not disturb the current base map selection or camera beyond the explicit cleanup required by route entry.
- Side menu navigation while drafting: the app asks for confirmation before leaving and only continues if the user confirms.
- Keyboard-driven use: allowed shortcuts still work while route mode is active, but route-incompatible shortcuts stay disabled.

Error flows:
- If the user cancels the side-menu warning, the route sheet stays open and the selected destination is not changed.
- If the user closes the sheet, all draft route state is discarded so reopening starts clean.
- If map clicks occur while the route sheet is closed, they must not create markers.
</user_flows>

<requirements>
**Functional:**
1. Add `RouteConstants.sheetHeight` in `lib/core/constants.dart` and set it to `320.0`.
2. Wire the existing Create Route FAB so it opens the route bottom sheet instead of remaining disabled.
3. When Create Route is activated, clear the selected-location marker, clear any selected tracks, and close any open popups or drawers before showing the sheet.
4. Render a bottom sheet that contains a header bar, a blank placeholder elevation graph, a route name text field, and Cancel/Save actions.
5. The header must show a distance/elevation group, a route editing group, and an actions group in that left-to-right order.
6. Use placeholder values for the header metrics: `12.3 km`, `315 m` ascent, and `234 m` descent.
7. The route editing group must include the text `Routing Mode:`, a Snap to Trail button, and a Straight Line button.
8. Snap to Trail is the default mode when the sheet opens.
9. Snap to Trail and Straight Line are mutually exclusive; selecting one deselects the other.
10. The selected mode must be visually obvious by switching to green.
11. Cancel closes the sheet.
12. Save closes the sheet and does not persist route data yet.
13. The route name field must accept text input without route-mode keyboard shortcuts firing while the field has focus.
14. While route drafting is active, the user can click the map to place temporary green markers using `Icons.adjust`, and those taps must not trigger the existing selected-location, peak-info, or track-selection tap behavior.
15. The route sheet must fit the current desktop shell layout without clipping the header, graph placeholder, or actions.
16. The route sheet must participate in the existing dismiss-surface priority so Escape closes the sheet before lower-priority surfaces.
17. Store route draft state in the map provider with an explicit draft model containing the draft route name, the current routing mode, and an ordered list of temporary marker locations.
18. Route marker placement must append to the ordered draft marker list in tap order while drafting is active.
19. Cancel, Save, dismiss, and re-entry must clear the entire draft model so reopening starts with the default mode and no draft markers.
20. Render draft markers on the map as a separate temporary marker layer using `Icons.adjust`.

**Error Handling:**
21. Side-menu navigation while route drafting is active must show the existing danger confirmation dialog with the warning text from the current draft requirement.
22. Confirming the warning closes the sheet and then navigates to the selected destination.
23. Cancelling the warning keeps the route sheet and draft state intact.
24. Allowed keyboard shortcuts must continue to work when the map has focus: zoom keys, navigation keys, tracks, and basemaps.
25. All other map shortcuts must be ignored while route drafting is active.

**Edge Cases:**
26. Reopening Create Route after closing the sheet must start from a clean draft, with the default mode selected and no stale markers.
27. The route sheet must not appear twice if Create Route is tapped repeatedly while already open.
28. Map clicks outside the active route mode must not change route state.
29. If the app is resized or rebuilt while drafting, the sheet state must remain consistent.
30. If the route mode is open and the user opens a permitted drawer through the remaining View affordances or allowed shortcuts, the route state must not be lost unless the user explicitly closes it.

**Validation:**
31. Validate the state transitions for opening route mode, toggling the selected routing mode, adding markers, and closing the sheet.
32. Validate that route-name typing does not trigger map shortcuts while the field has focus.
33. Validate that the sheet uses the fixed height constant and the expected placeholder values.
34. Validate that the sheet and map shell preserve the current route of dismissal priority and keyboard behavior.
</requirements>

<boundaries>
Edge cases:
- Repeated Create Route taps: keep a single active sheet and a single active draft.
- Empty draft: the sheet may close with no markers placed.
- Rebuilds and orientation changes: preserve the active route draft until the user closes it.
- Touch and mouse input: map marker placement must work for both input styles on the current desktop shell.

Error scenarios:
- Side menu confirm cancelled: stay in route mode and do not navigate.
- Side menu confirm accepted: close route mode first, then navigate.
- Shortcut collision: route-incompatible shortcuts such as `g`, `i`, `c`, and `m` must do nothing while drafting.
- Drawer or popup conflict: opening route mode must dismiss existing transient UI before showing the sheet.

Limits:
- The feature is placeholder-only; there is no route persistence, export, or save backend yet.
- The elevation graph is a blank visual placeholder only and must not imply live charting.
- Route markers are temporary UI state only and are discarded when the sheet closes.
- The sheet height is fixed by `RouteConstants.sheetHeight` until a later product decision changes it.
</boundaries>

<implementation>
Modify or create the following files:
- `lib/core/constants.dart` add `RouteConstants.sheetHeight`.
- `lib/providers/map_provider.dart` add route draft state and actions needed to track route mode, route name, and temporary markers.
- `lib/widgets/map_action_rail.dart` enable Create Route and route it into the new sheet entry point.
- `lib/screens/map_screen.dart` open and dismiss the route sheet, gate keyboard shortcuts, route map taps, and clear conflicting transient surfaces.
- `lib/widgets/map_route_bottom_sheet.dart` create the route sheet UI and its stable keys.
- `lib/router.dart` and `lib/widgets/side_menu.dart` as needed to ensure route-drafting navigation is intercepted before `goBranch(...)` runs and the warning dialog is shown before leaving route mode.
- `test/widget/map_screen_route_entry_test.dart` add coverage for opening the sheet from the map shell.
- `test/widget/map_screen_route_sheet_test.dart` cover layout, selection, close behavior, and placeholder content.
- `test/widget/map_screen_keyboard_test.dart` extend shortcut coverage for route mode gating.
- `test/robot/map/map_route_journey_test.dart` cover the end-to-end route entry journey.

Use the existing map-provider pattern instead of adding ad hoc local state in the widget tree unless a local controller is strictly sufficient for the draft UI.
Prefer stable widget keys for the sheet root, mode buttons, route name field, graph placeholder, marker layer, cancel button, and save button.
Keep the implementation minimal and placeholder-focused; do not add persistence, networking, or saved route management.
</implementation>

<stages>
Phase 1: Add route draft state and the bottom sheet widget.
Verify that the sheet opens, renders the required fields, and closes cleanly.

Phase 2: Wire the map shell entry points and route cleanup behavior.
Verify that Create Route clears transient map surfaces, disables the right controls, and places markers when the map is clicked.

Phase 3: Add keyboard and side-menu integration.
Verify that the allowed shortcuts still work, disallowed shortcuts are ignored, and side-menu navigation follows the warning flow.

Phase 4: Add automated coverage.
Verify the widget tests and robot journey test cover the critical route flow, the close/cancel path, and the side-menu warning path.
</stages>

<validation>
Testing must follow a behavior-first, vertical-slice approach.

For route state logic:
1. Write tests for opening route mode before adding any visual assertions.
2. Add tests for exclusive mode toggling and draft reset behavior next.
3. Add tests for marker placement and close/discard behavior last.
4. Keep the route state deterministic by exposing explicit provider methods for mode changes and marker insertion.
5. Prefer fakes or provider overrides for map and drawer dependencies rather than mocking Flutter widgets.

For widget coverage:
6. Add widget tests that assert the bottom sheet root, header groups, placeholder elevation box, route name field, and Cancel/Save controls are present.
7. Add widget tests that confirm Snap to Trail is selected by default and only one mode is selected at a time.
8. Add widget tests that confirm the sheet closes on Cancel and on Save.
9. Add widget tests that confirm the Create Route FAB opens the sheet and repeated taps do not create duplicates.
10. Add widget tests that confirm the fixed height constant is respected.
11. Add widget tests that confirm route-incompatible shortcuts do nothing while drafting and that typing into the route name field does not trigger map shortcuts.
12. Add widget tests that confirm route-mode taps add markers without firing the existing selected-location or peak-info tap behavior.
13. Add widget tests that confirm the route sheet dismisses through the existing surface-dismiss behavior before lower-priority map surfaces.

For robot coverage:
14. Add a robot-driven journey for Create Route -> sheet opens -> mode toggle -> map click marker placement -> Cancel closes and resets.
15. Add a robot-driven journey for Create Route -> side menu tap -> warning appears -> Continue closes the sheet and navigates.
16. Use stable selectors for all robot assertions, including the sheet root, mode buttons, route name field, cancel/save buttons, marker layer, and side-menu confirm button.

Baseline automated coverage outcomes:
- Logic/business rules: route mode state, marker state, and cleanup rules are covered.
- UI behavior: the sheet layout, selected mode styling, and close actions are covered.
- Critical journeys: opening route mode, placing a marker, and confirming side-menu navigation are covered.

Do not consider the work done unless the tests verify the placeholder flow on the current desktop-sized layout.
</validation>

<done_when>
The feature is complete when the Map screen can open a single placeholder route bottom sheet, show the specified header and placeholder graph, accept route name input, place temporary green markers on map clicks, respect the allowed shortcut set, warn before sidebar navigation, and close cleanly without persisting data.
</done_when>
