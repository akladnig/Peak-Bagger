<goal>
Replace the main map's widget-per-peak `MarkerLayer` implementation with a custom-painted peak rendering stack that can handle Tasmania-scale peak datasets and larger Italy/Slovenia-style datasets with materially less jank.

This work matters because the map screen is the app's primary exploration surface, and current peak rendering uses one Flutter widget subtree per visible peak plus optional label widgets. Users should be able to pan, zoom, hover, and inspect dense peak datasets smoothly while retaining the current meaning of climbed versus unclimbed peaks and the current peak-info feature semantics.
</goal>

<background>
Peak rendering currently lives in `./lib/screens/map_screen.dart` and `./lib/screens/map_screen_layers.dart`. The main map uses `flutter_map` and currently builds a `MarkerLayer` keyed `Key('peak-marker-layer')` whose markers come from `buildPeakMarkers(...)`. Each marker currently wraps either `assets/peak_marker.svg` or `assets/peak_marker_ticked.svg` in a widget subtree that may also render hover chrome and two outlined text labels.

The current implementation is expensive for dense datasets because it combines:
- one `Marker` widget per visible peak,
- one `SvgPicture` per peak in the hot rendering path,
- optional label widgets for name and elevation,
- whole-layer rebuilds when transient hover state changes.

Relevant existing behavior and seams:
- peak visibility and zoom gating are driven from `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, and `./lib/core/constants.dart`
- filtered peak data comes from `./lib/providers/peak_list_selection_provider.dart`
- hovered peak detection currently uses `./lib/services/peak_hover_detector.dart`
- climbed correlation state currently comes from `MapNotifier.correlatedPeakIds`
- peak mini-map and dashboard renderers still call `buildPeakMarkers(...)` from `./lib/screens/peak_lists_screen.dart` and `./lib/widgets/dashboard/latest_walk_card.dart`
- existing widget tests and robot tests depend on stable app-owned keys around the current peak marker layer and hover/label affordances

The requested end state is not a generic marker-cluster package drop-in. The implementation should deliver clustering behavior similar to Leaflet markercluster or `flutter_map_marker_cluster`, but integrated into a custom-painted peak layer that also replaces SVG marker rendering with raw canvas drawing on the main map. Treat Leaflet markercluster and `flutter_map_marker_cluster` as behavioral references for overlap-driven clustering, cluster expansion, and viewport culling rather than as the production rendering path.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/providers/map_provider.dart`
- `./lib/providers/peak_list_selection_provider.dart`
- `./lib/services/peak_hover_detector.dart`
- `./lib/core/constants.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./test/widget/tasmap_map_screen_test.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/**`
</background>

<user_flows>
Primary flow:
1. User opens the main map with a dense peak dataset enabled.
2. At low or medium zoom, or at any zoom where projected peak markers materially overlap in screen space, nearby peaks are shown as canvas-drawn clusters rather than thousands of individual markers.
3. User pans or zooms the map and the cluster or marker layer updates smoothly without obvious widget churn or SVG-related jank.
4. User taps or clicks a cluster and the map animates or fits to a zoom level where that cluster expands into smaller clusters or individual peaks.
5. At high enough zoom, individual peaks are rendered as canvas-drawn markers with climbed versus unclimbed styling preserved.
6. User hovers a peak on desktop or inspects peak info at the current feature toggle, and the relevant sparse overlay affordances appear without forcing the whole map to rebuild.

Alternative flows:
- Sparse dataset or sparse viewport: if few peaks are visible, clustering may disappear entirely and the layer should render only individual peaks.
- Peak info disabled: the user still gets markers or clusters, but no label overlay is rendered.
- Peak info enabled: the app preserves the current feature semantics while resolving label visibility through collision rules rather than rendering every visible label.
- Correlated peak state present: climbed or ticked peaks continue to render distinctly from unticked peaks when shown individually.

Error flows:
- If peak data has invalid or non-finite coordinates, those peaks should be skipped safely without breaking the rest of the layer.
- If cluster membership or projected screen positions become stale after camera or dataset changes, the layer must invalidate and rebuild its derived data deterministically before reuse.
- If a programmatic cluster expansion zoom target cannot be computed precisely, fall back to a safe bounded zoom-in behavior rather than doing nothing or crashing.
</user_flows>

<discovery>
Before implementation, confirm the current hot-path costs with profiling and code inspection.

Specifically verify:
1. Baseline frame cost and rebuild pressure for the current peak layer using a fixed dense-map scenario on the main map screen.
2. How many visible peaks and label widgets are typically present in the Tasmania-wide and Italy/Slovenia-style scenarios used for profiling.
3. Which current tests assert directly on `MarkerLayer`, `Marker`, peak-marker keys, hover keys, and label keys, so replacement selectors can be introduced deliberately rather than accidentally breaking coverage.
4. Which `flutter_map` layer extension point is the smallest correct fit for a custom-painted peak layer in this codebase.
5. Whether existing map movement seams already provide a clean way to trigger cluster zoom-to-expand animation or fit logic without introducing a second competing camera-control path.
6. Whether peak hover hit testing should remain screen-distance based with the current threshold from `PeakHoverDetector`, or whether the threshold should become a named constant in `./lib/core/constants.dart` shared by paint and hit-test logic.
7. Whether any new cluster-derived or viewport-derived state introduced by this work accidentally watches transient hover, cursor, or unrelated UI fields instead of only the peak, correlation, and camera inputs it actually needs.
</discovery>

<requirements>
**Functional:**
1. Replace the main map's peak `MarkerLayer` widget path with a custom peak layer that paints markers and clusters directly to a canvas.
2. Scope the first implementation to the main interactive map screen only. Do not migrate peak mini-maps, dashboard cards, or other secondary peak renderers in this task.
3. Render individual peak markers on the main map using raw canvas drawing rather than `SvgPicture`, preserving distinct visual states for climbed or ticked peaks versus unticked peaks.
4. Add clustering behavior on the main map that groups nearby visible peaks when their projected marker footprints overlap or fall within a small configurable screen-space clustering radius, and dissolves them into smaller clusters or individual peaks as screen-space separation increases.
5. Keep the current low-zoom hide rule: below `MapConstants.peakMinZoom`, the main map renders no peak layer. At or above `MapConstants.peakMinZoom`, visible peaks enter the overlap-driven clustering or individual-marker path.
6. Use a simple screen-space clustering strategy for the first implementation unless discovery proves it incorrect for the required map behavior. A grid- or radius-based clustering pass over viewport-visible projected peaks is the preferred first approach.
7. Draw clusters in the visual language of `./cluster.png`: a centered count with an outer ring that encodes the proportion of unticked peaks in the current unticked color and ticked peaks in the current ticked color. Cluster appearance may tier by size bucket, but must remain visually lightweight and fast to paint.
8. Support cluster tap or click behavior that zooms or fits the map to expand the tapped cluster, similar to Leaflet markercluster. This is the required first interaction; do not implement spiderfy or cluster bottom-sheet behavior in this task.
9. Treat cluster tap or click as a high-priority consumed navigation interaction. If a cluster is hit, suppress underlying peak, track, route, and selected-location click behavior for that event.
10. On cluster tap or click, clear transient peak hover state, close hovered peak popups, close pinned peak popups, and clear transient hovered track or hovered route affordances before performing the expansion camera change.
11. Cluster tap or click must not set `selectedLocation` and must not open a peak popup.
12. On desktop, clusters may change cursor or hit-test affordance, but they should not show special hover previews, labels, or tooltips in the first implementation.
13. Preserve the meaning of the current peak-info feature toggle on the main map, but replace the current all-visible-label path with a collision-based sparse overlay path for non-hovered individual peaks.
14. Preserve existing individual-peak hover affordances and peak-info popup semantics on the main map. Hovered peaks do not require marker labels because the hover popup is the primary information surface.
15. Render labels only for non-hovered individual peaks. Labels are not rendered for clusters in the first pass.
16. Resolve label visibility by projected screen-space collision rules rather than a simple zoom gate. Build candidate label bounds, sort candidates by screen `y` descending so lower-on-screen labels win first, accept a label only when it does not intersect any already accepted label or any other peak marker exclusion zone, and reject later conflicting labels.
17. Replace the current `MapConstants.peakInfoMinZoom`-gated all-label behavior on the main map with the collision-based label rule above. Mini-maps and other out-of-scope renderers may keep their current behavior.
18. Preserve the current unticked-before-ticked rendering and hit-test ordering intent unless a deliberate documented adjustment is required for correctness.
19. Continue to support deterministic hit testing for individual peaks on desktop hover and pointer interactions after the rendering path is moved to canvas.
20. Continue to support deterministic hit testing for clusters so tap-to-zoom behavior is stable and testable.
21. Ensure only viewport-relevant peaks participate in painting and cluster generation for a given frame.
22. Keep the main map's peak rendering integrated with existing filtered peak selection, climbed correlation state, and current map-state toggles.
23. Define one explicit derived-data contract for the custom layer that separates source peak data from derived viewport data such as projected screen points, visible peaks, cluster membership, cluster composition ratios, label candidates, and hit-test candidates.
24. Introduce app-owned stable keys or equivalent deterministic selectors for the new main-map peak layer, sparse label overlay, and any new cluster interaction target needed by widget or robot tests.

**Error Handling:**
25. If a peak record has invalid or non-finite coordinates, skip it safely and continue rendering the rest of the dataset.
26. If cluster expansion cannot produce a precise bounds fit, fall back to a bounded zoom increment centered on the cluster's representative point.
27. If derived viewport or cluster data is stale or invalid, rebuild it synchronously from source state before using it for paint or hit testing.
28. If too many labels are eligible for the collision pass, degrade by stopping once the accepted-label pass and a bounded candidate scan budget are complete rather than forcing layout for every visible peak.

**Edge Cases:**
29. Multiple peaks at identical or near-identical coordinates must remain interactable across clustered and de-clustered states without causing unstable flicker between cluster and individual rendering.
30. Rapid sequences of pan, zoom, hover, and cluster tap must not leave stale hover state, stale hit-test data, or clusters that no longer match the visible camera.
31. Very sparse viewports should avoid showing a cluster when a single individual marker would be clearer.
32. Very dense viewports should avoid immediately exploding into thousands of individual labels or markers at threshold boundaries in a way that recreates jank.
33. Cluster dissolve and individual marker reveal thresholds must be deterministic for a given zoom and viewport state.
34. Existing map interactions unrelated to peaks, including tracks, selected map overlays, and route layers, must continue to function correctly alongside the new peak layer.

**Validation:**
35. Add automated coverage for clustering decisions, cluster tap expansion behavior, viewport culling, hover hit testing, and sparse peak-info overlay behavior.
36. Keep baseline automated coverage across logic or state, widget behavior, and critical map interaction journeys.
37. Keep the critical map interaction lane testable with stable app-owned selectors rather than relying on implementation details of old `Marker` widgets.
</requirements>

<boundaries>
Edge cases:
- The first implementation applies only to the main map screen. Secondary mini-maps may keep existing widget markers and SVG assets for now.
- Cluster appearance should follow the ringed `./cluster.png` visual contract in the first pass. Do not broaden this task into richer aggregate behavior such as hover previews, spiderfy, or multi-metric cluster styling unless a later spec explicitly requests it.
- Peak labels must preserve current feature meaning but not current per-peak rendering shape. The accepted label rule for the main map is collision-based visibility for non-hovered individual peaks, with lower-on-screen labels winning.
- If the map is rotated or if `flutter_map` exposes non-trivial projection edge cases, correctness of placement and hit testing wins over micro-optimizations.

Error scenarios:
- If a custom-painted layer cannot reuse previously derived viewport data safely, it must recompute from source state rather than risk stale cluster or hit-test behavior.
- If cluster expansion animation cannot complete because the map controller is unavailable at that instant, no crash should occur; retry on the nearest safe seam or fall back to a synchronous state-driven zoom change.
- If label rendering risks dominating frame work, clamp the number of rendered labels and log or document the budgeted behavior rather than silently allowing worst-case unbounded layout.

Limits:
- Do not replace `flutter_map`.
- Do not add `flutter_map_marker_cluster` as the production rendering path for the main map. The desired outcome is a custom-painted layer with markercluster-like behavior, not another widget-heavy marker stack.
- Avoid new dependencies unless discovery proves a narrowly scoped dependency is required for a non-trivial spatial index or clustering utility. Default first pass to an in-repo implementation.
- Do not redesign the overall map UI, route structure, or peak data model.
- Do not migrate peak mini-maps or dashboard maps in this task; document them as follow-on work only.
</boundaries>

<implementation>
Deliver the smallest correct custom peak-layer architecture that scales to the datasets described in this session.

Expected output paths:
- Update `./lib/screens/map_screen.dart` to replace the current peak `MarkerLayer` integration with the new custom-painted peak layer and any associated sparse overlay wiring.
- Update `./lib/screens/map_screen_layers.dart` by removing or narrowing main-map-specific widget peak marker construction and adding any shared paint-layer helpers that belong there.
- Add new support code under `./lib/screens/` or `./lib/services/` for cluster computation, viewport peak projection, layer painting, and peak or cluster hit testing.
- Update `./lib/providers/map_provider.dart` only as needed to support stable peak or cluster interaction state without broadening rebuild scope.
- Update `./lib/core/constants.dart` with named constants for cluster thresholds, hover thresholds, label budgets, or zoom gates if they need to be shared across production and tests.
- Add focused tests under `./test/` covering logic, widget behavior, and robot journeys.

Implementation expectations:
1. Remove the main map's reliance on `buildPeakMarkers(...)` returning `Marker` widgets for dense peak rendering. If `buildPeakMarkers(...)` remains for mini-maps, document that it is no longer the main-map renderer.
2. Introduce a dedicated custom-painted main-map peak layer with one clear owner for source peak data, one clear owner for derived viewport data, and one clear owner for interaction or hit-test logic.
3. Prefer a layer design that keeps painting in one pass for clusters and one pass for individual markers, rather than building many child widgets.
4. Replace the current SVG marker art on the main map with raw canvas drawing using primitives such as circles, paths, strokes, and fills. Keep the visual language recognizably aligned with the current marker intent, but do not attempt pixel-identical SVG reproduction if that adds unnecessary complexity.
5. Paint individual peaks with styles that preserve current climbed versus unclimbed meaning. The exact canvas implementation may use shared `Paint`, `Path`, and text-painter resources cached at the layer or painter level.
6. Paint hover chrome for individual peaks in the sparse overlay or interaction-aware paint path so hovered-state changes do not rebuild the broader map subtree.
7. Use viewport culling before clustering or painting. The first pass must avoid iterating the full dataset for paint decisions more than necessary.
8. Default first-pass clustering to a screen-space algorithm derived from projected visible peak positions rather than a geographic tile-clustering system. The algorithm must be deterministic for a given camera and viewport size and should mirror the reference packages' use of a configurable pixel-radius clustering threshold.
9. Define one explicit cluster membership rule and one explicit cluster representative rule. Acceptable representatives include centroid-like projected center, first member, or highest-priority member, but the rule must be stable and documented in code and tests.
10. Define one explicit cluster dissolve contract: at `zoom < MapConstants.peakMinZoom`, peaks remain hidden; at `zoom >= MapConstants.peakMinZoom`, peaks cluster only when projected marker exclusion zones overlap or come within the configured clustering radius; otherwise they render individually.
11. On cluster tap or click, compute a target camera change that expands the cluster. Prefer fit-to-members or a bounded zoom-in based on member extents. The contract must avoid repeated no-op taps on a cluster that never expands.
12. Paint clusters in the style of `./cluster.png` using canvas primitives. Use a centered count and an outer ring split into ticked and unticked arcs whose lengths are proportional to the cluster's composition.
13. Keep cluster hover behavior minimal in the first pass. Cursor changes are acceptable; preview labels, spiderfy, and sheets are out of scope.
14. Preserve or replace existing stable keys deliberately. At minimum, provide deterministic selectors for the new peak layer root, the sparse peak-label overlay root, and any interactive cluster overlay target that tests need to exercise.
15. For the main map, explicitly retire test dependence on `MarkerLayer` type checks, `Marker` instances, and per-peak `peak-marker-hitbox-*` widget expectations. Replace those assertions with app-owned selectors and interaction-driven tests against the new custom layer.
16. Preserve `Key('map-interaction-region')` and `Key('peak-marker-layer')` as stable main-map selectors even if the latter no longer belongs to a `MarkerLayer` widget.
17. Preserve label keys such as `peak-marker-labels-*`, `peak-marker-name-*`, and `peak-marker-height-*` only for labels that are actually rendered by the collision pass. Preserve `peak-marker-hover-*` only if hover chrome remains exposed through a testable overlay widget.
18. Where deterministic cluster-specific widget selectors are needed, use app-owned selectors on the new cluster interaction surface rather than relying on internal widget-marker structure. Add cluster-specific keys only when interaction-driven testing through `map-interaction-region` is insufficient.
19. This selector migration applies to the main map only. Mini-maps and other out-of-scope peak renderers may keep their current marker-based test contracts until their later migration.
20. Do not let hover-only state changes rebuild the entire map-screen widget tree. Rebuild isolation should be explicit around the new peak layer or its interaction overlays.
21. Keep hit testing decoupled from widget markers. Introduce explicit peak and cluster hit-test candidates derived from the same viewport projection data used for paint.
22. Reuse the current `PeakHoverDetector` distance-based intent where practical, but adapt it to consume projected candidates from the new layer. If thresholds become shared with cluster hit testing or painter sizing, move them to named constants.
23. Keep the sparse peak-info overlay bounded by collision resolution rather than by an all-label render. Build candidate label bounds from visible non-hovered individual peaks, sort by descending screen `y`, accept only non-conflicting labels, and reject later conflicts.
24. The first pass may continue to use Flutter text layout for sparse labels, but it must not create a text widget subtree for every visible peak.
25. If canvas text for labels is considered, it must still preserve testability for visible label content and avoid making all label assertions screenshot-dependent.
26. Keep clustering and custom-painted marker work compatible with existing peak filtering, selected peak flows, and climbed correlation state.
27. Keep non-peak layers unchanged unless a narrow integration adjustment is required.
28. Do not introduce a package-level architectural rewrite or isolate-based rendering pipeline in the first pass.
29. A full scan of filtered peaks on camera changes is acceptable for the first pass if profiling remains acceptable after widget and SVG removal. Add spatial indexing or bucketed lookup only if profiling shows peak scanning remains a meaningful hotspot.
30. Define cache invalidation explicitly for derived viewport data. At minimum, invalidation must consider camera center, zoom, viewport size, filtered peak identity or revision, and climbed-correlation inputs that affect visuals.
31. Define which pieces of derived data are safe to cache across pointer moves and which must rebuild on camera changes.
32. Preserve the current visual stacking intent: the new peak layer must continue to render above track polylines unless a deliberate change is specified.
33. Keep the first pass scoped so it can be implemented and verified without also migrating `./lib/screens/peak_lists_screen.dart` or `./lib/widgets/dashboard/latest_walk_card.dart`.
34. Document follow-on migration work for mini-maps and dashboard maps, but do not implement it under this spec.

Avoid:
- Replacing one widget-heavy marker stack with another widget-heavy cluster package on the main map.
- Reproducing SVG complexity with overly intricate canvas paths that erase the performance win.
- Rendering text labels for every visible peak.
- Broad provider or screen refactors that are not needed to land the custom-painted main-map peak layer correctly.
</implementation>

<stages>
Phase 1: Measure and design the rendering contract.
- Profile the current dense-peak map path.
- Identify the exact main-map peak layer replacement seam.
- Define the overlap-driven cluster threshold, cluster ring composition rules, collision-based label policy, and test selectors.

Phase 2: Build the custom-painted individual marker path.
- Introduce canvas-based individual peak rendering.
- Move peak hover and hit-testing data onto projected candidate structures.
- Preserve climbed versus unclimbed visuals and basic hover behavior.

Phase 3: Add clustering and expansion behavior.
- Add screen-space clustering over viewport-visible peaks.
- Paint simple count-circle clusters.
- Implement deterministic cluster hit testing and tap-to-zoom expansion.

Phase 4: Reintroduce sparse peak-info overlays.
- Preserve current peak-info feature semantics with collision-based label rendering for non-hovered individual peaks.
- Keep label and hover affordances isolated from broad map rebuilds.

Phase 5: Validate and tune.
- Re-profile the dense-map scenario.
- Compare frame work, rebuild behavior, and interaction smoothness before and after.
- Fix regressions in hit testing, cluster expansion, and peak-info behavior.

Phase 6: Document follow-ons.
- Record mini-map and dashboard migration as explicit later work if the main-map renderer proves successful.
</stages>

<illustrations>
Desired:
- At Tasmania-wide zoom levels, the user sees a manageable number of ringed clusters rather than hundreds or thousands of widget markers, and clusters appear only where markers would materially overlap in screen space.
- Tapping a cluster zooms the map to a state where that cluster visibly breaks apart.
- At close zoom, individual peaks render crisply from canvas with climbed and unclimbed meaning intact, while non-hovered labels remain visible only when they do not collide with accepted labels or nearby markers.
- Hovering a peak updates only the narrow affordance path needed for hover and label presentation.

Undesired:
- The main map still builds one `Marker` widget per visible peak behind the scenes.
- Cluster rendering uses `flutter_map_marker_cluster` widgets on top of a still-widget-heavy per-marker path.
- The new renderer draws labels for every visible peak and reintroduces pan or zoom jank.
- A cluster tap repeatedly zooms without ever resolving into smaller clusters or individual peaks.
</illustrations>

<validation>
Implementation must follow behavior-first vertical-slice TDD where practical: add one failing test for one externally visible behavior, implement the smallest change to pass it, then refactor before the next slice.

Required behavior-first slices:
1. Individual canvas-rendered peaks appear on the main map when the peak layer is enabled and the map is at an individual-marker zoom state.
2. Clusters appear instead of individual peaks when projected marker exclusion zones overlap or fall within the configured clustering radius.
3. Tapping a cluster changes the camera so the tapped cluster expands.
4. Hovering an individual visible peak still updates hover affordances and peak-info presentation correctly.
5. Peak-info label rendering respects the collision-based visibility rule and current feature semantics.
6. Derived viewport data invalidates correctly when camera or filtered peaks change.

Required testability seams:
- A pure or narrowly scoped test seam for cluster computation from projected points.
- A deterministic seam for projecting or supplying visible peak candidates in tests without depending on live network tiles.
- Stable app-owned keys for the new peak-layer root and sparse overlay roots.
- A controllable seam for cluster expansion camera commands so widget or robot tests can assert the resulting visible state deterministically.

Required automated coverage split:
- Unit tests: cluster grouping rules, cluster representative rules, dissolve thresholds, label budgeting, viewport-data invalidation, and peak or cluster hit-testing logic.
- Widget tests: main map renders the new peak layer, toggles between clusters and individual peaks under controlled camera states, preserves peak-info behavior, and exposes stable selectors needed by tests without asserting `MarkerLayer` or `Marker` internals on the main map.
- Robot journey tests: a critical dense-map journey covers opening the map, reaching a cluster state, activating cluster expansion through app-owned selectors or `map-interaction-region`, and confirming that the map reaches an expanded peak state without regressing other map interactions.

Robot-testing expectations:
- Use app-owned `Key` selectors first.
- Add only the selectors needed for the declared dense-map journey.
- Keep the journey deterministic with repository or notifier fakes already used by this codebase.
- Explicitly report any residual risk if the robot lane cannot cover real performance characteristics and profiling remains the authority for jank reduction.

Profiling validation:
- Use one fixed dense-map scenario for before and after comparisons.
- Confirm a material reduction in frame work or rebuild pressure relative to the current widget-marker implementation.
- Confirm the new renderer does not introduce correctness regressions in hover, peak-info visibility, or cluster expansion.
</validation>

<done_when>
1. The main map no longer renders peaks through the current widget-based `MarkerLayer` path.
2. The main map renders canvas-drawn individual peaks and count-circle clusters with climbed versus unclimbed meaning preserved for individual markers.
3. Cluster tap or click reliably zooms to an expanded state.
4. Peak-info behavior remains available on the main map through a sparse overlay path that does not recreate per-peak widget rendering.
5. Automated coverage exists across clustering logic, widget behavior, and at least one robot-driven dense-map journey.
6. Profiling shows a material improvement over the current implementation in the agreed dense-map scenario.
7. Secondary mini-map and dashboard peak renderers remain unchanged and are explicitly documented as follow-on work, not accidental omissions.
</done_when>
