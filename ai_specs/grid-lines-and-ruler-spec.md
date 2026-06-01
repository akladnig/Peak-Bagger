<goal>
Add a two-phase map UI enhancement that makes grid context and distance estimation available directly on the main map screen.

Phase 1 adds a three-state grid control that preserves the current Tasmap map-grid behavior while layering an optional distance grid on top.
Phase 2 replaces the current zoom readout chip with a distance ruler that remains readable across the existing zoom range.

This work matters because map users need a fast way to understand both map-sheet boundaries and approximate on-screen distances without opening other tools or mentally translating zoom values.
</goal>

<background>
Project context:
- Flutter app using `flutter_map`, `flutter_riverpod`, `latlong2`, and `mgrs_dart`.
- The current grid FAB lives in `@lib/widgets/map_action_rail.dart` and calls `toggleMapOverlay()` in `@lib/providers/map_provider.dart`.
- Tasmap map-grid rendering currently depends on `TasmapDisplayMode` in `@lib/providers/map_provider.dart` and is painted in `@lib/screens/map_screen.dart` through helpers in `@lib/screens/map_screen_layers.dart` and `@lib/widgets/tasmap_outline_layer.dart`.
- The current bottom-left zoom chip is `MapZoomReadout` in `@lib/screens/map_screen_panels.dart` and is positioned from `@lib/screens/map_screen.dart`.

Files to examine:
- `@lib/providers/map_provider.dart`
- `@lib/widgets/map_action_rail.dart`
- `@lib/screens/map_screen.dart`
- `@lib/screens/map_screen_layers.dart`
- `@lib/screens/map_screen_panels.dart`
- `@lib/widgets/tasmap_outline_layer.dart`
- `@lib/core/constants.dart`
- `@lib/theme.dart`
- `@test/widget/tasmap_display_mode_test.dart`
- `@test/widget/map_screen_layers_test.dart`
- `@test/robot/map/map_camera_journey_test.dart`
- `@test/robot/map/map_route_robot.dart`
- `@test/harness/test_tasmap_map_notifier.dart`

Relevant current behavior to preserve:
- When a map is selected, the current app can show the selected map outline/label by setting `TasmapDisplayMode.selectedMap`.
- When no map is selected, the current app can show the all-sheets Tasmap overlay by using `TasmapDisplayMode.overlay`.
- Selecting a map through map lookup currently forces `TasmapDisplayMode.selectedMap`; the new implementation must not force grids visible when the user has chosen the hidden-grid state.
</background>

<user_flows>
Primary flow:
1. User opens the map screen with no grids visible.
2. User taps the grid FAB once.
3. The app shows the existing map-grid behavior only.
4. The FAB tooltip changes to `Show Map and 1 km Grid`.
5. User taps the FAB again.
6. The app keeps the map grid visible and adds the active distance grid.
7. The FAB tooltip changes to `Hide Grids`.
8. User taps the FAB a third time.
9. Both grids are hidden and the tooltip returns to `Show Map Grid`.

Alternative flows:
- Selected map present: the first visible grid state uses the current selected-map outline/label behavior instead of the all-sheets overlay.
- No selected map present: the first visible grid state uses the current all-sheets Tasmap overlay behavior.
- User changes selected map while grids are visible: the map-grid layer updates to reflect the same current semantics without resetting the FAB cycle.
- User pans or zooms while the distance grid is visible: the grid recomputes to the new visible viewport, remains aligned to the active MGRS interval, and switches intervals in sync with the ruler thresholds.

Error flows:
- Camera size/projection not ready: do not render the distance grid or ruler until the camera can provide stable bounds/screen conversions.
- Grid/ruler calculation failure: fail closed for that frame, keep the map interactive, and avoid crashes or stale painted geometry.
</user_flows>

<requirements>
**Functional:**
1. Add an explicit grid visibility state with exactly these values and meanings:
   - `hidden`: no Tasmap grid and no distance grid are rendered;
   - `mapGridOnly`: only the Tasmap map grid is rendered;
   - `mapGridAndDistanceGrid`: the Tasmap map grid and the active distance grid are both rendered.
2. Keep map-grid kind as a derived rule, not separate mutable state, with exactly these meanings:
   - `selectedMap`: render the currently selected map outline/label behavior already used today;
   - `overlay`: render the all-sheets Tasmap overlay behavior already used today.
3. Preserve the current Tasmap map-grid meaning for the first visible state:
   - if `selectedMap != null`, show the selected map outline/label behavior already used today;
   - otherwise show the all-sheets Tasmap overlay behavior already used today.
4. Decouple grid visibility from map selection so map search or map selection can continue setting `selectedMap`, but must not force any grid visible when the user is in the hidden-grid state.
5. The transition contract must be implemented exactly as follows:
   - FAB tap from `hidden` -> `mapGridOnly`
   - FAB tap from `mapGridOnly` -> `mapGridAndDistanceGrid`
   - FAB tap from `mapGridAndDistanceGrid` -> `hidden`
   - `selectMap(...)` and map-name parsing may update `selectedMap` and selected-map focus state, but must not change `gridVisibility`
   - when `gridVisibility != hidden` and `selectedMap` becomes non-null, map-grid kind resolves to `selectedMap`
   - when `gridVisibility != hidden` and `selectedMap` becomes null, map-grid kind resolves to `overlay`
6. Keep the existing FAB key `grid-map-fab` and implement tooltip text exactly as follows:
   - hidden state: `Show Map Grid`
   - map-grid-only state: `Show Map and MGRS Grid`
   - map-grid-plus-distance-grid state: `Hide Grids`
7. Add `MapConstants.mapGridBorderWidth = 2` and use it for existing Tasmap map-grid borders in `@lib/screens/map_screen_layers.dart` and `@lib/widgets/tasmap_outline_layer.dart`.
8. Add `MapConstants.mapMgrsGridBorderWidth = 1` and use it for distance-grid lines unless a later visual pass intentionally introduces separate widths for larger intervals.
9. Define a shared theme color token named `mapGridColour` in `@lib/theme.dart` as a top-level shared color constant using the current `Colors.blue` visual value, and replace existing hard-coded map-grid border color usage in map-grid-related files with that token.
10. Render a ruler-linked distance grid across the current visible viewport using MGRS easting and northing intervals, with the interval chosen from these bands:
   - use a `1 km` grid while the current ruler value is below `3 km`;
   - switch to a `10 km` grid when the current ruler value is `3 km` or greater and below `30 km`;
   - switch to a `100 km` grid when the current ruler value is `30 km` or greater.
11. Store the grid-switch thresholds in `@lib/core/constants.dart` as adjustable numeric constants rather than hard-coding them in rendering logic. At minimum, define numeric constants for the `3 km` and `30 km` switch points so they can be tuned later.
12. When the active distance grid interval is `1 km`, display 2-digit MGRS border labels for the corresponding visible 1 km grid lines.
13. Vertical 1 km grid lines must show the 2-digit easting value only on the top and bottom borders of the visible map.
14. Horizontal 1 km grid lines must show the 2-digit northing value only on the left and right borders of the visible map.
15. Render those 1 km-grid labels on the visible-map border so they do not sit on top of the interior grid lines.
16. Do not stack digits in the border labels and do not combine easting and northing into a single label.
17. Do not display those 1 km MGRS border labels for the `10 km` or `100 km` grid intervals.
18. Ensure the active distance grid remains geographically aligned while the user pans and zooms; line placement must be derived from map position, not from a fixed screen-space pattern.
19. Phase 1 must include the non-UI ruler-scale helper and threshold logic needed to choose the active distance-grid interval, but must not yet replace the visible bottom-left zoom readout.
20. Phase 2 must replace the current `MapZoomReadout` box with a ruler/readout widget in the same bottom-left map position, reusing the scale helper introduced in Phase 1.
21. The replacement ruler widget must preserve the existing container key `map-zoom-readout` so current tests and readout lookups keep working, and may add additional inner keys only if finer-grained assertions are needed.
22. The replacement ruler widget must preserve the current visibility behavior of `MapZoomReadout` and remain hidden in the same route/track-info states where the current readout is not shown.
23. The ruler must show a distance label from `1 m` through `100 km` and must use a `1, 2, 3, 5` stepping sequence for chosen ruler values, for example `1 m`, `2 m`, `3 m`, `5 m`, `10 m`, `20 m`, `30 m`, `50 m`, `100 m`, continuing upward until `100 km`.
24. The ruler selection rule must be deterministic:
   - compute meters-per-pixel from the current zoom and map-center latitude;
   - evaluate supported ruler steps from `1 m` through `100 km`;
   - choose the largest step whose horizontal bar width stays within a target usable width band of `96` to `160` logical pixels;
   - if no step fits that band, clamp to the closest supported step by width.
25. The active distance-grid interval must be derived from the current ruler value using the configurable threshold constants, so ruler changes and grid changes stay in sync.
26. The ruler box width must be derived from the selected ruler bar width plus fixed shared padding and a reserved trailing area wide enough to keep the right-aligned zoom text readable at all supported zoom values.
27. The zoom text must remain visible in the ruler box and be right-aligned within that box.
28. Move all ruler and grid-related styling values that are likely to be reused or tuned into `@lib/core/constants.dart` and `@lib/theme.dart` rather than leaving new magic numbers in widget build methods.

**Error Handling:**
29. If the visible bounds cannot be converted into usable grid geometry or usable border-label placements for the current frame, skip painting the affected distance-grid labels for that frame instead of painting incorrect values or overlapping the map interior.
30. If ruler scale calculation cannot produce a valid width within the supported range, clamp to the nearest supported ruler value and keep rendering the zoom text.
31. Do not let grid/ruler calculations throw uncaught exceptions during camera motion, first build, or widget tests with incomplete map camera state.

**Edge Cases:**
32. The active distance-grid interval must switch from `1 km` to `10 km` when the ruler reaches the configurable `3 km` threshold, and from `10 km` to `100 km` when the ruler reaches the configurable `30 km` threshold.
33. If the viewport crosses multiple Tasmap sheets, the active distance grid must still be based on geographic/MGRS intervals across the viewport rather than restarting per sheet.
34. When the active interval is `1 km`, border labels must stay readable at the visible-map edge and must not be painted across the interior grid lines.
35. If a selected map is cleared while the map-grid-only state is active, the first visible state must gracefully fall back to the all-sheets overlay behavior.
36. The ruler must continue updating during live camera movement without visibly lagging behind the current zoom level.

**Validation:**
37. Add stable keys for any new test-targeted UI that needs explicit lookup, including any new ruler sub-elements and, if needed, the distance-grid layer.
38. Keep selectors app-owned and key-first; do not rely on text matching alone for critical journey verification.
</requirements>

<boundaries>
Edge cases:
- Hidden-grid state with selected map present: selected map metadata may remain selected, but no map-grid overlay should render until the FAB enables it.
- First frame after screen load: if `flutter_map` camera dimensions are still impossible/uninitialized, render neither the distance grid nor an invalid ruler width.
- Rapid pan/zoom input: repeated camera updates must not accumulate stale grid lines or stale ruler values between frames.

Error scenarios:
- Invalid grid geometry conversion: log only if consistent with existing project patterns, otherwise silently fail closed for the affected frame.
- Unsupported ruler width after clamping: show the nearest supported ruler step instead of removing the entire readout.

Limits:
- Supported ruler labels must not exceed `100 km` or go below `1 m`.
- New behavior must not add package dependencies.
- Avoid introducing a separate persistent preference unless the existing map state persistence already has a clear place for the new grid visibility state.
</boundaries>

<implementation>
Modify these files:
- `./lib/providers/map_provider.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/widgets/tasmap_outline_layer.dart`
- `./lib/core/constants.dart`
- `./lib/theme.dart`

Add these pure helper files so grid and ruler math can be tested deterministically without depending on widget rendering:
- `./lib/services/map_grid_geometry.dart`
- `./lib/services/map_ruler_scale.dart`

Implementation guidance:
- Keep the existing `TasmapDisplayMode` semantics for selected-map vs overlay resolution, but add a separate grid-visibility concept that decides whether the Tasmap grid is hidden, shown alone, or shown together with the active distance grid.
- Derive map-grid kind directly from current map context rather than storing it as separate mutable state: use `selectedMap` when present, otherwise fall back to overlay.
- Update any existing code paths that currently force `TasmapDisplayMode.selectedMap` on map selection so they preserve selected-map context without overriding the hidden-grid choice.
- Implement the FAB cycle and map-selection behavior using the explicit transition contract in requirement 5 rather than inferring behavior ad hoc from current `TasmapDisplayMode` values.
- Build the active distance grid as derived geometry from the current visible viewport and camera state. Prefer pure helpers that accept visible bounds, the selected grid interval, MGRS/geographic conversion inputs, and return render-ready line definitions.
- For the `1 km` interval, generate companion border-label data for the visible grid lines so the UI can render 2-digit easting labels on the top and bottom borders and 2-digit northing labels on the left and right borders without placing text over the interior grid.
- Keep new render helpers small and composable. Avoid embedding complex grid math directly inside the `MapScreen` widget tree.
- Replace existing hard-coded grid stroke widths and `Colors.blue` usages only where they represent Tasmap map-grid visuals. Do not refactor unrelated blue borders as part of this work.
- Implement the ruler as a dedicated widget replacing `MapZoomReadout`, with scale selection delegated to a pure helper that computes meters-per-pixel from zoom and map center latitude, then chooses the best `1, 2, 3, 5` ruler step within the required `96` to `160` logical-pixel usable width band.
- Derive the displayed grid interval from the chosen ruler value so the map switches between `1 km`, `10 km`, and `100 km` grids at the configurable threshold constants rather than from an independent zoom heuristic.
- Preserve `map-zoom-readout` as the outer ruler key and only add new inner keys when the existing key is insufficient for targeted assertions.
- Preserve the current route/track-info visibility conditions for the readout when swapping `MapZoomReadout` for the ruler widget.
- Preserve the current visual placement of the zoom readout at the bottom-left of the map unless the existing layout requires a small adjustment to fit the ruler width.
- Use the sample image at `@ai_specs/ruler.png` as the visual reference for the left-aligned distance label, horizontal rule, and right-aligned zoom text.

What to avoid:
- Do not overload `TasmapDisplayMode` with both map-grid meaning and 1 km visibility if that makes selected-map behavior ambiguous.
- Do not hard-code ruler widths per zoom level.
- Do not add an independent zoom heuristic for grid switching; grid interval changes must be driven by the ruler thresholds defined in `constants.dart`.
- Do not use screen-space repeating stripes or pixels-only spacing for the distance grid; placement must follow map coordinates.
</implementation>

<stages>
Phase 1: Grid lines
- Introduce the new three-state grid visibility model.
- Wire the FAB tooltip/state machine to `Show Map Grid`, `Show Map and MGRS Grid`, and `Hide Grids`.
- Centralize map-grid color and width constants.
- Render the existing Tasmap map grid using shared constants/theme tokens.
- Add the non-UI ruler-scale helper and threshold logic needed for distance-grid interval selection.
- Add viewport-based distance-grid rendering aligned to MGRS intervals and switching between `1 km`, `10 km`, and `100 km` based on configurable ruler thresholds.
- Add 1 km-only border-label rendering with easting labels on the top and bottom borders and northing labels on the left and right borders.
- Verify Phase 1 completely before beginning Phase 2.

Phase 2: Distance ruler
- Replace the current zoom chip with a ruler widget in the same map corner.
- Add pure ruler scale logic for supported distance steps and dynamic width selection.
- Right-align zoom text inside the ruler box.
- Move all new ruler styling tokens into shared constants/theme files.
- Verify Phase 2 only after Phase 1 coverage remains green.
</stages>

<validation>
Baseline automated coverage is required across logic/business rules, UI behavior, and critical user journeys.

TDD expectations:
- Implement in vertical slices, one failing test at a time.
- Start with the smallest public behavior that proves each stage works before broadening coverage.
- Red -> green -> refactor per slice; do not batch all tests before implementation.
- Prefer fakes or pure helper inputs over mocks except at true external boundaries.

Required testability seams:
- `./lib/services/map_grid_geometry.dart` must expose pure geometry-building APIs that can be unit tested with deterministic bounds/input coordinates.
- `./lib/services/map_ruler_scale.dart` must expose pure ruler-step selection and width calculation APIs that can be unit tested independently from widgets.
- The ruler widget and FAB must have stable keys for widget/robot coverage.

Required test split:
- Unit tests for business/state logic:
  - grid visibility state transitions;
  - selected-map context preservation when grids are hidden or shown;
  - ruler step selection across representative zoom/latitude inputs;
  - active distance-grid interval selection for ruler values below, at, and above the configurable `3 km` and `30 km` thresholds;
  - `1 km` border-label value selection, border-side assignment, and suppression for `10 km` and `100 km` intervals;
  - valid-width clamping when no ruler step fits exactly within the target width band.
- Widget tests for screen-level behavior:
  - FAB tooltip text changes across the three states;
  - selected-map vs overlay fallback behavior;
  - ruler widget layout includes distance label, rule, and right-aligned zoom text;
  - map-grid rendering helpers use shared color/width tokens and switch intervals in sync with the ruler value;
  - `1 km` border labels render at the correct map edges with 2-digit easting-only and northing-only values and are absent for `10 km` and `100 km` intervals.
- Robot-driven journey tests for the critical happy path:
  - user opens the map screen, taps the grid FAB through all three states, and sees the correct tooltip/readout state changes without breaking existing map interactions.

Expected test files to add or update:
- `./test/widget/tasmap_display_mode_test.dart`
- `./test/widget/map_screen_layers_test.dart`
- `./test/widget/map_screen_ruler_test.dart`
- `./test/services/map_grid_geometry_test.dart`
- `./test/services/map_ruler_scale_test.dart`
- `./test/robot/map/map_grid_robot.dart`
- `./test/robot/map/map_grid_and_ruler_journey_test.dart`

Robot coverage details:
- Use app-owned `Key` selectors such as `grid-map-fab`, the preserved `map-zoom-readout` key, and any new visible grid-layer keys if widget lookup needs them.
- Keep the journey deterministic by driving camera/setup through a stable test harness rather than depending on asynchronous live tiles or unpredictable map loading.
- Explicitly report any residual risk if verifying exact painted line counts in widget tests is impractical due to `flutter_map` internals; in that case, cover interval selection and geometry counts in unit tests and visible state transitions in widget/robot tests.
</validation>

<done_when>
1. `./ai_specs/grid-lines-and-ruler-spec.md` can be implemented without further product-level clarification.
2. The grid FAB cycles exactly through hidden, map-grid-only, and map-grid-plus-distance-grid states with the specified tooltip text.
3. Selecting a map no longer forces a visible grid when the user has chosen the hidden-grid state.
4. Existing Tasmap outline rendering uses shared map-grid theme/constants tokens instead of hard-coded `Colors.blue` and width literals.
5. A distance grid can be shown across the visible viewport, stays aligned while panning/zooming, switches between `1 km`, `10 km`, and `100 km` intervals in sync with the configurable ruler thresholds, and shows `10 km`/`1 km` MGRS border labels only for the `1 km` interval.
6. The bottom-left zoom chip is replaced by a ruler that preserves the `map-zoom-readout` key, supports `1 m` through `100 km`, uses `1, 2, 3, 5` stepping, and keeps zoom text right-aligned.
7. Automated coverage exists for logic, screen behavior, and the critical grid-toggle journey, with any justified residual risks documented.
8. Phase 1 tests are green before Phase 2 implementation begins, and the full suite relevant to this feature is green at completion.
</done_when>
