---
type: Work Item
title: Publish Tasmania Overlay Tiles
parent: ../spec.md
---

## What to build

Extend the Tasmania Local Topo server from its v1 Local Topo-only capability response to v2, retaining its `localTopo` basemap declaration and adding the top-level `overlays` list. Publish separately addressable transparent raster XYZ routes for `terrainReliefShading` / `Terrain relief shading` and `contourLines` / `Contour lines`, using prepared `ELVIS topo DEM` artifacts from the selected Local Topo build metadata rather than the raw `Elvis 2m DEM` TIFF.

The standalone relief route must contain only DEM-derived relief, never Local Topo labels, routes, other OSM cartography, or contours. The standalone contour route must use the selected build's prepared contour data, normally 10 m with the existing 25 m fallback where required; it must have no client-side interval selector, render nothing below zoom 12, render only 50 m and 100 m tiers at zoom 12, add minor contours from zoom 13, and never render contour labels.

## Required context

- `local_topo/tasmania/server/app.mjs` and `local_topo/tasmania/fixtures/capabilities.json` define the gateway and current v1 contract.
- `local_topo/tasmania/config/tileserver-config.json`, `local_topo/tasmania/styles/local-topo/`, and `local_topo/tasmania/scripts/prerender_tiles.mjs` define the server rendering and prepared tile inputs.
- `local_topo/tasmania/tests/server.test.mjs` is the Node gateway test convention.

## Acceptance criteria

- [x] `GET /capabilities` advertises version 2 while retaining the current `localTopo` basemap declaration and adds a top-level `overlays` list whose declarations have exactly `key`, `label`, and `regions`, with each region containing `regionKey` and `tilePathTemplate`.
- [x] The server advertises only `terrainReliefShading` with `Terrain relief shading` and `contourLines` with `Contour lines`; each accepted declaration has one or more region-scoped relative XYZ tile-path templates.
- [x] The gateway exposes relief-only and contour-only transparent raster XYZ tile routes or equivalent gateway-backed routes derived from the selected Local Topo build's prepared artifacts, without exposing the complete Local Topo style as either overlay.
- [x] Deterministic Node tests validate the v2 server advertisement, the existing v1 fixture compatibility, both overlay routes, relief-only transparent rendering, contour-only output, zoom 11/12/13 contour-tier behavior, and the absence of contour labels.
- [x] Committed deterministic rendered PNG fixtures use alpha and expected-or-absent pixel assertions to prove the standalone rendering properties.
- [ ] `npm test` passes from `local_topo/tasmania` (blocked by existing Martin preview compatibility assertions for the committed `Service tunnel` and `Service road outline` layers).

## Covers

- User Stories: 1-4
- Requirements: 4-6, 10
- Technical Decisions: 1-2, 7
- Testing Strategy: 2, 9
- Interview Ledger: L1, L4, L6, L9, L13

## Blocked by

None - ready to start
