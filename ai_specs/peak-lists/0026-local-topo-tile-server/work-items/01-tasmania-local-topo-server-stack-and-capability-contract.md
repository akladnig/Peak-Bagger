---
type: Work Item
title: Tasmania Local Topo Server Stack And Capability Contract
parent: ../spec.md
---

## What to build
Create the first-version `local tile server` stack under `local_topo/tasmania/` as the project-managed external Tasmania `Local Topo` pipeline. This slice must include the committed canonical `Maputnik`-authored style assets, deterministic containerized build-and-serve entrypoints, the `GET /capabilities` v1 contract, the Tasmania `XYZ` tile route shape `/tasmania/local-topo/{z}/{x}/{y}.png`, scheduled and manual rebuild paths, and automated server-side tests plus smoke commands that run from local fixtures rather than live `Geofabrik` or `theLIST` network calls.

## Required context
- `local_topo/` does not exist yet in this repo, so this item establishes the entire non-Flutter stack boundary described in the Spec rather than extending an existing server implementation.
- Reuse `tool/download_tasmania_thelist_dem.dart` as the Tasmania contour-source entrypoint rather than replacing the repo-supported `theLIST 25m DEM` workflow.
- Keep the stack containerized and external to Flutter. The Spec explicitly rejects a custom Dart tile renderer and keeps `PostGIS` + `osm2pgsql` out of scope for v1.
- Keep the capability payload and tile routes deterministic in tests. The server-side coverage should validate the exact required contract fields and Tasmania route shape without depending on LAN availability or upstream source downloads.

## Acceptance criteria
- [x] `local_topo/tasmania/` contains the committed v1 stack assets and entrypoints needed to build and serve Tasmania `Local Topo` as raster `XYZ` PNG tiles from a separately run project-managed HTTP service.
- [x] The canonical style is maintained as committed project assets authored through a developer-only `Maputnik` workflow, including any required style JSON, sprite assets, and glyph assets needed by the stack.
- [x] The data pipeline uses separate Tasmania source inputs: a region-scoped `Geofabrik` `.osm.pbf` extract for OSM cartographic features and a separate contour pipeline rooted in the repo-supported `theLIST` 25m DEM workflow.
- [x] The v1 server architecture uses `Planetiler` for Tasmania OSM vector tile artifacts, builds Tasmania contour vector tile artifacts from the merged DEM workflow, and renders raster `XYZ` PNG tiles through `TileServer GL` or `tileserver-gl-light`.
- [x] The server exposes `GET /capabilities` and returns JSON that satisfies the v1 app contract: top-level `service`, integer `version`, top-level `basemaps`, one `localTopo` basemap entry labeled exactly `Local Topo`, and at least one accepted Tasmania region entry containing `regionKey: tasmania` plus a relative `tilePathTemplate` with `{z}`, `{x}`, and `{y}`.
- [x] The live Tasmania tile route shape `/tasmania/local-topo/{z}/{x}/{y}.png` is served by the stack and returns `200` in the committed smoke flow.
- [x] The stack requires no app-managed authentication, and the automated tests and smoke coverage prove the no-auth contract explicitly.
- [x] The stack includes one scheduled fresh-download rebuild path and one manual refresh path, and neither path requires `Osmosis`, replication diffs, or other long-lived change-feed state.
- [x] Automated server-side coverage under `local_topo/tasmania/` proves the capability endpoint contract, Tasmania tile route resolution, no-auth operation, and scheduled/manual rebuild entrypoints using deterministic local fixtures.
- [x] The committed verification commands under `local_topo/tasmania/` are sufficient to run the server tests, start the stack, and execute the smoke verification described by the Spec.

## Covers
- User Stories: 3-4
- Requirements: 3-5, 9-10, 12, 17, 19-22
- Technical Decisions: 2-5, 8
- Testing Strategy: 5, 8
- Interview Ledger: L2, L4-L7, L10-L12

## Blocked by
None - ready to start
