<goal>
Expand Peak Lists so users can inspect a peak, add peaks into the selected list, edit only that list membership's points, and remove only that membership without mutating the underlying peak catalog.
This matters because peak-bagging workflows need fast list maintenance while keeping source peak data stable and predictable.
</goal>

<background>
Flutter app using Riverpod, ObjectBox, `flutter_map`, and the existing peak/list/import patterns.
`PeakListsScreen` already shows the summary list, selected-list details, mini-map, and list deletion.
`Peak` already stores coordinates, MGRS data, and `sourceOfTruth`.
`PeaksBaggedRepository` already derives climbed-state data from GPX tracks, and `MapScreen` already supports selected-track state.
This spec builds on the existing Peak Lists workstream and narrows the scope to selected-list peak membership editing, peak inspection, and derived ascent display.

Files to examine:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./lib/models/peak_list.dart`
- `./lib/models/peaks_bagged.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_list_import_service.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peaks_bagged_repository.dart`
- `./lib/services/gpx_track_repository.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/widgets/dialog_helpers.dart`
</background>

<discovery>
Before implementing, verify the current behavior and extension points in:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./lib/models/peak_list.dart`
- `./lib/models/peaks_bagged.dart`
- `./lib/services/peaks_bagged_repository.dart`
- `./lib/services/gpx_track_repository.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/widgets/dialog_helpers.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/widget/peak_list_peak_dialog_test.dart`
- `./test/services/peak_list_repository_test.dart`
- `./test/robot/peaks/peak_lists_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`
</discovery>

<user_flows>
Primary flow:
1. User opens Peak Lists and selects a list.
2. User taps a peak row and sees a modal peak dialog with edit/delete actions, peak metadata, ascent history, and GPX links.
3. User taps Edit, changes points, saves, and the dialog closes while the row remains selected.
4. User taps Add New Peak, searches only the peaks not already in the list, chooses one, sets points from 0 to 10, saves, and the dialog closes while the new row becomes selected.
5. User taps a GPX link and the app opens Map Screen with the matching track selected and a marker at the peak.

Alternative flows:
- Existing lists load with prior selection preserved when available.
- User cancels add, edit, or delete and nothing changes.
- User opens a selected list with zero peaks and can still use Add New Peak.
- User follows a GPX link for a track that is missing and gets a recoverable error.

Error flows:
- Duplicate add is blocked before persistence.
- Save or delete failures leave the current list unchanged and use the existing modal failure pattern.
- Search returns no match and shows the same no-results state as the map peak search panel.
- A peak with no climbs shows blank `Ascents` and `Ascent Date` cells.
</user_flows>

<requirements>
**Functional:**
1. Add an `Ascents` column before `Points` in the selected-list peak table. Count `PeaksBagged` rows matching that peak's `Peak.osmId`. Show blank when the count is zero. Sort like `Ascent Date`: blanks always stay at the bottom, and ties sort stably by peak name then peak id. Keep the Peak Name column narrower so long names wrap, wrap the Ascent Date header as `Ascent\nDate`, and show heights as `Height` with an `m` suffix.
2. Tapping a peak row opens a modal detail dialog for that peak. The dialog should open anchored in the bottom-right of the screen so it covers the mini-map less, and it must be draggable to a new position while open. It shows top-right Edit and Delete actions, the peak name, height, points, MGRS coordinates, the peak's map resolved by building the peak's full MGRS string from its stored fields and passing it to `TasmapRepository.findByMgrsCodeAndCoordinates(...)`, ascent history, and GPX links. If the map cannot be resolved, display `Unknown`. Opening the dialog must not mutate the current `selectedPeakListId`, and the dialog's open/close lifecycle only affects `selectedPeakId`.
3. The ascent-history section shows one row per `PeaksBagged` record, newest-first by date then `gpxId`, with dates formatted `EEE, MMM d yyyy` (for example `Mon, Mar 10 2026`). Blank dates stay blank. Each row's GPX link is labeled with `trackName`, or `Track #<gpxTrackId>` when `trackName` is blank, and targets the track that produced that ascent. If `gpxId <= 0`, leave the link cell blank. If a track id exists but lookup fails, show a recoverable error. If a peak has no ascents, the history section remains visible but empty.
4. Any scrollable table in the peak detail experience keeps its header row pinned to the top of its scroll viewport, including the selected-list peak table and the ascent-history table inside the dialog.
5. The selected peak remains highlighted in the mini-map with the blue selection circle rendered above the peak markers, not underneath them.
6. Add New Peak sits at the top right of the details header, uses the outlined add-circle icon, and opens a searchable peak picker patterned after `MapPeakSearchPanel`. The picker uses the same search behavior as `PeakRepository.searchPeaks()`, excludes peaks already in the selected list by `Peak.osmId`, shows the matched peak's map name on the same line as height as `Map: MapName`, and includes a points selector bounded to 0-10 with default value 0. When the picker opens, the search text field automatically gains focus so typing can begin immediately. Hide the action when no peak list is selected.
7. Save in add mode appends the selected peak to the current list in the existing order model, closes automatically, and selects the newly added row as the sole selected peak. Duplicate `Peak.osmId` selections must be rejected even if a stale picker result slips past filtering.
8. Edit mode changes only the selected list entry's `points` via the same 0-10 selector used by add mode, closes automatically on save, and leaves the underlying `Peak` entity untouched. Edit mode must not change the list order or peak identity.
9. Delete mode removes only the selected list entry, closes automatically after confirm, and moves selection to the next visible row or previous row in the current on-screen sort order if the deleted row was last; clear selection if no rows remain.
10. GPX links resolve the `GpxTrack` by the ascent record's `gpxId`, call `mapProvider.enableSync()`, set the selected peak location as `mapProvider.selectedLocation` so the peak marker remains visible, and route through the existing `mapProvider.showTrack(...)` path so `selectedTrackId`, `showTracks`, and track-focus state are updated together before navigating to `/map` or `goNamed('map')`. The map state should immediately move toward the selected track as a fallback, and `MapScreen` should still fit to the selected track extents with `EdgeInsets.all(50)` padding when the map branch is active; if bounds cannot be derived or the fit fails, center on the track at zoom 12 using the same fallback behavior as MapScreen.
11. The resolved map name in the dialog is a tappable control. Tapping it should navigate to Map Screen, select the resolved map in `mapProvider`, and open the map at that map's extents using the existing selected-map fit behavior already used on Map Screen. If the map cannot be resolved, keep `Unknown` as plain text.
12. If a GPX track cannot be resolved, keep the peak detail dialog open and surface the recoverable error in a modal on top. The current list state must remain intact.
13. Preserve the current list summary, import flow, and list-delete behavior unless this feature explicitly changes them.

**Error Handling:**
13. Prevent duplicate adds both by filtering existing peaks out of the picker by `Peak.osmId` and by rejecting any duplicate selection that slips through.
14. If search produces no results, show the same no-results affordance as the map peak search panel.
15. If add, edit, or delete persistence fails, leave the current data unchanged and use the existing modal failure dialog pattern.
16. If the user cancels any dialog, make no persistence changes.

**Edge Cases:**
17. A list with zero peaks still renders cleanly and still allows Add New Peak when a list is selected.
18. A peak with no ascents renders blank `Ascents` and `Ascent Date` cells rather than `0`.
19. Multiple climbs on the same day remain separate ascent-history rows.
20. Points outside 0-10 are not accepted through the UI in either add or edit mode.
21. The dialog auto-close behavior must not clear the selected row unless that row was deleted.
22. Repeated GPX-link taps must retarget the newly selected track even when Map Screen is kept alive in the shell and the user is navigating back from another branch.
23. No global `Peak` records are created, edited, or deleted by the dialog actions.
</requirements>

<boundaries>
UI boundaries:
- Keep this task scoped to peak-list item management and the selected-list detail experience.
- Do not add bulk edit, bulk delete, reorder, or a second import flow.
- Do not make list points free-form text.
- Do not add new peak fields or a new peak schema.

Data boundaries:
- Preserve the existing `PeakList` JSON payload structure and ordering semantics.
- Keep `Ascents` derived from `PeaksBagged` rows; do not store it separately.
- Use the existing `GpxTrack` / `mapProvider` track-selection path for GPX navigation; do not invent a new navigation subsystem.
</boundaries>

<implementation>
Modify or create these files:
- `./lib/screens/peak_lists_screen.dart` - open the peak dialog from row selection, add the `Ascents` column, wire add/edit/delete actions, keep the blue selection circle above markers, and handle post-save or post-delete reselection.
- `./lib/services/peak_list_repository.dart` - list lookup and list-item persistence helpers used by add, edit, and delete flows
- `./lib/services/peak_repository.dart` - shared peak-search source of truth used by the add picker and `mapProvider`
- `./lib/providers/map_provider.dart` - delegate peak searching to `PeakRepository.searchPeaks()` instead of duplicating search logic, and own the GPX-link track-selection plus fallback focus update used before opening Map Screen
- `./lib/providers/tasmap_provider.dart` - provide the `TasmapRepository` used by the dialog's map-name lookup
- `./lib/providers/map_provider.dart` - expose the selected-map path used when the dialog's map-name link opens Map Screen
- `./lib/screens/map_screen.dart` - preserve the selected-map extent behavior that the dialog link relies on and fit pending selected-track requests when the map branch becomes active again
- `./lib/widgets/peak_list_peak_dialog.dart` - new modal for peak details, add mode, edit mode, delete confirmation, ascent-history table, GPX links, bottom-right draggable placement, autofocus on the add search field, and the `Map: MapName` result label.
- `./lib/screens/map_screen_panels.dart` - update the map peak search panel result rows to show `Map: MapName` alongside height.
- `./lib/services/peaks_bagged_repository.dart` - add ascent-count and ascent-history helpers keyed by peak id.
- `./lib/services/gpx_track_repository.dart` - provide track lookup by id for GPX-link navigation if the dialog cannot already reuse the existing API directly.
- `./lib/screens/map_screen_layers.dart` or `./lib/screens/map_screen.dart` - add the smallest stable selector needed to verify selected-track navigation from the GPX link, if the current UI has no reliable selector, and any selector/seam needed to verify the selected-track fit or centering behavior.
- `./test/widget/peak_lists_screen_test.dart` - cover detail dialog open/close, `Ascents` column, sticky header behavior, add/edit/delete state, and reselection.
- `./test/widget/peak_list_peak_dialog_test.dart` - cover add/edit modal states, filtering, points bounds, and GPX-link failure handling.
- `./test/robot/peaks/peak_lists_robot.dart` - update robot selectors and helpers for the new dialog and add action.
- `./test/robot/peaks/peak_lists_journey_test.dart` - cover the full add/edit/delete/GPX journey.
- `./test/services/peaks_bagged_repository_test.dart` - cover count/history aggregation.
- `./test/services/gpx_track_repository_test.dart` - cover track lookup behavior if a navigation helper is added or adjusted.

Patterns to use:
- Keep dialog-local state local to the widget.
- Use Riverpod only for injected repositories and navigation dependencies.
- Read `tasmapRepositoryProvider` where the dialog resolves the peak's map name from MGRS/coordinate fields.
- Reuse the existing selected-map path on Map Screen when wiring the clickable map-name control.
- Reuse `showDangerConfirmDialog` for delete confirmation.
- Make `PeakRepository.searchPeaks()` the single source of peak-search behavior; have `mapProvider.searchPeaks()` delegate to it and let the add picker call the shared repository/helper directly after filtering already-added peaks.
- Prefer deterministic fakes over live navigation or ObjectBox in tests.
</implementation>

<stages>
Phase 1: selected-peak view
- Add the `Ascents` column, row selection modal, pinned headers, and blue circle layering.
- Verify with widget tests for blank cells, sort behavior, and detail dialog rendering.

Phase 2: add/edit/delete mutation
- Implement the add and edit dialog modes, duplicate filtering, point bounds, and delete flow.
- Verify with widget tests for save, cancel, reselection, and duplicate rejection.

Phase 3: GPX link navigation
- Wire GPX links to the Map Screen track-selection path and add any minimal selector needed for deterministic verification.
- Verify with a focused widget test and the robot journey that the map opens with the target track selected.

Phase 4: regression hardening
- Run the robot journey, widget suite, and service tests against the updated peak-list flow.
- Verify that list summary, import, and list-delete behavior remain unchanged.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for ascent counting/history aggregation, duplicate prevention, point bounds, list-item mutation, and GPX track resolution.
- UI behavior: widget tests for the `Ascents` column, sticky headers, modal open/close, add search filtering, edit points-only flow, delete confirmation and reselection, no-results state, failure dialogs, and blank cells.
- Critical journeys: robot-driven tests for selecting a list, opening the peak dialog, adding a peak, editing points, deleting a peak, and following a GPX link into Map Screen.

TDD expectations:
- Use one failing test slice at a time.
- Start with selected-peak dialog open/close and the `Ascents` column.
- Then add filtered peak search and add-mode save.
- Then add edit-mode points-only save.
- Then add delete confirmation and post-delete reselection.
- Finish with GPX-link navigation and duplicate/error-path coverage.
- Keep tests on public widget behavior and repository/service APIs, not private state.
- Use fakes for peak storage, peak search, ascent history, TasmapRepository map-name lookup, track lookup, peakCorrelationSettingsProvider threshold resolution, track-bounds calculation, map viewport/fit behavior, and navigation so the flows stay deterministic.

Robot-test expectations:
- Use stable app-owned keys for the peak row, details dialog, edit/delete/save actions, add action, search field, search results, points selector, GPX links, and any map-screen selected-track selector needed for verification.
- Keep robot journeys key-first and behavior-focused.
- Verify journey outcomes with UI state and injected seams, not pixels.

Verification:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- The selected-list peak table shows `Ascents` and sorts blanks last.
- Selecting a peak opens a modal with edit, delete, metadata, ascent history, and GPX links, and the dialog does not disturb the current list selection.
- The dialog shows MGRS and lat/long on one line, formats ascent-history dates with the year, and lets the resolved map name open Map Screen at that map's extents.
- Add New Peak adds only missing peaks, edits only the selected list item points, and delete removes only the selected list item.
- GPX links navigate to Map Screen, select the associated track, place a marker at the peak, and keep working across repeated clicks when returning from another shell branch.
- The mini-map selection circle renders above the markers.
- Widget, unit, and robot coverage pass for the updated behavior.
</done_when>
