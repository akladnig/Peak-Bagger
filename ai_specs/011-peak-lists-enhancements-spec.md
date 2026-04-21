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
   - Ascent Date shows the most recent Date for that peak in "d MMM yyyy" format (e.g. "12 Jan 2024")
   - if no ascent date exists for a climbed peak, render a blank Ascent Date cell
   - unclimbed peaks also render a blank Ascent Date cell
   - summary Climbed counts unique climbed peaks in the list
   - Unclimbed = Total Peaks - Climbed
   - Percentage = Climbed / Total Peaks
   - mini-map ticked marker uses the same climbed predicate
4. The `Total Peaks` column must show the count for that summary row's `PeakList` payload, not the currently selected row unless they are the same row. If a legacy unsupported peak list row cannot decode its payload, the summary table must keep the row visible by name, show `-` for derived metric columns (`Total Peaks`, `Climbed`, `Percentage`, `Unclimbed`), and keep the delete action available.
5. The actions column must contain a delete icon (`Icons.delete_forever` from Flutter material) for each list row
6. The top-level layout must start at 40% summary width and 60% details width, with a draggable vertical divider on wide layouts.
7. The top-level divider must constrain both panes so neither can shrink below a usable minimum width; the spec may treat `280px` as the default minimum pane width on wide layouts, and `160px` on narrow layouts where stacking applies.
8. Treat `>= 900px` total content width as the default wide-layout breakpoint unless the current screen already uses a stronger existing breakpoint for comparable split views.
9. On narrow layouts, stack the summary and details panes vertically and disable drag-only resizing.
10. peak lists are to be sorted by Percentage from largest to smallest, with PeakList Name alphabetical ascending as the secondary sort for all ties. Legacy unsupported rows with `-` metric values sort after supported rows when sorting by derived metric columns. Allow list sorting by all columns except the actions column. Use a clickable up/down arrow to the right of the column to sort. The initial user-triggered sort direction for any sortable column is ascending. Only the active column shows the direction arrow state; inactive columns show a neutral affordance.
11. The selected row must drive the details pane, and the title at the top of the details pane must be the selected list name.
12. Under the title, show a summary sentence for the selected list. If the list has at least one climbed peak with an ascent date, name all peaks in the list whose most recent ascent falls on that latest date, ordered by peak ID ascending, e.g. `<PeakName1>, <PeakName2> and <PeakName3> are your most recent, climbed on <Date>. <list name> contains <total peaks> peaks. Climbed <climbed> of <total peaks> (<percentage>%).` This summary text must wrap onto multiple lines when needed. If the list has climbed peaks but none of them have an ascent date, use `<list name> contains <total peaks> peaks. Climbed <climbed> of <total peaks> (<percentage>%).` If the list has no climbed peaks, use `<list name> contains <total peaks> peaks. Climbed 0 of <total peaks> (0%).`
13. The details area must show a split view with the peak table on the left and a mini map on the right.
14. The details peak table must use these columns: `Peak Name`, `Elevation`, `Ascent Date`.
15. The details peak table must start at 30% of the available details width.
16. On narrow layouts, the inner details split must stack vertically with the peak table above the mini map instead of forcing a cramped horizontal split.
17. The mini map must use the same icon strategy as the main map: unclimbed peaks use `peak_marker.svg`, climbed peaks use `peak_marker_ticked.svg`. Use `flutter_map` with OpenStreetMap tile provider, following the existing marker sizing and SVG reuse conventions in `./lib/screens/map_screen_layers.dart`. Do not inherit the main map's `zoom < 9` marker suppression; list peaks must remain visible at the fitted mini-map zoom.
18. The mini map must include all peaks in the selected list, fit bounds to those peaks when at least one valid coordinate is available, and render the full Tasmania region when no plottable coordinates exist. Use the existing Tasmania bounds from `./lib/services/overpass_service.dart`: longitude `143.833` to `148.482`, latitude `-43.643` to `-39.579`.
19. A row delete action deletes the row it was invoked from, even if that row is not currently selected. If that row is selected, the screen must update selection after deletion according to the edge-case rules below.
20. The import flow must require these headers in the CSV: `Name`, `Points`, `Height`, `Latitude`, `Longitude`, `Zone`, `Easting`, and `Northing`. `Ht` remains an accepted alias for `Height`. Row values for one coordinate system may be blank.
21. The import flow must accept a row when either complete coordinate system is present: either both `Latitude` and `Longitude`, or all of `Zone`, `Easting`, and `Northing`.
22. When only one complete coordinate system is present, derive the missing coordinate system from the provided one before matching and persistence. For deriving lat/long from Zone/Easting/Northing, add a new helper method that converts the raw CSV UTM inputs directly to `LatLng` using the mgrs_dart library's UTM-to-lat/long capability; do not route this through `PeakMgrsComponents`.
23. Treat latitude/longitude values as WGS84 decimal degrees, matching the app's existing `LatLng` and `PeakMgrsConverter.fromLatLng()` usage.
24. Treat Zone/Easting/Northing as a CSV UTM reference using the existing `PeakMgrsConverter.fromCsvUtm()` assumptions: `Zone` must match `^\d{1,2}[A-Z]$`, and `Easting`/`Northing` may contain spaces but must reduce to numeric digits.
25. If both coordinate systems are present, parse both and preserve the provided values for this phase; do not attempt heuristic reconciliation between disagreeing coordinate systems beyond normal parsing/conversion checks.
26. If one coordinate system is present but cannot be parsed or converted under those rules, skip the row and log a warning rather than falling back to guesswork.
27. The `Name`, `Points`, and `Height` headers remain required. If a row's `Name` is blank, set it to `Unknown`. If a row's `Points` is blank, normalize it to the integer value `0`. If a row's `Points` value is non-blank but invalid, issue a warning, log it, and normalize it to `0`. If a row's height datum is blank, set it to `0` and log a warning containing the peak name in `import.log`.
28. The delete confirmation must use `showDangerConfirmDialog` with title `Delete Peak List?`, message `This will permanently delete the <list name>. Do you want to proceed`, cancelKey: `'cancel-delete'`, cancelLabel: `'Cancel'`, confirmKey: `'confirm-delete'`, confirmLabel: `'Delete'`.
29. Confirmed delete must remove only the `PeakList` record; underlying `Peak` rows must remain untouched, even if that leaves peaks no longer referenced by any list.
30. Preserve the existing import entry point and its persistence flow; this change only expands the screen and strengthens import handling. Deduplicate peaks on import by resolved `peakOsmId`, keeping the first occurrence in list order when duplicates resolve to the same peak. Update `PeakListItem.points` from `String` to `int` and adjust serialization accordingly. No backward-compatible decode is required for older stored peak lists with string `points` values; those lists are unsupported in this phase and are expected to be deleted and re-imported manually. If such a legacy peak list is encountered, keep the list row visible by name, make the delete action available, and surface a clear error instructing the user to delete and re-import it; metrics and details for that row may fall back to an unsupported-state message instead of decoded values. After a successful import or update, refresh the Peak Lists screen and, once the result dialog closes, select the imported or updated list. The import completion flow must return the imported or updated list identity back to `PeakListsScreen`, for example by carrying the list id or name in the presentation result and completing `PeakListImportDialog` with that result after the result dialog closes.

**Error Handling:**
31. If neither coordinate pair is complete, skip the row and log a warning instead of guessing.
32. If the user cancels delete confirmation, make no persistence changes.
33. If logging to `import.log` fails, keep the import result and expose the warning in memory.
34. Import parsing failures must fail the affected row or import before persistence, not partially commit corrupted data. Missing or invalid headers, empty CSVs, and similar file-level contract failures must fail the whole import by throwing and use the existing `Peak List Import Failed` dialog path rather than the successful-import result dialog.

**Edge Cases:**
35. If no list is selected and lists exist, default to the first available list; if no lists exist, show an empty state.
36. If the selected list is deleted, move selection to the next visible list row; if the deleted row was last, move selection to the previous row; if no lists remain, clear selection.
37. Deleting a non-selected row must preserve the current selection.
38. A list with zero peaks must still render cleanly in both panes.
39. Narrow layouts must remain usable without requiring drag gestures.
40. The empty state must display: a summary table with header row only, a details pane showing a peak table with header row only and a mini map showing the full Tasmania region using the existing Tasmania bounds from `./lib/services/overpass_service.dart`: longitude `143.833` to `148.482`, latitude `-43.643` to `-39.579`. It must also include this exact instructional copy: `No peak lists exist. Import a CSV to get started.`
41. Do not add list editing, reordering, or multi-file import in this phase.

**Validation:**
42. Expose deterministic seams for file picker, CSV source, peak repository, peak-list repository, clock, log writer, and layout/sizing behavior needed for the split view.
43. Use behavior-first TDD slices: summary render, row selection, delete confirmation, partial-coordinate import, missing-height defaulting, then invalid-data and logging-failure paths.
44. Use robot-driven coverage for the critical user journeys: open Peak Lists, select a list, delete it through confirmation, and import a CSV row that exercises the partial-coordinate repair path.
45. Use widget tests for screen layout, divider behavior, empty state, selection changes, confirmation dialogs, the inner details-pane responsive fallback, and unsupported legacy peak-list rows that remain visible by name, show `-` metrics, stay deletable, and surface the delete-and-reimport message.
46. Use unit tests for CSV transformation, coordinate repair, height defaulting, warning generation, and repository persistence behavior.
47. Tests must use stable app-owned `Key` selectors for rows, panes, divider, delete action, import controls, and dialog actions.
</requirements>

<boundaries>
UI boundaries:
- Keep Peak Lists focused on browsing, inspecting, deleting, and importing lists.
- Do not add bagging progress, tick state editing, or full-screen map navigation yet.
- Do not add summary-table columns beyond the exact 5 requested data columns plus actions.
- On narrow layouts, allow both the outer and inner split views to stack vertically instead of forcing drag-only interaction.

Data boundaries:
- Require these headers in the CSV: `Name`, `Points`, `Height`, `Latitude`, `Longitude`, `Zone`, `Easting`, and `Northing`, with `Ht` accepted as an alias for `Height`.
- Treat a coordinate pair as complete only when both values in the pair are present.
- Only derive missing coordinate fields; do not invent data when both coordinate systems are incomplete.
- If both coordinate systems are present, validate/parsing-check both but do not add a separate discrepancy-resolution feature in this phase.
- If the provided source coordinate set fails parsing or conversion, skip the row and log the reason; do not silently keep partially repaired data.
- Deduplicate imported peaks by resolved `peakOsmId`, keeping the first occurrence in list order.
- Normalize `Points` to an integer value and persist it as an integer on `PeakListItem`.
- Older stored peak lists with string `points` values are out of scope and are expected to be deleted and re-imported manually.
- Keep the delete action scoped to `PeakList` records only.
- Keep `peakList` as the persisted ordered payload already used by the app.
</boundaries>

<discovery>
Before implementing, verify the current screen, repository, and import flow behavior in:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./lib/services/peak_list_import_service.dart`
- `./lib/models/peak_list.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peaks_bagged_repository.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peak_mgrs_converter.dart`
- `./lib/services/overpass_service.dart`
- `./lib/screens/settings_screen.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/peaks/peak_lists_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`

Also verify that `PeaksBaggedRepository` provider wiring for climbed-state data must be introduced in `PeakListsScreen`, because no existing provider for it is assumed in this spec.
</discovery>

<implementation>
Modify or create these files:
- `./lib/screens/peak_lists_screen.dart` - split summary/details layout, row selection, divider handling, delete entry point, import entry point retention, and a Riverpod provider for `PeaksBaggedRepository` used by the screen
- `./lib/widgets/peak_list_import_dialog.dart` - keep the import dialog wiring, surface the updated import result states, and complete with the imported or updated list identity after the result dialog closes
- `./lib/services/peak_list_import_service.dart` - partial-coordinate repair, missing-height defaulting, warning/log emission, persistence
- `./lib/models/peak_list.dart` - update `PeakListItem.points` from `String` to `int` and adjust serialization
- `./lib/services/peak_list_repository.dart` - list lookup, getById, and delete support needed by the screen
- `./lib/services/peaks_bagged_repository.dart` - for checking if a peak has been climbed
- `./lib/services/peak_mgrs_converter.dart` - add or reuse helpers for deriving the missing coordinate system
- `./test/widget/peak_lists_screen_test.dart` - widget coverage for layout, selection, delete dialog, and empty state
- `./test/services/peak_list_import_service_test.dart` - unit coverage for CSV repair and warnings
- `./test/services/peak_list_repository_test.dart` - repository delete and getById behavior
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
- UI behavior: widget tests for split layout, divider min-width constraints, responsive fallback for both outer and inner splits, empty state, selection changes, delete confirmation, row removal after delete, and unsupported legacy peak-list rows that remain visible by name, show `-` metrics, stay deletable, and sort after supported rows for derived metric sorts.
- Critical journeys: robot-driven tests for open/select/delete and open/import/repair flows.

TDD expectations:
- Write one failing test slice at a time and implement the smallest change needed to make it green.
- Start with the summary screen render and default selection.
- Then add the delete confirmation path.
- Then add the partial-coordinate and missing-height import rules.
- Finish with row-level error handling, logging-failure coverage, and unsupported legacy peak-list row coverage.

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
- The delete action removes only the targeted `PeakList` row after confirmation, whether selected or not.
- CSV import backfills missing coordinate fields, normalizes `Points` to integers, defaults missing height to `0`, and logs the relevant warnings.
- Duplicate peaks are deduplicated by resolved `peakOsmId`, invalid or incomplete rows are skipped without corrupting already imported data, and file-level import failures use the existing failure dialog path.
- After a successful import or update, the screen refreshes and selects the imported or updated list using the identity returned from the import completion flow.
- Unsupported legacy peak lists remain deletable and surface a clear delete-and-reimport message.
- Widget, unit, and robot coverage pass for the updated behavior.
</done_when>
