<goal>
Enable users to select and add multiple peaks at once when adding peaks to a peak list. Currently only single peak selection is supported. This improves workflow efficiency when building or updating peak lists.

Beneficiaries: Users creating or managing peak lists who need to add several peaks in one session without reopening the dialog repeatedly.
</goal>

<background>
Flutter app using flutter_riverpod, ObjectBox for local storage. The peak list dialog (`PeakListPeakDialog`) currently supports single peak selection via `PeakSearchResultsList`.

Key files:
- @lib/widgets/peak_list_peak_dialog.dart - Dialog with add/edit/view modes
- @lib/widgets/peak_search_results_list.dart - Existing single-select search results list used elsewhere
- @lib/widgets/peak_multi_select_results_list.dart - New multi-select search results list for add mode
- @lib/models/peak.dart - Peak model (name, elevation, latitude, longitude, area)
- @lib/models/peak_list.dart - PeakList and PeakListItem models
- @lib/services/peak_list_repository.dart - Repository for peak list operations

Current state:
- `_selectedPeak` is a single `Peak?` in dialog state
- `PeakSearchResultsList` uses `selectedPeakId` for single selection highlight
- `PeakListPeakDialogOutcome` returns single `selectedPeakId`
- Points selector is a single dropdown for the one selected peak
</background>

<user_flows>
Primary flow (add multiple peaks):
1. User taps "Add New Peak" FAB on peak lists screen
2. Dialog opens in add mode with search field at top and peak results area below
3. User types search query, results appear with checkbox rows (all unchecked); empty query shows all peaks
4. Results sorted alphabetically (case-insensitive), each row shows: [checkbox] Name | Height | Map | Points
    - Name: peak.name (truncate with ellipsis if > 40 chars)
    - Height: peak.elevation formatted as "${elevation.round()}m" or `—`
    - Map: Tasmap 50k map name from `_mapNameForPeak(peak)` (e.g., "King Island")
5. User checks multiple peaks they want to add
6. User adjusts points inline for each selected peak (default 1)
7. User taps "Save"
8. All selected peaks are added to the list with their respective points
9. Dialog closes, returning list of added peak IDs and selects the first peak in the saved alphabetical order in the list view

Dialog layout (top to bottom):
- Title: "Add New Peak"
- Search field
- Search results list (expands to fill available space, scrolls if needed)
- Points control at end of each row (default 1, editable inline)
- Divider
- Cancel / Save buttons

Alternative flows:
- Search returns no results: Show "No peaks found" message
- User unchecks a peak: Checkbox becomes unticked and the row loses its green highlight
- User clears search: Previously selected peaks remain selected when they reappear
- User changes points: Updates immediately for that specific peak inline
- 50 peaks already selected: Checkboxes disabled, show "Maximum 50 peaks per save" message

Error flows:
- Peak already in list: Filtered out from search results (not shown)
- Save fails (repository error): Show error dialog, keep dialog open with any unsaved peaks still selected
- No peaks selected at save: Save button stays disabled until at least one peak is selected
- Partial save failure: Keep successful saves, show error with list of which peaks failed
</user_flows>

<requirements>
**Functional:**
1. Search results list must show a checkbox to the left of each peak name
2. Multiple peaks can be selected simultaneously via checkboxes
3. Peaks in search results must be sorted alphabetically by name (case-insensitive)
4. Each search result row displays collapsed to single row: `[checkbox] Name | Height | Map`
    - Name: peak.name, truncated to 40 chars with ellipsis if longer
    - Height: `${peak.elevation!.round()}m` or `—` if null
    - Map: Tasmap 50k map name from `_mapNameForPeak(peak)` (e.g., "King Island")
    - The row uses compact fixed widths so it still fits the 320px minimum dialog width without horizontal scrolling
5. Selected peaks already in the peak list must be excluded from search results
6. Selected peaks appear in a separate list below the search results, marked by a green-ticked checkbox plus a subtle green row highlight
    - Each selected row displays Name, Height, Map, and an editable Points field
    - Height renders as `—` when unknown
   - Points entry accepts digits only and clamps live to 0-10
   - If the field is cleared, it reverts to 1 when the change is committed
   - Editing points on an unchecked row automatically selects that peak
7. Search results list must expand to fill available dialog space and lazy-load rows as the user scrolls
8. Save operation must add all selected peaks with their individual point values
9. Dialog outcome must return list of all selected peak IDs (not just one)
10. Selecting 50 peaks disables further checkboxes, shows "Maximum 50 peaks per save" message
11. Search results must not be capped at 100 rows; rows should be built on demand so large result sets remain usable
12. Selected peaks and returned IDs must use alphabetical order by peak name for deterministic display and save order
13. Search-result row, selected-row, checkbox, and points controls must expose stable keys derived from `peak.osmId`:
    - `peak-multi-select-row-{osmId}`
    - `peak-multi-select-checkbox-{osmId}`
    - `peak-multi-select-points-{osmId}`
    - `peak-selected-row-{osmId}`
    - `peak-selected-checkbox-{osmId}`
    - `peak-selected-points-{osmId}`

**Error Handling:**
14. If repository save fails, continue saving remaining peaks, then show one error dialog listing all failures and preserve unsaved selections
15. Save button disabled (greyed out) when no peaks are selected

**Edge Cases:**
16. Selecting all visible search results must work without UI overflow
17. Selecting peaks, then searching again, then selecting more: all selections preserved across searches
18. Unchecking a peak must immediately remove the green highlight and tick from that row
19. Empty search query must show all peaks from the repository
20. Selected peaks list must not contain duplicates (enforced by Set<int>)

**Validation:**
21. Points values must be integers between 0 and 10 inclusive and can be changed by typing or stepper buttons
22. Search results display: verify checkbox, name (truncated), height, and map controls are present; unknown height renders as `—`
23. Selected rows render in the separate list with a green-ticked checkbox, highlight, editable points control, and `—` for unknown height
24. Stable keys exist for search rows, selected rows, checkbox, and points controls so robot tests can target them deterministically
</requirements>

<boundaries>
Edge cases:
- Very long peak names: Truncate with ellipsis at 40 chars in search result row and selected-peaks list
- Many selected peaks (10+): Selected rows remain in the separate selected-peaks list without layout overflow
- Search results exceed dialog height: Results list scrolls within its Expanded space
- Rapid checkbox toggling: Use setState only (no debounce needed for local state)
- Search results are not truncated at a fixed 100-row limit; the list lazily builds additional rows as needed

Error scenarios:
- Repository unavailable during save: Keep successful saves, show error dialog, and leave unsaved peaks selected for retry
- ObjectBox write failure: Report error and leave unsaved peaks selected for retry
- Invalid peak data: Should not occur (only selecting existing peaks), but skip if encountered

Limits:
- Maximum search results displayed: no fixed cap; rows are built lazily as needed
- Maximum selected peaks per save: 50 (disable checkboxes, show message)
- Points per peak: 0-10 range enforced by the numeric control in the selected-peaks list
</boundaries>

<implementation>
Files to modify:

1. **lib/widgets/peak_search_results_list.dart**
   - Keep current single-select behavior for map search and other existing uses

2. **lib/widgets/peak_multi_select_results_list.dart**
   - New dedicated multi-select results widget used only by add mode
   - Accept `Set<int> selectedPeakIds`, `Map<int, int> pointsByPeakId`, `ValueChanged<Set<int>> onSelectionChanged`, and `void Function(int peakId, int points) onPointsChanged`
   - Sort results alphabetically by `peak.name.toLowerCase()` before display
    - Collapse display to single row: checkbox + name (truncated 40ch) + height + map
    - Use compact fixed widths so the row fits the 320px minimum dialog width without overflow
    - Return a lazily built scrolling list wrapped in `Expanded` to fill available space so rows are created on demand rather than truncated
    - Disable checkbox if selectedPeakIds.length >= 50 (unless this peak is already selected)

3. **lib/widgets/peak_selected_peaks_list.dart**
   - New dedicated selected-peaks list used below the search results
   - Accept `Set<int> selectedPeakIds`, `Map<int, int> pointsByPeakId`, `ValueChanged<Set<int>> onSelectionChanged`, and `void Function(int peakId, int points) onPointsChanged`
   - Sort selected peaks alphabetically by `peak.name.toLowerCase()` before display
   - Collapse display to single row: checkbox + name (truncated 40ch) + height + map + points control
   - Render selected rows with a green ticked checkbox and subtle green row highlight
   - Points control is a compact numeric field with up/down buttons and direct typing, defaulting to 1
   - Filter points input to digits only and clamp live to 0-10
   - If the points field is cleared, restore 1 on commit
   - Editing points on a row selects that peak if it is not already selected
   - Use compact fixed widths so the row fits the 320px minimum dialog width without overflow
   - Wrap the list in a scrolling container below the results to allow multiple selections without overflow

4. **lib/widgets/peak_list_peak_dialog.dart**
     - Change state from `_selectedPeak` (Peak?) to:
      - `_selectedPeakIds` (Set<int>) for tracking which peaks are selected
      - `_selectedPoints` (Map<int, int>) for peak ID → points assignments
    - Update `_buildAddContent` layout (top to bottom):
       - Search TextField
       - Expanded `PeakMultiSelectResultsList` with checkboxes
       - Separate selected-peaks list below the search results
       - The selected-peaks list shows the green tick/highlight and updates `_selectedPoints[peakId]` inline in that list
   - Update `_saveAdd()` to iterate `_selectedPeakIds` in alphabetical order and call `addPeakItem` for each
      - Continue through the full selection, collect all failures, keep successful adds, and show one error dialog after the loop if any peak failed
    - Update outcome to return `List<int> selectedPeakIds`
    - Disable Save button when `_selectedPeakIds.isEmpty`

5. **lib/widgets/peak_list_peak_dialog.dart** (or inline in dialog)
    - Update `PeakListPeakDialogOutcome` to support multiple peaks:
   ```dart
   class PeakListPeakDialogOutcome {
     final List<int> selectedPeakIds;
     final bool deleted;  // Keep for edit mode, not used in add mode
     
     const PeakListPeakDialogOutcome.selected(List<int> selectedPeakIds)
       : this._(selectedPeakIds: selectedPeakIds, deleted: false);
     
     const PeakListPeakDialogOutcome.deleted([List<int>? selectedPeakIds])
       : this._(selectedPeakIds: selectedPeakIds ?? [], deleted: true);
   }
   ```

Note: This feature only modifies add mode. Edit and view modes remain unchanged.

Patterns to use:
- `Set<int>` for O(1) lookup of selected state in search results
- `Map<int, int>` to track peak ID → points assignments
- `Expanded` widget for search results list to fill space between search field and buttons
- A lazily built scrolling list for search results
- Alphabetical ordering for selected peaks and returned IDs
- Stable `Key`s derived from peak ID for the row, checkbox, and points control
- Compact width rules so the row fits the 320px dialog minimum without horizontal scrolling

What to avoid:
- Don't use `CheckboxListTile` (inflexible layout for single-row requirement)
- Don't store full `Peak` objects in selection state (only IDs needed, peaks available via repository)
- Don't clear selections when search query changes (must persist across searches)
- Don't use `const` for rows with live points controls or selection state
- Don't change the shared map-search list widget into a checkbox control
- Don't leave points input unvalidated or accept non-digit characters
- Don't let the row overflow horizontally on narrow dialogs
</implementation>

<validation>
**Unit Tests:**
- `PeakSearchResultsList` widget test: renders checkbox for each result, checkbox toggle updates selected set
- Sort verification: search results displayed in alphabetical order
- Selection persistence: toggling checkbox on/off correctly adds/removes from selected set
- Search results row layout: single row contains checkbox, name, height, and map (no wrapping)
- Selected list layout: selected peaks render in the separate list with checkbox, points control, and green selected styling

**Widget Tests:**
- Add dialog with multiple selections: select 3 peaks, assign different points to each, save
- Selected rows: show green tick/highlight and points control in the separate list
- Save with no selection: Save button is disabled until a selection exists
- Save with multiple peaks: verifies all peaks added with correct points
- Cross-search persistence: select peaks, search new query, verify previous selections preserved
- Large result sets: rows continue loading as needed instead of stopping at 100
- Robot flow uses keys for row, checkbox, and points controls
- Typing into points auto-selects the row and clamps to 0-10
- Clearing the points field restores 1 on commit

**Integration Tests (Robot):**
- Critical journey: Open add dialog → search "mount" → select 3 peaks → assign points 3, 5, 7 in the selected list → save → verify all 3 peaks appear in list with correct points
- Error journey: Open add dialog → search → select peak → clear selection → attempt save → verify error shown

**TDD Expectations:**
- Behavior-first slices: start with "checkbox appears" → "checkbox toggles selection" → "points field defaults to 1" → "selected row highlights green" → "save adds all" → "failure list reports all failed peaks"
- Testability seams: inject `peakListRepository` via constructor for mocking; use `ValueChanged<Set<int>>` callback for selection changes
- Vertical-slice cycle: UI widget + state management + repository call in each RED→GREEN→REFACTOR iteration

**Baseline Coverage:**
- Logic: search filtering, sort order, selection state management, points assignment
- UI behavior: checkbox toggle, selected-peaks points control, green selection highlight, error messages, save button state
- Critical journeys: multi-select-add flow via robot test
</validation>

<done_when>
1. Search results display with checkboxes, sorted alphabetically (case-insensitive)
2. Multiple peaks can be selected and persist across searches
3. Selected rows show a default points value of 1 and support typing or up/down adjustment inline
4. Save adds all selected peaks with their respective points to the list (partial success allowed, failures reported)
5. Dialog returns list of all added peak IDs
6. Search results list expands to fill available dialog space between search field and buttons
7. Search results lazily build rows as the user scrolls and are not truncated at 100
8. Selection disabled after 50 peaks with appropriate message
9. All widget tests pass for new multi-select behavior (including limits and error cases)
10. Robot test passes for critical multi-select-add journey
11. No regressions in existing single-peak edit/view functionality
</done_when>
