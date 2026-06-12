## Overview

Main-map peak renderer rewrite. Custom-painted peaks + overlap-driven clusters; keep current popup semantics, move labels to collision overlay.

**Spec**: `ai_specs/map-screen/peak-canvas-clustering-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `widgets/`, `services/`, `test/robot/`
- **State management**: Riverpod `NotifierProvider`; `MapScreen` owns `MapController`, pointer flow, popup orchestration
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/services/peak_hover_detector.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/tasmap_map_screen_test.dart`, `test/robot/peaks/peak_info_robot.dart`
- **Assumptions/Gaps**: main map only; mini-maps stay on `buildPeakMarkers(...)`; custom peak layer likely new `flutter_map` child + sparse overlay in `MapScreen`; cluster tap should reuse existing controller move/fit seams, not invent a second camera owner

## Plan

### Phase 1: Vertical Slice Cluster Layer

- **Goal**: prove custom layer, overlap clustering, consumed cluster tap
- [x] `lib/screens/map_screen.dart` - swap main-map peak `MarkerLayer` for new peak-rendering seam; preserve `Key('peak-marker-layer')`; route cluster hit before peak/track/route/location click path
- [x] `lib/screens/map_screen_peak_layer.dart` - add custom-painted peak layer widget/painter shell; expose projected hit-test surface and stable root selectors
- [x] `lib/services/peak_cluster_engine.dart` - add screen-space clustering from projected visible peaks; overlap/radius rule; cluster representative + composition counts
- [x] `lib/core/constants.dart` - add named cluster radius, marker exclusion sizing, cluster padding constants; keep `peakMinZoom` hide rule
- [x] `test/widget/tasmap_map_screen_test.dart` - replace main-map `MarkerLayer` assumptions with layer-presence and cluster-expansion assertions
- [x] TDD: at `zoom < MapConstants.peakMinZoom`, no main-map peak layer visuals; at `zoom >= MapConstants.peakMinZoom`, overlapping peaks yield one cluster, then implement
- [x] TDD: cluster tap is consumed, clears popup/hover state, does not set `selectedLocation`, and triggers camera expansion, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Individual Peaks And Hover Path

- **Goal**: individual canvas peaks replace SVG markers without popup regressions
- [x] `lib/screens/map_screen_peak_layer.dart` - paint individual ticked/unticked peaks, preserve unticked-before-ticked paint order, add optional hover chrome seam
- [x] `lib/services/peak_hit_test.dart` - derive peak + cluster hit-test candidates from shared projected viewport data
- [x] `lib/services/peak_hover_detector.dart` - adapt existing distance-based hover logic to projected candidates or wrap via new adapter seam
- [x] `lib/screens/map_screen.dart` - replace `_hitTestPeak()` candidate build path with shared projected data; keep popup open/close behavior intact
- [x] `test/widget/map_screen_peak_info_test.dart` - migrate hover and click tests off marker widgets; assert popup, cursor, hover affordance, and no selected-location regression
- [x] `test/robot/peaks/peak_info_robot.dart` - replace main-map marker-hitbox selectors with interaction helpers on `map-interaction-region` plus any minimal new stable selectors
- [x] TDD: non-overlapping visible peaks render as individual canvas peaks with climbed/unclimbed meaning preserved, then implement
- [x] TDD: hovering and clicking an individual peak still drive cursor + hover popup + pinned popup flows, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Label Collision Overlay

- **Goal**: restore peak-info labels via sparse collision pass
- [x] `lib/screens/map_screen.dart` - add sparse overlay seam above the custom peak layer; keep main-map-only scope
- [x] `lib/services/peak_label_layout.dart` - build label candidates from visible non-hovered individual peaks; descending screen-`y` acceptance; reject label/label and label/marker conflicts
- [x] `lib/screens/map_screen_layers.dart` - extract or reuse label text styling helpers without keeping per-peak widget marker composition on the main map
- [x] `lib/providers/peak_marker_info_settings_provider.dart` - keep current toggle semantics; no new persistence shape
- [x] `test/widget/map_screen_peak_info_test.dart` - cover collision visibility, hidden conflicting labels, preserved label keys only for accepted labels
- [x] `test/widget/tasmap_map_screen_test.dart` - cover main-map selector migration and preserved layer ordering above track polylines
- [x] TDD: with peak info enabled, only non-conflicting non-hovered individual labels render; lower-on-screen wins, then implement
- [x] TDD: hovered or pinned popup states do not require labels and do not regress popup behavior, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Cluster Visuals, Perf, Journey Proof

- **Goal**: finish `cluster.png` ring visuals; harden invalidation; prove dense-map journey
- [x] `lib/screens/map_screen_peak_layer.dart` - paint ringed cluster visuals with centered count and ticked/unticked proportional arcs; preserve current peak colors
- [x] `lib/services/peak_cluster_engine.dart` - add bounded viewport-data caching/invalidation keyed by camera, viewport size, filtered peaks, correlation inputs
- [x] `lib/services/peak_projection_cache.dart` - add smallest shared runtime cache only if profiling after earlier slices still shows repeated projection churn
- [x] `test/unit/` - add focused tests for cluster composition ratios, representative selection, dissolve threshold, invalid-coordinate skip, cache invalidation
- [x] `test/robot/peaks/peak_cluster_journey_test.dart` - add dense-map robot journey: open map, reach cluster state, expand cluster, confirm individual-peak state; use app-owned keys first
- [x] `test/robot/peaks/peak_info_robot.dart` - add minimal selectors/seams for cluster interaction only if `map-interaction-region` alone is insufficient
- [x] TDD: cluster ring arc proportions match ticked/unticked membership counts, then implement
- [x] TDD: repeated pan/zoom invalidates and rebuilds viewport data deterministically without stale cluster/hover state, then implement
- [x] Robot journey tests + selectors/seams for critical flows: `Key('map-interaction-region')`, `Key('peak-marker-layer')`, sparse label root, optional cluster-interaction selector, deterministic repository/notifier fixtures
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `flutter_map` custom-layer API may constrain hit testing or z-order; main-map selector migration may require broader widget-test rewrites than expected; collision labels can still be costly if candidate bounds/layout are rebuilt too often
- **Out of scope**: mini-map/dashboard renderer migration; spiderfy; cluster tooltips/previews; `flutter_map_marker_cluster` production adoption; peak data-model/schema changes; non-peak map-layer redesign
