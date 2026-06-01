## Overview

Add scalable MGRS grid + ruler on map screen.
Phase 1: state/geometry slice; Phase 2: labeling/grid polish; Phase 3: ruler UI + journeys.

**Spec**: `ai_specs/grid-lines-and-ruler-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `widgets/`, `providers/`, `services/`
- **State management**: Riverpod; large `MapNotifier` / `MapState`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/widgets/tasmap_polygon_label.dart`
- **Assumptions/Gaps**: spec flow text has one stale tooltip line; follow requirement/stage text: `Show Map and MGRS Grid`

## Plan

### Phase 1: Grid State Slice

- **Goal**: thin E2E; new grid state wired; first render path alive
- [x] `lib/providers/map_provider.dart` - add grid-visibility state; decouple from `TasmapDisplayMode`; preserve selected-map derivation; stop `selectMap`/`parseGridReference` forcing visible grids
- [x] `lib/widgets/map_action_rail.dart` - switch FAB cycle + tooltip text; keep `grid-map-fab`
- [x] `lib/core/constants.dart` - add MGRS-grid width + threshold constants (`3`, `30`); add ruler sizing tokens needed by scale helper
- [x] `lib/services/map_ruler_scale.dart` - add pure ruler-step + active-grid-interval selection API
- [x] `lib/screens/map_screen.dart` - gate Tasmap grid vs distance-grid rendering from new state; keep current readout visibility conditions
- [x] TDD: hidden -> map-grid-only -> map-grid-plus-distance-grid -> hidden; selected map must not force visible grids
- [x] TDD: ruler-scale helper picks interval bands from ruler value; threshold edges `3 km` / `30 km`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: MGRS Grid Geometry

- **Goal**: viewport geometry + border labels; map rendering complete
- [x] `lib/services/map_grid_geometry.dart` - pure viewport geometry builder for `1 km` / `10 km` / `100 km` lines + `1 km` border-label data
- [x] `lib/screens/map_screen_layers.dart` - add distance-grid layer builders; use shared color/width constants; reuse existing layer-key patterns
- [x] `lib/screens/map_screen.dart` - render keyed distance-grid layer only in `mapGridAndDistanceGrid`; preserve existing Tasmap polygon/label behavior
- [x] `lib/theme.dart` - add `mapGridColour` shared token
- [x] `lib/widgets/tasmap_outline_layer.dart` - swap hard-coded border color/width to shared tokens
- [x] TDD: geometry emits correct interval for viewport/ruler combo; fail closed on invalid bounds/camera
- [x] TDD: `1 km` labels only; eastings top/bottom; northings left/right; 2-digit only; none for `10 km` / `100 km`
- [x] TDD: selected-map fallback vs overlay fallback preserved while grids visible
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Ruler UI And Journeys

- **Goal**: replace zoom chip; lock user-visible behavior + journeys
- [x] `lib/screens/map_screen_panels.dart` - replace `MapZoomReadout` body with ruler UI; preserve outer key `map-zoom-readout`; right-align zoom text
- [x] `lib/screens/map_screen.dart` - keep ruler placement + hidden route/track-info states identical to old readout
- [x] `test/services/map_ruler_scale_test.dart` - cover step selection, width band, clamp behavior
- [x] `test/services/map_grid_geometry_test.dart` - cover interval/label seams, invalid-frame fail-closed behavior
- [x] `test/widget/tasmap_display_mode_test.dart` - update for new grid-visibility contract + tooltip sequence
- [x] `test/widget/map_screen_layers_test.dart` - cover layer keys/tokens/switching
- [x] `test/widget/map_screen_ruler_test.dart` - cover preserved key, layout, right-aligned zoom, hidden route/track-info states
- [x] `test/robot/map/map_grid_robot.dart` - add key-first robot helpers/selectors
- [x] `test/robot/map/map_grid_and_ruler_journey_test.dart` - cover FAB cycle + live readout/grid journey; deterministic harness only
- [x] TDD: ruler widget preserves key + visibility contract before visual polish
- [x] Robot journey tests + selectors/seams for critical flows
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: MGRS interval math near viewport edges; `flutter_map` camera readiness; border-label placement overlap at tiny viewports
- **Out of scope**: new package deps; persistence UX beyond existing map-state conventions; visual redesign beyond spec tokens/sample
