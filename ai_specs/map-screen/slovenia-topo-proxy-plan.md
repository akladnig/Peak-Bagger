## Overview

Slovenia ortho basemap via XYZ proxy. Keep Flutter on manifest + `TileLayer`; add standalone Dart proxy; opt proxy basemap out of global warmup.

**Spec**: `ai_specs/map-screen/slovenia-topo-proxy-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first app under `./lib/screens`, `./lib/widgets`, `./lib/services`, `./lib/providers`; new standalone Dart package under `./proxy/`
- **State management**: Riverpod
- **Reference implementations**: `./tool/generate_region_manifest_catalog.dart`, `./lib/services/region_manifest_catalog.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/services/tile_cache_service.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./test/widget/map_basemaps_drawer_test.dart`, `./test/robot/map/basemap_selection_journey_test.dart`
- **Assumptions/Gaps**: committed tile URL fixed to `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`; upstream WMS fixed to `https://storitve.eprostor.gov.si/ows-pub-wms/wms`; `maxZoom` still smoke-test-driven; no existing server workspace

## Plan

### Phase 1: Thin slice

- **Goal**: proxy serves one tile; app exposes basemap; warmup opt-out wired
- [x] `./proxy/slovenia-topo-proxy/pubspec.yaml` - new package; `shelf`, `http`, `proj4dart`, test deps
- [x] `./proxy/slovenia-topo-proxy/bin/server.dart` - boot `shelf`; route `/slovenia-ortofoto/{z}/{x}/{y}.png`
- [x] `./proxy/slovenia-topo-proxy/lib/src/tile_handler.dart` - parse XYZ; exact bbox; no-intersection => transparent PNG; fakeable upstream seam
- [x] `./proxy/slovenia-topo-proxy/test/tile_handler_test.dart` - fake upstream; malformed coords; transparent tile; exact bbox request
- [x] `./assets/region_manifest.json` - add `sloveniaOrtofoto` with committed XYZ URL
- [x] `./lib/generated/region_manifest_catalog.g.dart` - regenerate enum/catalog after manifest update
- [x] `./lib/services/tile_cache_service.dart` - skip `sloveniaOrtofoto` in global low-zoom warmup; keep store creation
- [x] `./test/unit/tile_cache_service_test.dart` - store still created; warmup skips proxy basemap
- [x] TDD: proxy route parses XYZ; no-overlap => transparent tile; overlap => exact bbox upstream request
- [x] TDD: manifest entry regenerates `Basemap.sloveniaOrtofoto`; cache store exists; warmup excludes only this basemap
- [x] Verify: `flutter analyze` && `flutter test`; in `./proxy/slovenia-topo-proxy`: `dart analyze` && `dart test`

### Phase 2: Proxy hardening

- **Goal**: production-safe projection, headers, error mapping
- [x] `./proxy/slovenia-topo-proxy/lib/src/projection.dart` - Web Mercator tile bounds -> `EPSG:3794` corner transform; intersection test against source coverage
- [x] `./proxy/slovenia-topo-proxy/lib/src/upstream_wms_client.dart` - `GetMap` builder; timeout; 502 mapping; PNG-only response contract
- [x] `./proxy/slovenia-topo-proxy/lib/src/transparent_tile.dart` - embedded 256x256 transparent PNG bytes; no image package unless required
- [x] `./proxy/slovenia-topo-proxy/test/projection_test.dart` - partial overlap keeps original tile bbox; no bbox clamping; Y orientation stable
- [x] `./proxy/slovenia-topo-proxy/test/upstream_wms_client_test.dart` - cache headers; timeout/error mapping; HTML leak prevention
- [x] `./proxy/slovenia-topo-proxy/README.md` - committed XYZ URL, upstream WMS URL/layer, `PORT` override, local run steps
- [x] TDD: partial-overlap tile keeps exact tile extent; out-of-coverage uses transparent tile; upstream failure => controlled 502 + short cache
- [x] Verify: `flutter analyze` && `flutter test`; in `./proxy/slovenia-topo-proxy`: `dart analyze` && `dart test`

### Phase 3: Drawer + journey proof

- **Goal**: region-visible basemap; deterministic selection proof
- [x] `./test/widget/map_basemaps_drawer_test.dart` - Slovenia region shows `basemap-option-sloveniaOrtofoto`; non-Slovenia unaffected
- [x] `./test/robot/map/basemap_selection_journey_test.dart` - extend existing journey for Slovenia-centered state + `sloveniaOrtofoto` selection
- [x] `./test/unit/region_manifest_catalog_test.dart` - Slovenia region membership/order includes new basemap key once
- [x] TDD: Slovenia drawer includes new option; selecting it updates `mapProvider.basemap`; drawer key path unchanged
- [x] Robot journey tests + selectors/seams: reuse `Key('show-basemaps-fab')`, `Key('basemaps-drawer')`, `Key('basemap-option-sloveniaOrtofoto')`; deterministic state via existing `MapRouteRobot` / `TestMapNotifier`
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: proxy bbox math seams at borders; unknown practical `maxZoom` until smoke test; proxy host/cdn availability outside repo
- **Out of scope**: direct WMS/WMTS Flutter path; runtime manifest loading; multi-environment app-side tile URL switching
