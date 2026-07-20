---
type: Spec
title: Local Topo Tile Server
---

## Problem

`Peak Bagger` already supports region-scoped basemaps, offline tile caching, and a manifest-backed basemap drawer, but it does not yet have a project-managed local topographic basemap that combines OSM-derived cartography, contour lines, and a developer-owned custom style. The app also cannot currently point at a user-managed local topo host while preserving its existing raster `XYZ` tile contract, region filtering, and fallback basemap behavior. [L1] [L3] [L4] [L8]

## Proposed Outcome

Add a first-version `Local Topo` basemap for Tasmania that `Peak Bagger` consumes as normal raster `XYZ` tiles from a separately run project-managed `local tile server`. The server stack lives in `local_topo/tasmania/`, is configured outside Flutter, authored with a committed `Maputnik`-managed style, built from Tasmania `Geofabrik` OSM data plus `theLIST` 25m DEM-derived contours, and exposed to the app through one validated Settings value: `Local tile server base URL`. Existing manifest basemaps remain unchanged and continue to act as the fallback outside supported regions or when local topo is not configured. [L1] [L2] [L3] [L4] [L5] [L7] [L8] [L10] [L12]

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
8. Settings must expose explicit `Local tile server base URL` states: `Empty`, `Invalid URL syntax`, `Validating`, `Live validated`, `Restored snapshot`, and `Validation failed`. The saved value and current validation state must remain visible in Settings in every state. `Local Topo` must not appear in the basemap drawer in `Empty`, `Invalid URL syntax`, or `Validation failed`. `Live validated` and `Restored snapshot` may make `Local Topo` available subject to the accepted capability contract and viewport rules. `Validating` may continue using the most recently active validated or restored snapshot until the in-flight validation succeeds or fails. `Save` and `Retry` must be disabled while validation is in flight. `Retry` must be enabled only when a persisted non-empty URL exists. `Clear` must remove `Local Topo` availability and return the app to existing basemap-only behavior. If `Local Topo` is currently selected when the setting is cleared or a revalidation attempt fails, the app must immediately switch the active basemap to `Tracestrack Topo` as the existing safe fallback. [L8]
9. The live capability contract must confirm all of the following before `Local Topo` becomes available: [L8]
   - `service` is exactly `peak-bagger-local-topo`
   - `version` is exactly `1`
   - the response contains one compatible `localTopo` basemap contract for the canonical `Local Topo` app-owned basemap
   - the compatible `localTopo` basemap contract advertises one or more supported regions using app-canonical region keys
   - the compatible `localTopo` basemap contract advertises the tile path template the app must resolve against the validated base URL
10. The local tile server must expose a stable capability endpoint at `GET /capabilities` returning JSON. For v1, the app must require:
   - a top-level string field `service`
   - a top-level integer field `version`
   - a top-level array field `basemaps`
   - one basemap entry with `key` exactly `localTopo`
   - that basemap entry to use `label` exactly `Local Topo`
   - that basemap entry to include a non-empty `regions` array
   - each accepted region entry to include:
     - `regionKey`, which must exactly match an existing app canonical region key such as `tasmania`
     - `tilePathTemplate`, which must be a relative tile path template containing `{z}`, `{x}`, and `{y}`

The local tile server should return JSON matching the v1 contract, for example:

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

The app may ignore unknown additional top-level fields, unknown additional basemap fields, and unknown region entries for forward compatibility. However, the app must reject the capability response if the required `localTopo` contract is missing, if required fields are malformed, or if no accepted region entries remain after validation. [L8] [L9] [L10]
11. The basemap drawer must show one logical `Local Topo` entry only when the current visible map bounds intersect at least one supported `Local Topo` region from the accepted capability response. V1 must not show a disabled `Local Topo` row in the drawer. The app must use viewport-region intersection for this `Local Topo` availability decision rather than a single cursor-point or map-center lookup. Existing manifest-backed basemap availability rules remain unchanged in v1 unless separately specified. [L8] [L9] [L10]
12. The actual tile route must resolve by region behind the scenes from the validated base URL plus the capability-advertised tile path template. V1 must support the Tasmania route shape `/tasmania/local-topo/{z}/{x}/{y}.png`. [L9] [L10]
13. If a newly accepted capability response does not advertise `Local Topo` support for any region intersecting the current visible map bounds, `Local Topo` must not appear in the basemap drawer for that viewport. If `Local Topo` is currently selected when that visible-bounds support is removed by the accepted capability response, the app must immediately switch the active basemap to `Tracestrack Topo`. A viewport change caused only by panning or zooming must hide `Local Topo` from the basemap drawer when unsupported for the new viewport, but it must not auto-switch the active basemap by itself. [L9] [L10]
14. If the user selects `Local Topo` and tile requests later fail, time out, or return temporary server errors while the validated settings and accepted capability contract remain in place, the app must behave like any other basemap outage: no crash, no automatic switch to a different basemap, and the current selection remains `Local Topo` until the user changes it manually. [L4]
15. The app must not continuously probe the local tile server in the background. Live capability validation should run only when the user saves the Settings value and when the user explicitly retries validation. App launch may restore the last successful persisted capability snapshot, but it must not trigger an automatic live validation request in v1. [L8]
16. The app must persist both the saved `Local tile server base URL` and the last successful local-topo capability snapshot. On app launch, if a previously successful capability snapshot exists for the saved base URL, the app must restore that snapshot without performing an automatic network probe and may use it to determine `Local Topo` availability until the user saves the URL again, explicitly retries validation, or clears the setting. Restored availability represents the last successfully validated server state, not a guarantee that the server is currently reachable. [L8]
17. V1 must require no app-managed authentication. The app must not add username/password fields, bearer tokens, API keys, or custom auth headers for `Local Topo`. [L11]
18. For the current checked-in macOS Flutter target, v1 must include any required platform networking configuration so trusted local or LAN `http://` `Local tile server base URL` values can be validated and used for tile requests. If the app continues to allow non-HTTPS hosts in v1, `http` support is not optional on that target. [L4] [L8]
19. Build the local topo source stack from separate data inputs: [L5] [L12]
    - a region-scoped `Geofabrik` `.osm.pbf` extract for OSM cartographic features
    - a separate DEM-derived contour source
20. For Tasmania v1, the contour source of truth must be the repo-supported `theLIST` 25m DEM workflow starting from `tool/download_tasmania_thelist_dem.dart`. [L12]
21. V1 source refresh must use scheduled fresh region downloads plus a manual refresh path. It must not require `Osmosis`, replication diffs, or other long-lived change-feed state. [L6]
22. V1 server architecture must be a containerized external tile stack rooted at `local_topo/tasmania/`, not a custom Dart tile renderer in this repo. The stack must: [L7]
    - build Tasmania OSM vector tile artifacts with `Planetiler`
    - build Tasmania contour vector tile artifacts from the merged `theLIST` DEM
    - render raster `XYZ` PNG tiles from the committed canonical style with `TileServer GL` or `tileserver-gl-light`
23. Existing manifest-backed basemaps must remain intact. V1 must add one checked-in app-owned basemap key `localTopo` for `Local Topo` to the app's generated basemap catalog so the current enum-, drawer-, and cache-based basemap architecture stays in place. The checked-in catalog entry must use a fixed non-routable placeholder `tileUrl` and a fixed checked-in attribution string for v1. The app must not rewrite the checked-in region manifest per user host. Instead, it must resolve the effective `Local Topo` tile URL at runtime from the validated `Local tile server base URL` plus the capability-advertised tile path template. The checked-in placeholder catalog URL is identity-only and must not be used for live `Local Topo` tile requests once a validated capability snapshot exists. [L1] [L8] [L9]
24. The app must expose one shared source of truth for the effective `Local Topo` tile URL or tile path template after validation. Map rendering, manual tile-cache download flows, and any browse or download URL transformation used by the tile-cache stack for `Local Topo` must all use that same resolved runtime contract. [L1] [L8] [L9]
25. `Local Topo` must participate in the existing basemap-specific tile-cache architecture in v1, but it must be excluded from automatic startup low-zoom warmup. Tile-cache Settings must hide or disable `Local Topo` until a last successful capability snapshot exists for the saved `Local tile server base URL`. After a successful validation snapshot exists, manual cache download and clear flows may operate on `Local Topo` using the shared resolved runtime tile URL contract rather than the placeholder catalog URL. [L8]

## Technical Decisions

1. Keep the generated region manifest catalog and generated `Basemap` enum as the runtime source of truth for basemap identity, ordering, and selection state. Add one checked-in `Local Topo` basemap entry for v1 with a fixed placeholder `tileUrl` and fixed checked-in attribution, then gate its visibility and runtime tile URL through validated settings and capability data rather than through per-user manifest edits. Use one shared app-side resolver for the effective `Local Topo` runtime tile contract so rendering and cache flows stay aligned. This preserves the current basemap architecture while avoiding a broader dynamic-basemap refactor. [L1] [L8] [L9]
2. Model `Local Topo` as one canonical v1 basemap label and one canonical style, even though the server capability shape should allow future style variants and future supported regions. [L9] [L10]
3. Prefer a capability-driven server contract over host guessing or LAN discovery so the app can validate compatibility, region support, and future extensibility deterministically. [L8]
4. Use a build-and-serve regional tile pipeline rather than a continuously updated live render database in v1. The heavier `PostGIS` + `osm2pgsql` alternative remains a future option only if update frequency or server-side query needs justify the extra operational complexity. [L6] [L7]
5. Treat server trust and network hardening as infrastructure concerns outside the Flutter app in v1. The app contract is intentionally limited to a base URL plus validation. [L4] [L11]
6. `Local Topo` availability in the basemap drawer should follow viewport-region intersection rather than the app's current point-scoped basemap drawer lookup. This applies to the app-owned `Local Topo` decision path only in v1 and does not, by itself, redefine the existing availability rules for other manifest-backed basemaps. [L9] [L10]
7. Keep `Local Topo` inside the current tile-cache/store architecture so manual offline caching remains available, but explicitly exclude it from automatic startup warmup because its host is user-managed and validated separately from app launch. [L8]
8. Place the non-Flutter tile stack under `local_topo/tasmania/` so the committed style assets, container orchestration, rebuild entry points, and automated server-side tests live beside the Tasmania-specific pipeline they verify. [L7] [L12]

## Testing Strategy

1. Add app-side unit or service coverage for `Local tile server base URL` parsing, capability response parsing, region support filtering, and the rule that `Local Topo` remains hidden until validation succeeds. [L8] [L9] [L10]
2. Add widget or provider coverage for the Settings flow that saves, validates, persists, restores, retries validation, and clears `Local tile server base URL` without affecting existing basemap settings flows. Cover the explicit Settings states `Empty`, `Invalid URL syntax`, `Validating`, `Live validated`, `Restored snapshot`, and `Validation failed`, including which actions remain enabled, which validation or stale-state messages remain visible, and whether the last successful capability snapshot remains active in each state. Cover launch-time restoration of the last successful capability snapshot without an automatic live probe, plus the tile-cache Settings rule that `Local Topo` stays hidden or disabled until a successful capability snapshot exists. [L8]
3. Add widget coverage for the basemap drawer proving `Local Topo` appears when the visible bounds intersect supported Tasmania local-topo coverage after successful validation, stays hidden when the viewport does not intersect supported coverage, and reuses the existing stable basemap option key pattern for journey coverage. [L3] [L8] [L9] [L10]
4. Add app-side regression coverage for both classes of failure behavior: selecting `Local Topo` must not auto-switch on tile-fetch failure from an otherwise valid server contract, but the app must immediately fall back to `Tracestrack Topo` when the `Local Topo` configuration is cleared, revalidation fails, or accepted capabilities remove support for the current region. Prefer deterministic fake tile or HTTP seams over real network calls. [L4] [L8] [L9] [L10]
5. Add server-side automated coverage under `local_topo/tasmania/` for the capability endpoint contract, Tasmania tile route resolution, no-auth operation, and scheduled/manual rebuild entry points using deterministic local fixtures rather than live `Geofabrik` or `theLIST` network calls. [L6] [L7] [L11] [L12]
6. Add app-side regression coverage proving `Local Topo` is excluded from automatic startup low-zoom warmup while still participating in manual cache-management flows after successful validation. [L8]
7. Add one robot journey covering the main Flutter flow: configure a valid local tile server URL, validate it successfully, open the basemap drawer on a Tasmania viewport that intersects supported local-topo coverage, select `Local Topo`, and confirm the journey completes through the normal basemap-selection path. [L8] [L9] [L10]
8. Keep automated tests free of live secrets, live LAN dependencies, and real tile-server availability. Prefer provider overrides, fake HTTP clients, fixture capability payloads, and deterministic server test seams. [L8] [L11]

## Verification

1. Run `flutter analyze`.
2. Run focused Flutter tests covering Settings, basemap drawer behavior, and any new local-topo service or provider logic.
3. Run the relevant robot journey for configuring and selecting `Local Topo`.
4. In `local_topo/tasmania/`, run the committed automated server test command.
5. In `local_topo/tasmania/`, run the committed stack start command and the committed smoke command for the local topo stack.
6. The server smoke verification must prove all of the following:
   - `GET /capabilities` returns the required v1 contract
   - one Tasmania tile route such as `/tasmania/local-topo/{z}/{x}/{y}.png` returns `200`
   - no app-managed authentication is required
   - tests and smoke coverage use deterministic local fixtures rather than live `Geofabrik` or `theLIST` network calls

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

1. Likely Flutter implementation surfaces include `lib/widgets/map_basemaps_drawer.dart`, `lib/screens/settings_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/services/region_manifest_catalog.dart`, `lib/generated/region_manifest_catalog.g.dart`, `lib/services/tile_cache_service.dart`, and the current persisted settings patterns already used elsewhere in the app.
2. Existing basemap drawer tests already use `Key('basemap-option-<key>')`, which should remain the stable selector pattern for `Local Topo` and any future variants.
3. The existing Tasmania DEM acquisition workflow in `tool/download_tasmania_thelist_dem.dart` should be reused rather than replaced for v1 contour-source acquisition.
4. The current basemap drawer implementation in `lib/screens/map_screen.dart` and `lib/widgets/map_basemaps_drawer.dart` still uses point-scoped availability based on `cursorPoint ?? center`. This Spec includes the viewport-intersection basemap-drawer update needed for `Local Topo` rather than deferring it.
