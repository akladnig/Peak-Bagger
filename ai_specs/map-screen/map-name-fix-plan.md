## Overview

Map readout/popup fallback, region-aware grid capability, 1000 km grid.
Pure service seams first; then provider/UI wiring; preserve current Riverpod + robot patterns.

**Spec**: `ai_specs/map-screen/map-name-fix-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `models/`, `providers/`, `screens/`, `services/`, `widgets/`
- **State management**: Riverpod
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen_layers.dart`, `lib/services/peak_info_content_resolver.dart`
- **Assumptions/Gaps**: `mapSet` already shipped; visible-region union only for grid capability; viewport intersection stays pure in `region_manifest_catalog.dart`

## Plan

### Phase 1: Naming Fallback Slice

- **Goal**: end-to-end sheet/region/unknown resolution
- [x] `lib/services/map_name_resolution.dart` - add pure resolver for point + MGRS; output label + origin kind; humanize keys; Tasmania alias
- [x] `lib/services/peak_info_content_resolver.dart` - carry origin metadata in `PeakInfoContent`; use shared resolver
- [x] `lib/providers/map_provider.dart` - route `mapNameForPoint` / `mapNameForMgrs` through shared resolver; keep callers stable
- [x] `lib/screens/map_screen_panels.dart` - render `Map:` vs `Region:` from typed origin
- [x] `test/unit/map_name_resolution_test.dart` - resolver coverage
- [x] `test/widget/map_screen_peak_info_test.dart` - popup/readout label assertions
- [x] `test/robot/peaks/peak_info_robot.dart` - update expected fallback lines; keep existing selectors
- [x] `test/robot/peaks/peak_info_journey_test.dart` - region-fallback journey
- [x] TDD: sheet hit -> sheet name, `Map:`
- [x] TDD: no sheet + known region -> region label, `Region:`
- [x] TDD: no sheet + no region -> `Map: Unknown`
- [x] Robot journey tests + selectors/seams for fallback popup; reuse `peak-info-popup`, `map-interaction-region`; no new selectors unless needed
- [x] Verify: `flutter analyze` && `flutter test test/unit/map_name_resolution_test.dart test/widget/map_screen_peak_info_test.dart test/robot/peaks/peak_info_journey_test.dart`

### Phase 2: Region-Aware Grid Capability

- **Goal**: viewport intersection + MGRS-only grid contract
- [ ] `lib/services/region_manifest_catalog.dart` - add pure viewport-vs-region intersection helper; expose visible-region `mapSet` union API
- [ ] `test/unit/region_manifest_catalog_test.dart` - extend catalog assertions for visible-region union behavior
- [ ] `test/unit/visible_region_intersection_test.dart` - deterministic mixed-viewport intersection coverage
- [ ] `lib/providers/map_provider.dart` - derive effective grid capability/tooltip/render state from visible-region `mapSet` union; suppress sheet-grid when union empty; preserve stored `gridVisibility`
- [ ] `lib/screens/map_screen.dart` - pass visible bounds/effective grid state into render path
- [ ] `lib/widgets/map_action_rail.dart` - consume new tooltip contract only; preserve `grid-map-fab`
- [ ] `test/widget/tasmap_display_mode_test.dart` - sheet-backed vs MGRS-only tooltip/state cases
- [ ] `test/robot/map/map_grid_robot.dart` - add non-sheet-backed fixture/seam
- [ ] `test/robot/map/map_grid_and_ruler_journey_test.dart` - MGRS-only journey
- [ ] TDD: viewport intersecting sheet dataset -> existing 3-state copy
- [ ] TDD: viewport with empty `mapSet` union -> `Show MGRS Grid` / `Hide MGRS Grid`
- [ ] TDD: stored `mapGridOnly` + empty union -> suppress selected-map sheet render, keep stored state
- [ ] Robot journey tests + selectors/seams for MGRS-only cycle; reuse `grid-map-fab`, `map-zoom-readout`; add layer key only if widget assertions need it
- [ ] Verify: `flutter analyze` && `flutter test test/unit/region_manifest_catalog_test.dart test/unit/visible_region_intersection_test.dart test/widget/tasmap_display_mode_test.dart test/robot/map/map_grid_and_ruler_journey_test.dart`

### Phase 3: 1000 km + Full-Viewport Geometry

- **Goal**: low-zoom interval + no trimmed gaps
- [ ] `lib/core/constants.dart` - add `1000 km` threshold token
- [ ] `lib/services/map_ruler_scale.dart` - add `1000 km` interval selection
- [ ] `lib/services/map_grid_geometry.dart` - support `1000 km`; stop label-driven line shortening; preserve `1 km` label behavior
- [ ] `lib/screens/map_screen_layers.dart` - stop passing trim insets that shorten visible lines; keep label placement stable
- [ ] `test/services/map_ruler_scale_test.dart` - threshold + `1000 km` coverage
- [ ] `test/services/map_grid_geometry_test.dart` - viewport-edge coverage + `1000 km` interval coverage
- [ ] `test/widget/map_screen_layers_test.dart` - layer/key assertions if render contract changes
- [ ] TDD: threshold boundary enters `1000 km` at configured cutoff
- [ ] TDD: visible lines reach viewport edges while `1 km` labels remain usable
- [ ] TDD: `10 km` / `100 km` / `1000 km` suppress border labels
- [ ] Verify: `flutter analyze` && `flutter test test/services/map_ruler_scale_test.dart test/services/map_grid_geometry_test.dart test/widget/map_screen_layers_test.dart`

## Risks / Out of scope

- **Risks**: viewport-region intersection correctness at polygon edges; legacy `selectedMap`/`tasmapDisplayMode` coupling; MGRS geometry behavior across very broad extents
- **Out of scope**: basemap drawer unioning; peak-list region unioning; new sheet datasets beyond current `Tasmap50k`-backed `mapSet`
