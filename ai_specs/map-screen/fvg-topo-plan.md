## Overview

Add Friuli Venezia Giulia topo to `italy-nord-est`, but keep post-`PR#111` map stack intact: manifest-backed catalog, keyed basemap gating, proxy-backed non-XYZ sources.

**Spec**: quick plan from task description + post-`PR#111` / `PR#112` map changes; no standalone spec file

## Context

- **Structure**: feature-first app under `./lib/screens`, `./lib/widgets`, `./lib/services`, `./lib/providers`; standalone tile proxies under `./proxy/`
- **State management**: Riverpod
- **Reference implementations**: `./assets/region_manifest.json`, `./tool/generate_region_manifest_catalog.dart`, `./lib/services/region_manifest_catalog.dart`, `./lib/screens/map_screen.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/services/tile_cache_service.dart`, `./proxy/slovenia-topo-proxy/`, `./test/unit/region_manifest_catalog_test.dart`, `./test/widget/map_basemaps_drawer_test.dart`, `./test/robot/map/basemap_selection_journey_test.dart`
- **Assumptions/Gaps**: FVG topo source remains public WMS at `https://serviziogc.regione.fvg.it/geoserver/CARTOGRAFIA/wms?request=GetCapabilities&version=1.3.0`; exact live layer ids/CRS still need confirmation; prefer one user-facing basemap `fvgTopo` with zoom-routed upstream layers (`CRN25K` low zoom, `CTRN5K` high zoom); orthophoto out of scope

## Plan

### Phase 1: Coverage-aware catalog slice

- **Goal**: FVG-only basemap visibility; no peak-region rewrite
- [ ] `./assets/region_manifest.json` - add lower-camel basemap key `fvgTopo` under `italy-nord-est`; add FVG-only basemap coverage metadata instead of exposing it across the whole nord-est polygon
- [ ] `./assets/polygons/friuli-venezia-giulia.poly` - add dedicated FVG coverage polygon for basemap filtering
- [ ] `./tool/generate_region_manifest_catalog.dart` - parse optional per-basemap coverage polygons; keep existing enum ordering contract intact
- [ ] `./lib/generated/region_manifest_catalog.g.dart` - regenerate typed coverage data; append `fvgTopo` after existing baseline + post-`PR#111` keys
- [ ] `./lib/services/region_manifest_catalog.dart` - add point-scoped basemap resolution that honors optional basemap coverage polygons; keep region key lookup stable for peaks/lists/imports
- [ ] `./lib/screens/map_screen.dart` - snapshot basemap options from cursor/center point, not coarse region key alone; keep tracestrack fallback before drawer open
- [ ] `./lib/widgets/map_basemaps_drawer.dart` - consume snapped basemap list/keys; keep existing selector keys
- [ ] TDD: point inside FVG sees `fvgTopo`; point elsewhere in `italy-nord-est` does not; Tasmania/NSW/Slovenia drawer behavior unchanged; fallback still lands on `Basemap.tracestrack`
- [ ] Robot journey tests + selectors/seams for critical flows: keep `Key('show-basemaps-fab')`, `Key('basemaps-drawer')`, `Key('basemap-option-fvgTopo')`; snapshot must stay stable while drawer remains open
- [ ] Verify: `flutter analyze` && `flutter test test/unit/region_manifest_catalog_test.dart test/widget/map_basemaps_drawer_test.dart test/robot/map/basemap_selection_journey_test.dart`

### Phase 2: FVG topo proxy thin slice

- **Goal**: one XYZ endpoint backed by FVG WMS
- [ ] `./proxy/fvg-topo-proxy/pubspec.yaml` - new standalone proxy package; mirror Slovenia proxy deps only where needed
- [ ] `./proxy/fvg-topo-proxy/bin/server.dart` - serve `/fvg-topo/{z}/{x}/{y}.png`
- [ ] `./proxy/fvg-topo-proxy/lib/src/tile_handler.dart` - XYZ parse; zoom-bucket layer selection; exact WMS `GetMap` request; transparent tile fallback on final upstream failure
- [ ] `./proxy/fvg-topo-proxy/lib/src/upstream_wms_client.dart` - WMS URL builder; timeout/error mapping; PNG-only response contract
- [ ] `./proxy/fvg-topo-proxy/lib/src/transparent_tile.dart` - embedded transparent PNG for out-of-coverage / exhausted retries
- [ ] `./proxy/fvg-topo-proxy/README.md` - committed prod URL, local debug URL, upstream WMS URL, chosen layer mapping by zoom, local run steps
- [ ] `./proxy/fvg-topo-proxy/test/tile_handler_test.dart` - fake upstream; malformed XYZ; expected layer by zoom; transparent fallback; exact bbox request
- [ ] `./proxy/fvg-topo-proxy/test/upstream_wms_client_test.dart` - query params, timeout mapping, HTML/error leak prevention
- [ ] TDD: `z<=N` uses CRN25K layer; `z>N` uses CTRN5K layer; final upstream failure returns transparent tile; exact XYZ tile extent preserved in WMS request
- [ ] Verify: in `./proxy/fvg-topo-proxy`: `dart analyze` && `dart test`

### Phase 3: App integration + cache sync

- **Goal**: manifest basemap live in app; cache/store behavior safe
- [ ] `./assets/region_manifest.json` - point `fvgTopo` at committed production XYZ URL, not raw WMS
- [ ] `./lib/generated/region_manifest_catalog.g.dart` - regenerate final enum/catalog after committed URL lands
- [ ] `./lib/screens/map_screen_layers.dart` - add debug override seam like Slovenia if local proxy URL differs in debug builds
- [ ] `./dart_defines.example.json` - document optional `FVG_TOPO_TILE_URL` debug override only if app-side override seam is added
- [ ] `./lib/services/tile_cache_service.dart` - create store for `fvgTopo`; skip global low-zoom warmup if proxy-backed source should not be bulk-prefetched
- [ ] `./run_local_maps.sh` - extend local map helper if combined Flutter + proxy startup is needed for daily dev flow
- [ ] `./start_fvg_proxy.sh` - helper start script, matching post-`PR#111` Slovenia workflow if separate local lifecycle is kept
- [ ] `./stop_fvg_proxy.sh` - helper stop script
- [ ] `./restart_fvg_proxy.sh` - helper restart script
- [ ] `./test/unit/tile_cache_service_test.dart` - store exists; warmup policy stays intentional
- [ ] `./test/unit/region_manifest_catalog_test.dart` - enum order includes `fvgTopo`; FVG-only coverage filter proven; other Italy regions stay unchanged
- [ ] `./test/widget/map_basemaps_drawer_test.dart` - FVG point shows `basemap-option-fvgTopo`; non-FVG nord-est point hides it
- [ ] `./test/robot/map/basemap_selection_journey_test.dart` - FVG-centered journey selects `fvgTopo`; non-FVG nord-est journey cannot
- [ ] TDD: cache store still initializes; warmup excludes only intended proxy-backed basemaps; debug override does not affect release URL
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: current drawer filter is region-key-based and too coarse for FVG coverage; live FVG WMS capabilities still need confirmation for layer ids/CRS; proxy hosting/deployment sits outside Flutter repo
- **Out of scope**: FVG orthophoto; changing peak import regions or peak-list region keys; generic multi-source proxy refactor of `./proxy/slovenia-topo-proxy/`
