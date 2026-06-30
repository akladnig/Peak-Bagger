<goal>
Add a shared, keyboard-accessible search experience to the AppBar so macOS desktop map users can find peaks, tracks/routes, and maps from one entry point.
This matters because the current search lives in the map chrome as a peak-only panel; the new flow should feel like a first-class shell action for desktop users.
</goal>

<background>
The app is a Flutter shell with a shared AppBar in `./lib/router.dart` and map-specific chrome in `./lib/screens/map_screen.dart`.
The current peak-only search panel already exists in `./lib/screens/map_screen_panels.dart` and uses shared map state from `./lib/providers/map_provider.dart`.
Existing search result row styling lives in `./lib/widgets/peak_search_results_list.dart`, and selected button styling comes from `./lib/theme.dart`.
Shared popup sizing and shell tokens live in `./lib/core/constants.dart`, and popup composition should use `./lib/core/widgets/popup_shell.dart`.
Region and map metadata are resolved from `./assets/region_manifest.json` and `./lib/services/region_manifest_catalog.dart`; use the manifest's `name` field directly for user-facing region labels, and regenerate the catalog so that field is available through the generated API rather than hand-editing generated output.
The implementation should reuse the current transient-UI cleanup behavior so search closes when the shell navigates or another overlay takes priority.

Files to examine:
`./lib/router.dart`
`./lib/screens/map_screen.dart`
`./lib/screens/map_screen_panels.dart`
`./lib/providers/map_provider.dart`
`./lib/widgets/peak_search_results_list.dart`
`./lib/theme.dart`
`./lib/core/constants.dart`
`./lib/core/widgets/popup_shell.dart`
`./lib/services/gpx_storage_destination_resolver.dart`
`./lib/services/gpx_importer.dart`
`./lib/services/region_manifest_catalog.dart`
`./assets/region_manifest.json`
</background>

<discovery>
Examine how the existing peak search panel is wired so the new AppBar popup can reuse the same cleanup, focus, and selection patterns.
Confirm the track and route sources already present in the app, and derive each result's anchor from the first available runtime geometry point so region and map labels can be resolved from point-based runtime helpers.
Confirm the current map/region resolution helpers so result summaries can show map name and region consistently.
</discovery>

<user_flows>
Primary flow:
1. User clicks the AppBar search control or presses `Cmd+F` on macOS.
2. A popup opens, the search field receives focus, and the current search state starts from defaults.
3. User types a query, optionally narrows the entity type, optionally applies a region filter, and optionally changes sort order.
4. Matching results render in a scrollable list under the controls.
5. User selects a result, the popup closes, the map moves to the result anchor, and a marker is dropped at that location.

Alternative flows:
- User opens search and changes only entity buttons, filter, or sort: the result list updates immediately without closing the popup.
- User opens search via `Cmd+F` with the map shell active: the same popup opens and focus lands in the search field.
- User chooses a disabled Natural or Roads button: nothing changes and the button stays inert.

Error flows:
- Query matches nothing: show an empty-state message in the results area, not a dialog or snackbar.
- Metadata is incomplete: show `—` for missing optional fields such as height, map name, or region.
- A record cannot produce a stable anchor point: exclude it from the popup rather than failing selection.
- The user navigates away or another transient overlay opens: close the search popup and clear its temporary state.
</user_flows>

<requirements>
Functional:
1. Restructure the shared AppBar into a left title block, a centered search control, and a right actions block, and show `Icons.search`, the label `Search`, and the macOS command symbol with `F` in the centered control.
2. Style the search control border with `outlineVariant` and use `SelectedButtonThemeData` for the popup's entity, filter, and sort buttons.
3. Open the popup from the AppBar control and from `Cmd+F` on macOS, then focus the search text field immediately.
4. Render the popup with a search field at the top left, a thin divider, a row of mutually exclusive entity buttons, a vertical divider before Filter and Sort, and a `Results` header above the list.
5. Keep the search field and controls visible while only the results list scrolls.
6. Support All, Peaks, Tracks/Routes, Natural, Roads, and Maps entity buttons, with All selected by default and Natural/Roads disabled placeholders for now.
7. Filter Tracks/Routes by `GpxTrack` and `Route` only, and derive each result's anchor from the first available runtime geometry point on that track or route so region and map labels can be resolved from point-based runtime helpers.
8. Show result summaries with the type icon on the left and the correct detail set per type: Peaks use name, height, map name if available, and region name; Tracks use track name plus distance/elevation metrics formatted by the existing track/route formatting helpers, map name if available, and region name resolved from the first-point anchor; Routes use route name plus distance/elevation metrics formatted by the existing track/route formatting helpers, map name if available, and region name resolved from the first-point anchor; Maps use map name and region name.
9. Selecting a map result must use a map-specific atomic helper that updates `selectedMap`, `selectedLocation`, and `selectedMapFocusSerial` together. Selecting a track or route must use the existing type-specific selection/focus path for that entity type and may also set `selectedLocation` to the derived anchor so the marker remains visible. Selecting a peak must follow the existing peak selection path. All result selections must move the map, close the popup, and clear the temporary search state.
10. Add a region filter menu sourced from `./assets/region_manifest.json` with a `None` option, single-select behavior, and labels taken directly from each manifest entry's `name` field.
11. Add a sort menu with name ascending as the default and name descending as the alternate option.
12. Keep the popup usable within the macOS desktop window using the shared popup shell and a scrollable body; compact/mobile layouts are out of scope.

Error Handling:
13. Treat search input as trimmed and case-insensitive.
14. When the query is empty, keep the results area empty rather than pretending there are matches.
15. When the query is non-empty and nothing matches, show a clear empty state such as `No results found`.
16. If a result's optional metadata is missing, render a safe fallback instead of crashing or hiding the row.

Edge Cases:
17. Closing the popup must restore the map shell to a clean transient state so keyboard shortcuts continue to work.
18. Opening the popup should dismiss any competing map overlays that would otherwise obscure it.
19. The result list should cap itself to a reasonable popup-sized page so large data sets remain responsive; use a total cap of 20 results after filtering.
20. Search buttons for disabled categories must remain visible so the future expansion point is obvious, but they must not alter filtering state until enabled.

Validation:
21. Implement the search logic in a testable service or controller with deterministic dependencies, not in widget-only code.
22. Use vertical-slice TDD for the logic layer: one failing behavior at a time, then the minimum code to pass, then refactor.
23. Keep widgets deterministic by injecting fakes for ObjectBox-backed repositories and region metadata, not real storage.
24. Cover the search service with unit tests for empty query, query matching, type filtering, first-point anchor resolution from runtime geometry, region filtering, sorting, and type-specific selection projection.
25. Cover the popup UI with widget tests for open/close, focus handoff, entity selection, filter/sort menus, disabled placeholders, empty state, and result rendering.
26. Cover the critical user journey with robot-driven tests for opening from the AppBar, opening with `Cmd+F`, searching a peak, and selecting a non-peak result.
27. Use stable, app-owned `Key` selectors for the AppBar control, popup root, search field, entity buttons, filter button, sort button, and result rows.
</requirements>

<boundaries>
Edge cases:
- Empty query: do not auto-expand into a full database browse view.
- Missing map name, region, or height: show a fallback value instead of failing the row layout.
- Missing anchor point: omit the record from results.

Error scenarios:
- Search or result projection failure: degrade to an empty state and keep the popup usable.
- Navigation away from the map shell: close the popup and clear temporary search state.
- Conflicting transient UI: search loses priority to the higher-priority overlay and can be reopened cleanly.

Limits:
- Result count: 20 total after search, filter, and sort.
- Shortcut scope: macOS `Cmd+F` only.
- Disabled categories: Natural and Roads remain inert until their data sources exist.
</boundaries>

<implementation>
Create or modify the AppBar entry point in `./lib/router.dart` and the map-shell integration in `./lib/screens/map_screen.dart`.
Add a generic search controller/service in `./lib/providers/map_provider.dart` or a dedicated adjacent provider file if that keeps the state cleaner, but do not keep a second peak-only search path alive in parallel.
Add a reusable popup widget and result-row widget under `./lib/widgets/` so the AppBar and map shell share the same UI surface.
Build the popup with `./lib/core/widgets/popup_shell.dart` and take popup radius, padding, and close icon sizing from `PopupUIConstants` in `./lib/core/constants.dart`.
Reuse `SelectedButtonThemeData` from `./lib/theme.dart` and the existing result-row style conventions rather than inventing a new visual system.
Avoid direct ObjectBox access from widgets; all data access should go through a testable search layer.
Avoid duplicating the current peak search panel logic; it should either become the shared popup or delegate to it.
Do not edit `./lib/generated/region_manifest_catalog.g.dart` by hand; update the source manifest/catalog inputs and regenerate the file.

Output paths:
`./lib/router.dart`
`./lib/screens/map_screen.dart`
`./lib/providers/map_provider.dart` or `./lib/providers/map_search_provider.dart`
`./lib/services/map_search_service.dart`
`./lib/widgets/map_search_popup.dart`
`./lib/widgets/map_search_results_list.dart`
`./test/widget/map_screen_appbar_search_test.dart`
`./test/widget/map_screen_keyboard_test.dart`
`./test/robot/map/appbar_search_robot.dart`
`./test/robot/map/appbar_search_journey_test.dart`
</implementation>

<validation>
Start with a unit-test slice for the search service: empty query, peak match, track match, route match, map match, region filter, name sort, and selection anchor behavior.
Then add widget-test slices for the popup shell: button layout, focus behavior, disabled categories, empty state, and control interactions.
Finally add robot-driven journeys for the critical flows: AppBar open, `Cmd+F` open, peak selection, and non-peak selection.

Use deterministic seams for repositories and region metadata so tests can run without real ObjectBox storage or network access.
Require baseline automated coverage across logic, widget behavior, and critical journeys before the feature is considered done.
Report any residual risk explicitly if a source cannot yet produce a stable anchor or summary field.
Keep the coverage and implementation assumptions macOS desktop only; do not add mobile or compact-layout branches to satisfy this spec.
</validation>

<stages>
Phase 1: Build the search domain and service layer, then verify it with unit tests for query, filter, sort, and selection projection.
Phase 2: Build the popup UI and AppBar trigger, then verify open/close, focus, button states, and empty-state behavior with widget tests.
Phase 3: Wire result selection into map movement and marker placement, then verify the end-to-end user journey with robot tests.
Phase 4: Clean up the old peak-only search entry points so there is one shared search surface and no duplicate behavior paths.
</stages>

<done_when>
The AppBar exposes a working search control and `Cmd+F` opens the same popup on macOS.
The popup supports mixed search results, entity filtering, region filtering, and name sorting.
Selecting a result moves the map, drops a marker, and closes the popup.
Natural and Roads are visible but disabled.
Automated tests cover the logic layer, the popup widget behavior, and the critical journey paths.
</done_when>
