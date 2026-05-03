<goal>
Replace the current "Show Peaks" FAB toggle with a "Select Peaks" FAB that opens a drawer allowing users to choose which Peak List to display on the map. This gives users control over which peaks are visible instead of a simple on/off toggle.

Users benefit by being able to filter map peaks to specific lists (e.g., "Tasmanian 3000ers") instead of seeing all peaks or none.
</goal>

<background>
Flutter app using flutter_riverpod for state management and ObjectBox for persistence.

**Tech stack:** Flutter, Riverpod, ObjectBox, flutter_map

**Key files to modify:**
- `lib/widgets/map_action_rail.dart` - Rename FAB and change behavior
- `lib/providers/map_provider.dart` - Add selection state, replace showPeaks
- `lib/screens/map_screen.dart` - Add dynamic endDrawer support

**Files to create:**
- `lib/widgets/map_peak_lists_drawer.dart` - New drawer widget

**Reference implementation:** `lib/widgets/map_basemaps_drawer.dart` (drawer pattern), `lib/providers/peak_list_provider.dart` (peak list access)
</background>

<user_flows>
Primary flow:
1. User taps "Select Peaks" FAB (formerly "Show Peaks")
2. Drawer slides open from right showing peak list options
3. Drawer displays: "None" (top), alphabetically sorted PeakLists, "All Peaks" (bottom)
4. User taps a selection (e.g., "Tasmanian 3000ers")
5. Drawer closes, map now shows only peaks from selected list

Alternative flows:
- Select "None": Map shows no peaks (equivalent to old showPeaks = false)
- Select "All Peaks": Map shows all peaks (equivalent to old showPeaks = true)
- Select different list: Map updates to show only that list's peaks

Error flows:
- No PeakLists in ObjectBox: Drawer shows only "None" and "All Peaks"
- PeakList has invalid JSON: That list is skipped, user sees others
- PeakList references non-existent peaks: Only valid peaks render
</user_flows>

<requirements>
**Functional:**
1. Rename FAB tooltip and message from "Show peaks" to "Select Peaks"
2. Keep FAB icon as `Icons.landscape`
3. Update drawer entry points:
   - Peaks FAB onPressed: dismiss transient UI, set `endDrawerMode` to `peakLists`, open endDrawer
   - Basemaps FAB and keyboard shortcut `B`: set `endDrawerMode` to `basemaps`, open endDrawer
4. Add `PeakListSelectionMode` enum to MapState: `none`, `allPeaks`, `specificList`
5. Add `peakListSelectionMode` field to MapState (default: `allPeaks` for backward compatibility)
6. Add `selectedPeakListId` to MapState (nullable int, only valid when mode is `specificList`)
7. Add `EndDrawerMode` enum to MapState: `basemaps`, `peakLists` — single source of truth for drawer content
8. Persist selection across sessions using SharedPrefs:
    - Key `peak_list_selection_mode`: string ("none", "allPeaks", "specificList")
    - Key `peak_list_id`: int (only stored when mode is `specificList`)
    - Update `_loadPosition()` to also load these values
    - Startup loads and reconciles persisted peak-list selection asynchronously after the default map state is created
    - If startup restores a missing or corrupt `specificList`, normalize to `allPeaks` and persist the correction during that async reconciliation
    - Update `savePosition()` to also save these values
9. Create MapPeakListsDrawer widget displaying "None", PeakLists (sorted A-Z), "All Peaks"
10. "None" at top: selection sets mode to `none`, clears `selectedPeakListId`
11. "All Peaks" at bottom: selection sets mode to `allPeaks`, clears `selectedPeakListId`
12. PeakList items: selection sets mode to `specificList`, sets `selectedPeakListId = peakList.peakListId`
13. Sort PeakLists alphabetically by name in drawer
14. Show checkmark icon on currently selected item
15. Show renderable peak count as subtitle in each PeakList ListTile (e.g., "42 renderable peaks")
16. Replace `showPeaks` boolean with derived getter: `bool get showPeaks => peakListSelectionMode != PeakListSelectionMode.none`
17. Filtering is handled by `filteredPeaksProvider` (see requirement 18), not in rendering code
18. Add reactive peak-list providers:
    - Add `peakListRevisionProvider` as a lightweight invalidation counter for peak-list create/import/update/delete operations
    - Add `peakListsProvider` that watches `peakListRevisionProvider`, reads `peakListRepositoryProvider`, and returns the current PeakLists
    - `peakListsProvider` catches repository errors, logs them, and returns `[]` so the drawer can still show "None" and "All Peaks"
    - Add `filteredPeaksProvider` as a separate Riverpod provider that watches `mapProvider` and `peakListsProvider`
    - Every successful in-app peak-list mutation must increment `peakListRevisionProvider` and call `mapProvider.notifier.reconcileSelectedPeakList()`
    - When mode is `none`: returns `[]`
    - When mode is `allPeaks`: returns `mapState.peaks`
    - When mode is `specificList`: decodes selected PeakList's `peakList` JSON, extracts `peakOsmId` values, filters `mapState.peaks` to matching IDs
    - `filteredPeaksProvider` must remain pure and must not mutate `mapProvider`
    - If a selected list is missing or corrupt, fallback reconciliation happens in `MapNotifier`, not in provider evaluation
    - Handles JSON decode errors gracefully (logs warning and returns all peaks until reconciliation has corrected the invalid selection)
    - When `peakListsProvider` falls back to `[]` because of a repository error while mode is `specificList`, the map also falls back to showing all peaks without mutating the current selection
19. Add `selectPeakList(PeakListSelectionMode mode, {int? peakListId})` method to MapNotifier
     - Whenever the active peak filter changes, clear peak info popup and hovered peak ID
     - Persist new selection to SharedPrefs immediately
20. Update map rendering and peak interaction logic to use `filteredPeaksProvider` instead of `mapState.peaks`
21. Update existing tests:
    - `test/widget/map_screen_peak_info_test.dart`: replace `togglePeaks()` calls with `selectPeakList(PeakListSelectionMode.allPeaks)`
    - `test/robot/gpx_tracks/gpx_tracks_robot.dart`: update `showPeaksFab` finder (keep key), rewrite `togglePeaks()` to open drawer and select "All Peaks"

**Error Handling:**
22. When PeakList JSON decode fails, skip that list in drawer (log warning)
23. When the selected PeakList is removed by an in-app mutation and is no longer found by ID, fallback immediately to `allPeaks` and persist
24. When filtered list yields no peaks, show empty map (no error, just no markers)
25. When SharedPrefs load fails, default to `allPeaks` mode (matches old default behavior)

**Edge Cases:**
26. Empty PeakList (no items): Selection shows no peaks, no error
27. Same peak in multiple lists: Only relevant when selecting a single list; show if that list contains it
28. First launch with no PeakLists: Drawer shows "None" and "All Peaks" only
29. `selectedPeakListId` is only valid when mode is `specificList`; ignore it in other modes

**Validation:**
30. FAB key remains `Key('show-peaks-fab')` for test stability
31. Drawer title reads "Peak Lists"
32. "None" and "All Peaks" are not sorted alphabetically — they are fixed at top/bottom
33. PeakList items show subtitle with renderable peak count
</requirements>

<boundaries>
Edge cases:
- PeakList with empty peakList JSON: Shows in drawer, selects correctly, renders no peaks
- ObjectBox returns unsorted PeakLists: Sort alphabetically before display
- Selected list removed by an in-app mutation: Detect immediately, fallback to All Peaks, and persist the correction

Error scenarios:
- PeakList JSON corruption: Catch FormatException, skip list, log to console
- PeakList references osmId not in Peak table: Filter out silently during render
- Repository throws: Show drawer with "None" and "All Peaks" only, and log the error

Limits:
- Large number of PeakLists (>50): Use a scrollable ListView (no pagination required)
- PeakList with many items (>1000): Filtering happens in provider, acceptable performance
</boundaries>

<implementation>
**Files to modify:**

1. `lib/providers/map_provider.dart`:
   - Add `PeakListSelectionMode { none, allPeaks, specificList }` enum
   - Add `EndDrawerMode { basemaps, peakLists }` enum
   - Add `PeakListSelectionMode peakListSelectionMode` field (default: `allPeaks`)
   - Add `int? selectedPeakListId` field (only valid when mode is `specificList`)
   - Change `showPeaks` to computed getter: `bool get showPeaks => peakListSelectionMode != PeakListSelectionMode.none`
   - Update constructor default: `this.peakListSelectionMode = PeakListSelectionMode.allPeaks`
   - Update `copyWith()` to include new fields
    - Replace `togglePeaks()` with `selectPeakList(PeakListSelectionMode mode, {int? peakListId})` method
      - Whenever the active peak filter changes, clear peak info popup and hovered peak ID
      - Persist selection to SharedPrefs immediately
    - Add `reconcileSelectedPeakList()` method:
      - Reads the current selected list from `peakListRepositoryProvider`
      - If the current `specificList` selection is missing or its JSON is corrupt, switch to `allPeaks`, clear `selectedPeakListId`, and persist immediately
    - Update `_loadPosition()` to also load `peak_list_selection_mode` and `peak_list_id` from SharedPrefs
      - After loading saved selection, call `reconcileSelectedPeakList()` as part of async startup reconciliation
    - Update `savePosition()` to also save these values
    - Remove old `showPeaks` boolean field and `togglePeaks()` method

2. `lib/widgets/map_action_rail.dart`:
    - Change line 247: `message: 'Select Peaks'`
    - Change onPressed: dismiss transient UI, set `endDrawerMode` to `peakLists` via notifier, then `Scaffold.of(context).openEndDrawer()`
    - Update the basemaps FAB to set `endDrawerMode` to `basemaps` before opening the endDrawer

3. `lib/screens/map_screen.dart`:
    - Modify `endDrawer` to read `ref.watch(mapProvider).endDrawerMode` and return `MapBasemapsDrawer()` or `MapPeakListsDrawer()` accordingly
    - Read `filteredPeaksProvider` and use it for peak marker rendering, hover candidate building, and peak hit-testing instead of raw `mapState.peaks`
    - Update keyboard shortcut `B` to set `endDrawerMode` to `basemaps` before opening the endDrawer
    - Keep zoom check (`mapState.zoom >= 9`) in rendering logic alongside `showPeaks`

4. `test/widget/map_screen_peak_info_test.dart`:
   - Replace `togglePeaks()` calls with `selectPeakList(PeakListSelectionMode.allPeaks)`

5. `test/robot/gpx_tracks/gpx_tracks_robot.dart`:
   - Keep `showPeaksFab` finder with `Key('show-peaks-fab')`
   - Rewrite `togglePeaks()` method to open drawer and select "All Peaks" (or remove if journey tests updated)

**Files to create:**

6. `lib/widgets/map_peak_lists_drawer.dart`:
    - Follow `MapBasemapsDrawer` pattern (ConsumerWidget)
    - Watch `mapProvider` for current selection state
    - Watch `peakListsProvider` for PeakList data
    - Decode each PeakList before rendering; omit lists with invalid JSON from the visible list and log a warning
    - Build method returns Drawer with a scrollable ListView containing:
      - Drawer key: `Key('peak-lists-drawer')`
      - Title: "Peak Lists"
      - ListTile for "None" (top): trailing checkmark when mode is `none`
      - ListTile for each PeakList (sorted alphabetically by name):
        - Key: `Key('peak-list-item-$name')`
        - Title: peak list name
        - Subtitle: renderable peak count (e.g., "42 renderable peaks") derived from filtered peak IDs after invalid references are removed
        - Trailing checkmark when mode is `specificList` and ID matches
      - ListTile for "All Peaks" (bottom): trailing checkmark when mode is `allPeaks`
    - Each onTap calls `selectPeakList()` with appropriate mode and closes drawer

7. `lib/providers/peak_list_selection_provider.dart` (or add to map_provider.dart):
    - Define `peakListRevisionProvider` and increment it after in-app peak-list create/import/update/delete operations
    - After every successful in-app peak-list mutation, also call `mapProvider.notifier.reconcileSelectedPeakList()`
      - Explicit mutation sites to update in this feature:
        - `lib/screens/peak_lists_screen.dart` after delete and save/create flows
        - `lib/widgets/peak_list_peak_dialog.dart` after add/update/remove peak item flows
          - For the multi-add flow, if one or more peak items were added successfully, bump revision and reconcile once after the loop even if other additions failed and the dialog remains open
        - `lib/providers/peak_list_provider.dart` inside `peakListImportRunnerProvider` after a successful import result
    - Define `peakListsProvider` that watches `peakListRevisionProvider`, reads `peakListRepositoryProvider`, and returns the latest PeakLists
    - Define `filteredPeaksProvider`:
    ```dart
    final peakListRevisionProvider = StateProvider<int>((ref) => 0);

    final peakListsProvider = Provider<List<PeakList>>((ref) {
      ref.watch(peakListRevisionProvider);
      try {
        final repo = ref.watch(peakListRepositoryProvider);
        return repo.getAllPeakLists();
      } catch (e) {
        // log warning
        return const [];
      }
    });

    final filteredPeaksProvider = Provider<List<Peak>>((ref) {
      final mapState = ref.watch(mapProvider);
      final mode = mapState.peakListSelectionMode;
      final peaks = mapState.peaks;
      final peakLists = ref.watch(peakListsProvider);
      
      if (mode == PeakListSelectionMode.none) return [];
      if (mode == PeakListSelectionMode.allPeaks) return peaks;
      
      // mode == specificList
      final peakListId = mapState.selectedPeakListId;
      if (peakListId == null) return peaks;

      final matchingLists = peakLists
          .where((entry) => entry.peakListId == peakListId)
          .toList(growable: false);
      if (matchingLists.isEmpty) {
        return peaks;
      }
      final peakList = matchingLists.first;
      
      try {
        final items = decodePeakListItems(peakList.peakList);
        final osmIds = items.map((item) => item.peakOsmId).toSet();
        return peaks.where((peak) => osmIds.contains(peak.osmId)).toList();
      } catch (e) {
        // log warning
        return peaks;
      }
    });
    ```

**Patterns to use:**
- Riverpod state management (existing MapState/MapNotifier pattern)
- ObjectBox for PeakList queries via PeakListRepository
- ConsumerWidget for drawer (watch both mapProvider and `peakListsProvider`)
- SharedPrefs for persistence (follow existing `_loadPosition`/`savePosition` pattern)

**What to avoid:**
- Don't use multiple endDrawers (Scaffold limitation) - use dynamic switching via MapState
- Don't keep `showPeaks` as independent boolean (causes state inconsistency)
- Don't fetch PeakLists in build method without provider caching
- Don't rely on `peakListRepositoryProvider` alone for reactivity after list mutations
- Don't use `-1` sentinel for "All Peaks" - use enum instead
</implementation>

<validation>
**Logic/business rules tests (unit):**
- `filteredPeaksProvider` returns empty list when mode is `none`
- `filteredPeaksProvider` returns all peaks when mode is `allPeaks`
- `filteredPeaksProvider` returns only matching osmIds when mode is `specificList`
- `filteredPeaksProvider` remains pure and does not mutate `mapProvider`
- `selectPeakList(none)` sets mode to `none`, clears `selectedPeakListId`
- `selectPeakList(allPeaks)` sets mode to `allPeaks`, clears `selectedPeakListId`
- `selectPeakList(specificList, peakListId: X)` sets mode and ID
- PeakList sorting: verify drawer shows lists alphabetically
- Deleted in-app list detection: fallback immediately to `allPeaks` when selected list not found and persist the correction
- Peak-list create/import/update/delete invalidates `peakListsProvider` and refreshes filtered peaks
- Partial-success multi-add invalidates and reconciles once when at least one peak item was added
- Invalid-JSON PeakLists are omitted from the drawer and logged
- Startup loads default selection first, then asynchronously restores and reconciles persisted peak-list selection
- Startup restores a missing or corrupt `specificList` as `allPeaks` and persists the correction
- Repository error fallback shows only "None" and "All Peaks"
- `peakListsProvider` catches repository errors, logs them, and returns `[]`
- Repository error during `specificList` mode leaves selection unchanged but falls back to showing all peaks
- Persistence: verify SharedPrefs keys written on selection
- `showPeaks` getter returns false only when mode is `none`

**UI behavior tests (widget):**
- FAB shows "Select Peaks" tooltip, keeps `Icons.landscape`
- FAB onPressed opens endDrawer with peak lists content
- Layers FAB and keyboard shortcut `B` open the basemaps drawer even after the peak-lists drawer was previously shown
- Drawer displays "None", sorted PeakLists with renderable peak subtitles, "All Peaks"
- Checkmark appears on selected item
- Tapping item closes drawer and updates map
- "None" selection clears peaks from map, clears popup and hover
- "All Peaks" shows all peaks
- Specific list shows filtered peaks with correct count in subtitle
- Filtered-out peaks are not hoverable or clickable

**Critical journey tests (robot):**
- Open drawer → select "None" → verify no peaks visible
- Open drawer → select "All Peaks" → verify all peaks visible
- Open drawer → select specific PeakList → verify only list peaks visible
- Switch between basemaps drawer and peak lists drawer
- Select "None" → verify popup clears and hover clears

**Testability seams:**
- `filteredPeaksProvider` is independently testable with mocked providers
- Drawer widget accepts state via providers (mock `peakListsProvider` for drawer tests)
- Stable selectors: FAB key `Key('show-peaks-fab')`, drawer key `Key('peak-lists-drawer')`, list item keys `Key('peak-list-item-$name')`
- `selectPeakList()` method is directly callable in unit tests
</validation>

<done_when>
- "Select Peaks" FAB opens drawer with "None", PeakLists (with renderable peak subtitles), "All Peaks"
- "None" hides all peaks on map, clears popup and hover
- "All Peaks" shows all peaks (matches old toggle-on behavior)
- Selecting a PeakList filters map to only those peaks
- PeakLists are sorted alphabetically in drawer with renderable peak subtitles
- Currently selected item shows checkmark
- Dynamic endDrawer switches between basemaps and peak lists correctly
- `showPeaks` boolean replaced by `peakListSelectionMode` derived getter
- Selection persists across app restarts via SharedPrefs
- `filteredPeaksProvider` handles reactive filtering via Riverpod
- All existing tests pass after updating `togglePeaks()` references
- New tests cover selection logic, filtering, and persistence
- FAB keeps `Icons.landscape` icon and `Key('show-peaks-fab')`
</done_when>
