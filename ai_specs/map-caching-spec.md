<goal>
Reduce tile-cache download volume in `./lib/screens/settings_screen.dart` by letting users narrow a basemap download to a specific Tasmap sheet selected through a search dropdown.
The selector is mandatory for download scope and defaults to the first Tasmap sheet, so users do not download the full basemap extent by mistake.
</goal>

<background>
The current `Map Tile Cache` screen in `./lib/screens/settings_screen.dart` lets users choose a basemap, zoom range, and download all tiles for a fixed Tasmania-wide extent.
The app already has a matching map-search interaction in `./lib/screens/map_screen_panels.dart` (`MapGotoPanel`) and Tasmap search/polygon helpers in `./lib/services/tasmap_repository.dart` and `./lib/providers/map_provider.dart`.
Tile stores are managed per basemap in `./lib/services/tile_cache_service.dart`; the new map selection should narrow the download region only, not change the target store.
Files to examine: `./lib/screens/settings_screen.dart`, `./lib/screens/map_screen_panels.dart`, `./lib/providers/map_provider.dart`, `./lib/providers/tasmap_provider.dart`, `./lib/services/tile_cache_service.dart`, `./lib/services/tasmap_repository.dart`, `./test/widget/tasmap_refactor_test.dart`, `./test/widget/map_screen_camera_request_test.dart`, `./test/robot/tasmap/tasmap_robot.dart`.
</background>

<discovery>
1. Confirm the selected map should narrow the download with an exact polygon-shaped region derived from the Tasmap sheet outline, using the package's `CustomPolygonRegion` path rather than a rectangle approximation.
2. Confirm the map selection is screen-local state in `TileCacheSettingsScreen` and must not mutate `mapProvider.selectedMap` or the map screen display mode.
3. Confirm the tile-cache screen always starts with a selected map, using the first Tasmap sheet by name sort, and disables download if no Tasmap sheets exist.
4. Confirm Tasmap reimport changes are detected through `tasmapStateProvider.tasmapRevision`, reseeding the selected map if the current selection no longer exists.
</discovery>

<user_flows>
Primary flow:
1. User opens `Settings` and goes to `Map Tile Cache`.
2. User chooses a basemap.
3. The screen already has a selected Tasmap sheet, defaulting to the first Tasmap sheet by name sort.
4. User types a Tasmap sheet name into the new `Map` search field.
5. User picks a suggestion from the dropdown.
6. User taps `Download`.
7. The download uses the chosen basemap and the selected map extent, so the tile set is much smaller than the current full-basemap download.

Alternative flows:
1. User changes the basemap after selecting a map; the selected map stays available for the next download.
2. Tasmap data is refreshed while the screen is open; the screen keeps the current selection if it still exists, otherwise it reseeds to the first map by name sort.
3. User reopens the screen; the screen-local query and selection do not leak into map-screen state.

Error flows:
1. Search query returns no maps: show no suggestions and keep the current selection unchanged.
2. No Tasmap sheets are available: disable download and show a clear status error.
3. Tile cache store is unavailable: preserve the existing error path and leave the screen usable.
</user_flows>

<requirements>
**Functional:**
1. Add a `Map` search dropdown directly under the existing basemap selector in `./lib/screens/settings_screen.dart`.
2. Make the search interaction match the `MapGotoPanel` pattern: live query text, suggestion list, tap-to-select behavior, and a visible selected map state.
3. Populate suggestions from `TasmapRepository.searchMaps`, using the same prefix-style matching and top-10 cap already used in the app.
4. Keep the selected map local to the tile-cache screen; do not write it into `mapProvider` or any shared map-screen selection state.
5. The screen must always have a selected map. On first build, default to the first Tasmap sheet returned by `getAllMaps()` after sorting by map name; if no Tasmap sheets exist, disable download and surface an error.
6. When a map is selected, use `TasmapRepository.getMapPolygonPoints` as the exact polygon outline for tile download scope.
7. Show the current selected map in a visible chip or label near the search field so the mandatory selection is obvious.
8. Keep `Clear Cache`, zoom limits, skip-existing-tiles behavior, and the basemap-specific store selection unchanged.

**Error Handling:**
7. If the search yields no matches, clear the suggestion list and do not clear the current selected map.
8. If the Tasmap repository is empty, do not start the foreground download and show a concise error status instead.
9. If the download start fails for any reason, or if the widget is disposed mid-download, reset the in-progress flag without throwing and leave the current basemap, map selection, and search query intact.

**Edge Cases:**
10. A map selection must survive unrelated basemap changes within the same screen session so the user can reuse it for the next download.
11. If the user changes the query while suggestions are visible, the list should update deterministically and never select a stale result.
12. Mid-download UI edits only affect the next download request; the active request must use the snapshot taken at tap time.

**Validation:**
13. Require baseline automated coverage for logic, UI behavior, and the critical download journey.
</requirements>

<boundaries>
1. The new map selector is a download-scope filter only; it must not change the map screen itself, map overlay mode, or route navigation.
2. `Clear Cache` remains basemap-scoped and clears the whole store for the selected basemap, not a per-map subset.
3. Do not broaden the search to unrelated data sources; use Tasmap sheet search only.
4. Do not switch the tile store or tile URL based on the selected map; the basemap still controls the source layer.
5. Do not add persistence for the tile-cache map selection unless future work explicitly asks for it.
6. Do not add a way to clear the selected map; selection is mandatory for download scope.
</boundaries>

<implementation>
1. Update `./lib/screens/settings_screen.dart` to hold local map-search state, render the new `Map` field, and drive the download region from the selected map when present.
2. Add a small helper in `./lib/services/tile_cache_download_scope.dart` for resolving the download region so the selected-map polygon and rectangle fallback can be unit tested without a widget harness.
3. Reuse `./lib/providers/tasmap_provider.dart` and `./lib/services/tasmap_repository.dart` for search and polygon lookup rather than introducing a second map repository.
4. Add stable keys for the new controls, including the basemap selector, map search field, suggestion items, and download button.
5. Introduce a narrow seam around `store.download.startForeground` so tests can assert the chosen region, selected-map fallback, and skip-existing flag without touching the real cache backend.
6. Add or update tests in `./test/unit/tile_cache_download_scope_test.dart`, `./test/widget/tile_cache_settings_screen_test.dart`, and `./test/robot/settings/tile_cache_settings_journey_test.dart`.
7. Avoid pushing the new selection through `mapProvider` or widening the existing `MapGotoPanel` API unless reuse is clearly cheaper than a local settings-only implementation.
8. Align test doubles with production Tasmap search semantics so the harness uses the same prefix matching and top-10 limit as `TasmapRepository.searchMaps`.
9. Seed the initial tile-cache selection from the first map in name-sorted order, and re-seed the same way if Tasmap data changes and the current selection no longer exists.
10. Add a stable key for the selected-map chip or label, such as `Key('tile-cache-selected-map-chip')`.
</implementation>

<stages>
Phase 1: Research and seam
1. Verify the download extent source and the smallest seam around the tile-cache foreground download.
2. Add the pure download-region helper and cover exact polygon download shapes with unit tests.

Phase 2: Settings UI
1. Add the map search UI and selected-map state to `TileCacheSettingsScreen`.
2. Wire search suggestions and selection to Tasmap repository data.
3. Verify the screen still opens, clears cache, and starts a download.

Phase 3: Download behavior and journey proof
1. Route the download through the selected map polygon when present.
2. Add widget and robot coverage for the search, selection, and download journey.
3. Run the relevant Flutter test suite and fix regressions before finishing.
</stages>

<validation>
Use strict TDD slices for the pure region helper first: red on fallback rectangle, green on selected-map polygon, then refactor.
Keep test seams public-facing and deterministic; prefer a fake downloader seam over mocking private widget methods.
Widget coverage must verify the new search field, the suggestion list, selection retention, the mandatory-default selection, and the download status path.
Robot coverage must drive the critical settings journey with stable keys such as `Key('tile-cache-basemap-dropdown')`, `Key('tile-cache-map-search-field')`, `Key('tile-cache-map-suggestion-0')`, and `Key('tile-cache-download-button')`.
Required automated coverage outcome:
1. `unit` or logic: download-region helper, including exact polygon conversion and empty-repository handling.
2. `widget`: map search, suggestion selection, empty-result behavior, and download-state messaging.
3. `robot`: open settings, choose basemap, search map, select suggestion, and start download through the fake seam.
Verify the download path with both the default name-sorted selection and an explicit user-chosen map so the default remains intentional.
</validation>

<done_when>
The spec is complete when the settings screen can narrow tile-cache downloads to a selected Tasmap sheet using the exact polygon outline, the map search behaves like the existing goto-location flow, the screen defaults to the first name-sorted Tasmap sheet and never downloads without a selection, Tasmap reimports reseed the screen-local selection when needed, the basemap store logic is unchanged, and the behavior is covered by unit, widget, and robot tests.
</done_when>
