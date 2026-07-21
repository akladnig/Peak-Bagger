---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this work keep `Local Topo` as the same user-facing basemap or introduce a separate pre-rendered/offline basemap concept?

Recommended Answer:
- Keep `Local Topo` as the existing basemap label.
- Broaden the backend concept from `Local tile server` to `Local Topo tile source`.
- Allow that tile source to be backed by either on-demand rendering or pre-rendered raster tiles.
- Do not add a second basemap entry just for pre-rendered tiles.

Answer: agreed

Decision: Keep one user-facing `Local Topo` basemap while broadening the backend concept to `Local Topo tile source`.

### L2

Status: current

Question: Should `Peak Bagger` continue to consume `Local Topo` through a configured HTTP base URL, or should it also support direct device-local tile reading with no HTTP service?

Recommended Answer:
- Keep the app contract HTTP-based.
- Support pre-rendered tiles only when they are served through a simple static HTTP host.
- Do not add direct device-file, embedded `MBTiles`, or direct `PMTiles` reading in this slice.

Answer: Keep Local Topo HTTP-based, even for pre-rendered tiles

Decision: `Local Topo` remains an HTTP `XYZ` basemap from the app's perspective, even when backed by pre-rendered tiles.

Negative Requirements:
- No direct on-device tile reading in this slice.

### L3

Status: current

Question: Should the pre-rendered `Local Topo` path keep the exact same public HTTP contract as today?

Recommended Answer:
- Keep the same public HTTP contract for both delivery modes.
- `GET /capabilities` remains required.
- The Tasmania tile route remains `/tasmania/local-topo/{z}/{x}/{y}.png`.
- The app should not need to know whether tiles come from on-demand rendering or pre-rendered static output.

Answer: agreed

Decision: Pre-rendered and on-demand `Local Topo` delivery must share the same public HTTP contract.

### L4

Status: current

Question: Should the Tasmania `Local Topo` stack switch fully to pre-rendered raster delivery, or should it support both backend modes under the same contract?

Recommended Answer:
- Support both modes under the same public HTTP contract.
- Make pre-rendered raster tiles the only production path.
- Keep on-demand rendering available only as an explicit developer and maintenance mode for style iteration and spot checks.
- Do not require runtime mixed availability or automatic per-tile fallback between static and on-demand sources in this slice.

Answer: agreed

Decision: Support both delivery modes under one contract, with pre-rendered tiles as the only production path and on-demand rendering retained only as an explicit developer and maintenance workflow.

### L5

Status: current

Question: What coverage and zoom contract should the pre-rendered `Local Topo` artifacts guarantee for Tasmania, especially for `z16+`?

Recommended Answer:
- Pre-render the full Tasmania supported footprint, not just a warmed cache.
- Guarantee complete raster coverage for zooms `0-16`.
- Cap `Local Topo` at `maxZoom: 16` end-to-end for the pre-rendered path.
- Treat missing tiles inside the supported footprint as build or deployment defects.

Answer: agreed

Decision: The pre-rendered production contract guarantees complete Tasmania coverage through `z16` and caps `Local Topo` at `maxZoom: 16`.

### L6

Status: current

Question: What should be the canonical pre-rendered production artifact behind the `Local Topo` HTTP contract?

Recommended Answer:
- Use a static `XYZ` PNG tile tree as the canonical production artifact.
- Build tiles into a deterministic path layout matching the public route shape: `tasmania/local-topo/{z}/{x}/{y}.png`.
- Serve those files through a simple static HTTP host or lightweight gateway.
- Do not make raster `MBTiles` or `PMTiles` the primary production contract in this slice.

Answer: agreed

Decision: The canonical production artifact is a static `XYZ` PNG tile tree laid out as `tasmania/local-topo/{z}/{x}/{y}.png`.

### L7

Status: current

Question: Should the goal for `Local Topo` be a richer project-owned map style that approaches OSM and Tracestrack detail, or should it stay a lighter custom topo basemap?

Recommended Answer:
- Target a richer project-owned `Local Topo` style that approaches OSM and Tracestrack detail in visible map information density.
- Do not require pixel-for-pixel parity with either upstream basemap.
- Keep `Local Topo` topographic and project-owned rather than cloning a third-party style exactly.

Answer: agreed

Decision: The upgraded `Local Topo` target is a richer project-owned topo style that approaches OSM and Tracestrack detail without requiring exact visual parity.

### L8

Status: current

Question: How should relief shading, contour density, and DEM sourcing work for the richer `Local Topo` build?

Recommended Answer:
- Use `terrain relief shading` as the canonical term for the Tracestrack-like depth effect.
- Allow a higher-resolution local DEM when available.
- Prefer `10m` contours when the chosen local DEM supports acceptable output.
- Fall back to local `theLIST 25m DEM` with `25m` contours otherwise.
- Do not attempt to fetch DEM data automatically from the internet.
- Treat local `theLIST 25m DEM` as the canonical fallback, with `Copernicus GLO 30` reserve-only rather than the default baseline.

Answer: agreed

Decision: Use DEM-derived `terrain relief shading`, prefer higher-detail local DEM input with `10m` contours when viable, otherwise fall back to local `theLIST 25m DEM` with `25m` contours, and never auto-download DEM input.

### L9

Status: current

Question: How should Tasmania OSM source refresh work for the richer pre-rendered stack?

Recommended Answer:
- Keep automatic `Geofabrik` OSM download allowed.
- Allow a local pre-supplied OSM extract as an override.
- Change scheduled refresh to an age-gated monthly refresh.
- If a monthly refresh is due but download fails, continue with the existing local extract when it still exists and passes validity checks.
- Fail only when no usable local extract exists.

Answer: agreed

Decision: Keep `Geofabrik` auto-download for OSM data, allow local override, gate scheduled refresh monthly, and fall back to a valid stale local extract when refresh fails.

### L10

Status: current

Question: Should the richer `Local Topo` style now include map labels and symbols closer to OSM and Tracestrack detail, and should peaks be included?

Recommended Answer:
- Include labels and selected symbols for place and locality names, road and track labels where legible, and major water-feature labels.
- Do not include peak or summit symbols or labels because those are already provided by the app's peak rendering.

Answer: agreed

Decision: The richer basemap includes labels for places, roads or tracks, and major water features, but explicitly excludes peak and summit labels or symbols.

### L11

Status: current

Question: What transport and hiking-route detail should the richer `Local Topo` style include?

Recommended Answer:
- Show a high-detail hiking-oriented transport layer closer to Tracestrack than the current simplified roads-only style.
- Include hiking paths and footways, tracks and unsealed access roads, and relevant service roads.
- Do not require dedicated hiking-route overlays, colored trail-relation styling, or named route labels in the first richer version.
- Carry those route-overlay features forward as a future-version note.

Answer: agreed

Decision: The richer style emphasizes detailed hiking-path and track geometry now, while deferring dedicated hiking-route overlays and route-label cartography to a future version.

### L12

Status: current

Question: Should the monthly richer `Local Topo` refresh rebuild the full Tasmania pre-rendered tileset each time, or require incremental tile updates now?

Recommended Answer:
- Use full Tasmania tileset rebuilds for the first richer pre-rendered version.
- Do not require incremental or changed-area-only tile regeneration in this slice.
- Carry forward dedicated hiking-route overlays, colored trail-relation styling, named route labels, and incremental prerender updates as future-version enhancements.

Answer: agreed

Decision: The first richer pre-rendered version uses full Tasmania tileset rebuilds and defers incremental prerender updates to a future version.

### L13

Status: current

Question: Is the current stack problem primarily `MBTiles` generation, or rendering and serving those tiles through the style-backed raster path?

Answer: Rendering and serving them, not generating the `MBTiles`

Decision: This change targets runtime raster rendering and serving as the primary bottleneck rather than the existing vector `MBTiles` generation tools.

Reason: `Planetiler` and `tippecanoe` generation are not the current failure point; the style-backed raster path is.
