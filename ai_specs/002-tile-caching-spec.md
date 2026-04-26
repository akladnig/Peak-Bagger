<goal>
Implement persistent tile caching for map tiles using flutter_map_tile_caching to improve performance and enable offline use. Users should be able to bulk download tiles for all 5 basemaps (openstreetmap, tracestrack, tasmapTopo, tasmap50k, tasmap25k) for offline map access while hiking in areas without connectivity.

Caching must be:
- Persistent and survives app restarts
- Cache metadata visible in Settings for user inspection
- Configurable via Settings screen with zoom range and area selection
</goal>

<background>
Tech stack: Flutter with flutter_map ^8.2.2, flutter_map_tile_caching ^10.1.1, Riverpod for state

Files to examine:
- @lib/services/tile_downloader.dart (existing manual download)
- @lib/screens/map_screen.dart:439-443 (current TileLayer with NetworkTileProvider)
- @lib/screens/map_screen_layers.dart:13-26 (mapTileUrl function)
- @lib/providers/map_provider.dart:40 (Basemap enum)
- @lib/screens/settings_screen.dart (for caching UI location)

Context: App already has manual tile download in TileDownloader but uses direct HTTP and file system. FMTC provides superior caching with automatic cache management, LRU eviction, and proper tile provider integration.
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
**Functional:**
1. Integrate flutter_map_tile_caching package for tile caching
2. Create separate FMTC store for each basemap on startup: 'openstreetmap', 'tracestrack', 'tasmapTopo', 'tasmap50k', 'tasmap25k'
3. Replace NetworkTileProvider with single FMTCTileProvider using urlTransformer for all basemaps
4. Add "Map Tile Cache" section to Settings showing metadata per store (tile count, size)
5. Implement bulk download for openstreetmap (zoom 6-14, Tasmania bounds)
6. Implement bulk download for tracestrack (zoom 6-14, Tasmania bounds)
7. Implement bulk download for tasmapTopo/tasmap50k/tasmap25k (zoom 6-14, Tasmania bounds)
8. Show download progress with cancel option
9. Support cache-first behavior: check cache, fallback to network on miss
10. Cache newly fetched tiles (auto-caching for tiles outside initial download region)
11. Display cache statistics per store: tile count, size, zoom levels cached
12. Clear cache functionality per store via Settings

Future (out of scope):
- None - all 5 basemaps covered in this implementation

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
Note: tasmap basemaps use non-standard tile URLs (/{z}/{y}/{x} with y/x swapped). FMTC may need custom URL transformer or this basemap may require testing.

FMTC v10+ API details (verified):
- Initialize: `await FMTCObjectBoxBackend().initialise()`
- Create store: `await FMTCStore('storeName').manage.create()`
- Stores map entry key must correspond to basemap name used in urlTransformer

FMTC initialization (@lib/main.dart):
- Initialize FMTC ObjectBox: `await FMTCObjectBoxBackend().initialise()`
- Create 5 stores on startup: 'openstreetmap', 'tracestrack', 'tasmapTopo', 'tasmap50k', 'tasmap25k'
- Each store uses `BrowseStoreStrategy.readUpdateCreate`

FMTCTileProvider configuration (@lib/screens/map_screen.dart):
- Single FMTCTileProvider instance with URL transformer for scalability to N basemaps
- urlTransformer callback maps tile coordinates → basemap-specific URL at runtime
- Note: tasmap URLs use {z}/{y}/{x} format, not {z}/{x}/{y}. urlTransformer must handle this format correctly
- Uses all 5 stores with same strategy:
  ```dart
  FMTCTileProvider(
    urlTransformer: (tileCoords, fallbackUrl) {
      final mapState = ref.read(mapProvider);
      final basemap = mapState.basemap;
      var url = mapTileUrl(basemap);
      // Handle tasmap {z}/{y}/{x} vs standard {z}/{x}/{y} format
      if (basemap == Basemap.tasmapTopo || 
          basemap == Basemap.tasmap50k || 
          basemap == Basemap.tasmap25k) {
        url = url.replaceAll('{z}', '${tileCoords.z}')
                 .replaceAll('{y}', '${tileCoords.y}')
                 .replaceAll('{x}', '${tileCoords.x}');
      } else {
        url = url.replaceAll('{z}', '${tileCoords.z}')
                 .replaceAll('{x}', '${tileCoords.x}')
                 .replaceAll('{y}', '${tileCoords.y}');
      }
      return url;
    },
    stores: const {
      'openstreetmap': BrowseStoreStrategy.readUpdateCreate,
      'tracestrack': BrowseStoreStrategy.readUpdateCreate,
      'tasmapTopo': BrowseStoreStrategy.readUpdateCreate,
      'tasmap50k': BrowseStoreStrategy.readUpdateCreate,
      'tasmap25k': BrowseStoreStrategy.readUpdateCreate,
    },
    loadingStrategy: BrowseLoadingStrategy.cacheFirst,
  )
  ```

Files to create:
- @lib/services/tile_cache_service.dart (new: FMTC store management)
- @test/services/tile_cache_service_test.dart (new: unit tests)

Files to modify:
- @lib/screens/map_screen.dart (line 442): Replace NetworkTileProvider with FMTCTileProvider using urlTransformer
- @lib/screens/settings_screen.dart: Replace existing tile download ListTile with expanded "Map Tile Cache" section
- @lib/main.dart: Initialize FMTC ObjectBox and create stores
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