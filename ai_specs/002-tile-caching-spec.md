<goal>
Implement persistent tile caching for map tiles using flutter_map_tile_caching to improve performance and enable offline use. Users should be able to bulk download tiles for all 5 basemaps (openstreetmap, tracestrack, tasmapTopo, tasmap50k, tasmap25k) for offline map access while hiking in areas without connectivity.

Caching must be:
- Persistent and survives app restarts
- Cache metadata visible in Settings for user inspection (tile count, size)
- Configurable via Settings screen with zoom range and basemap selection
</goal>

<background>
Tech stack: Flutter with flutter_map ^8.2.2, flutter_map_tile_caching (local fork), Riverpod for state

Implementation uses local FMTC fork at /Users/adrian/Development/mapping/flutter_map_tile_caching for objectbox ^5 compatibility.

Files:
- @lib/services/tile_cache_service.dart (FMTC service with store management)
- @lib/screens/map_screen.dart:438-458 (TileLayer with FMTCTileProvider)
- @lib/screens/settings_screen.dart:722- (TileCacheSettingsScreen)
- @lib/main.dart:23 (FMTC initialization)
- @lib/providers/map_provider.dart:40 (Basemap enum)
</background>

<user_flows>
Primary flow:
1. User goes to Settings → "Map Tile Cache"
2. User selects basemap from dropdown (openstreetmap, tracestrack, tasmapTopo, tasmap50k, tasmap25k)
3. User views cache metadata for selected basemap (tile count, size)
4. User configures zoom range (default 6-14, Tasmania bounds)
5. User taps "Download"
6. Progress indicator shows download status
7. Completion notification
8. Tiles now served from cache automatically

Alternative flows:
- First-time user: App uses network until cache is populated
- Returning user with cache: Tiles load from cache first, network fallback
- Download cancelled: Partial cache retained
- User clears cache: Metadata updates to reflect cleared state

Error flows:
- Network error during download: Retry option, partial cache preserved
- Storage full: Warning shown, suggest clearing old tiles
- Invalid zoom range: Validation error before download starts
</user_flows>

<requirements>
**Functional (Complete):**
1. ✓ Integrate flutter_map_tile_caching package (local fork)
2. ✓ Create 5 FMTC stores on startup
3. ✓ Replace NetworkTileProvider with FMTCTileProvider
4. ✓ "Map Tile Cache" section in Settings with cache stats (tile count, size)
5. ✓ Bulk download with zoom range selection
6. ✓ Download progress display
7. ✓ Cache-first behavior via BrowseLoadingStrategy.cacheFirst
8. ✓ Clear cache per basemap
</requirements>

**Error Handling:**
E1. Handle network timeout during bulk download gracefully
E2. Preserve partial cache on download failure or cancellation
E3. Handle storage full scenario with user notification
E4. Handle corrupted tile cache entries

**Edge Cases:**
EC1. Handle empty cache (first launch)
EC2. Handle concurrent access (unlikely but handle gracefully)
EC3. Handle app killed during download

**Validation:**
V1. Configurable zoom range input (min 0, max 18, validated)
V2. Basemap selection (dropdown), all 5 options available
V3. Download button disabled during active download
</requirements>

<boundaries>
Edge cases:
- Download cancelled mid-progress: Keep valid tiles already downloaded
- Zero tiles in selected range: Show informative message
- Network unavailable during cache check: Fallback to network if available

Error scenarios:
- 500+ HTTP errors during download: Stop and report error count
- Disk full: Abort gracefully, report bytes written vs needed
- Corrupted tile file: Skip and log, continue with next tile
- API key error (401/403 for Tracestrack): Show clear error message

Behavior outside cached region:
- Zoom < 6 or > 14: Network fetch + auto-cache new tiles
- Outside Tasmania bounds: Network fetch + auto-cache new tiles
- No cached tiles for basemap: Network fetch only (FMTC store per basemap)
- Use FMTC's built-in network caching (tiles auto-cached on first fetch)

Limits:
- Max zoom: 18 (FMTC default, don't exceed)
- Tasmania bounds: lat -43.8 to -40.5, lng 144.0 to 149.0
- Default zoom range: 6-14 (~5000 tiles per source)
- Zoom outside 6-14: Network fetch (not pre-cached), tiles auto-cached on first view
</boundaries>

<implementation>
**Dependency:**
```yaml
flutter_map_tile_caching:
  path: /Users/adrian/Development/mapping/flutter_map_tile_caching
```

**TileCacheService** (`lib/services/tile_cache_service.dart`):
- `initialize()`: Creates FMTCObjectBoxBackend and 5 stores
- `getStoreForBasemap(Basemap)`: Returns store for given basemap
- `clearStore(String)`: Clears cache for given store name

**FMTC Initialization** (`lib/main.dart`):
```dart
await TileCacheService.initialize(); // before openStore()
```

**FMTCTileProvider** (`lib/screens/map_screen.dart`):
- Uses all 5 stores with BrowseStoreStrategy.readUpdateCreate
- BrowseLoadingStrategy.cacheFirst for cache-first behavior
- Simple urlTransformer (identity function)

**TileCacheSettingsScreen** (`lib/screens/settings_screen.dart`):
- Basemap dropdown selector
- Min/max zoom dropdowns (default 6-14)
- Download button with progress stream
- Cache stats display (tile count, size) using FutureBuilder
- Clear cache button

**Download API:**
```dart
final tileLayer = TileLayer(urlTemplate: mapTileUrl(basemap));
final bounds = LatLngBounds(southWest, northEast);
final region = RectangleRegion(bounds).toDownloadable(
  minZoom: _minZoom,
  maxZoom: _maxZoom,
  options: tileLayer,
);
final result = store.download.startForeground(region: region);
await for (final progress in result.downloadProgress) { ... }
```
</implementation>

<validation>
**Unit tests:**
- TileCacheService.downloadTiles completes for valid bounds
- TileCacheService.downloadTiles handles network errors gracefully
- TileCacheService.getTileProvider returns correct provider type
- Zoom range validation rejects invalid inputs

**Widget tests:**
- TileDownloadScreen shows source selection options
- TileDownloadScreen disables download during active download
- TileDownloadScreen shows progress during download
- TileDownloadScreen validates zoom range input

**Integration:**
- Map loads tiles from cache when available
- Map falls back to network when tile not in cache

Required testType mapping:
- Robot: critical happy path (download OSM, verify map loads cached)
- Widget: screen edge cases (cancel download, validation errors)
- Unit: cache service logic, zoom validation
</validation>

<done_when>
1. flutter_map_tile_caching integrated and builds successfully
2. FMTC initializes with 5 stores on app startup
3. Settings screen has working tile download UI (replaces existing)
4. Settings screen shows cache metadata per store (tile count, size)
5. Bulk download completes for all 5 basemaps with progress
6. Map uses cache-first with network fallback for all basemaps
7. Auto-caches newly fetched tiles outside initial download region
8. Cache cleared per basemap via Settings
9. Tests pass: unit, widget, integration
</done_when>