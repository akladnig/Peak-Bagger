---
type: Spec
title: Local Topo Tile Server
---

## Problem

`Peak Bagger` already supports region-scoped basemaps, offline tile caching, and a manifest-backed basemap drawer, but it does not yet have a project-managed local topographic basemap that combines OSM-derived cartography, contour lines, and a developer-owned custom style. The app also cannot currently point at a user-managed local topo host while preserving its existing raster `XYZ` tile contract, region filtering, and fallback basemap behavior. [L1] [L3] [L4] [L8]

## Proposed Outcome

Add a first-version `Local Topo` basemap for Tasmania that `Peak Bagger` consumes as normal raster `XYZ` tiles from a separately run project-managed `local tile server`. The server is configured outside Flutter, authored with a committed `Maputnik`-managed style, built from Tasmania `Geofabrik` OSM data plus `theLIST` 25m DEM-derived contours, and exposed to the app through one validated Settings value: `Local tile server base URL`. Existing manifest basemaps remain unchanged and continue to act as the fallback outside supported regions or when local topo is not configured. [L1] [L2] [L3] [L4] [L5] [L7] [L8] [L10] [L12]

## User Stories

1. As a Tasmania user, I can configure a trusted local topo host once and then select `Local Topo` from the existing basemap drawer when I am in a supported region. [L3] [L8] [L9] [L10]
2. As a user outside supported local-topo coverage, I keep using the existing basemap set without extra setup noise or broken basemap entries. [L3] [L8] [L9]
3. As a maintainer, I can author the canonical topo style with `Maputnik`, commit the style assets, rebuild the regional tile stack on a schedule, and keep the Flutter app on its existing raster `XYZ` rendering path. [L1] [L2] [L5] [L6] [L7]
4. As a maintainer planning future expansion, I can add more supported regions or additional local topo style variants later without redesigning the v1 app contract. [L7] [L9] [L10]

## Requirements

1. Keep `Peak Bagger` on its existing raster `XYZ` basemap contract for this feature. The app must not gain direct vector-tile rendering, direct WMS rendering, or custom CRS logic for `Local Topo`. [L1]
2. Introduce one app-owned basemap concept labeled exactly `Local Topo`. V1 must expose one canonical style only. [L2] [L9]
3. `Maputnik` must be treated as a developer-only authoring tool. The canonical style JSON, plus any required sprite or glyph assets, must be committed as project-managed assets for the local tile stack. App users must not edit styles, upload style JSON, or switch arbitrary style files at runtime. [L2]
4. Scope `Local Topo` coverage to project-managed regions only. V1 must support `Tasmania` and no other region. Outside supported local-topo regions, the existing basemap list remains the only available fallback path. [L3] [L10]
5. Define `local tile server` as a separately run project-managed HTTP service that the app reaches as a normal `XYZ` basemap host. The feature must support localhost for development and non-localhost trusted LAN hosts for normal use. [L4]
6. Add a persisted Settings value labeled exactly `Local tile server base URL`. The value must store an `http` or `https` base URL only, without embedding region-specific tile path segments in the saved setting. [L8]
7. Treat `Local tile server base URL` as configured only after both validations pass: [L8]
   - the value parses as a syntactically valid `http` or `https` base URL
   - a live capability request to the local tile server succeeds and identifies a compatible `Peak Bagger` local topo service
8. When the saved URL is empty, invalid, or fails live capability validation, the app must keep the value and validation state visible in Settings, but `Local Topo` must not appear in the basemap drawer. Clearing the setting must remove `Local Topo` availability and return the app to existing basemap-only behavior. [L8]
9. The live capability contract must confirm at least the following before `Local Topo` becomes available: [L8]
   - this is a compatible `Peak Bagger` local tile server
   - the supported region keys for `Local Topo`
   - the canonical basemap route name for `Local Topo`
   - optional future style variants when supported by later versions
10. The local tile server must expose a stable capability endpoint for the validation flow. V1 should standardize on `GET /capabilities` returning JSON with enough data for the app to validate compatibility and supported regions, for example:

```json
{
  "service": "peak-bagger-local-topo",
  "version": 1,
  "basemaps": [
    {
      "key": "localTopo",
      "label": "Local Topo",
      "regions": [
        {
          "regionKey": "tasmania",
          "tilePathTemplate": "/tasmania/local-topo/{z}/{x}/{y}.png"
        }
      ]
    }
  ]
}
```

The app may ignore unknown additional fields so the server can evolve compatibly. [L8] [L9] [L10]
11. The basemap drawer must show one logical `Local Topo` entry only when the current region is supported by the validated capability response. V1 must not show a disabled `Local Topo` row in the drawer. [L8] [L9] [L10]
12. The actual tile route must resolve by region behind the scenes from the validated base URL plus the capability-advertised tile path template. V1 must support the Tasmania route shape `/tasmania/local-topo/{z}/{x}/{y}.png`. [L9] [L10]
13. If the user selects `Local Topo` and tile requests later fail or time out, the app must behave like any other basemap outage: no crash, no automatic switch to a different basemap, and the current selection remains `Local Topo` until the user changes it manually. [L4]
14. The app must not continuously probe the local tile server in the background. Capability validation should run when the user saves the Settings value and when the user explicitly retries validation. [L8]
15. V1 must require no app-managed authentication. The app must not add username/password fields, bearer tokens, API keys, or custom auth headers for `Local Topo`. [L11]
16. Build the local topo source stack from separate data inputs: [L5] [L12]
   - a region-scoped `Geofabrik` `.osm.pbf` extract for OSM cartographic features
   - a separate DEM-derived contour source
17. For Tasmania v1, the contour source of truth must be the repo-supported `theLIST` 25m DEM workflow starting from `tool/download_tasmania_thelist_dem.dart`. [L12]
18. V1 source refresh must use scheduled fresh region downloads plus a manual refresh path. It must not require `Osmosis`, replication diffs, or other long-lived change-feed state. [L6]
19. V1 server architecture must be a containerized external tile stack, not a custom Dart tile renderer in this repo. The stack must: [L7]
   - build Tasmania OSM vector tile artifacts with `Planetiler`
   - build Tasmania contour vector tile artifacts from the merged `theLIST` DEM
   - render raster `XYZ` PNG tiles from the committed canonical style with `TileServer GL` or `tileserver-gl-light`
20. Existing manifest-backed basemaps must remain intact. `Local Topo` should be introduced as an app-owned runtime basemap overlay driven by the validated settings and capability response rather than by rewriting the checked-in region manifest for each user host. [L1] [L8] [L9]

## Technical Decisions

1. Keep the generated region manifest catalog as the runtime source of truth for existing static basemaps, and merge one dynamic `Local Topo` basemap into the drawer only after successful settings validation. This avoids per-user manifest edits while preserving the current basemap architecture. [L1] [L8] [L9]
2. Model `Local Topo` as one canonical v1 basemap label and one canonical style, even though the server capability shape should allow future style variants and future supported regions. [L9] [L10]
3. Prefer a capability-driven server contract over host guessing or LAN discovery so the app can validate compatibility, region support, and future extensibility deterministically. [L8]
4. Use a build-and-serve regional tile pipeline rather than a continuously updated live render database in v1. The heavier `PostGIS` + `osm2pgsql` alternative remains a future option only if update frequency or server-side query needs justify the extra operational complexity. [L6] [L7]
5. Treat server trust and network hardening as infrastructure concerns outside the Flutter app in v1. The app contract is intentionally limited to a base URL plus validation. [L4] [L11]

## Testing Strategy

1. Add app-side unit or service coverage for `Local tile server base URL` parsing, capability response parsing, region support filtering, and the rule that `Local Topo` remains hidden until validation succeeds. [L8] [L9] [L10]
2. Add widget coverage for the Settings flow that saves, validates, shows error state, retries validation, and clears `Local tile server base URL` without affecting existing basemap settings flows. [L8]
3. Add widget coverage for the basemap drawer proving `Local Topo` appears for Tasmania only after successful validation, stays hidden when unsupported or invalid, and preserves the existing empty or fallback drawer behavior elsewhere. Reuse the existing stable basemap option key pattern for journey coverage. [L3] [L8] [L9] [L10]
4. Add app-side regression coverage for basemap failure behavior so selecting `Local Topo` does not crash the app and does not auto-switch on tile failure. Prefer deterministic fake tile or HTTP seams over real network calls. [L4]
5. Add server-side automated coverage for the capability endpoint contract, Tasmania tile route resolution, no-auth operation, and scheduled/manual rebuild entry points using deterministic local fixtures rather than live `Geofabrik` or `theLIST` network calls. [L6] [L7] [L11] [L12]
6. Add one robot journey covering the main Flutter flow: configure a valid local tile server URL, validate it successfully, open the basemap drawer on a Tasmania-centered map, select `Local Topo`, and confirm the journey completes through the normal basemap-selection path. [L8] [L9] [L10]
7. Keep automated tests free of live secrets, live LAN dependencies, and real tile-server availability. Prefer provider overrides, fake HTTP clients, fixture capability payloads, and deterministic server test seams. [L8] [L11]

## Verification

1. Run `flutter analyze`.
2. Run focused Flutter tests covering Settings, basemap drawer behavior, and any new local-topo service or provider logic.
3. Run the relevant robot journey for configuring and selecting `Local Topo`.
4. Run the local tile stack test suite or smoke checks for the capability endpoint and Tasmania tile route.

## Out of Scope

1. Direct vector-tile rendering, WMS rendering, or custom CRS support inside the Flutter app. [L1]
2. A user-facing style editor, user-uploaded style JSON, or arbitrary runtime style switching. [L2] [L9]
3. Planet-scale local hosting, unmanaged global coverage, or local-topo support outside project-managed regions in v1. [L3]
4. Automatic basemap failover, continuous background health polling, mDNS discovery, or LAN auto-discovery. [L4] [L8]
5. App-managed authentication, secret storage, or custom auth headers for the local tile server. [L11]
6. Replication-diff infrastructure such as `Osmosis` in v1. [L6]
7. A `PostGIS` + `osm2pgsql` live render database in v1. [L7]
8. Non-Tasmania `Local Topo` region support in v1. [L10]

## Follow-Ups

1. Add additional supported regions after the Tasmania pipeline, capability contract, and basemap visibility rules are proven stable. [L10]
2. Add future style variants such as `Local Topo Dark` as separate basemap entries backed by their own committed style JSON and advertised capability routes. [L9]
3. Revisit `PostGIS` + `osm2pgsql` only if faster regional updates, richer server-side querying, or more dynamic rendering needs emerge after v1. [L7]

## Notes

1. Likely Flutter implementation surfaces include `lib/widgets/map_basemaps_drawer.dart`, `lib/screens/settings_screen.dart`, `lib/services/region_manifest_catalog.dart`, `lib/services/tile_cache_service.dart`, and the current persisted settings patterns already used elsewhere in the app.
2. Existing basemap drawer tests already use `Key('basemap-option-<key>')`, which should remain the stable selector pattern for `Local Topo` and any future variants.
3. The existing Tasmania DEM acquisition workflow in `tool/download_tasmania_thelist_dem.dart` should be reused rather than replaced for v1 contour-source acquisition.
