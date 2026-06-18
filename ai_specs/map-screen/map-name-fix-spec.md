<goal>
Fix the map-screen naming and grid UX when the current point is inside a supported app region but outside Tasmap sheet coverage.

This work matters because users currently see `Unknown` in the MGRS readout and peak popup even when the app already knows the broader region, and the grid FAB still advertises a map-grid flow in regions where only the MGRS grid is available. The map screen should describe what the user is actually looking at and keep the grid overlay useful at broader zoom levels.
</goal>

<background>
Project context:
- Flutter app using `flutter_map`, `flutter_riverpod`, `latlong2`, and `mgrs_dart`.
- The MGRS readout name is resolved from `@lib/screens/map_screen.dart` through `mapNameForPoint(...)` and `mapNameForMgrs(...)` in `@lib/providers/map_provider.dart` and displayed by `MapMgrsReadout` in `@lib/screens/map_screen_panels.dart`.
- Peak popup map naming is resolved separately in `@lib/services/peak_info_content_resolver.dart` and rendered in `@lib/screens/map_screen_panels.dart`.
- Region membership already exists through `@lib/services/region_manifest_catalog.dart`, backed by generated region polygons in `@lib/generated/region_manifest_catalog.g.dart`.
- The manifest-backed region catalog already exposes `mapSet`, and `@test/unit/region_manifest_catalog_test.dart` already verifies that Tasmania currently reports `['tasmap50k']` while sampled non-sheet-backed regions report `[]`.
- `mapSet` represents supported sheet-dataset identifiers, not an exhaustive mirror of visible basemap keys. The currently supported sheet dataset is the existing `Tasmap50k` ObjectBox entity in `@lib/models/tasmap50k.dart`.
- The grid FAB tooltip and state transitions live in `@lib/providers/map_provider.dart` and `@lib/widgets/map_action_rail.dart`.
- The current MGRS grid interval ladder is implemented in `@lib/services/map_ruler_scale.dart`, and the current grid geometry is built in `@lib/services/map_grid_geometry.dart` and rendered from `@lib/screens/map_screen_layers.dart`.

Files to examine:
- `@lib/providers/map_provider.dart`
- `@lib/screens/map_screen.dart`
- `@lib/screens/map_screen_panels.dart`
- `@lib/widgets/map_action_rail.dart`
- `@lib/models/tasmap50k.dart`
- `@lib/services/peak_info_content_resolver.dart`
- `@lib/services/region_manifest_catalog.dart`
- `@lib/services/map_ruler_scale.dart`
- `@lib/services/map_grid_geometry.dart`
- `@lib/screens/map_screen_layers.dart`
- `@test/unit/region_manifest_catalog_test.dart`
- `@test/widget/map_screen_peak_info_test.dart`
- `@test/widget/tasmap_display_mode_test.dart`
- `@test/widget/map_screen_layers_test.dart`
- `@test/services/map_ruler_scale_test.dart`
- `@test/services/map_grid_geometry_test.dart`
- `@test/robot/map/map_grid_and_ruler_journey_test.dart`
- `@test/robot/peaks/peak_info_journey_test.dart`
- `@test/robot/peaks/peak_info_robot.dart`

Relevant current behavior:
- `mapNameForMgrs(...)`, `mapNameForPoint(...)`, and `_resolvePeakMapName(...)` currently fall back to `Unknown` when no Tasmap sheet matches.
- Peak info currently hardcodes the popup label `Map:` even when no sheet name is available.
- The FAB currently assumes a sheet-backed three-state flow with `Show Map Grid`, `Show Map and MGRS Grid`, and `Hide Grids`.
- `MapMgrsGridInterval` currently supports only `1 km`, `10 km`, and `100 km`.
- The current geometry helpers support trimming grid lines away from border labels; this leaves parts of the visible viewport without drawn grid lines.
</background>

<user_flows>
Primary flow:
1. User pans or hovers in a supported region with no matching Tasmap sheet under the cursor.
2. The readout shows the region name instead of `Unknown`.
3. If the user opens a peak popup for a peak without a matching sheet, the popup shows `Region:` with the same resolved region label.
4. If the current viewport exposes no supported sheet-grid dataset, the grid FAB advertises MGRS-only behavior.
5. User toggles the grid and sees the MGRS grid fill the visible screen and step up through the new broader interval at low zoom.

Alternative flows:
- Tasmanian sheet-backed area: existing sheet-name behavior remains the default whenever a sheet match exists.
- Non-Tasmanian supported region such as `italy-nord-est`: humanized region naming is shown when no sheet match exists.
- User pans between sheet-backed and non-sheet-backed regions while grids are visible: the visible grid behavior adapts to current regional capability without crashing or leaving an empty overlay state.

Error flows:
- No matching sheet and no matching known region: preserve the safe `Unknown` fallback rather than inventing a label.
- Grid geometry or map projection failure: fail closed for that frame and keep the map interactive.
</user_flows>

<requirements>
**Functional:**
1. Replace the current `Unknown` fallback in the map readout and peak popup with a shared region fallback path that first attempts sheet resolution, then attempts region resolution, then falls back to `Unknown` only if neither is available.
2. Implement the region fallback through one shared app-owned formatter or resolver so `@lib/providers/map_provider.dart` and `@lib/services/peak_info_content_resolver.dart` do not duplicate region-name rules.
3. The shared formatter must derive labels from the existing region manifest data rather than introducing a second region registry.
4. Humanize region keys for display by default, for example `italy-nord-est` -> `Italy Nord Est`.
5. Support a small explicit alias layer for regions whose preferred label is not the direct humanized key, including `tasmania` -> `Tasmanian`.
6. Do not edit `@lib/generated/region_manifest_catalog.g.dart` by hand; prefer a handwritten formatter or helper adjacent to `@lib/services/region_manifest_catalog.dart` unless the existing generation pipeline already has a safe source-of-truth for display labels.
7. The MGRS readout in `MapMgrsReadout` must display the resolved region label when there is no matching sheet but there is a matching known region.
8. The peak info popup must show `Map:` when the displayed value is an actual sheet name and `Region:` when the displayed value comes from the region fallback.
9. If neither a sheet nor a region can be resolved for peak info, keep the existing safe fallback of `Map: Unknown` rather than showing `Region: Unknown` for unsupported geography.
10. Use the existing typed `mapSet` data from the manifest-backed region catalog as the source of truth for sheet-dataset capability.
11. Treat `mapSet` as a list of supported sheet-dataset identifiers. For this feature, capability is determined by whether the union of visible-region `mapSet` values is empty or not; do not reinterpret `mapSet` as a mirror of visible basemap keys.
12. Add a proper viewport-vs-region intersection helper in `@lib/services/region_manifest_catalog.dart` so the app can determine which regions intersect the current visible map bounds without relying on corner or center point sampling heuristics.
13. The region-detection seam must support multiple simultaneous visible regions and expose the union of visible-region `mapSet` values needed for grid capability decisions.
14. For the grid FAB, base copy and capability behavior on the visible-region `mapSet` union from the viewport-detection seam. Do not derive FAB behavior from transient cursor hover position.
15. In sheet-backed regions, preserve the existing three-state grid behavior:
   - hidden -> tooltip `Show Map Grid`
   - map-grid-only -> tooltip `Show Map and MGRS Grid`
   - map-grid-plus-MGRS -> tooltip `Hide Grids`
16. In regions without sheet-grid dataset support, change the visible grid contract to MGRS-only behavior:
   - hidden -> tooltip `Show MGRS Grid`
   - visible MGRS state -> tooltip `Hide MGRS Grid`
17. In non-sheet-backed regions, tapping the FAB from hidden must enter a visible MGRS-grid state directly without stopping on an empty map-grid-only state.
18. Preserve stored `gridVisibility`, but derive an effective visible/rendered state from `gridVisibility + visible-region mapSet capability` when the current viewport contains no supported sheet dataset.
19. If stored `gridVisibility == mapGridOnly` and the current viewport's visible-region `mapSet` union becomes empty, suppress sheet-grid rendering regardless of `selectedMap` and render/advertise the state as MGRS-visible for as long as the viewport remains non-sheet-backed; when any visible region again contributes a supported sheet dataset, the original stored state semantics resume without mutating persisted state.
20. Preserve the existing grid FAB key `grid-map-fab` and keep the state logic centralized in `@lib/providers/map_provider.dart`.
21. Peak info state must carry structured origin metadata such as `sheet`, `region`, or `unknown` in `PeakInfoContent` or an equivalent typed seam; do not infer `Map:` vs `Region:` from the final display string.
22. Extend `MapMgrsGridInterval` to add a `1000 km` interval as part of the existing interval ladder rather than as a separate overlay system.
23. Extend `mapMgrsGridIntervalForRulerMeters(...)` so the interval progression becomes:
   - `1 km` below the existing `10 km` threshold transition,
   - `10 km` from the existing `10 km` threshold up to the existing `100 km` threshold,
   - `100 km` up to a new configurable `1000 km` threshold,
   - `1000 km` at and above that new threshold.
24. Add the new `1000 km` threshold as a named constant in `@lib/core/constants.dart` rather than hard-coding it in the selection helper.
25. Unless stronger existing product rules are discovered during implementation, use the same decade-based progression as the current thresholds so the new switch occurs at `300 km` ruler distance.
26. Keep the interval selection synchronized with the existing ruler-driven grid selection path; do not introduce a second independent zoom heuristic for the `1000 km` level.
27. The MGRS grid must extend across the full visible map viewport for all supported intervals, including the `1 km` case.
28. Full-viewport coverage means the full map viewport bounds even if some grid lines pass beneath overlay chrome such as the action rail or readout widgets.
29. Do not shorten visible grid lines merely to create label spacing. If label overlap needs management, solve it through label placement, background treatment, or clipping rather than by leaving uncovered strips at the viewport edges.
30. Preserve the current behavior that `1 km` interval labels use two-digit easting and northing border labels.
31. Do not introduce equivalent border labels for `10 km`, `100 km`, or `1000 km` unless existing tests or implementation realities require a narrow compatibility adjustment.

**Error Handling:**
32. If sheet lookup throws or returns no match, continue to region fallback rather than immediately returning `Unknown`.
33. If region lookup also fails, return the existing safe `Unknown` fallback without crashing.
34. If grid geometry cannot be produced for the current frame, skip drawing the affected MGRS layer for that frame and keep the map interactive.

**Edge Cases:**
35. Tasmania must show `Tasmanian` as the fallback region label, not a raw or humanized `Tasmania` label.
36. Region fallback must work for both cursor-driven readouts and non-cursor readouts that derive from `gotoMgrs`, live camera centre, or current map centre.
37. Peaks with incomplete stored MGRS parts must still attempt point-based sheet and region resolution before falling back to `Unknown`.
38. The new `1000 km` interval must be reachable at broad zoom levels covered by the existing ruler step ladder and must not be blocked by the current `100 km` cap.
39. Existing sheet-name behavior in Tasmap-covered areas must remain unchanged when a direct sheet match exists.
40. A mixed-region viewport may expose more than one region at once; grid-capability decisions that depend on regional coverage must use the union of those visible-region `mapSet` results rather than assuming a single active region.

**Validation:**
41. Keep selectors key-first and app-owned; continue using existing keys such as `map-mgrs-readout`, `grid-map-fab`, and `map-zoom-readout`.
42. If additional assertions on grid presence are required for the new non-sheet-backed MGRS-only flow, add stable layer-level keys rather than relying on tooltip text alone.
</requirements>

<boundaries>
Edge cases:
- Supported region, no sheet match: show region fallback, not `Unknown`.
- Unsupported region, no sheet match: keep `Unknown` fallback.
- Transition from Tasmania to a non-sheet-backed region while the grid is already visible: keep the overlay useful and avoid a blank intermediate state.
- Very broad zoom: the interval ladder must advance to `1000 km` instead of staying capped at `100 km`.

Error scenarios:
- Malformed or unusable map bounds: do not paint incorrect grid geometry.
- Resolver mismatch between peak popup and map readout: prevent this by routing both through the same fallback rules.

Limits:
- No new package dependencies.
- Do not hand-edit generated region manifest code.
- Do not change unrelated map-selection, basemap-selection, or peak-popup layout behavior beyond what is needed for the label/value changes.
</boundaries>

<implementation>
Modify these files:
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/services/peak_info_content_resolver.dart`
- `./lib/services/region_manifest_catalog.dart`
- `./lib/services/map_ruler_scale.dart`
- `./lib/services/map_grid_geometry.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/core/constants.dart`

Expected implementation shape:
- Introduce one shared resolver that can return both the display string and whether the value represents a sheet name, a region fallback, or an unresolved unknown. Keep this resolver small and reuse it from both the readout path and the peak popup path.
- Carry the resolver origin through `PeakInfoContent` or an equivalent typed state seam so the popup label is driven by structured data, not by string inspection.
- Put region-key humanization and alias handling in a small handwritten helper near the region manifest service so future region additions have one obvious place to update.
- Add a small viewport-region detection seam in `@lib/services/region_manifest_catalog.dart` that accepts visible bounds, resolves all intersecting manifest regions, and exposes the visible-region `mapSet` union needed for grid capability decisions.
- Use the existing `mapSet` data as supported sheet-dataset identifiers. Current behavior should continue treating Tasmania as sheet-backed because its visible-region `mapSet` union includes `tasmap50k`, while other currently supported regions remain MGRS-only unless additional sheet datasets are introduced later.
- Keep grid state changes minimal. Prefer adapting the existing visibility model to support the non-sheet-backed MGRS-only toggle path rather than introducing an entirely separate grid subsystem.
- In viewports whose visible-region `mapSet` union is empty, keep stored `gridVisibility` stable, suppress selected-map sheet rendering, and derive effective render/tooltip behavior from the MGRS-only capability so returning to a sheet-backed viewport restores the prior sheet-grid semantics automatically.
- Extend the existing interval enum and threshold helper for `1000 km` rather than adding special-case rendering code outside `map_ruler_scale.dart`.
- Update `buildVisibleMgrsGridGeometry(...)` and any supporting geometry helpers so visible lines reach the screen bounds; treat label clearance as a label-rendering problem, not a line-geometry truncation rule.

What to avoid:
- Do not duplicate region fallback logic in both the map provider and peak info resolver.
- Do not infer “maps available” from the existence of global basemaps.
- Do not leave the FAB in a state where the tooltip advertises MGRS visibility but no useful grid is painted.
- Do not preserve the old `100 km` cap if it prevents the requested `1000 km` grid level from appearing.
</implementation>

<stages>
Phase 1: Shared naming fallback
- Add the shared sheet-or-region resolver and region display formatter.
- Switch the MGRS readout and peak popup to use it.
- Verify Tasmania aliasing and non-Tasmanian humanized keys.

Phase 2: Region-aware grid control
- Add derived sheet-grid capability for the current viewport.
- Add viewport-based visible-region detection and `mapSet`-union capability resolution.
- Update the FAB tooltip and toggle contract for sheet-backed versus non-sheet-backed regions.
- Verify region transitions do not expose a blank or misleading grid state.

Phase 3: 1000 km interval and full-viewport grid geometry
- Extend the interval ladder and add the new configurable threshold.
- Update geometry so MGRS lines fill the visible viewport.
- Verify low-zoom interval selection and visible grid coverage.
</stages>

<validation>
Baseline automated coverage is required across logic, UI behavior, and critical user journeys.

TDD expectations:
- Implement one vertical slice at a time: shared fallback naming first, then region-aware FAB behavior, then the `1000 km` interval and full-viewport geometry.
- For each slice, start with one failing public-behavior test, implement the minimal code to pass it, then refactor.
- Prefer fakes and pure helpers over mocks; only mock true external boundaries.

Required testability seams:
- The shared sheet-or-region resolver must be callable from unit tests without a widget harness.
- The region display formatter must be deterministic and unit-testable.
- The viewport-vs-region intersection seam must be callable from unit tests and must accept deterministic visible-bounds inputs so multi-region unions can be verified without a widget harness.
- `mapMgrsGridIntervalForRulerMeters(...)` and geometry builders must remain pure so interval selection and viewport coverage can be tested without rendering widgets.

Required test split:
- Unit tests for logic/business rules:
  - viewport-vs-region intersection and visible-region `mapSet`-union capability detection, including mixed-region viewports;
  - region-key humanization and aliasing, including `tasmania` -> `Tasmanian`;
  - shared fallback resolution order: sheet first, region second, `Unknown` last;
  - peak popup label-kind resolution (`Map:` vs `Region:`);
  - grid interval selection across `1 km`, `10 km`, `100 km`, and `1000 km`, including threshold-boundary assertions;
  - geometry behavior proving visible grid lines now reach the viewport edges instead of being truncated for label clearance.
- Widget tests for screen-level behavior:
  - MGRS readout shows region fallback instead of `Unknown` in a supported non-sheet-backed region;
  - peak popup shows `Region:` when using a region fallback and retains `Map:` when using a real sheet name;
  - grid FAB tooltip copy in sheet-backed and non-sheet-backed scenarios;
  - layer or geometry-derived assertions proving the MGRS grid remains visible across the full screen area.
- Robot-driven journey tests for critical happy paths:
  - grid FAB journey in a non-sheet-backed region toggles `Show MGRS Grid` -> `Hide MGRS Grid` -> `Show MGRS Grid`;
  - peak info journey for a peak without sheet coverage shows the region fallback label/value consistently.

Expected test files to add or update:
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/tasmap_display_mode_test.dart`
- `./test/widget/map_screen_layers_test.dart`
- `./test/services/map_ruler_scale_test.dart`
- `./test/services/map_grid_geometry_test.dart`
- `./test/unit/region_manifest_catalog_test.dart`
- `./test/unit/visible_region_intersection_test.dart`
- add a focused unit/service test for the shared fallback resolver if it does not fit cleanly in the existing region catalog test file
- `./test/robot/map/map_grid_and_ruler_journey_test.dart`
- `./test/robot/peaks/peak_info_journey_test.dart`
- `./test/robot/peaks/peak_info_robot.dart`

Robot coverage details:
- Keep robot selectors key-first and app-owned.
- Reuse the existing robot harnesses instead of introducing a second map-screen test harness.
- If asserting exact rendered line counts is brittle under `flutter_map`, cover exact interval selection and viewport-edge geometry in unit tests and reserve widget/robot tests for visible state, labels, and tooltip behavior.
</validation>

<done_when>
1. `./ai_specs/map-screen/map-name-fix-spec.md` is specific enough to implement without further product clarification.
2. The MGRS readout no longer shows `Unknown` for supported regions that lack sheet coverage and instead shows the correct region label.
3. Peak popups display `Region:` with the correct region fallback when no sheet name is available, while still displaying `Map:` for real sheet matches.
4. In non-sheet-backed regions, the grid FAB behaves as an MGRS-only toggle with `Show MGRS Grid` and `Hide MGRS Grid` copy.
5. In sheet-backed regions, the existing three-state sheet-grid plus MGRS-grid behavior remains intact.
6. The MGRS grid interval ladder includes `1000 km` and reaches it at broad zoom levels through the existing ruler-driven selection path.
7. The visible MGRS grid fills the viewable map screen instead of stopping short to make room for labels.
8. Automated coverage exists for the shared fallback logic, the peak-popup/readout UI, the grid tooltip/state behavior, and the new `1000 km` interval and full-viewport geometry behavior.
</done_when>
