<goal>
Rework the Peak Lists screen so the summary list and mini-map share the left side, the selected-list details table owns the right side, and the screen stays usable without draggable split controls.
This matters because users rely on this screen to browse many peak lists, inspect selected-list details, import CSVs, and delete old or unsupported lists without losing context.
</goal>

<background>
Flutter app using Material, Riverpod, and `flutter_map`.
The current `PeakListsScreen` already supports summary rows, sorting, selection, delete confirmation, empty-state rendering, import flow, legacy unsupported rows, and mini-map marker rendering.
The current implementation in `./lib/screens/peak_lists_screen.dart` still uses an outer draggable split and an inner details split; this spec replaces that layout contract while preserving the existing data and import behaviors.
Reference files:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/left_tooltip_fab.dart`
- `./lib/widgets/peak_list_import_dialog.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/peaks/peak_lists_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`
This spec supersedes layout-conflicting portions of `./ai_specs/011-peak-lists-enhancements-spec.md` and `./ai_specs/011-desktop-ui-spec.md`.
</background>

<user_flows>
Primary flow:
1. User opens Peak Lists on a wide viewport.
2. User sees a left column with a section toolbar labeled `My Peak Lists`, the summary list card below it, and the mini-map card below that.
3. User sees a right column with the selected list title, the selected-list summary sentence, and the peak table inside its own bordered container.
4. User taps a summary row and the right-hand details area and left mini-map update to the selected list.
5. User opens the import action in the section toolbar and completes the existing import flow.
6. User deletes a row from the summary list and the screen resolves selection deterministically without leaving the page.

Alternative flows:
- Empty library: the screen still renders the header containers, shows the existing empty-state guidance, and keeps the mini-map fallback visible.
- Returning user: previously imported lists load directly into the revised layout with the same selection, sorting, delete, and import behavior.
- Unsupported legacy list: the row stays visible, selectable, and deletable, but the details area shows the unsupported-state guidance instead of decoded metrics.

Error flows:
- Import cancelled: close the dialog and leave selection and scroll position unchanged.
- Delete cancelled: close the confirmation dialog and leave the repository and selection unchanged.
- Mini-map cannot fit bounds or has no plottable coordinates: keep the map container visible and fall back to Tasmania bounds without crashing.
</user_flows>

<requirements>
**Functional:**
1. `./lib/screens/peak_lists_screen.dart` must remove the current draggable wide-layout divider and replace it with a non-draggable responsive layout.
2. On all supported widths, the screen must render two columns: a left column for the summary list plus mini-map, and a right column for the selected-list details plus peak table.
3. Treat the outer desktop split as configurable default ratios, not rigid guarantees. Use a default target of `40%` left column and `60%` right column, but allow adjustment when the intrinsic content widths, minimum usable pane sizes, or the mini-map aspect ratio would otherwise make a pane unusable.
4. Treat the left-column vertical split as configurable default ratios, not rigid guarantees. Use a default target of `30%` summary-list area and `70%` mini-map area, measured against the left-column height remaining after the section-toolbar row.
5. The top-left row is a section toolbar, not the page heading. The shared shell `AppBar` title remains the actual route title.
6. The section toolbar must stay at the top-left and contain:
   - title `My Peak Lists`
   - an import action on the right
7. The import action must:
    - stay wired to the existing import dialog flow
    - use `FloatingActionButton.small` with icon-only presentation for this screen
    - show tooltip text exactly `Import Peak List (csv)`
    - live inside the Peak Lists body instead of using `Scaffold.floatingActionButton`
    - use the same `backgroundColor` treatment as the map rail FABs: `Theme.of(context).colorScheme.surface`
    - use the same icon and text foreground treatment as the map rail FABs: `Theme.of(context).colorScheme.onSurface`
    - reuse `LeftTooltipFab` for the visible hover bubble pattern and the semantic label
    - treat the hover bubble as desktop-pointer only; touch discoverability comes from the icon-only control's semantics rather than a required touch-visible tooltip
    - preserve an accessible semantic label for assistive technologies even when the control is icon-only
8. The summary-list container must sit directly below the section toolbar, use the app's existing card or outlined-surface styling, and keep the current summary-table content and row actions.
9. The mini-map container must sit below the summary-list container in the left column, use the app's existing card or outlined-surface styling, and preserve the current peak-marker, selection, and Tasmania-fallback behavior. Climbed peak markers must render above unclimbed peak markers in the marker stack. When a peak row is selected in the details table, the mini-map must draw the same blue selection circle used by `map_screen` around that peak. When `PeakListsScreen` is entered, its peak-marker data must be refreshed via `reloadPeakMarkers()` rather than `refreshPeaks()`. The visible mini-map content must respect a `4:3` aspect ratio.
10. The right column must contain the selected list title and summary sentence above the peak table. Keep these in the right-hand details area rather than moving or removing them.
11. The peak table must be positioned on the right-hand side inside its own bordered container and preserve the current selected-list row content and unsupported-state messaging. The visible peak columns are `Peak Name`, `Elevation`, `Ascent Date`, and `Points`.
12. Do not change the current logical behaviors for selection, sorting, delete confirmation, import completion, unsupported legacy rows, or empty-state messaging except where layout and selector updates are needed to support this spec.

**Error Handling:**
13. If there are no peak lists, preserve the existing instructional copy `No peak lists exist. Import a CSV to get started.` and keep the new layout containers rendered in their empty states instead of collapsing them away.
14. If a selected row represents an unsupported legacy list, keep the right-hand title, unsupported guidance, delete action, and left-side map container visible without throwing layout errors.
15. If the mini-map cannot fit the selected peaks or has zero plottable peaks, fall back to the existing Tasmania bounds behavior and keep the container height stable.
16. If the import dialog closes without importing, do not change the current selection or scroll position unless the current implementation already does so outside this spec.
**Edge Cases:**
17. The screen must not expose any draggable resize handle, resize gesture target, or visual affordance implying manual pane resizing. Non-interactive separators and spacing remain allowed.
18. The minimum supported `PeakListsScreen` body width is `588px`.
19. When the preferred ratios conflict with usable rendering, prioritize minimum usability over exact percentages. Use these desktop-layout defaults unless the existing screen already has stronger constraints that are demonstrably required:
   - wide-layout minimum left column width: `320px` as a preferred target that may relax at the minimum supported body width
   - wide-layout minimum right column width: `360px` as a preferred target that may relax at the minimum supported body width
   - summary-list minimum usable height: `180px`
   - mini-map minimum usable height: `220px`
20. On supported body widths with insufficient viewport height, keep the two-column layout instead of forcing any alternate layout fallback solely because height is tight.
21. In that short-viewport case:
    - keep the mini-map at or above its minimum usable height
    - allow vertical scrolling inside the summary-list container on the left
    - make the right-column content region containing the selected title, summary sentence, and peak-table container vertically scrollable
    - avoid making the whole page scroll merely to satisfy the preferred ratios
22. The summary-list height calculation must exclude the section-toolbar row from the `30%` target.
23. Preserve row selection and post-delete selection behavior from the existing Peak Lists implementation when moving widgets into the new layout.

**Validation:**
25. Summary-list headers and cells must not line-wrap. Each summary column width must be driven by the widest intrinsic content in that column across the full table dataset, including header text, with the action column fixed to `max(header width, delete icon width)`. If the total intrinsic width exceeds the available container width, the summary table region must support horizontal scrolling inside its container.
26. The summary header row and each summary data row must use the same shared column-sizing contract so headers and cells remain aligned while horizontally scrolling.
27. Peak-table headers and cells must not line-wrap. Each peak column width must be driven by the widest intrinsic content in that column across the full table dataset, including header text. Keep a `12px` gap between peak-table columns. Right-align the `Elevation`, `Ascent Date`, and `Points` columns in both headers and cells. If the total intrinsic width exceeds the available container width, the peak-table region must support horizontal scrolling inside its container.
28. The peak-table header row and each peak-table data row must use the same shared column-sizing contract so headers and cells remain aligned while horizontally scrolling.
29. Preserve the existing stable app-owned `Key` selectors used by widget and robot tests, including `peak-lists-summary-pane`, `peak-lists-details-pane`, `peak-lists-import-fab`, `peak-lists-selected-title`, `peak-lists-mini-map`, summary rows, delete actions, and existing import-dialog actions.
30. Add stable keys for the summary-table scroll viewport, the peak-table scroll viewport, and the right-column content viewport if it is distinct from the details pane.
31. Reuse the app's current `Card` or equivalent outlined-surface styling for the new bordered containers rather than introducing a new visual language.
</requirements>

<boundaries>
Edge cases:
- Keep the update scoped to layout and presentation. Do not add new peak-list fields, edit flows, reorder flows, full-screen map navigation, or new map gestures.
- Do not remove or rewrite current selection, delete, import, unsupported-row, or empty-state business rules unless needed to satisfy the new layout.
- Do not make the percentages user-adjustable in this phase. The change is to tuneable implementation constants, not runtime controls.
- Do not replace the shared shell title with the in-body toolbar label. `My Peak Lists` is a section label only.
- Do not add any compact-layout or narrow-layout branch. This screen is wide-layout only.
- Measure layout against the `PeakListsScreen` body constraints, not the full app shell width.
- Keep the section toolbar and import action pinned above the left-column content; only the table regions scroll horizontally.

Error scenarios:
- Tile loading failures or bounds-fit issues must not crash the screen or collapse the mini-map container.
- Empty-state and unsupported-row states must still render predictable containers so the layout does not jump or disappear.
- Import cancellation must not trigger layout resets beyond normal widget rebuild behavior.
- Short wide layouts must keep the page frame stable by assigning overflow to the summary-list container and the right-column content region rather than to the whole screen.

Limits:
- Treat `40% / 60%` and `30% / 70%` as preferred desktop-layout tuning defaults stored in one place for easy adjustment.
- Use horizontal scrolling inside table containers to satisfy the no-wrap requirement instead of shrinking text, clipping key values, or forcing wider global layouts.
- Use shared column-sizing constants or an equivalent shared sizing model so horizontally scrollable headers and rows stay aligned.
- Use the import control for this screen only: `LeftTooltipFab` + `FloatingActionButton.small` with the map rail FAB surface/onSurface color treatment.
- Keep the update within `PeakListsScreen` and its tests unless a small supporting widget extraction clearly improves readability without changing behavior.
</boundaries>

<discovery>
Before implementing, verify in `./lib/screens/peak_lists_screen.dart`:
- the current wide-layout divider and any associated drag state that must be removed
- the current placement of the selected-list title and summary sentence
- the current summary and details table structures, including how keys are attached
- the current mini-map rendering and Tasmania fallback logic
- the current import action wiring and selection refresh after import completion
- the map-screen FAB styling and tooltip behavior in `./lib/widgets/map_action_rail.dart` and `./lib/widgets/left_tooltip_fab.dart`

Before finalizing tests, verify in:
- `./test/widget/peak_lists_screen_test.dart` which selectors already exist and can be preserved
- `./test/robot/peaks/peak_lists_robot.dart` which robot helpers assume a global FAB location or a draggable divider
- `./test/robot/peaks/peak_lists_journey_test.dart` which journeys must be updated to use the in-container import action and the wide-layout selectors
</discovery>

<implementation>
Modify these files:
- `./lib/screens/peak_lists_screen.dart` - replace the draggable split layout, move the import action into the `My Peak Lists` section toolbar, add the new left/right layout, preserve the selected-list title and summary on the right, define shared column-sizing rules for both tables, and add any new stable keys needed for testing
- `./test/widget/peak_lists_screen_test.dart` - update and extend widget coverage for the new layout, no-divider behavior, and scroll containers
- `./test/robot/peaks/peak_lists_robot.dart` - update robot selectors and helpers for the in-container import action and new layout regions
- `./test/robot/peaks/peak_lists_journey_test.dart` - keep the critical journeys passing against the new layout and selectors

Patterns to use:
- Keep layout ratio constants local to `PeakListsScreen` and name them clearly so future tuning changes happen in one place.
- Use `LayoutBuilder`, `Flex` or `Expanded`, and container-local horizontal scrolling to satisfy ratio and no-wrap requirements.
- Keep overflow ownership local: in short wide layouts, the summary-list container and the right-column content region scroll vertically while the overall page frame remains fixed.
- Keep transient layout state local to the screen. Do not introduce new global state for pane sizing.
- Preserve existing import and delete wiring; only move the visual entry point.

Avoid:
- reintroducing any draggable divider or resize handle
- hard-coding the same ratio literals in multiple places
- shrinking typography or clipping headers as the primary solution to table-width pressure
- adding a new standalone layout service or controller when the screen-local widget tree is sufficient
</implementation>

<stages>
Phase 1: wide-layout restructure
- Replace the draggable outer split with the new two-column layout.
- Move the import action into the `My Peak Lists` section toolbar.
- Keep the selected-list title and summary sentence above the right-hand peak table.
- Verify with widget tests that the divider is gone and the new regions render in the expected places.

Phase 2: responsive and constraint behavior
- Apply preferred default ratios with the required minimum-size guards.
- Add horizontal scrolling inside both table containers with shared column sizing.
- Verify with widget tests that ratios flex when needed and short wide layouts keep the map minimum height and right-column content scrolling.

Phase 3: regression and journey coverage
- Update robot helpers and journeys for the moved import action and persistent list interactions.
- Re-run empty-state, unsupported-row, delete, selection, and import journeys against the new structure.
- Verify the screen preserves existing behavior while matching the new layout contract.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic and state behavior: cover selection persistence, post-delete selection resolution, short-viewport overflow ownership, and import-selection refresh through widget tests. If any pure layout helper is extracted, add focused unit tests for clamp and fallback rules.
- UI behavior: widget tests for wide layout region placement, removed divider, `My Peak Lists` section-toolbar rendering, in-container import action widget type, desktop-pointer hover bubble behavior, mini-map `4:3` presentation, selected-peak blue circle overlay, preserved map minimum height in short wide layouts, right-column content scrolling, right-hand title and summary placement, horizontal scrolling for both tables, aligned shared column sizing, empty state, and unsupported legacy rows.
- Critical journeys: robot-driven tests for opening Peak Lists, selecting a list, deleting a targeted row, and importing through the moved in-container action.

TDD expectations:
- Work in vertical slices, one failing test at a time.
- Start with the wide shell render and removal of the draggable divider.
- Then add the in-container import action placement and preserved wiring.
- Then add shared table column sizing and short-viewport overflow behavior.
- Finish with regression slices for delete selection, empty state, unsupported legacy rows, and import-result reselection.
- Prefer exercising public widget behavior and stable selectors over private implementation details.

Robot-test expectations:
- Keep robot journeys key-first and deterministic.
- Add only the selectors needed for the critical journeys and new layout regions.
- Preserve existing dialog-action keys such as delete confirm or cancel where possible to avoid unnecessary churn.
- Use the existing fake file picker and import seams so the moved import button does not introduce flakiness.

Required selectors and seams:
- stable keys for the Peak Lists section-toolbar region, left-column container, summary-list container, mini-map container, right-hand details container, peak-table container, in-container import action, and both table scroll regions
- stable keys for the right-column content scroll region in addition to the peak-table container if those become separate widgets
- preserved keys for summary rows, delete actions, selected-title text, dialog actions, and any existing import dialog controls already used by tests
- deterministic fake or injected dependencies for file picking, import execution, repositories, and map-safe widget pumping already used by the existing test harness

Verification:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- Peak Lists uses the new non-draggable layout: summary list top-left, mini-map bottom-left, and selected-list details table on the right for this screen.
- The top-left row is a `My Peak Lists` section toolbar, while the shared shell `AppBar` remains the page title.
- The import action lives inside the Peak Lists body, uses `FloatingActionButton.small` with `LeftTooltipFab` for this screen, shows tooltip text `Import Peak List (csv)`, uses the map rail FAB surface/onSurface color treatment, and keeps its visible hover bubble desktop-pointer only.
- Preferred `40% / 60%` and `30% / 70%` ratios are implemented as tuneable defaults with minimum-size and aspect-ratio guards rather than rigid percentages.
- Short wide layouts keep the two-column frame, preserve the mini-map minimum height, and assign vertical overflow to the summary-list container and the right-column content region rather than the whole page.
- Both summary and details tables keep headers and cell text on one line by using internal horizontal scrolling with shared column sizing, fixed inter-column gaps, and right-aligned numeric/date columns where needed. The selected-list summary sentence also reports peak points earned out of total points.
- Selecting a peak row in the details table draws a blue circle around the matching peak in the mini-map, matching the `map_screen` selection treatment.
- Climbed peak markers render above unclimbed peak markers in the shared marker stack.
- No draggable divider or manual pane resizing remains anywhere on the screen.
- Existing selection, delete, import, empty-state, Tasmania fallback, and unsupported legacy-row behaviors still work in the new layout.
- Widget and robot coverage pass for the updated structure and critical journeys.
</done_when>
