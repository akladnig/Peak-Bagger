<goal>
Allow users to manage one or more peak lists from the map drawer without closing the drawer, show the active selection as chips in the shared app bar, and keep the map's peak filtering in sync.

Who: map users comparing multiple peak lists and switching between filtered and unfiltered peak views.

Why: the current drawer is single-select and closes on tap, which makes multi-list workflows impossible and hides the active filter state from the shell chrome.
</goal>

<background>
Flutter desktop app using Riverpod and shared preferences in `./lib/providers/map_provider.dart`.

Current selection contract is single-list: `PeakListSelectionMode.none|allPeaks|specificList` plus `selectedPeakListId`. Existing peak visibility is derived from `PeakListSelectionMode.none`, so the multi-select replacement must preserve a real `none` mode instead of removing it.

The drawer is `./lib/widgets/map_peak_lists_drawer.dart`; the shell app bar is `./lib/router.dart` with theme action key `Key('app-bar-theme-action')`.

Peak filtering lives in `./lib/providers/peak_list_selection_provider.dart`.

Existing widget and robot coverage already exercises peak list drawer flows in `./test/widget/map_screen_peak_info_test.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/robot/gpx_tracks/gpx_tracks_robot.dart`, and selection persistence in `./test/providers/map_peak_list_selection_persistence_test.dart`.

Files to examine:
- `./lib/providers/map_provider.dart`
- `./lib/providers/peak_list_selection_provider.dart`
- `./lib/widgets/map_peak_lists_drawer.dart`
- `./lib/router.dart`
- `./test/providers/map_peak_list_selection_persistence_test.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens the Select Peak List drawer from the map.
2. User turns on several peak-list switches without closing the drawer.
3. The map immediately shows the union of peaks from the selected lists.
4. The shared app bar shows chip(s) for the active selection to the left of the theme toggle.
5. User closes the drawer or switches routes and the active selection remains visible in the shell chrome.

Alternative flows:
- User selects `All Peaks`: the drawer clears any specific-list checks, the app bar shows exactly one `All Peaks` chip, and the map shows all peaks.
- User turns `All Peaks` off after a specific-list selection existed: the previous specific-list selection is restored.
- User returns to the app after restart or route changes: the last saved active selection is restored.
- User toggles a specific list while `All Peaks` is active: the app exits `All Peaks`, applies the resulting specific-list toggle set, and treats that resulting set as the new remembered snapshot.

Error flows:
- A selected peak list is deleted, corrupted, or no longer resolves: drop it from the active selection, keep the remaining valid lists, and fall back to `none` if no specific lists remain active.
- A selected list payload cannot be decoded: skip only that list during filtering and logging; do not crash or clear unrelated selections.
- All specific-list switches are turned off: enter `none`, hide peaks, and show exactly one `None` chip in the app bar.
- The user tries to turn off `All Peaks` with no remembered specific selection: keep `All Peaks` active.
</user_flows>

<requirements>
**Functional:**
1. Replace the single-list selection contract in `./lib/providers/map_provider.dart` with an explicit multi-select state contract that names these active fields: `peakListSelectionMode`, `selectedPeakListIds`, and `previousSpecificPeakListIds`.
2. Remove `selectedPeakListId` from the active selection contract. If any caller still needs a single selected id, derive it locally from `selectedPeakListIds` instead of storing a competing single-id state field.
3. Keep `PeakListSelectionMode.none`, `PeakListSelectionMode.allPeaks`, and `PeakListSelectionMode.specificList` as the only three modes. `none` is the zero-active-lists mode, `allPeaks` is the global unfiltered mode, and `specificList` means one-or-more selected specific peak lists.
4. Update `./lib/widgets/map_peak_lists_drawer.dart` so each decodable `PeakList` from the repository is rendered with a leading switch, using the same whole-row/switch interaction pattern as the tracks/routes drawer. Tapping a row or switch must toggle that list without closing the drawer.
5. Do not render a dedicated `None` row in the drawer. Turning off all specific-list switches must enter `PeakListSelectionMode.none`.
6. Keep `All Peaks` in the drawer as a master switch. Turning it on must deselect all specific lists and capture the current non-empty specific-list set as the remembered snapshot. Turning it off must restore the remembered specific-list set if one exists; otherwise it remains in `All Peaks`.
7. Toggling a specific list while `All Peaks` is active must exit `All Peaks`, apply the resulting specific-list toggle set, and treat that resulting set as the new remembered snapshot.
8. Update `./lib/providers/peak_list_selection_provider.dart` so peak filtering returns the union of all selected specific lists, deduplicated by peak id while preserving existing map-peak iteration order. The provider must remain deterministic and pure.
9. Show the active selection in the shared shell app bar in `./lib/router.dart` as a read-only chip strip positioned immediately to the left of `Key('app-bar-theme-action')`. The strip always exists and is mode-specific: `allPeaks` shows exactly one `All Peaks` chip, `none` shows exactly one `None` chip, and `specificList` shows one chip per selected list.

**Error Handling:**
10. Persist and restore the active mode plus the remembered specific-list set through the existing shared-preferences path in `./lib/providers/map_provider.dart`, using fully new multi-select keys: `peak_list_selection_mode_v2`, `peak_list_selected_ids_v2`, and `peak_list_previous_specific_ids_v2`. The two id collections must be stored as JSON arrays of integers in stable numeric order.
11. No migration path is required. Legacy single-id peak-list preference keys are ignored by the multi-select feature, and the feature reads and writes only the new `*_v2` keys.
12. If persisted `*_v2` id payloads are missing, malformed, contain non-integer values, or otherwise cannot be decoded safely, log the issue, reset to first-launch defaults (`allPeaks`, empty remembered set), and overwrite the corrupt payloads on the next successful save.
13. If persisted or active selection references missing list ids, normalize by removing the missing ids only after a successful repository read confirms those ids are truly absent. If specific-list mode then has no remaining ids, normalize to `none`, not `allPeaks`.
14. If the peak-list repository read fails, preserve current active and remembered selection ids in memory, keep chip-strip fallback labels available for unresolved ids, and do not perform destructive normalization during that failure window.
15. If a selected list fails to decode, skip only that list during filtering and continue rendering the rest of the app. Drawers skip malformed lists entirely; filtering and summary logic must not crash because of a single bad payload.
16. If the user attempts to leave `All Peaks` with no prior remembered specific-list selection, keep `All Peaks` selected.

**Edge Cases:**
15. The drawer remains open while toggling peak lists so the user can select multiple lists in one session.
16. Drawer rows are ordered alphabetically by `PeakList.name`, and specific-list chips are always ordered by rendered chip label. The ordering remains stable across toggles and restarts.
17. The chip strip always exists. In `allPeaks` and `none` it shows exactly one chip; in `specificList` it shows one chip per selected list and no `All Peaks` or `None` chip.
18. If the app bar does not have enough horizontal room, the chip row must scroll horizontally rather than pushing the theme toggle out of view. Chip labels truncate gracefully but the strip remains visible.
19. If a list is removed while selected, the map filter and chip strip update immediately from provider state after normalization; stale chips must not remain visible after provider refresh.
20. Keep existing `All Peaks` and peak-list interactions keyboard/tap friendly; do not regress the current shell app bar or drawer accessibility.
21. If the peak-list repository cannot be read, the drawer shows the `All Peaks` control plus a small unavailable-state message instead of silently collapsing to an empty list, while chip-strip state and active selection remain intact.
22. Specific-list chip ordering always uses rendered chip label, including when one or more chip labels are unresolved and use fallback labels such as `List #<id>`.

**Validation:**
23. Add unit coverage for the selection reducer/filtering logic and persistence normalization. The tests must cover: `none` semantics, multi-select union, All Peaks exclusivity, specific-list toggles while `All Peaks` is active, remembered-snapshot updates, missing-id cleanup, legacy-key ignore/overwrite behavior, stable persisted id ordering, corrupt `*_v2` payload recovery, repository-failure preservation behavior, and decode-error resilience.
24. Add widget coverage for the drawer and shell chrome. The tests must cover: no `None` row, leading switches per decodable list, zero-renderable-count rows stay visible, repository-failure drawer message behavior, drawer stays open after toggles, chip strip renders before the theme action, one-chip behavior for `none` and `allPeaks`, and chip truncation/scroll behavior on constrained widths.
25. Add robot-driven journey coverage for the critical flow. The robot tests must cover: open drawer, select multiple lists, verify map filtering changes, switch to `All Peaks`, turn `All Peaks` off to restore the prior specific selection, turn all specific lists off to reach `none`, and verify the app bar chip strip stays in sync.
26. Add or update stable selectors so robot/widget coverage is key-first. Required keys: `Key('peak-lists-drawer')`, `Key('peak-list-selection-all-peaks-row')`, `Key('peak-list-selection-all-peaks-switch')`, `Key('peak-list-selection-switch-<id>')`, `Key('peak-list-selection-row-<id>')`, `Key('peak-list-selection-summary')`, `Key('peak-list-selection-chip-<id>')`, `Key('peak-list-selection-chip-none')`, `Key('peak-list-selection-chip-all-peaks')`, `Key('peak-list-selection-unavailable-message')`, and keep `Key('app-bar-theme-action')`.
27. Use TDD in vertical slices: one failing test at a time, then the smallest implementation to make it pass, then refactor only after green. Include persistence-ordering coverage so rapid toggle sequences prove last-write-wins behavior.
</requirements>

<boundaries>
Edge cases:
- `PeakListSelectionMode.none` is allowed and represents zero active specific-list switches.
- `All Peaks` is mutually exclusive with specific-list selection.
- Invalid peak lists remain skipped in the drawer rather than rendered as broken controls, but decodable zero-renderable-count lists remain visible.
- Chip labels must stay readable without changing the app bar height.

Error scenarios:
- Corrupt or missing list data should not crash the shell app bar or the map route.
- Reconciliation should happen in notifier-owned state logic, not during widget build.
- If selection state becomes stale after import/delete/reset/rebuild, normalize it before filtering/rendering and remove stale ids before chip rendering, but only after a successful repository read.
- Repository failure must be distinguishable from a successful empty-list result before normalization or drawer-state decisions are made.

Limits:
- Do not add ObjectBox schema changes.
- Do not add a new global navigation surface.
- Do not auto-close the drawer after a toggle.
- Do not add a separate persistence layer just for multi-select.
</boundaries>

<implementation>
- Modify `./lib/providers/map_provider.dart` to store `peakListSelectionMode`, `selectedPeakListIds`, and `previousSpecificPeakListIds` as immutable unique `Set<int>` snapshots with copy-on-write updates only. Preserve `none` as the zero-active-lists mode, keep first launch defaulting to `allPeaks`, serialize only the new `*_v2` preference keys in stable numeric order, ignore legacy single-id prefs entirely, recover safely from corrupt `*_v2` payloads, and ensure persistence is last-write-wins through write serialization or debouncing.
- Modify `./lib/providers/peak_list_selection_provider.dart` to expose the selected-list summary and union filtering used by both the drawer and app bar. Introduce a failure-aware seam so the feature can distinguish repository failure from a successful empty-list result before normalization or drawer-state decisions are made. Chip labels use current `PeakList.name` when available and a deterministic fallback such as `List #<id>` when a selected id is temporarily unresolved.
- Modify `./lib/widgets/map_peak_lists_drawer.dart` to replace the current tap-to-close single-select rows with switch rows and master `All Peaks` behavior. Show every decodable repository list, keep renderable-count subtitles including `0 renderable peaks`, skip only malformed lists, let all specific-list switches off enter `none`, and show an unavailable-state message with `Key('peak-list-selection-unavailable-message')` plus the `All Peaks` control if the repository read fails.
- Modify `./lib/router.dart` to render the active read-only chip strip immediately before `Key('app-bar-theme-action')`. The strip always exists and shows mode-specific chips only.
- Update `./test/providers/map_peak_list_selection_persistence_test.dart` and add focused unit tests for selection normalization and filtering.
- Add a focused widget test file such as `./test/widget/map_peak_list_selection_test.dart` or extend `./test/widget/map_screen_peak_info_test.dart` for drawer and chip behavior.
- Extend `./test/robot/gpx_tracks/gpx_tracks_robot.dart` and `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` for the multi-select journey.
- If chip rendering becomes bulky, extract a tiny helper widget to `./lib/widgets/peak_list_selection_summary.dart`; keep it presentation-only.
- Avoid broad refactors of the peak/track map layers; this slice is selection state, drawer UI, and shell chrome only.
</implementation>

<stages>
Phase 1: Replace the single-select contract with normalized multi-select state and persistence. Verify unit tests for `none`, `allPeaks`, specific-list selection, restore-previous-selection behavior, immutable unique-set copy-on-write updates, `*_v2` persistence without legacy-key reads, and corrupt-payload recovery.

Phase 2: Convert the drawer to switch-based multi-select controls. Verify the drawer stays open, no `None` row exists, `All Peaks` behaves as the master switch, and decodable zero-renderable-count rows stay visible.

Phase 3: Add the shell app bar chip strip. Verify mode-specific chip rendering, route-global visibility, fallback labels, and truncation or scrolling that preserves the theme toggle.

Phase 4: Add robot coverage for the full journey. Verify selecting multiple lists changes the map, toggling `All Peaks` clears and restores selection, turning all specific lists off enters `none`, and stale selections normalize after data changes.
</stages>

<validation>
1. Follow vertical-slice TDD: start with the simplest failing unit test, make it pass, then move to the next slice.
2. Prefer pure helpers or provider-level seams for selection normalization, persisted-schema encoding/decoding, failure-aware list loading, and summary generation so the unit tests can stay deterministic.
3. Unit tests must cover the exact selection contract: `none`, multi-select union, master `All Peaks` exclusivity, specific-list toggles while `All Peaks` is active, restore-previous-selection behavior, stale-id cleanup, legacy-key ignore behavior, stable persisted id ordering, last-write-wins persistence ordering, corrupt `*_v2` payload recovery, repository-failure preservation behavior, and decode-error resilience.
4. Widget tests must cover the actual shell UI: drawer switch rendering, drawer persistence while toggling, mode-specific chip-strip placement, special chips for `None` and `All Peaks`, zero-renderable-count rows, repository-failure unavailable messaging, fallback-chip ordering, and constrained-width overflow behavior.
5. Robot tests must cover the critical user journey with stable keys and a desktop-sized surface.
6. Required automated coverage outcomes:
- logic/business rules: selection normalization, immutable state updates, and peak filtering
- UI behavior: drawer and chip-strip rendering
- critical journeys: open drawer, select multiple lists, verify map/filter sync, switch to `All Peaks`, restore prior selection, and enter `none`
</validation>

<done_when>
- The drawer supports multi-select peak lists with no `None` row and preserves `PeakListSelectionMode.none` when all specific-list switches are off.
- `All Peaks` acts as the exclusive global mode and restores the previous specific-list selection when turned off.
- The map filter reflects the union of selected lists.
- The app bar shows the active read-only chip strip to the left of the theme toggle, with one chip in `allPeaks` and `none` and multiple chips in `specificList`.
- Selection state survives persistence and normalizes missing or invalid lists safely.
- Unit, widget, and robot coverage exists for the behaviors above.
</done_when>
