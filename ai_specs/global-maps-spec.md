<goal>
Replace hardcoded basemap metadata with a manifest-backed catalog so the map screen only offers region-appropriate basemaps and every tile URL/name comes from `./assets/region_manifest.json`.
This matters because users should only see valid basemaps for the region under the cursor, and future region/map additions should not require editing multiple hardcoded switches.
</goal>

<background>
The current basemap source of truth is split across `./lib/screens/map_screen_layers.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/providers/map_provider.dart`, and `./lib/services/tile_cache_service.dart`.
`map_screen_layers.dart` hardcodes tile URLs in `mapTileUrl(Basemap basemap)`, `MapBasemapsDrawer` hardcodes the visible list with one `ListTile` per enum value, and `TileCacheService` assumes the enum and store names are manually maintained.
The bundled manifest at `./assets/region_manifest.json` already contains the data this feature needs: region keys, region polygons, and per-region `maps` entries with a stable `key`, `name`, `tileUrl`, `attribution`, and optional `maxZoom`.
The app already has a cursor/map-point lookup seam in `./lib/providers/map_provider.dart` (`mapNameForPoint`) and existing polygon asset loading patterns in `./lib/services/polygon_asset_repository.dart`.
Files to examine: `./assets/region_manifest.json`, `./lib/screens/map_screen_layers.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/widgets/map_action_rail.dart`, `./lib/providers/map_provider.dart`, `./lib/services/tile_cache_service.dart`, `./lib/screens/settings_screen.dart`, `./lib/services/polygon_asset_repository.dart`, `./test/unit/tile_cache_service_test.dart`, `./test/widget/tile_cache_settings_screen_test.dart`, `./test/robot/settings/tile_cache_journey_test.dart`
</background>

<discovery>
1. Define the smallest manifest-backed catalog shape that can replace both the hardcoded URL switch and the hardcoded basemap drawer list without broadening map-state responsibilities.
2. Decide the region resolution seam for the drawer open event: cursor point first, then map center, with a stable snapshot for the open drawer session.
3. Confirm how to normalize manifest map keys into stable Dart identifiers and how to handle duplicate keys that resolve to the same identifier.
4. Confirm whether identical map entries that appear in multiple regions should be deduplicated into one enum/catalog entry or represented separately.
</discovery>

<user_flows>
Primary flow:
1. User moves the cursor over a supported region on the map.
2. User taps `Select Basemaps`.
3. The app snapshots the region from the current cursor point, or the visible map center if the cursor is unavailable.
4. The drawer shows only the basemaps valid for that region, using labels and URLs from the manifest.
5. User selects one of the visible basemaps and the map updates with the manifest URL for that basemap.

Alternative flows:
- Touch or keyboard-only use: the app falls back to the current map center when no cursor point exists.
- Drawer reopen: the region snapshot is recomputed when the FAB is tapped again, but the already-open drawer does not live-update if the cursor moves.
- If the current basemap is not available for the snapped region, the app falls back to `Basemap.tracestrack` and keeps the selection coherent.
- New manifest region: the generated catalog and enum include its basemaps without manual edits to `map_screen_layers.dart`.

Error flows:
- Region lookup fails for both cursor and center: show a safe unavailable state instead of a mixed global basemap list.
- Manifest parsing or generation fails: log the failure and fail closed with an empty or disabled basemap drawer rather than partial hardcoded fallback data.
</user_flows>

<requirements>
**Functional:**
1. Create a single manifest-backed basemap catalog sourced from `./assets/region_manifest.json` that defines every unique basemap `key`, display label, tile URL, optional max zoom, and region membership used by the app.
2. Generate the `Basemap` enum from the manifest at build time so the current five enum names remain `tasmapTopo`, `tasmap50k`, `tasmap25k`, `tracestrack`, and `openstreetmap`, and new manifest keys such as `nswTopo`, `nswBasemap`, and `nswImagery` are added as stable identifiers.
3. Replace the hardcoded URL switch in `./lib/screens/map_screen_layers.dart` with catalog lookup only.
4. Replace the hardcoded basemap list in `./lib/widgets/map_basemaps_drawer.dart` with a region-filtered list from the catalog.
5. Resolve the drawer region from the cursor point when available, otherwise from the current map center, and freeze that region snapshot for the lifetime of the open drawer.
6. Keep `TileCacheService` store initialization and warmup in sync with the expanded enum/catalog so every manifest basemap has a cache store and URL template.
7. Keep existing basemap selection state and map routing behavior intact; this task is a catalog/filter refactor, not a map-state redesign.
8. If the currently selected basemap is not offered for the snapped region, automatically switch to `Basemap.tracestrack` as the safe fallback before presenting the drawer state.
9. Preserve the existing five basemap identifiers in their current order, then append new manifest keys in manifest order so `Basemap.values`, warmup iteration, and store initialization stay deterministic.

**Error Handling:**
8. If the manifest data is missing from the generated catalog or the generator/CI detects malformed manifest input, fail fast at build time; runtime only needs to handle missing or stale generated data with a deterministic empty or disabled drawer state and logging.
9. If region lookup fails for both cursor and map center, render a safe unavailable state rather than cross-region basemap options.
10. If a basemap entry is duplicated with identical metadata, deduplicate it once in the generated catalog; if metadata conflicts, fail validation before the app ships.

**Edge Cases:**
11. Preserve manifest order when presenting basemaps within a region so the drawer remains stable across launches.
12. Keep hidden or unavailable basemaps out of the region-filtered drawer; if the active basemap is unavailable, replace it with `Basemap.tracestrack` before the drawer presents its final state.
13. Preserve manifest URL templates exactly, including any token ordering needed by a basemap; the rendering code must not reintroduce URL special-casing.
14. The generated catalog must remain deterministic across platforms and test runs.

**Validation:**
15. Add pure unit coverage for manifest parsing, deduplication, region grouping, and conflict detection.
16. Add widget coverage for the basemap drawer showing region-filtered options, fallback region resolution, and the empty or unavailable state.
17. Add robot coverage for the critical journey: open basemap drawer, resolve region from the current point, choose a region-appropriate basemap, and verify the map updates.
18. Validation must follow TDD slices: catalog/parser first, drawer filter second, journey coverage last.
19. Require stable selectors for the drawer and options, including `Key('show-basemaps-fab')`, `Key('basemaps-drawer')`, and per-option keys like `Key('basemap-option-${basemap.name}')`.
20. Require baseline automated coverage across catalog logic, widget behavior, and the critical map-selection journey.
</requirements>

<boundaries>
Edge cases:
- If the cursor is outside every supported region, the drawer should not invent a cross-region list.
- If a map region contains only globally shared basemaps, still show only the manifest entries for that region.
- Opening the drawer should not clear the current basemap or any other transient map UI state.

Error scenarios:
- Manifest asset load failure: keep the app usable and emit a logged error, but do not expose stale hardcoded basemap choices.
- Duplicate identifier collision: reject the manifest during catalog generation so the app build fails fast.

Limits:
- Do not change camera, route, peak, or cache-download behavior beyond the basemap source of truth and region filtering needed here.
- Do not add network loading; read the bundled asset only.
- Do not introduce a second basemap registry or a separate hardcoded fallback list.
- Do not broaden scope to touch-pinch, route overlays, or other map-screen refactors.
- Do not add user-visible error dialogs; use empty or disabled states plus logs.
- Do not change persistent basemap-selection storage keys unless the existing settings flow proves they are tied to the old static enum and must be migrated.
</boundaries>

<implementation>
Add `./lib/generated/region_manifest_catalog.g.dart` as the generated source of truth for the enum and basemap metadata, and add `./tool/generate_region_manifest_catalog.dart` to rebuild it from `./assets/region_manifest.json`. The generated file is checked in so the app can import stable catalog data without parsing the manifest at runtime.
Add `./lib/services/region_manifest_catalog.dart` as the runtime accessor for region lookup and basemap metadata so the map drawer, map layers, and tile-cache service consume one catalog.
Update `./lib/screens/map_screen_layers.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/widgets/map_action_rail.dart`, `./lib/providers/map_provider.dart`, and `./lib/services/tile_cache_service.dart` only as needed to consume the catalog and snapshot the open-drawer region context.
Make `./lib/screens/map_screen.dart` own the drawer-region snapshot as route-local state and pass that snapshot into `./lib/widgets/map_basemaps_drawer.dart` via constructor parameters when the end drawer is built.
Derive cache store names from the manifest-backed `Basemap` enum rather than maintaining a separate manual list.
Update any `Basemap.values` iteration sites so they continue to work with the expanded, manifest-driven enum and the preserved ordering contract.
Add or update tests in `./test/unit/region_manifest_catalog_test.dart`, `./test/unit/tile_cache_service_test.dart`, `./test/widget/map_basemaps_drawer_test.dart`, and `./test/robot/map/basemap_selection_journey_test.dart`.
Keep the change minimal: one catalog, one region-resolution seam, no general map-state rewrite.
</implementation>

<stages>
Phase 1: Catalog generation and lookup
1. Implement the manifest parser and generated basemap catalog.
2. Verify deduplication, ordering, and conflict detection with unit tests.

Phase 2: Map drawer and layer wiring
1. Replace hardcoded basemap URLs and drawer items with catalog lookups.
2. Add the region snapshot seam so the drawer stays stable while open.
3. Verify the drawer still opens and the map continues to render the selected basemap.

Phase 3: Cache/service sync and journey proof
1. Align tile-cache store initialization and warmup with the manifest-backed enum.
2. Add widget and robot coverage for the region-filtered basemap journey.
3. Run the relevant Flutter test suite and fix regressions before finishing.
</stages>

<validation>
Use strict TDD slices for the pure catalog first: red on missing or conflicting manifest entries, green on valid catalog generation, then refactor.
Keep test seams public-facing and deterministic; prefer a fake catalog/repository seam over mocking private widget methods.
Widget coverage must verify the basemap drawer, the region snapshot behavior, the empty or unavailable state, and the map update path after selection.
Robot coverage must drive the critical map journey with stable keys such as `Key('show-basemaps-fab')`, `Key('basemaps-drawer')`, and `Key('basemap-option-${basemap.name}')`.
Required automated coverage outcome:
1. `unit` or logic: manifest parsing, unique basemap generation, duplicate handling, and conflict rejection.
2. `widget`: region-filtered drawer options, fallback region resolution, and empty-state behavior.
3. `robot`: open basemaps drawer, verify the filtered list, select a basemap, and confirm the map updates through the fake seam.
Verify the expanded enum path with the existing tile-cache warmup and store initialization tests so the new basemap set stays in sync.
</validation>

<done_when>
The spec is complete when `./lib/screens/map_screen_layers.dart` no longer hardcodes basemap URLs, every basemap referenced in `./assets/region_manifest.json` is represented by the app’s manifest-backed catalog and enum, the Select Basemaps drawer only shows region-appropriate options based on the open-drawer snapshot, tile-cache initialization stays aligned with the expanded basemap set, and the behavior is covered by unit, widget, and robot tests.
</done_when>
