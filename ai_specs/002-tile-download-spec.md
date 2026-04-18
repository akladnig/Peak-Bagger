<goal>
Make map rendering local-first for all basemaps so hikers can pan, zoom, and switch basemaps with cached tiles served from application documents before any remote fetch.
This matters because the map is a core navigation surface and must keep working when connectivity is poor or absent.
</goal>

<background>
The app is a Flutter project using `flutter_map`, Riverpod, `http`, `path_provider`, and `dart:io` for file access.
Current map rendering always points `TileLayer` at remote URL templates in `./lib/screens/map_screen_layers.dart`, while `./lib/services/tile_downloader.dart` only preloads a subset of tiles into app storage under legacy folder names.
The task is to replace that remote-first behavior with a local-first tile cache under application documents and keep the existing map UX intact.
The current `flutter_map` API supports this through a custom `TileProvider` or equivalent tile-loading seam, not by moving file logic into the widget tree.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/services/tile_downloader.dart`
- `./lib/widgets/map_basemaps_drawer.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/providers/map_provider.dart`

Known conventions:
- `map-interaction-region` is the existing stable selector for map journey tests.
- The app already uses Riverpod state for basemap selection and map position.
</background>

<discovery>
Before coding, confirm the smallest seam that lets `TileLayer` resolve tiles through a cache service while tests inject a fake cache root, fake HTTP client, and fake file I/O.
Verify the exact URL template and file extension for each basemap, then define a single canonical cache layout under `ApplicationDocumentsDirectory/map_tiles`.
Check whether any existing downloaded tiles under `tiles_osm` and `tiles_tracestrack` should remain readable as legacy cache data.
</discovery>

<user_flows>
Primary flow:
1. User opens the map screen.
2. Visible tiles resolve from the on-device cache first.
3. Missing tiles are fetched from the active basemap source, written to application documents, and then displayed.
4. User pans or zooms and the newly visible tiles repeat the same local-first resolution.

Alternative flows:
- Basemap switch: user opens the basemap drawer, selects another basemap, and the next visible tiles come from that basemap's cache namespace.
- Returning user: previously cached tiles appear immediately even after app restart.
- Offline user: already cached tiles still render; uncached tiles remain unavailable until connectivity returns.

Error flows:
- Remote tile fetch fails: the map stays usable and only the missing tile stays blank or unresolved.
- Local cache write fails after a successful fetch: render the fetched tile for that request, log the cache failure, and do not block the map.
- Corrupt local tile file: treat it as a cache miss and retry from the remote source once.
</user_flows>

<requirements>
**Functional:**
1. The canonical cache root must be `ApplicationDocumentsDirectory/map_tiles`.
2. Cache paths must be basemap-specific and coordinate-specific, and the remote URL template must stay source-specific so Tasmap keeps its current `{z}/{y}/{x}` order. Use this mapping and keep legacy folders readable as a fallback, but never write new tiles there:

| Basemap | Remote URL pattern | Canonical cache folder | Legacy cache folder | File extension |
| --- | --- | --- | --- | --- |
| `Basemap.tracestrack` | `https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=...` | `map_tiles/OSM_tracestrack` | `tiles_tracestrack` | `.webp` |
| `Basemap.openstreetmap` | `https://tile.openstreetmap.org/{z}/{x}/{y}.png` | `map_tiles/OSM_standard` | `tiles_osm` | `.png` |
| `Basemap.tasmapTopo` | `https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/Topographic/MapServer/tile/{z}/{y}/{x}` | `map_tiles/tasmap_topo` | none | `.png` |
| `Basemap.tasmap50k` | `https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/TasmapRaster/MapServer/tile/{z}/{y}/{x}` | `map_tiles/tasmap_50k` | none | `.png` |
| `Basemap.tasmap25k` | `https://services.thelist.tas.gov.au/arcgis/rest/services/Basemaps/Tasmap25K/MapServer/tile/{z}/{y}/{x}` | `map_tiles/tasmap_25k` | none | `.png` |

3. Tile lookup must be local-first for every requested visible tile: check the canonical cache, then the legacy cache folder if one exists, then fetch remote only on miss, then persist the bytes to the canonical cache and return the fetched tile.
4. Tile requests must be evaluated whenever the map pans, zooms, or the basemap changes; the shipped feature is opportunistic cache fill only, not area-based bulk predownload.
5. Add a separate future task for area-based bulk download. This spec does not implement a "Download Area" workflow.
6. Remove the Settings screen "Download Offline Tiles" action once on-demand caching is in place; do not leave a dead-end UI entry.

**Error Handling:**
7. A failed remote tile request must not surface a screen-level error or stop other tiles from rendering.
8. A successful fetch followed by a disk-write failure must still allow the tile to render for that request, with the failure logged for diagnosis.
9. A malformed or unreadable local tile must be treated as a cache miss rather than crashing the map.

**Edge Cases:**
10. Rapid pan/zoom interactions may trigger duplicate requests for the same tile; the cache layer must tolerate this without corruption.
11. Switching basemaps while tiles are in flight must not write a tile into the wrong basemap namespace.
12. The feature should not add cache eviction, TTL, or background prefetch behavior in this iteration.

**Validation:**
13. The cache layer must expose deterministic seams for tests: inject the cache root, the HTTP client, and file-system boundaries so tests do not touch the real network or real user documents directory.
14. Unsupported basemap values and malformed tile coordinates must fail fast in the cache layer, not in the widget tree.
15. Add stable keys to each basemap drawer `ListTile` so robot tests can tap them without relying on visible text.
</requirements>

<boundaries>
Cache boundaries:
- The cache lives in application documents only; do not write tiles into the asset bundle.
- Keep the cache append-only for this iteration; do not implement eviction or cleanup unless a separate task requests it.
- Do not migrate or rewrite legacy tiles; existing `tiles_osm` and `tiles_tracestrack` tiles may remain readable as a fallback only.

Runtime boundaries:
- Tile fetch failures are isolated to the affected tile.
- The map screen must remain interactive while tiles are loading or retrying.
- The basemap drawer continues to drive basemap selection; it should not own any download logic.

Out of scope:
- Area-based bulk download and background prefetching based on route prediction.
- Tile compression, deduplication, or cache size management.
- Visual redesign of the map screen or basemap drawer.
</boundaries>

<implementation>
Modify `./lib/screens/map_screen_layers.dart` to replace the current remote-only tile URL helper with a cache-aware tile source definition that includes URL template, cache folder, legacy fallback folder, and file extension per basemap.
Modify `./lib/screens/map_screen.dart` so `TileLayer` uses the cache-aware source/provider instead of `NetworkTileProvider()` plus `urlTemplate` alone.
Refactor `./lib/services/tile_downloader.dart` into a cache service or replace it with a new file under `./lib/services/` that owns canonical path resolution, legacy fallback reads, remote fetch, and write-through persistence.
Modify `./lib/widgets/map_basemaps_drawer.dart` and `./lib/screens/settings_screen.dart` to keep basemap selection intact and remove the obsolete offline-tile download entry.
Add or update tests under `./test/services/`, `./test/widget/`, and `./test/robot/` to cover the cache behavior and the user journey.
Add stable keys to the basemap drawer items in `./lib/widgets/map_basemaps_drawer.dart` and use them in the robot journey tests.

Patterns to use:
- Prefer a small service boundary over burying file/network logic inside the widget tree.
- Keep tile resolution synchronous at the call site only where the API requires it; inject async dependencies so tests stay deterministic.
- Prefer fakes over mocks for cache and HTTP behavior.

What to avoid:
- Do not write to `assets/map_tiles/...` at runtime.
- Do not keep two competing tile cache systems.
- Do not make the map screen wait on a full predownload before showing tiles.
</implementation>

<stages>
Phase 1: Implement the cache-aware tile resolution layer and verify local-hit, remote-miss, and write-through behavior with unit tests.
Phase 2: Wire the map screen and basemap selection to the new cache layer, then verify pan, zoom, and basemap switches still render correctly.
Phase 3: Remove the obsolete Settings download action and run widget plus robot coverage for the critical map journey.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for cache path mapping, canonical-hit behavior, legacy-hit behavior, remote fetch success, remote fetch failure, and disk-write failure.
- UI behavior: widget tests for map screen basemap selection, local-first tile resolution wiring, and removal of the Settings download action.
- Critical journeys: a robot-driven map journey that opens the map, changes basemaps, pans or zooms, and confirms the map remains interactive without a manual download step.

TDD expectations:
- Write one failing test at a time.
- Keep the first slice narrow: path mapping and local-hit behavior.
- Add the remote miss and error slices next, then refactor only after each slice is green.
- Use constructor injection or equivalent seams for cache root, file access, and HTTP so tests stay isolated from the real device state.

Robot test expectations:
- Use stable app-owned keys, especially `map-interaction-region` and dedicated basemap drawer item keys.
- Prefer deterministic fakes or a fake HTTP server over live network calls.
- Assert the journey through behavior, not pixels: selected basemap, map interactivity, and absence of the removed manual tile-download path.

Known risks to report:
- Tasmap remote tile format must match the cached file extension chosen for each source.
</validation>

<done_when>
- Every basemap resolves visible tiles from application-documents cache before fetching remotely.
- Pan, zoom, and basemap switches all trigger the local-first tile path.
- Remote misses are written to the canonical cache and reused on later visits.
- Existing legacy tiles remain readable, but new tiles are written only to the canonical cache layout.
- The Settings tile-download action is removed.
- Automated unit, widget, and robot coverage exists for the critical flows.
</done_when>
