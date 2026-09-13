---
type: Spec
title: Tasmania DEM Overlays For Existing Basemaps
---

## Problem

The ELVIS topo DEM currently contributes terrain relief and contours only as part of the complete `Local Topo` basemap. A user selecting an external Tasmania basemap, such as `TasMap 25K`, cannot combine that cartography with DEM-derived terrain detail. The app also needs to avoid duplicate relief and contours when `Local Topo` is selected and must remain compatible with existing Local Topo v1 servers.

## Proposed Outcome

Provide two independently selectable Local tile server overlays in the map's existing Basemaps drawer: `Terrain relief shading` and `Contour lines`. They use prepared ELVIS topo DEM artifacts, apply above eligible Tasmania basemaps, retain user choices and opacity independently, and use the existing Local Topo capability and map-region availability model.

## User Stories

1. As a Tasmania map user, I can add terrain relief shading to `TasMap 25K` or another Tasmania basemap without replacing its cartography.
2. As a user of a basemap without contours, I can independently add DEM-derived contour lines and tune the opacity of either overlay.
3. As a Local Topo user, I can see that relief and contours are already included and avoid accidentally rendering duplicate treatments.
4. As a user with an older or temporarily unavailable local tile server, I retain a working basemap and receive clear, non-disruptive overlay behavior.

## Requirements

1. Add an `Overlays` section below the existing `Basemaps` list in `MapBasemapsDrawer`. It must contain independently toggleable `Terrain relief shading` and `Contour lines` controls. Either or both can be enabled. If the validated v2 snapshot has no usable Tasmania declaration for one of the two overlay keys, keep that control visible but disabled and show `Unavailable from the local tile server`. [L1] [L3] [L4]
2. A switch change must update the map immediately and keep the drawer open. Both overlay enabled states default to off for existing and new users, and persist globally across app restarts. [L3]
3. Each enabled and currently available standalone overlay must expose an `Opacity` control comprising a 0% through 100% slider with 5% increments and a direct integer percentage entry field. Values persist independently. Defaults are 35% for Terrain relief shading and 70% for Contour lines. A blank, non-numeric, or out-of-range value reverts to its prior valid value when the field loses focus. [L5]
4. Render terrain relief as its own DEM-derived raster overlay and do not include Local Topo labels, routes, other OSM cartography, or contours in that layer. [L1]
5. Render Contour lines as a separate DEM-derived overlay. It must use the selected Local Topo build's prepared contour data, without a client-side contour-spacing selector: normally 10 m, with the existing 25 m build fallback where required. [L4] [L6]
6. The standalone Contour lines overlay must render no contours below zoom 12, the 50 m and 100 m tiers at zoom 12, and minor contour lines from zoom 13 upward. It must never render contour labels. [L13]
7. When both overlays are enabled, order layers as basemap, Terrain relief shading, Contour lines, then trails, routes, tracks, peaks, markers, grids, and other app-owned map content. [L12]
8. Do not draw either standalone overlay over `Local Topo`. Keep its stored switches and opacity values unchanged; in the drawer, disable both switches and show `Included in Local Topo`. Hide both standalone `Opacity` controls. Restore the stored choices when a different eligible basemap is selected. [L7]
9. Show the `Overlays` section only when all conditions hold: the drawer's cursor-or-centre map point is in Tasmania, visible bounds intersect Tasmania, and the validated v2 Local tile server capability has at least one usable Tasmania overlay declaration. Hide the whole section otherwise without clearing stored preferences or changing the selected basemap. A drawer opened under eligible conditions keeps the existing fixed drawer snapshot behavior. Independently, compose standalone overlay layers only while the live map meets the same Tasmania point-and-bounds eligibility; remove them and stop their tile requests when it does not, without changing stored preferences. [L2] [L10]
10. Extend the Local Topo server capabilities response to advertise available overlays per region. Version 2 retains the current `localTopo` basemap declaration and adds a top-level `overlays` list. Each declaration has `key`, `label`, and `regions`; each region has `regionKey` and `tilePathTemplate`. The only accepted key-and-label pairs are `terrainReliefShading` with `Terrain relief shading` and `contourLines` with `Contour lines`. The Flutter client must accept the existing v1 contract for Local Topo-only operation and hide `Overlays` for a valid v1 snapshot. A valid v2 response with no usable advertised Tasmania overlays likewise exposes no overlay controls. [L9]
11. Fetch overlay tiles only from the validated Local tile server. Do not include either overlay in the app's offline tile-cache download or cache it as an offline basemap. [L11]
12. If an enabled overlay becomes unavailable after capability validation, preserve all map and preference state, leave missing tiles absent, and show at most one non-blocking message per outage: `Terrain relief shading is unavailable from the local tile server` or `Contour lines are unavailable from the local tile server`. An outage is a tile transport exception, a 15-second tile request timeout, or an HTTP 5xx response; leave 4xx and no-data tiles absent without notification. Do not automatically turn off a switch or repeatedly notify. Suppression resets only when the relevant overlay is disabled or Settings capability validation succeeds; individual successful tile responses do not reset it. Settings validation is the user retry path. [L8]

## Technical Decisions

1. Reuse the prepared `ELVIS topo DEM` artifacts; the Flutter app must not read the raw `Elvis 2m DEM` TIFF. The server must publish separately addressable transparent raster XYZ tiles for relief and contours, derived from the same selected DEM build metadata as Local Topo. [L1] [L6]
2. Evolve `GET /capabilities` from the v1 Local Topo-only contract to v2. Its top-level `overlays` list contains declarations of the exact shape `{ "key": String, "label": String, "regions": [{ "regionKey": String, "tilePathTemplate": String }] }`; the accepted key-and-label pairs are `terrainReliefShading` with `Terrain relief shading` and `contourLines` with `Contour lines`. Each accepted declaration has one or more region-scoped relative XYZ tile-path templates. Discard an individually malformed declaration while retaining valid overlays and the `localTopo` capability for external URLs, query strings, fragments, malformed templates, unsupported keys, unknown manifest region keys, or an incorrect label. A duplicate accepted key or duplicate region declaration invalidates that entire overlay key; retain unrelated valid overlays and the `localTopo` capability. [L2] [L4] [L9]
3. Store validated v2 overlay declarations in `LocalTopoCapabilitySnapshot` alongside its existing region declarations, using an optional `overlays` list in the stored JSON. A v1 stored snapshot without that field remains valid and represents no overlays. Changing or clearing the Local tile server base URL must clear the full capability snapshot as it does today. [L2] [L9]
4. Add a small persisted Riverpod settings state for the two enabled values and two integer opacity values. It must use an injectable `SharedPreferences` loader, matching existing provider test seams, and must keep the previous valid in-memory value if persistence fails. [L3] [L5]
5. Resolve overlay eligibility with the existing `basemapsForDrawer` point and `isLocalTopoAvailableForBounds` bounds logic rather than introducing a separate selected-region concept. [L10]
6. Build overlay `TileLayer` instances independently of `buildBasemapTileLayer`, use the Local tile server's resolved relative templates, and disable app tile-cache integration for both. Compose them only while the live map has Tasmania point-and-bounds eligibility. The relief layer receives its persisted opacity; contour rendering must preserve transparent pixels and receives its separate opacity. [L5] [L10] [L11] [L12]
7. Server rendering must expose relief-only and contour-only tile routes or equivalent gateway-backed routes. The contour renderer owns the established zoom-tier visibility and omits labels; it must not expose the complete Local Topo style as an overlay. [L6] [L13]
8. Route transport exceptions, 15-second tile request timeouts, and HTTP 5xx tile failures through an injectable tile provider and a shared, concurrency-safe, deduplicated overlay-specific error reporter. It must not report 4xx or no-data tiles. Reset one-message suppression only after the relevant overlay is disabled or Settings capability validation succeeds, so a later independent outage can be surfaced once. [L8]

## Testing Strategy

1. Use TDD for capability parsing, persisted overlay settings, availability resolution, layer composition, and tile-failure classification. Keep external tile fetching deterministic through the existing Local Topo runtime snapshot fixtures and fake tile providers; automated Flutter tests must not call a real local tile server. The fake overlay tile provider must deterministically emit transport exceptions, 15-second timeout expiry, HTTP 4xx, HTTP 5xx, and successful responses. [L2] [L5] [L8] [L9]
2. Add Local Topo Node tests for v2 capabilities and overlay tile routes: validate the server advertisement, transparent relief-only rendering, contour-only output, zoom 11/12/13 tier behavior, no contour labels, and compatibility with the existing v1 fixture. Use committed deterministic rendered PNG fixtures with alpha and expected-or-absent pixel assertions to prove those standalone rendering properties. [L6] [L9] [L13]
3. Extend Dart unit tests for v1 and v2 capability parsing, the exact accepted key-and-label pairs, stored snapshot restore with and without `overlays`, rejection of only individually malformed overlay declarations, invalidation of an entire overlay key for duplicate accepted keys or duplicate region declarations, base-URL invalidation, Tasmania point-and-bounds eligibility, live layer removal outside eligible Tasmania, and non-cacheable overlay URL resolution. [L2] [L9] [L10] [L11]
4. Add provider tests using mocked `SharedPreferences` for defaults, independent restoration, slider values, valid direct entry persistence, invalid-entry reversion, and persistence-failure in-memory behavior. [L3] [L5]
5. Add map drawer/widget tests with stable keys for the `Overlays` section, both switches, both opacity controls, v1 hidden state, a partially advertised v2 response with the unavailable control disabled and showing `Unavailable from the local tile server`, Local Topo disabled `Included in Local Topo` states with hidden opacity controls, and correct relief-before-contours layer ordering. [L3] [L7] [L12]
6. Extend the map basemap robot journey with a validated Tasmania v2 capability fixture. Verify selecting `TasMap 25K`, independently enabling both overlays, changing opacity, selecting `Local Topo` without duplicate layers, selecting another Tasmania basemap to restore choices, and removing layers without clearing choices outside Tasmania. [L1] [L3] [L4] [L7] [L10]
7. Verify tile failure notification deduplication with a controllable fake tile provider: one overlay-specific message per transport exception, 15-second timeout expiry, or HTTP 5xx outage; no message for 4xx/no-data; preserved switches and basemap; no suppression reset after individual successful tile responses; and suppression reset only after Settings capability validation succeeds or the relevant overlay is disabled. [L8]
8. Manually inspect desktop and mobile drawer layouts at enlarged text scale to confirm labels, switches, slider, and integer field remain reachable and readable. [L3] [L5]
9. Run `flutter analyze`, `flutter test`, and `npm test` from `local_topo/tasmania` before completion.

## Out of Scope

- An in-app DEM picker, raw DEM file access, or per-feature DEM source selection.
- True 3D terrain, a pitched camera, terrain extrusion, contour labels, or any Local Topo labels and cartography in either overlay.
- Overlay support outside Tasmania.
- Offline download or caching of overlay tiles.
- An in-app contour interval selector.
- Changing existing TasMap tile sources, their attribution, or the full Local Topo basemap rendering.

## Notes

- `Contour lines` is the canonical reusable overlay term. `Contour cartography` remains the name for the complete Local Topo style-layer presentation.
- Relevant code and test seams: `lib/services/local_topo_runtime.dart`, `lib/services/region_manifest_catalog.dart`, `lib/screens/map_screen_layers.dart`, `lib/widgets/map_basemaps_drawer.dart`, `test/services/local_topo_runtime_test.dart`, and `test/robot/map/basemap_selection_journey_test.dart`.
