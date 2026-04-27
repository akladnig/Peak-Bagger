---
title: FMTC Tile Caching Integration for flutter_map
date: 2026-04-26
work_type: feature
tags: [flutter, flutter_map, tile-caching, offline, objectbox]
confidence: high
references: [lib/services/tile_cache_service.dart, lib/screens/map_screen.dart, lib/screens/settings_screen.dart, lib/main.dart]
---

## Summary

Integrated flutter_map_tile_caching for persistent tile caching across 5 basemaps (openstreetmap, tracestrack, tasmapTopo, tasmap50k, tasmap25k). Uses local FMTC fork for objectbox ^5 compatibility.

## Dependency Resolution

**Solution:** Local FMTC fork at `/Users/adrian/Development/mapping/flutter_map_tile_caching` with objectbox ^5 support.

```yaml
flutter_map_tile_caching:
  path: /Users/adrian/Development/mapping/flutter_map_tile_caching
```

## Architecture

1. **TileCacheService** (`lib/services/tile_cache_service.dart`):
   - Initializes FMTCObjectBoxBackend
   - Creates 5 stores (one per basemap)
   - Provides getStoreForBasemap, getStats, clearStore

2. **main.dart**: Calls `TileCacheService.initialize()` before ObjectBox

3. **map_screen.dart**: FMTCTileProvider with:
   - urlTransformer (identity)
   - 5 stores with BrowseStoreStrategy.readUpdateCreate
   - BrowseLoadingStrategy.cacheFirst

4. **settings_screen.dart**: TileCacheSettingsScreen with:
   - Basemap dropdown
   - Min/max zoom dropdowns
   - Download button with progress stream
   - Clear cache button

## Key API Patterns

- Store initialization: `FMTCObjectBoxBackend().initialise()`
- Store creation: `FMTCStore(name).manage.create()`
- Download: `store.download.startForeground(region: region)`
- Progress: iterate `result.downloadProgress`
- Stats: `store.stats` (sync, not Future)

## Pitfalls Fixed

- **version conflict:** FMTC requires objectbox ^4, app uses ^5 → used local fork
- **LatLngBounds:** import from latlong2 correctly
- **for-loop:** must use `await for` with streams