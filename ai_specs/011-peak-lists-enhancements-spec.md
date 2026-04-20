<goal>
Enhance Peak Lists so users can review all available lists, inspect the selected list in a split details view, delete a list safely, and import imperfect CSV files without manual cleanup.
This matters because peak-bagging workflows depend on a reliable list-management screen and resilient imports from real-world source data.
</goal>

<background>
Flutter app using Riverpod, ObjectBox, `csv`, `path`, `mgrs_dart`, `latlong2`, and the existing import/logging patterns.
The current `PeakListsScreen` already exists, along with the import dialog and list/import repositories.

Follow the current app conventions in:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./lib/services/peak_list_import_service.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peak_mgrs_converter.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/services/gpx_importer.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/peaks/peak_lists_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens Peak Lists and sees a split summary/details screen.
2. The summary table shows all peak lists; the first list is selected by default when one exists.
3. User clicks a row and the details pane updates to that list.
4. User resizes the top-level split on wide screens with the vertical divider.
5. User imports a CSV through the existing import action.
6. Import fills missing coordinate data, defaults missing height to 0, and reports warnings when needed.

Alternative flows:
- Returning user: existing lists load and remain selectable without re-importing.
- Empty library: show an empty state until a list is imported.
- Narrow screen: stack the summary and details panes vertically and hide or disable the divider.
- Delete flow: user confirms deletion of the selected list and the screen selects the next available list or returns to empty state.

Error flows:
- Delete cancel: close the confirmation dialog and leave data unchanged.
- Import row invalid: skip only that row and continue the import.
- Log write failure: keep the imported data and surface the warning in memory.
</user_flows>

<requirements>
**Functional:**
1. `./lib/screens/peak_lists_screen.dart` must show a peak-list summary table on the left and list details on the right when the layout is wide enough.
2. The summary table must use exactly these data columns: `List`, `Total Peaks`, `Climbed`, `Percentage`, `Unclimbed`, plus an actions column.
3.
   - a peak is climbed if any PeaksBagged row exists with PeakId == Peak.osmId
   - Ascent Date shows the most recent Date for that peak
   - summary Climbed counts unique climbed peaks in the list
   - Unclimbed = Total Peaks - Climbed
   - Percentage = Climbed / Total Peaks
   - mini-map ticked marker uses the same climbed predicate
4. The `Total Peaks` column must show the count for that summary row's `PeakList` payload, not the currently selected row unless they are the same row.
5. The actions column must contain a delete icon for each list row
6. The top-level layout must start at 40% summary width and 60% details width, with a draggable vertical divider on wide layouts.
7. The top-level divider must constrain both panes so neither can shrink below a usable minimum width; the spec may treat `280px` as the default minimum pane width unless an existing shared split-view pattern already defines a stronger app-wide minimum.
8. Treat `>= 900px` total content width as the default wide-layout breakpoint unless the current screen already uses a stronger existing breakpoint for comparable split views.
9. On narrow layouts, stack the summary and details panes vertically and disable drag-only resizing.
10. peak lists are to be sorted by Percentage from largest to smallest. Allow list sorting by all columns except the actions column. Use a clickable up/down arrow to the right of the column to sort.
11. The selected row must drive the details pane, and the title at the top of the details pane must be the selected list name.
12. Under the title, show a summary sentence for the selected list using only metrics already available in this phase. Use an exact shape such as `<list name> contains <total peaks> peaks. Climbed 0 of <total peaks> (0%).` and do not reference a most-recent climb or date in this phase.
13. The details area must show a split view with the peak table on the left and a mini map on the right.
14. The details peak table must use these columns: `Peak Name`, `Elevation`, `Ascent Date`.
15. The details peak table must start at 30% of the available details width.
16. On narrow layouts, the inner details split must stack vertically with the peak table above the mini map instead of forcing a cramped horizontal split.
17. The mini map must use the same icon strategy as the main map: unclimbed peaks use `peak_marker.svg`, climbed peaks use `peak_marker_ticked.svg`.
18. The mini map must include all peaks in the selected list, fit bounds to those peaks when at least one valid coordinate is available, and render an empty-state placeholder when no plottable coordinates exist.
19. A row delete action deletes the row it was invoked from, even if that row is not currently selected. If that row is selected, the screen must update selection after deletion according to the edge-case rules below.
20. The import flow must accept a row when either complete coordinate system is present: either both `Latitude` and `Longitude`, or all of `Zone`, `Easting`, and `Northing`.
21. When only one complete coordinate system is present, derive the missing coordinate system from the provided one before matching and persistence.
22. Treat latitude/longitude values as WGS84 decimal degrees, matching the app's existing `LatLng` and `PeakMgrsConverter.fromLatLng()` usage.
23. Treat Zone/Easting/Northing as a CSV UTM reference using the existing `PeakMgrsConverter.fromCsvUtm()` assumptions: `Zone` must match `^\d{1,2}[A-Z]$`, and `Easting`/`Northing` may contain spaces but must reduce to numeric digits.
24. If both coordinate systems are present, parse both and preserve the provided values for this phase; do not attempt heuristic reconciliation between disagreeing coordinate systems beyond normal parsing/conversion checks.
25. If one coordinate system is present but cannot be parsed or converted under those rules, skip the row and log a warning rather than falling back to guesswork.
26. If a height datum is missing, the import must set it to `0` and log a warning containing the peak name in `import.log`.
27. The delete confirmation must use `showDangerConfirmDialog` with title `Delete Peak List?` and message `This will permanently delete the <list name>. Do you want to proceed`.
28. Confirmed delete must remove only the `PeakList` record; underlying `Peak` rows must remain untouched, even if that leaves peaks no longer referenced by any list.
29. Preserve the existing import entry point and its persistence flow; this change only expands the screen and strengthens import handling.

**Error Handling:**
30. If neither coordinate pair is complete, skip the row and log a warning instead of guessing.
31. If the user cancels delete confirmation, make no persistence changes.
32. If logging to `import.log` fails, keep the import result and expose the warning in memory.
33. Import parsing failures must fail the affected row or import before persistence, not partially commit corrupted data.

**Edge Cases:**
34. If no list is selected and lists exist, default to the first available list; if no lists exist, show an empty state.
35. If the selected list is deleted, move selection to the next visible list row; if the deleted row was last, move selection to the previous row; if no lists remain, clear selection.
36. Deleting a non-selected row must preserve the current selection unless the repository reorder semantics make that impossible.
37. A list with zero peaks must still render cleanly in both panes.
38. Narrow layouts must remain usable without requiring drag gestures.
39. Do not add `Most Recent Peak` or `Date` columns to the summary table in this phase.
40. Do not add list editing, reordering, or multi-file import in this phase.

**Validation:**
41. Expose deterministic seams for file picker, CSV source, peak repository, peak-list repository, clock, log writer, and layout/sizing behavior needed for the split view.
42. Use behavior-first TDD slices: summary render, row selection, delete confirmation, partial-coordinate import, missing-height defaulting, then invalid-data and logging-failure paths.
43. Use robot-driven coverage for the critical user journeys: open Peak Lists, select a list, delete it through confirmation, and import a CSV row that exercises the partial-coordinate repair path.
44. Use widget tests for screen layout, divider behavior, empty state, selection changes, confirmation dialogs, and the inner details-pane responsive fallback.
45. Use unit tests for CSV transformation, coordinate repair, height defaulting, warning generation, and repository persistence behavior.
46. Tests must use stable app-owned `Key` selectors for rows, panes, divider, delete action, import controls, and dialog actions.
</requirements>

<boundaries>
UI boundaries:
- Keep Peak Lists focused on browsing, inspecting, deleting, and importing lists.
- Do not add bagging progress, tick state editing, or full-screen map navigation yet.
- Do not add summary-table columns beyond the exact 5 requested data columns plus actions.
- On narrow layouts, allow both the outer and inner split views to stack vertically instead of forcing drag-only interaction.
- Keep the details summary text limited to currently available placeholder metrics; do not imply climb-history data that the app does not yet compute.

Data boundaries:
- Treat a coordinate pair as complete only when both values in the pair are present.
- Only derive missing coordinate fields; do not invent data when both coordinate systems are incomplete.
- If both coordinate systems are present, validate/parsing-check both but do not add a separate discrepancy-resolution feature in this phase.
- If the provided source coordinate set fails parsing or conversion, skip the row and log the reason; do not silently keep partially repaired data.
- Keep the delete action scoped to `PeakList` records only.
- Keep `peakList` as the persisted ordered payload already used by the app.
</boundaries>

<discovery>
Before implementing, verify the current screen, repository, and import flow behavior in:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./lib/services/peak_list_import_service.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peak_mgrs_converter.dart`
- `./lib/screens/settings_screen.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/peaks/peak_lists_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`
</discovery>

<implementation>
Modify or create these files:
- `./lib/screens/peak_lists_screen.dart` - split summary/details layout, row selection, divider handling, delete entry point, import entry point retention
- `./lib/widgets/peak_list_import_dialog.dart` - keep the import dialog wiring and surface the updated import result states
- `./lib/services/peak_list_import_service.dart` - partial-coordinate repair, missing-height defaulting, warning/log emission, persistence
- `./lib/services/peak_list_repository.dart` - list lookup and delete support needed by the screen
- `./lib/services/peak_mgrs_converter.dart` - add or reuse helpers for deriving the missing coordinate system
- `./test/widget/peak_lists_screen_test.dart` - widget coverage for layout, selection, delete dialog, and empty state
- `./test/services/peak_list_import_service_test.dart` - unit coverage for CSV repair and warnings
- `./test/services/peak_list_repository_test.dart` - repository delete and selection-safe behavior
- `./test/robot/peaks/peak_lists_robot.dart` - stable key-first robot harness
- `./test/robot/peaks/peak_lists_journey_test.dart` - end-to-end critical journey coverage

Patterns to follow:
- Keep transient layout state local to the screen/widgets.
- Use Riverpod only for injected services and repositories.
- Reuse `showDangerConfirmDialog` for delete confirmation.
- Prefer deterministic fakes over live file pickers or filesystem calls in tests.
</implementation>

<stages>
Phase 1: summary/details shell
- Build the split layout, default selection, empty state, and responsive behavior.
- Verify with widget tests for row selection and divider state.

Phase 2: delete flow
- Wire delete actions, confirmation dialog, and post-delete selection changes.
- Verify with widget and robot tests for confirm/cancel behavior.

Phase 3: import repair rules
- Implement partial-coordinate repair, missing-height defaulting, and warning/log behavior.
- Verify with unit tests first, then widget coverage for the import result path.

Phase 4: end-to-end regression
- Run the robot journey tests and the full test suite.
- Verify that the screen still behaves correctly after list mutation and import warnings.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for coordinate repair, missing-height defaulting, warning generation, delete-only-list behavior, and log-write failure handling.
- UI behavior: widget tests for split layout, divider min-width constraints, responsive fallback for both outer and inner splits, empty state, selection changes, delete confirmation, and row removal after delete.
- Critical journeys: robot-driven tests for open/select/delete and open/import/repair flows.

TDD expectations:
- Write one failing test slice at a time and implement the smallest change needed to make it green.
- Start with the summary screen render and default selection.
- Then add the delete confirmation path.
- Then add the partial-coordinate and missing-height import rules.
- Finish with row-level error handling and logging-failure coverage.

Robot-test expectations:
- Use stable keys for the summary table, selected details pane, divider handle, row delete action, import dialog controls, confirm button, and cancel button.
- Keep robot tests focused on behavior, not pixel measurements.
- Use fakes for file selection and import data so the journey stays deterministic.

Verification:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- Peak Lists renders a responsive summary/details screen with the requested columns and selection behavior.
- The delete action removes only the selected `PeakList` after confirmation.
- CSV import backfills missing coordinate fields, defaults missing height to 0, and logs the warning with the peak name.
- Invalid or incomplete rows are skipped without corrupting already imported data.
- Widget, unit, and robot coverage pass for the updated behavior.
</done_when>
