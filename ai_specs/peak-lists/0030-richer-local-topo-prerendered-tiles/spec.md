---
type: Spec
title: Richer Local Topo Pre-Rendered Tiles
---

## Problem

The current Tasmania `Local Topo` stack depends on live style-backed raster rendering and serving, which is the main timeout and runtime bottleneck rather than vector `MBTiles` generation itself. At the same time, the current committed style is intentionally sparse and does not yet approach the information density or terrain depth users expect from richer basemaps such as OSM or Tracestrack. `Peak Bagger` needs a richer project-owned topo basemap without changing its existing app-facing HTTP `XYZ` contract or adding a second basemap concept for pre-rendered delivery. [L1] [L2] [L3] [L4] [L7] [L13]

## Proposed Outcome

Upgrade Tasmania `Local Topo` to a richer project-owned topographic basemap that the app continues to consume as the same HTTP `XYZ` basemap under the same capability and tile-route contract, while shifting production delivery to a pre-rendered static `XYZ` PNG tileset and retaining on-demand rendering only for developer and maintenance workflows. The richer style adds DEM-derived `terrain relief shading`, closer contours when viable, more detailed hiking-oriented transport cartography, and selected labels for places, roads or tracks, and major water features, while excluding peak or summit labels so app-owned peak rendering remains the only peak presentation layer. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10] [L11] [L12]

## User Stories

1. As a `Peak Bagger` user, I keep selecting the same `Local Topo` basemap through the existing app contract and do not need to know whether the backend is serving pre-rendered tiles or developer-mode on-demand rendering. [L1] [L2] [L3] [L4]
2. As a Tasmania user, I see a richer topographic basemap with terrain depth, closer contours when available, more detailed hiking-path visibility, and useful place or road or water labels, without duplicate peak labels from the basemap. [L5] [L7] [L8] [L10] [L11]
3. As a maintainer, I can generate a deterministic full Tasmania pre-rendered tileset for production, serve it behind the existing `Local Topo` HTTP contract, and avoid runtime render timeouts. [L4] [L5] [L6] [L12] [L13]
4. As a maintainer iterating on style changes, I can still use on-demand rendering for preview and maintenance work without changing the app-facing contract. [L3] [L4]
5. As a maintainer managing regional source inputs, I can keep DEM inputs fully local, refresh OSM data monthly when needed, and continue a scheduled rebuild with stale but valid OSM input if a refresh attempt fails. [L8] [L9]

## Requirements

1. Keep `Local Topo` as the existing user-facing basemap label. Do not introduce a second app basemap entry just for pre-rendered or offline delivery. [L1]
2. Broaden the backend concept to `Local Topo tile source`, but keep the app contract HTTP-based. `Peak Bagger` must continue to consume `Local Topo` as raster `XYZ` over a configured HTTP base URL and must not gain direct device-file, embedded `MBTiles`, or direct `PMTiles` reading in this slice. [L1] [L2]
3. Preserve one public HTTP contract across both delivery modes. `GET /capabilities` remains required, Tasmania tiles remain addressed as `/tasmania/local-topo/{z}/{x}/{y}.png`, and the app must not need to know whether the backend is serving pre-rendered tiles or on-demand renders. [L3] [L4]
4. Support two backend modes under the same public contract: pre-rendered raster tiles as the only production path, and on-demand rendering only as an explicit developer and maintenance mode for style iteration and spot checks. This slice must not require runtime mixed availability or automatic per-tile fallback between static and on-demand sources. [L4]
5. The canonical production artifact must be a static `XYZ` PNG tile tree laid out deterministically as `tasmania/local-topo/{z}/{x}/{y}.png`. Production serving may use a simple static HTTP host or lightweight gateway. Raster `MBTiles` or `PMTiles` must not become the primary production contract in this slice, and missing supported production tiles must fail as defects rather than falling back to on-demand rendering. [L5] [L6]
6. The production pre-rendered tileset must provide complete supported Tasmania coverage for zooms `0-16`. Missing tiles inside the supported footprint or zoom range are build or deployment defects, not normal runtime behavior. [L5]
7. Update the app-owned `Local Topo` basemap metadata to `maxZoom: 16`. This slice must not change the `GET /capabilities` schema to advertise max zoom. When `Local Topo` is selected, the app must not request native `z17+` `Local Topo` tiles; interactive zoom above `z16` may overzoom the highest supported tiles instead. [L5]
8. Target a richer project-owned `Local Topo` style that approaches OSM and Tracestrack information density without requiring pixel-for-pixel visual parity or cloning a third-party style exactly. [L7]
9. The richer style must include `terrain relief shading`: DEM-derived raster shaded relief blended into a north-up 2D topo basemap to create terrain depth. Do not require pitched camera views, true 3D terrain, or extruded terrain. [L7] [L8]
10. Manual and scheduled rebuild paths must not automatically fetch DEM data from the internet. Both rebuild modes must consume only pre-supplied local DEM input and fail clearly when no accepted local DEM is available. For this slice, an accepted local DEM means the configured local DEM file exists and the rebuild toolchain can read it successfully. Each rebuild must write simple source metadata beside the output identifying which DEM source was used. [L8]
11. DEM source priority for richer `Local Topo` builds must be:
    - a suitable higher-detail local DEM when available and viable for richer relief and contours
    - otherwise the local `theLIST 25m DEM` as the canonical fallback

    Local `Copernicus GLO 30` must remain reserve-only rather than the normal fallback when local `theLIST 25m DEM` is already available. [L8]
12. The richer contour target must prefer `10m` contours when the chosen local DEM supports acceptable output. If that is not viable, the build must fall back to `25m` contours from local `theLIST 25m DEM`. [L8]
13. OSM cartographic feature input may continue to use the Tasmania `Geofabrik` extract with automatic download allowed. The build must also allow a pre-supplied local OSM extract override for offline or pinned rebuilds. [L9]
14. Scheduled OSM refresh must be age-gated monthly. For this slice, a refresh is due when the local extract is older than `30` days by file modification time. Manual rebuild should keep reusing the local extract unless it is missing, unusable by the same checks, or explicitly force-refreshed. [L9]
15. For this slice, a local OSM extract is usable when it exists and exceeds the configured minimum size threshold. If a monthly OSM refresh is due but the `Geofabrik` download fails, scheduled rebuild must continue using the existing local extract only when it remains usable by those same checks, and must log clearly that stale OSM data was used. If no usable local extract exists, fail the rebuild. [L9]
16. The richer basemap must include labels for place and locality names, road and track labels where legible, and major named water features. It must not include peak or summit labels or symbols. App-owned peak markers, clusters, and labels remain the sole peak presentation layer. [L10]
17. The richer transport layer must be hiking-oriented and closer to Tracestrack than the current simplified roads-only style. It must include hiking paths and footways, tracks and unsealed access roads, and relevant service roads, with visible class or surface differentiation where source data supports it. [L11]
18. The first richer version must not require dedicated hiking-route overlays, colored trail-relation styling, or named route labels. Those capabilities should be preserved as explicit future-version enhancements. [L11]
19. The first richer pre-rendered version may use full Tasmania tileset rebuilds only. Incremental or changed-area-only tile regeneration is not required in this slice. [L12]
20. This feature must treat runtime raster rendering and serving as the current bottleneck to replace or avoid. It does not replace `Planetiler` or `tippecanoe` as the existing vector `MBTiles` generation tools unless future requirements explicitly change that scope. [L13]

## Technical Decisions

1. Use `Local Topo tile source` as the broader backend term while keeping `Local Topo` as the single user-facing basemap label. This preserves app language while allowing both static and on-demand backend implementations under one concept. [L1] [L4]
2. Keep the Flutter app on the existing HTTP `XYZ` contract and validated base-URL model. This minimizes app-side change, preserves existing tile-cache and basemap architecture, and keeps the pre-rendered migration as a backend swap rather than a second integration path. [L2] [L3]
3. Make pre-rendered static `XYZ` PNG tiles the only production backend and keep on-demand rendering only as an explicit developer and maintenance workflow, not a runtime production fallback path. [L4] [L6] [L13]
4. Cap the app-owned `Local Topo` basemap metadata at `maxZoom: 16` for the richer pre-rendered path without expanding the `GET /capabilities` schema. This keeps the contract aligned with the current contour-build ceiling and avoids the very large storage jump associated with `z17-z18` full Tasmania prerendering. [L5]
5. Keep DEM acquisition fully local and deterministic, while allowing OSM feature refresh to remain network-driven and maintenance-friendly through monthly age gating plus valid-stale fallback. [L8] [L9]
6. Treat the richer cartographic target as project-owned topo styling with DEM-based `terrain relief shading`, richer hiking transport detail, and selected labels, while explicitly excluding peak duplication from the basemap. [L7] [L8] [L10] [L11]
7. Defer dedicated hiking-route overlays, colored trail-relation styling, named route labels, and incremental prerender updates to later versions so the first richer release stays cohesive and buildable. [L11] [L12]

## Testing Strategy

1. Add deterministic server-side coverage for the shared HTTP contract in both delivery modes: `GET /capabilities` must remain valid without a max-zoom schema change, Tasmania tile routes must stay `/tasmania/local-topo/{z}/{x}/{y}.png`, pre-rendered production serving must return static PNG tiles without runtime fallback to on-demand rendering, and developer-mode on-demand rendering must remain available as a separate explicit workflow without changing the app-facing contract. [L3] [L4] [L6]
2. Add deterministic rebuild-script coverage for DEM and source-refresh policy: no automatic DEM internet fetches, correct local DEM source precedence, preferred-versus-fallback contour selection, DEM acceptance checks, `30`-day scheduled OSM refresh gating by file modification time, local OSM override behavior, OSM usability checks via the configured minimum size threshold, stale-valid OSM fallback when a scheduled refresh fails, and writing simple build metadata that records the DEM source used. Use local fixtures and fakes rather than live DEM or `Geofabrik` network calls. [L8] [L9]
3. Keep and update app-side regression coverage proving the Flutter contract stays the same: `Local Topo` remains an HTTP-based basemap, runtime URL resolution still uses the validated base URL plus capability-advertised path, the app-owned `Local Topo` basemap metadata now caps at `maxZoom: 16`, and `Local Topo` does not issue native `z17+` tile requests. Prefer existing unit, service, and widget test seams over new integration paths. [L2] [L3] [L5]
4. Retain the existing `Local Topo` selection journey as a regression seam. Robot or widget journey coverage should continue to prove that configuring and selecting `Local Topo` works through the normal app flow without the app needing to know whether the backend is static or on-demand. Use fake capability and tile seams rather than real LAN dependencies. [L3] [L4]
5. Add deterministic visual verification for representative Tasmania tiles across low, mid, and high supported zooms. Verification must cover visible `terrain relief shading`, contour density, hiking-path detail, place or road or water labels, and the absence of basemap peak labels. Prefer stable fixture-driven image comparison when feasible; otherwise capture an explicit manual screenshot review loop with committed expectations. [L5] [L7] [L8] [L10] [L11]

## Out of Scope

1. A second user-facing `Local Topo` basemap entry for pre-rendered or offline delivery. [L1]
2. Direct device-local file-tree tiles, embedded `MBTiles`, or direct `PMTiles` reading inside the Flutter app. [L2]
3. Any public HTTP contract change that would force the app to distinguish pre-rendered versus on-demand backend modes. [L3] [L4]
4. Production support for `z17+` `Local Topo` tiles in this richer pre-rendered slice. [L5]
5. Replacing `Planetiler` or `tippecanoe` as the current vector `MBTiles` generation tools. [L13]
6. True 3D terrain, pitched map camera behavior, or extruded terrain rendering. [L8]
7. Automatic DEM download from the internet in manual or scheduled rebuilds. [L8]
8. Peak or summit labels or symbols in the basemap. [L10]
9. Dedicated hiking-route overlays, colored trail-relation styling, or named route labels in the first richer version. [L11]
10. Incremental or changed-area-only prerender updates in the first richer version. [L12]

## Follow-Ups

1. Add dedicated hiking-route overlays, colored trail-relation styling, and named route labels in a future richer `Local Topo` version. [L11]
2. Revisit incremental prerender updates after the full Tasmania rebuild pipeline is stable and operationally proven. [L12]
3. Add richer local DEM inputs beyond `theLIST 25m DEM` when suitable higher-detail local sources become available and practical to maintain. [L8]
