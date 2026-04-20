## Overview

Local-first map tiles via cache service + `flutter_map` adapter.
Remove manual tile seeding UI; cover cache, map wiring, and robot journey.

**Spec**: `ai_specs/002-tile-download-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first; screen/widget/service split
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/services/tile_downloader.dart`, `./test/robot/tasmap/tasmap_robot.dart`
- **Assumptions/Gaps**: use current `flutter_map` tile-provider seam; legacy cache lookup only if folders exist; Tasmap keeps `{z}/{y}/{x}` service order; basemap drawer needs stable keys

## Plan

### Phase 1: Cache service

- **Goal**: canonical pathing + local-hit/write-through seam
- [ ] `./lib/services/tile_cache_service.dart` - new cache root/path resolver, legacy-read fallback, remote fetch, write-through persistence; inject cache root, HTTP client, file I/O
- [ ] `./lib/screens/map_screen_layers.dart` - basemap metadata table: remote URL, canonical cache folder, legacy folder, file extension
- [ ] `./test/services/tile_cache_service_test.dart` - TDD: canonical path mapping for all basemaps
- [ ] `./test/services/tile_cache_service_test.dart` - TDD: local hit returns cached bytes; remote miss fetches and writes canonical cache
- [ ] `./test/services/tile_cache_service_test.dart` - TDD: remote failure, write failure, unreadable file stay local to the tile
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Map wiring

- **Goal**: tile layer uses cache-aware provider; UI cleanup
- [ ] `./lib/screens/map_screen.dart` - swap `NetworkTileProvider` flow for cache-aware tile loading; keep pan/zoom/basemap triggers intact
- [ ] `./lib/widgets/map_basemaps_drawer.dart` - add stable keys for each basemap tile
- [ ] `./lib/screens/settings_screen.dart` - remove "Download Offline Tiles" action
- [ ] `./test/widget/map_screen_tile_cache_test.dart` - TDD: basemap switch selects correct namespace; pan/zoom still requests local-first tiles
- [ ] `./test/widget/map_settings_test.dart` - TDD: settings tile removed; drawer keys present
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey

- **Goal**: critical map flow coverage end to end
- [ ] `./test/robot/map/map_tile_cache_robot.dart` - helper around `map-interaction-region` and basemap drawer keys
- [ ] `./test/robot/map/map_tile_cache_journey_test.dart` - TDD: open map, pan/zoom, switch basemaps, confirm local-first behavior stays interactive
- [ ] `./test/robot/map/map_tile_cache_journey_test.dart` - TDD: no manual download step; cached tiles persist across restart-style pump
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `flutter_map` adapter seam may need one small API adjustment; Tasmap URL order must stay `{z}/{y}/{x}`; legacy cache branch may be dead code if no old tiles exist
- **Out of scope**: area-based bulk download, cache eviction/TTL, tile compression/deduplication, visual redesign
