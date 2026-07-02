<goal>
Add interactive, region-aware peak-list buttons to the shared map app bar so users can pin frequently used peak lists for each region and toggle those lists without reopening the peak-lists drawer.

This matters for map users who regularly switch between challenge lists while exploring different regions. Pinning should provide faster repeat access without collapsing selection and visibility into one action.
</goal>

<background>
This is a Flutter app with Riverpod-managed map state, a shared shell `AppBar`, and region-aware peak-list filtering already wired through map selection state.

Relevant files to examine:
- `./ai_specs/peak-lists/peak-list-pins.md` - source task brief
- `./pubspec.yaml` - confirms `flutter_svg` is available
- `./lib/widgets/map_peak_lists_drawer.dart` - current peak-list drawer rows and region filtering
- `./lib/widgets/drawer_outline_button.dart` - current drawer button styling and layout helper
- `./lib/providers/map_provider.dart` - peak-list selection state, persistence, visible-bounds state, and region reconciliation
- `./lib/providers/peak_list_selection_provider.dart` - current app-bar summary model derived from map state
- `./lib/widgets/peak_list_selection_summary.dart` - current passive app-bar summary strip
- `./lib/router.dart` - shared app bar layout and map-route app-bar wiring
- `./lib/screens/map_screen.dart` - map route shell and end-drawer usage
- `./lib/services/region_manifest_catalog.dart` - region polygon/bounds helpers including `regionsForBounds`
- `./test/providers/map_peak_list_selection_state_test.dart` - peak-list state transition coverage
- `./test/providers/map_peak_list_selection_persistence_test.dart` - preference restore/save coverage
- `./test/widget/map_peak_list_selection_test.dart` - shared app-bar summary widget coverage
- `./test/widget/map_screen_peak_info_test.dart` - drawer region-filtering behavior
- `./test/robot/map/` - preferred folder for new map journey coverage

Current behavior to preserve:
- Peak-list selection remains owned by `mapProvider` and continues to drive peak visibility.
- The drawer still filters region-valid/renderable peak lists using existing region helpers.
- The shared map app bar keeps the centered search trigger centered and the title/search/right-lane layout intact.
- Existing stable selectors such as `show-peaks-fab`, `peak-list-item-$name`, `peak-list-selection-row-$id`, `peak-list-selection-summary`, and `shared-app-bar` should stay valid unless a change is unavoidable.
</background>

<user_flows>
Primary flow:
1. User opens the peak-lists drawer from the map screen.
2. User selects a region-valid specific peak list.
3. That list appears in the app bar as a selected button for the current normalized visible-region `Set<String>` with a visible pin affordance.
4. User taps the pin affordance.
5. The button becomes pinned for its region and remains available in the app bar whenever that region is visible, even after the user later deselects it.

Alternative flows:
- Multiple pins: user pins more than one list for the same region and sees all pinned buttons in deterministic label order.
- Temporary selection: user selects a list but does not pin it; the app-bar button remains visible only while selected.
- App-bar toggle: user clicks the text/toggle area of a pinned button to deselect it; the button stays visible but becomes unselected.
- `All Peaks` or `None` active: pinned buttons remain visible for the current normalized visible-region `Set<String>`, the corresponding mode chip remains visible, and clicking a pinned button switches into `specificList` mode for that list.
- Multiple visible regions: when visible bounds intersect more than one region, the drawer and map app bar show the union of applicable peak lists across those visible regions.
- Region switch: user changes visible bounds and the app bar updates to the pinned buttons and transient selected buttons applicable to the current normalized visible-region `Set<String>`.
- Restart restore: user closes and reopens the app and per-region pinned state restores from preferences and is surfaced again when that region becomes visible.

Error flows:
- Repository refresh fails: keep the last good visible app-bar buttons and do not clear persisted pins because of a transient load failure.
- Pinned list is deleted, unreadable, or no longer renderable for the current visible-region set: omit it from rendering and prune it from persisted pins on a successful reconcile path.
- The visible-region helper resolves zero regions: do not show any peak-list buttons or chips in the map app bar right lane for that view.
</user_flows>

<requirements>
**Functional:**
1. Add a separate pin action to each region-valid specific peak-list row in `./lib/widgets/map_peak_lists_drawer.dart` using `assets/svg/pin.svg`.
2. Keep the drawer row's main text/button action dedicated to selection toggling only; pinning and selection must remain independent actions.
3. Show a visible-region app-bar button for every currently selected specific peak list that is renderable in the current normalized visible-region `Set<String>`, even if it is not pinned.
4. Support multiple pinned peak lists per region.
5. Scope pinned state by region key, not globally.
6. Show pinned buttons in the map app bar even when they are deselected.
7. When a pinned button is deselected from its text/toggle area, keep the button visible in an unselected state.
8. When an unpinned selected button is deselected from the app bar, remove it from the app bar because it is no longer selected and not pinned.
9. When a user pins a selected list, do not change its selected/deselected state; only change whether it persists in the app bar.
10. When a user unpins a button from the app bar, remove it immediately only if it is already deselected; otherwise keep it visible as an unpinned selected button until it is deselected.
11. Derive the visible region set for this feature from `regionManifestCatalog.regionsForBounds(bounds)` using visible map bounds rather than `state.center`.
12. If needed, extract one reusable helper that turns visible bounds into a normalized `Set<String>` of visible region keys so the drawer, app-bar row, and peak-list reconciliation all use the same rule.
13. When zero visible regions are returned, do not show any peak-list buttons for that view.
14. When multiple visible regions are returned, show the union of applicable peak lists across those visible regions.
15. Update the existing peak-list drawer and peak-list reconciliation code paths to use the visible-bounds-based visible-region-set helper instead of `regionManifestCatalog.regionKeyForPoint(state.center)`.
16. When `PeakListSelectionMode.allPeaks` is active and pinned buttons exist for the current normalized visible-region `Set<String>`, keep the `All Peaks` chip visible alongside the pinned buttons. Clicking a pinned button's toggle area must switch to `specificList` mode for that list.
17. When `PeakListSelectionMode.none` is active and pinned buttons exist for the current normalized visible-region `Set<String>`, keep the `None` chip visible alongside the pinned buttons. Clicking a pinned button's toggle area must switch to `specificList` mode for that list.
18. When multiple visible regions are active, show pinned app-bar buttons for the union of pinned lists whose region keys are contained in the current normalized visible-region `Set<String>`, plus any visible-region selected transient buttons.
19. Replace or extend the current single-region peak-list filtering/reconciliation helper contracts so they accept the normalized visible-region `Set<String>` and apply union semantics consistently across drawer filtering, app-bar derivation, and selection reconciliation.
20. Order visible specific-list app-bar buttons alphabetically by display label.
21. Render the interactive pin/unpin/toggle button row on the map route only.
22. Do not display peak-list buttons or summary chips on non-map routes.
23. Persist per-region pinned ids across app restarts using a new versioned preference payload separate from the existing peak-list selection preference keys.
24. Restore pinned ids best-effort on startup. If the pinned payload is corrupt or unreadable, default to no pins without disturbing existing camera or peak-list selection preferences.
25. Update `./pubspec.yaml` so `assets/svg/pin.svg` and `assets/svg/unpin.svg` are declared Flutter assets before the feature ships.

**Error Handling:**
26. Do not clear in-memory app-bar buttons or persisted pin state solely because a peak-list refresh failed and cached data is still in use.
27. Exclude and prune pinned ids whose peak lists no longer exist, fail decode, or no longer apply to the current normalized visible-region `Set<String>` during a successful reconcile path.
28. If zero visible regions apply, do not render peak-list buttons or chips in the map app bar right lane for that view.
29. Keep the centered search trigger, title lane, and right-lane clipping behavior working on the map route while removing peak-list buttons from non-map routes.

**Edge Cases:**
30. Treat selection and pinning as separate state machines: a list may be `selected+pinned`, `selected+unpinned`, `unselected+pinned`, or absent; `unselected+unpinned` means it should not appear in the app bar.
31. Handle rapid select/pin/unpin toggles deterministically so the final persisted state matches the final visible UI state.
32. Do not leak pinned buttons from regions outside the current normalized visible-region `Set<String>` into the map app bar.
33. When zero visible regions apply, preserve existing pinned persistence and selection state in memory, but do not render peak-list buttons until at least one region becomes visible again.
34. When multiple visible regions apply, region-based filtering and pin rendering operate on the union of those region keys.
35. When selection reconciliation runs with zero visible regions, skip region-based pruning rather than forcing a fallback mode.
36. When selection reconciliation runs with multiple visible regions, prune only against the union of lists applicable to those visible region keys.
37. When selection reconciliation changes `selectedPeakListIds` because of visible-region rules, update the app-bar row from the reconciled state rather than stale pre-switch state.
38. Keep existing name-based drawer button keys working unless there is a compelling documented reason to change them.

**Validation:**
39. Add stable app-owned `Key` selectors for every new actionable control, including drawer pin buttons and app-bar pin/unpin/toggle controls.
40. If the drawer row needs split tap targets, implement them with explicit semantics and clear pointer targets; do not overload one press target to infer whether the user meant select or pin.
</requirements>

<boundaries>
Edge cases:
- If pinned prefs contain ids for regions outside the current visible-region set, do not render those buttons until their regions become visible again.
- If zero visible regions are returned, render no peak-list buttons or chips in the map app bar right lane for that view.
- If multiple visible regions are returned, render the union of applicable lists across those regions.
- If multiple long list names are visible, keep the right app-bar lane bounded and scrollable or otherwise constrained so it does not push the centered search control off center.
- If labels are temporarily unavailable while providers load, use the existing summary/provider fallback strategy rather than inventing a second label-resolution path.

Error scenarios:
- Corrupt pinned preference payload: ignore it, log if helpful, and fall back to no pins.
- Repository failure during reconcile: preserve current in-memory rendering and persisted pins.
- Deleted/unreadable pinned ids after a successful repository load: prune them from the persisted pin map.

Limits:
- Do not change how the map drawer opens, how `EndDrawerMode` works, or how peak filtering itself works.
- Do not add pin controls outside the map peak-lists drawer and the shared map app bar.
- Do not add backward-compatibility migrations for old pin data because no prior pin feature exists; a fresh versioned preference key is sufficient.
</boundaries>

<implementation>
Modify or extend these files:
- `./pubspec.yaml` to declare `assets/svg/pin.svg` and `assets/svg/unpin.svg` as Flutter assets.
- `./lib/widgets/map_peak_lists_drawer.dart` for split selection vs pin actions in peak-list rows.
- `./lib/widgets/drawer_outline_button.dart` only if a small reusable trailing-action extension is cleaner than a drawer-specific row widget.
- `./lib/providers/map_provider.dart` to add per-region pinned state, mutation methods, bounds-based reconciliation, and persistence.
- `./lib/providers/peak_list_selection_provider.dart` to derive a visible-region app-bar view model that merges selected ids, pinned ids, labels, region keys, and selected-state flags.
- `./lib/widgets/peak_list_selection_summary.dart` to repurpose the existing map-route right-lane widget for the interactive peak-list row while preserving `Key('peak-list-selection-summary')` on the map route only.
- `./lib/router.dart` to render the updated app-bar right-lane content without breaking centered search layout.
- `./lib/services/region_manifest_catalog.dart` only if a small reusable helper is needed to expose normalized visible-region-key resolution for peak-list consumers.
- `./test/providers/map_peak_list_selection_state_test.dart` and `./test/providers/map_peak_list_selection_persistence_test.dart` for state/persistence coverage.
- `./test/widget/map_peak_list_selection_test.dart` and any adjacent widget tests needed for app-bar and drawer behavior.
- `./test/robot/map/` for a robot and journey test covering the critical workflow.

Implementation guidance:
- Keep pin-state ownership with `mapProvider` or a directly related provider that shares the same persistence lifecycle as peak-list selection. Avoid splitting persistence ownership across unrelated notifiers.
- Prefer one derived app-bar view model so selection state, pin state, region filtering, and label lookup stay in one place.
- Reuse `regionManifestCatalog.regionsForBounds(bounds)` as the source of truth for this feature's visible-region resolution, alongside `peakListAppliesToRegion` and `renderablePeakListIds`.
- If visible-region-key normalization is currently private or duplicated, extract it into one reusable helper and update the existing peak-list drawer/reconcile code to call it instead of `regionManifestCatalog.regionKeyForPoint(state.center)`.
- Replace or extend any current single-region helper contracts, such as `currentRegionKey`-based filtering inputs, so they consume the normalized visible-region `Set<String>` directly.
- Persist the per-region pinned map under a fresh versioned key as deterministic JSON from region key to sorted id list.
- Avoid clearing selection state when pinning or unpinning.
- Remove peak-list buttons from non-map routes entirely. Limit peak-list button rendering to the map route.
- In `./lib/router.dart`, render an empty right-lane placeholder on non-map routes so title and search alignment remain stable while no peak-list UI is shown.
- Preserve `Key('peak-list-selection-summary')` as the root container key for the replacement interactive row on the map route. Do not render that keyed container on non-map routes.
- Use `MapNotifier.updateVisibleBounds(...)` as the canonical trigger for visible-region changes that affect drawer filtering, app-bar button rendering, and bounds-based peak-list reconciliation.
- Reconcile pinned ids at named trigger points: after startup restore when visible bounds are available, after successful peak-list reload/revision updates, when opening the peak-lists drawer, and when `MapNotifier.updateVisibleBounds(...)` changes the visible region set.
- Preserve the current right-aligned horizontal scroll behavior of the app-bar summary lane unless a tested replacement is introduced.
</implementation>

<stages>
Phase 1: Extend provider state and persistence for per-region pinned ids, then verify serialization, restore, corruption fallback, and pin/unpin state transitions with provider tests.
Phase 2: Build the visible-region app-bar view model and interactive map-route buttons, then verify zero-region, multi-region, selected, deselected, pinned, `All Peaks`, `None`, and constrained-width layout behavior with widget tests.
Phase 3: Update drawer rows to expose separate selection and pin actions and verify split-action behavior with widget tests.
Phase 4: Add robot-driven map journey coverage for select, pin, deselect, visible-area region switch, restart restore, and unpin flows.
</stages>

<illustrations>
Desired behavior:
- User selects `Abels` in Tasmania. `Abels` appears in the app bar with a pin affordance. The user pins it. Later they deselect `Abels`, but the button stays visible in an unselected state because it is pinned.
- User is in `All Peaks`. The `All Peaks` chip stays visible and pinned buttons still appear for the current normalized visible-region `Set<String>`. Clicking pinned `Abels` switches the app to `specificList` with `Abels` selected.
- User zooms or pans so Tasmania and New South Wales are both visible. The drawer and map app bar show the union of applicable lists across both regions.
- User moves to a view with zero visible regions. No peak-list buttons are shown for that view.
- User returns to Tasmania, sees `Abels` restored, then unpins it. If `Abels` is deselected, the button disappears immediately.

Counter-examples to avoid:
- Pinning a list automatically selecting it when the user only wanted persistent visibility.
- Deselecting a pinned list making the button disappear.
- Showing pins from two regions at once.
- Renaming existing keys like `peak-list-item-Alpha` without a compelling reason and breaking unrelated tests.
</illustrations>

<validation>
Follow vertical-slice TDD. Add one failing test at a time, implement the minimum production change to pass it, and refactor only after green.

Baseline automated coverage outcomes required:
- Unit/provider coverage for visible-region helper behavior, pin mutation methods, visible-region app-bar model derivation, persistence encode/decode, corrupt-payload fallback, and region-switch reconciliation.
- Widget coverage for drawer split tap targets, zero-region and multi-region list visibility, app-bar selected vs deselected states, `All Peaks` / `None` coexistence with pinned buttons, pin-to-unpin affordance swaps, transient-button removal on deselect, non-map-route suppression, and constrained-width app-bar layout.
- Robot-driven coverage for the critical user journey across the map shell.

Behavior-first TDD slice order:
1. Provider slice: pinning and unpinning ids for one region does not alter `selectedPeakListIds` and persists deterministic payloads.
2. Provider slice: visible-region derivation returns zero, one, or multiple normalized region keys from polygon-intersecting bounds and drives drawer/app-bar filtering.
3. Provider slice: bounds-based reconciliation skips pruning when zero visible regions apply and prunes against the union of applicable lists when multiple visible regions apply.
4. Provider slice: visible-region app-bar derivation merges pinned ids with selected ids, preserves `All Peaks` / `None` chips when required, prunes invalid ids, and swaps visible buttons when the visible region set changes.
5. Widget slice: a selected unpinned list appears in the app bar with a pin affordance and disappears when deselected.
6. Widget slice: a pinned list remains visible when deselected and swaps to an unpin affordance.
7. Widget slice: `All Peaks` and `None` remain visible alongside pinned buttons and tapping a pinned button exits those modes into `specificList`.
8. Widget slice: zero-region views show no peak-list buttons, while multi-region views show the union of applicable lists.
9. Widget slice: drawer rows expose independent selection and pin actions.
10. Robot slice: user selects a list, pins it, deselects it while it stays visible, switches visible-area regions, returns, and unpins it.

Required testability seams:
- Keep preference access behind the existing `mapPreferencesLoaderProvider` and SharedPreferences seam so tests can inject deterministic prefs.
- Keep the map-route app-bar row driven by a pure derived model that can be exercised in provider tests without pumping the whole app where practical.
- Allow tests to change visible bounds directly on notifier state or through an equivalent deterministic seam so bounds-based region-switch coverage does not depend on real pan gestures.
- Prefer the existing fake/in-memory repositories already used across provider, widget, and robot tests. Mock only true external boundaries if a fake is not practical.

Robot coverage requirements:
- Add or extend a map robot under `./test/robot/map/` with helpers for opening the peak-lists drawer, pinning from the drawer, toggling from the app bar, unpinning from the app bar, and forcing deterministic visible-bounds region changes.
- Cover at least this critical journey: select a region-valid list, observe a transient app-bar button, pin it, deselect it while it remains visible, switch to a multi-region visible view and confirm the union of applicable lists appears, switch to a zero-region view and confirm no peak-list buttons are shown, then return and confirm pinned state restores and unpin removal still works.
- Use stable app-owned `Key` selectors for robot interactions rather than relying on visible text for pin/unpin controls.

Selectors to define for new controls:
- drawer pin action: `Key('peak-list-pin-$peakListId')`
- map-route row root: `Key('peak-list-selection-summary')`
- app-bar button root: `Key('peak-list-app-bar-item-$peakListId')`
- app-bar toggle action: `Key('peak-list-app-bar-toggle-$peakListId')`
- app-bar pin action for transient buttons: `Key('peak-list-app-bar-pin-$peakListId')`
- app-bar unpin action for pinned buttons: `Key('peak-list-app-bar-unpin-$peakListId')`

Known testing risk to manage explicitly:
- The shared app-bar layout is already sensitive on constrained widths. Keep an assertion that the centered search trigger remains centered and that the right-aligned peak-list row does not overflow or clip important controls.
</validation>

<done_when>
- The map peak-lists drawer shows a separate pin control for region-valid specific peak lists using `assets/svg/pin.svg`.
- The shared map app bar shows interactive visible-region peak-list buttons with separate toggle and pin/unpin actions on the map route only.
- Multiple peak lists can be pinned per region.
- `All Peaks` and `None` remain visible when active, even if pinned buttons are also visible for the current normalized visible-region `Set<String>`.
- Pinned buttons remain visible when deselected, while unpinned deselected buttons disappear.
- Zero-region views show no peak-list buttons, while multi-region views show the union of applicable lists.
- Pinned state survives restart and safely ignores corrupt persisted pin payloads.
- Non-map routes do not display peak-list buttons, while drawer opening and centered map-route search layout remain passing.
- Provider, widget, and robot coverage for the declared slices passes.
</done_when>
