## Overview

Manifest-backed basemap catalog. Remove hardcoded URL/list switches; drive map drawer + tile cache from `./assets/region_manifest.json`.

**Spec**: `ai_specs/global-maps-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first under `./lib/screens`, `./lib/widgets`, `./lib/services`, `./lib/providers`
- **State management**: Riverpod
- **Reference implementations**: `./lib/screens/map_screen.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/services/tile_cache_service.dart`, `./lib/services/tile_cache_download_scope.dart`, `./test/unit/tile_cache_download_scope_test.dart`, `./test/robot/settings/tile_cache_journey_test.dart`
- **Assumptions/Gaps**: checked-in generated catalog; `MapScreen` owns open-drawer region snapshot; existing five basemap ids stay first, NSW keys append in manifest order; fallback unavailable basemap => `Basemap.tracestrack`

## Plan

### Phase 1: Catalog generation

- **Goal**: manifest parser + stable catalog + enum ordering
- [x] `./tool/generate_region_manifest_catalog.dart` - generate checked-in `./lib/generated/region_manifest_catalog.g.dart` from `./assets/region_manifest.json`
- [x] `./lib/services/region_manifest_catalog.dart` - runtime lookup API for basemap metadata + region membership
- [x] `./lib/generated/region_manifest_catalog.g.dart` - generated enum/catalog output; preserve current five ids, append new keys in manifest order
- [x] `./assets/region_manifest.json` - keep stable `key` values authoritative for all regions/maps
- [x] TDD: parse manifest list; dedupe identical entries; reject conflicting duplicate keys; preserve ordering contract
- [x] Verify: `flutter analyze` && `flutter test test/unit/region_manifest_catalog_test.dart test/unit/tile_cache_download_scope_test.dart`

### Phase 2: Drawer + map wiring

- **Goal**: region-filtered basemap drawer; no hardcoded URL switch
- [ ] `./lib/screens/map_screen.dart` - own drawer-region snapshot as route-local state; pass snapshot into drawer builder
- [ ] `./lib/widgets/map_basemaps_drawer.dart` - render manifest-filtered basemaps for snapped region; show empty/unavailable state; fallback current selection to `Basemap.tracestrack` when needed
- [ ] `./lib/screens/map_screen_layers.dart` - replace `mapTileUrl` switch with catalog lookup only
- [ ] `./lib/widgets/map_action_rail.dart` - keep FAB open behavior aligned with new snapshot seam if plumbing changes
- [ ] TDD: drawer snapshot stays stable while open; cursor-first then center fallback; hidden basemaps excluded; unavailable active basemap falls back to tracestrack
- [ ] Robot selectors: `Key('show-basemaps-fab')`, `Key('basemaps-drawer')`, `Key('basemap-option-${basemap.name}')`-style option keys
- [ ] Verify: `flutter analyze` && `flutter test test/widget/map_basemaps_drawer_test.dart test/widget/map_screen_rebuild_test.dart`

### Phase 3: Cache sync + journey proof

- **Goal**: keep cache warmup/store init aligned; prove critical user journey
- [ ] `./lib/services/tile_cache_service.dart` - derive store init/warmup iteration from manifest-backed enum ordering
- [ ] `./test/unit/tile_cache_service_test.dart` - update ordering/assertions for expanded enum/catalog
- [ ] `./test/robot/map/basemap_selection_journey_test.dart` - critical journey: open drawer, region-resolved list, select basemap, confirm map updates
- [ ] TDD: warmup/store order matches enum order; selected basemap selection path still updates map; stale/hidden basemap selection falls back cleanly
- [ ] Verify: `flutter analyze` && `flutter test test/unit/tile_cache_service_test.dart test/robot/map/basemap_selection_journey_test.dart`

## Risks / Out of scope

- **Risks**: manifest-key collisions; ordering drift between generator and runtime; drawer snapshot seam leaking into global state
- **Out of scope**: network manifest loading; touch-pinch/route-overlay refactors; cache-download behavior changes beyond basemap source-of-truth wiring
