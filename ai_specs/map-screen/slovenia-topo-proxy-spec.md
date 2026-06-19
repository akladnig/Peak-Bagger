<goal>
Add Slovenia's official ortho imagery as a normal basemap in Peak Bagger without teaching the Flutter app to speak WMS directly.
The app should keep using its existing XYZ tile pipeline, cache behavior, and basemap drawer, while a small proxy service converts Web Mercator tile requests into the GURS WMS endpoint for `SI.GURS.ZPDZ:DOF5`.
This matters because the current map stack is already built around XYZ basemaps, and a proxy keeps the production integration maintainable while avoiding a custom CRS branch in the Flutter UI.
</goal>

<background>
The live Slovenian source is the public WMS endpoint at `https://storitve.eprostor.gov.si/ows-pub-wms/wms` with layer `SI.GURS.ZPDZ:DOF5` (`DOF5`, ortofoto / raster) in `EPSG:3794`.
The committed app-side XYZ tile URL for this basemap should be `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`.
The Flutter app already renders basemaps from the manifest-backed catalog in `./assets/region_manifest.json`, generated into `./lib/generated/region_manifest_catalog.g.dart`, and selected through the existing basemap drawer and `TileLayer` XYZ URL templates.
The app's current map/cache code assumes normal tile URLs and should not be rewritten to use direct WMS or custom map projection logic for this feature.
The proxy should be a new standalone Dart package created under `./proxy/slovenia-topo-proxy/` with its own `pubspec.yaml`, entrypoint, and tests.
Files to examine: `./assets/region_manifest.json`, `./tool/generate_region_manifest_catalog.dart`, `./lib/generated/region_manifest_catalog.g.dart`, `./lib/services/region_manifest_catalog.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/services/tile_cache_service.dart`, `./test/unit/region_manifest_catalog_test.dart`, `./test/unit/tile_cache_service_test.dart`, `./test/widget/map_basemaps_drawer_test.dart`.
</background>

<discovery>
1. Confirm the proxy should be created as a standalone deployable HTTP service package in `./proxy/slovenia-topo-proxy/` rather than a Flutter-side workaround or direct WMS call.
2. Confirm the proxy should expose a stable XYZ endpoint of the form `/slovenia-ortofoto/{z}/{x}/{y}.png` so the existing `TileLayer` code can consume it unchanged.
3. Confirm the proxy package should use `shelf` + `http` + `proj4dart` (or equivalent small Dart server/projection dependencies) and expose local overrides for `PORT` and the upstream WMS base URL while keeping the app manifest pointed at one stable published proxy URL.
4. Confirm the final `maxZoom` for the proxy and manifest with a live smoke test against the upstream WMS, then keep the proxy seed/cache config and manifest entry aligned to that single value.
5. Confirm outside-coverage tile requests should return a transparent PNG, not a 404, so the map can pan smoothly at the country edge without noisy tile failures.
</discovery>

<user_flows>
Primary flow:
1. User opens the map centered in or near Slovenia.
2. User opens `Basemaps`.
3. The drawer shows `Slovenia Ortofoto` as a region-appropriate option.
4. User selects it.
5. The map requests XYZ tiles from the proxy service.
6. The proxy converts each tile request into a WMS `GetMap` request against `SI.GURS.ZPDZ:DOF5` and returns a PNG tile.
7. The map renders the imagery and the existing tile cache stores it normally.

Alternative flows:
1. The user revisits the basemap drawer later in the same session; the Slovenian basemap remains available through the same manifest-backed route.
2. The proxy receives repeated requests for the same tile; cached responses should be reused without changing the app-side behavior.
3. The user pans beyond Slovenia's coverage; the proxy returns transparent tiles for out-of-coverage requests, preserving smooth map interaction.

Error flows:
1. Upstream WMS times out or returns a server error: the proxy returns a controlled 502 with a short cache policy and the map remains usable.
2. Proxy deployment is unavailable: the app should fail like any other missing basemap source, without crashing or requiring a custom WMS fallback path.
3. Malformed tile coordinates are requested: the proxy returns 400 and logs the request as invalid input.
</user_flows>

<requirements>
**Functional:**
1. Add a new Slovenian basemap entry to `./assets/region_manifest.json` under the `slovenia` region with a stable key such as `sloveniaOrtofoto`, a human-readable name such as `Slovenia Ortofoto`, attribution that matches the GURS use constraints, and the committed proxy tile URL template `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`.
2. Regenerate `./lib/generated/region_manifest_catalog.g.dart` from the manifest so the new basemap becomes part of `Basemap.values`, the region basemap drawer, and the tile-cache store list without manual enum edits.
3. Implement a standalone `shelf`-based tile proxy service in `./proxy/slovenia-topo-proxy/` that includes `pubspec.yaml`, a server entrypoint, projection and WMS client helpers, and tests.
4. The proxy must translate the incoming XYZ tile bounds from Web Mercator into the upstream WMS request for `SI.GURS.ZPDZ:DOF5` using `EPSG:3794`, calculating the request bbox from the tile's exact projected corner coordinates.
5. The proxy must keep the app on the existing XYZ path; do not add a direct WMS code path to `./lib/screens/map_screen.dart` or `./lib/widgets/map_basemaps_drawer.dart`.
6. The proxy must emit cache-friendly headers so the app's own tile cache and any CDN or browser cache can reuse responses safely.
7. The proxy package README must document the committed published proxy URL `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`, local `PORT` override, upstream WMS URL override, and the single supported layer `SI.GURS.ZPDZ:DOF5` from `https://storitve.eprostor.gov.si/ows-pub-wms/wms`.
8. The new `sloveniaOrtofoto` basemap must be excluded from the existing global low-zoom warmup path in `./lib/services/tile_cache_service.dart`; do not let a Slovenia-only proxy source inherit world-scale warmup downloads just because it is part of `Basemap.values`.

**Error Handling:**
9. Requests outside the source coverage or beyond the configured zoom ceiling should return a transparent 256x256 PNG rather than an error tile.
10. For tiles that partially overlap the Slovenian source coverage, the proxy must request the original exact tile bbox unchanged and let the upstream WMS return blank or no-data pixels outside coverage; use source bounds only for intersection testing, not for bbox mutation.
11. Requests with malformed path segments or non-integer coordinates should return 400.
12. Upstream WMS failures should not leak stack traces or HTML error pages to the app; return a controlled 502 and log the failure on the proxy side.
13. The app must continue to render and keep the currently selected basemap if the proxy is temporarily unavailable.

**Edge Cases:**
14. The proxy must preserve the exact tile coordinate mapping for XYZ, including Y orientation, so the returned tiles line up with the existing `flutter_map` basemap logic.
15. The proxy should avoid re-requesting the live WMS unnecessarily for tiles already cached locally or through HTTP caching.
16. The manifest entry must remain region-scoped to Slovenia and should not appear in other region basemap lists.
17. Keep the URL template and proxy route stable once published; changing either later should be treated as a breaking change.

**Validation:**
18. Require baseline automated coverage for proxy math/service behavior, manifest/catalog generation, and the critical basemap selection journey.
</requirements>

<boundaries>
Edge cases:
- The proxy is read-only and must only serve raster tiles for the single Slovenian ortho layer.
- The app should not gain any custom CRS logic for this feature; the proxy exists specifically to avoid that.
- Do not add persistence, settings UI, or per-user configuration for the proxy base URL.
- The published proxy base URL is part of the app's manifest-backed configuration and is fixed as `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`; local dev/test can override only the proxy process, not the app-side tile URL contract.
- The Slovenia proxy basemap is region-limited and must not participate in world-scale low-zoom warmup.

Error scenarios:
- If the upstream WMS changes availability or rate limits, the proxy should degrade with controlled error codes and logs, not with app-side map exceptions.
- If the proxy returns transparent tiles for out-of-coverage areas, the app should treat them like normal blank tiles, not as errors.

Limits:
- Do not broaden the proxy to handle arbitrary WMS layers; scope it to `SI.GURS.ZPDZ:DOF5` only.
- Do not change the existing region manifest model or the basemap drawer pattern beyond the new Slovenian entry.
- Do not add a second basemap registry or a custom runtime manifest parser.
- Do not switch the map screen to direct WMS, WMTS, or custom CRS rendering.
</boundaries>

<implementation>
Create `./proxy/slovenia-topo-proxy/` as a small standalone `shelf` Dart HTTP service package with `pubspec.yaml`, a server entrypoint, a thin request handler, upstream WMS client, projection helper, and tests.
The proxy should compute Web Mercator tile bounds, convert them to the WMS request CRS, call the live GURS endpoint, and return the response as a cached PNG tile.
Add the new Slovenian basemap entry in `./assets/region_manifest.json`, then regenerate `./lib/generated/region_manifest_catalog.g.dart` so the app automatically exposes the new basemap key everywhere manifest-backed basemaps are already used.
Keep `./lib/screens/map_screen_layers.dart` and `./lib/widgets/map_basemaps_drawer.dart` unchanged unless the manifest regeneration exposes a real compatibility issue.
Update `./lib/services/tile_cache_service.dart` only as needed to exclude `sloveniaOrtofoto` from global low-zoom warmup while keeping per-basemap store creation intact.
Add a proxy configuration file or README inside `./proxy/slovenia-topo-proxy/` that captures the upstream WMS URL `https://storitve.eprostor.gov.si/ows-pub-wms/wms`, the single layer name `SI.GURS.ZPDZ:DOF5`, the expected bounding box, and the committed app manifest URL `https://tiles.peakbagger.com/slovenia-ortofoto/{z}/{x}/{y}.png`.
Add stable test keys in the app only if the current basemap drawer tests need them; the existing `Key('basemap-option-${basemapData.key}')` pattern should already cover the new entry.
Avoid any app-side special casing for Slovenia beyond the new manifest entry and regenerated catalog.
</implementation>

<stages>
Phase 1: Proxy math and handler
1. Build the projection and tile-bbox conversion helpers.
2. Add unit tests for valid tiles, malformed coordinates, outside-coverage tiles, and upstream URL construction.
3. Verify the proxy can return a PNG tile from a fake upstream WMS before touching the app manifest.

Phase 2: App registration
1. Add the Slovenian basemap entry to `./assets/region_manifest.json`.
2. Regenerate `./lib/generated/region_manifest_catalog.g.dart` and confirm the basemap drawer and cache store list include the new enum value.
3. Verify the map screen still renders existing basemaps unchanged.
4. Exclude `sloveniaOrtofoto` from global low-zoom warmup and verify existing warmup behavior remains unchanged for the other basemaps.

Phase 3: Journey proof
1. Add widget coverage for the Slovenia region basemap drawer showing `Slovenia Ortofoto`.
2. Add robot coverage for discovering and selecting the new basemap on the map screen.
3. Run the proxy test suite and the Flutter test suite together, then fix regressions before finishing.
</stages>

<validation>
Use strict TDD slices for the proxy first: red on tile-bbox conversion, green on upstream URL generation, then refactor.
Keep proxy tests deterministic by using a fake upstream HTTP server; do not hit the live GURS endpoint in automated tests.
The projection test slice must cover Mercator-to-WMS bbox generation against the configured proxy layer bounds, not just string assembly.
Required automated coverage outcome:
1. `unit` or logic: XYZ tile math, WMS parameter construction, transparent-tile fallback, malformed-request handling, and cache-header behavior.
2. `widget`: the basemap drawer includes `Slovenia Ortofoto` when the selected region is Slovenia and keeps the existing basemap flow intact.
3. `unit` or logic: `./lib/services/region_manifest_catalog.dart` and `./lib/services/tile_cache_service.dart` still include the new manifest basemap in `Basemap.values`, region filtering, and cache-store initialization, while excluding it from global low-zoom warmup.
4. `robot`: open the basemap drawer on a Slovenia-centered map, select the new basemap, and confirm the journey completes through the manifest-backed option key `Key('basemap-option-sloveniaOrtofoto')`.
5. `integration` or smoke: a local proxy instance responds to one known tile request with a valid PNG and the expected caching headers.
Validation must cover both the app-side manifest/catalog update and the proxy-side request translation so the tile source stays production-safe.
</validation>

<done_when>
The work is complete when the app exposes `Slovenia Ortofoto` as a normal basemap through the existing manifest-driven drawer, the selected basemap loads through a standalone XYZ proxy instead of direct WMS access, the proxy correctly translates XYZ requests to the GURS `SI.GURS.ZPDZ:DOF5` service, out-of-coverage and upstream-failure behavior is controlled, and the behavior is covered by proxy unit tests plus Flutter widget and robot coverage.
</done_when>
