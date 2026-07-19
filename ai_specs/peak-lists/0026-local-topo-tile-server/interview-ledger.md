---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Is this request for a new `Peak Bagger` basemap source inside this Flutter app, or for a separate local map stack outside the app?

Recommended Answer:
- Add a project-managed local basemap source inside `Peak Bagger`.
- Keep the Flutter app on its current `XYZ` tile-cache path.
- Do not add direct vector-tile, WMS, or custom CRS rendering logic to the app.

Answer: agreed

Decision: The feature is an in-app `Peak Bagger` basemap integration that must preserve the current raster `XYZ` app contract.

### L2

Status: current

Question: Should `Maputnik`-style editing be a developer-maintained authoring workflow, or a user-facing feature inside `Peak Bagger`?

Recommended Answer:
- Use `Maputnik` only as an external developer tool to author and preview the canonical basemap style.
- Commit the resulting style JSON and any required sprite or glyph assets.
- Serve one app-owned rendered raster `XYZ` basemap to `Peak Bagger`.
- Do not let app users edit styles, upload styles, or switch raw style JSON at runtime in this feature.

Answer: agreed

Decision: `Maputnik` is a developer-only style authoring workflow, not a user-facing app feature.

Negative Requirements:
- No in-app style editor.
- No user-uploaded style JSON.

### L3

Status: current

Question: Should the local topo basemap cover only project-managed hiking regions, or broad or planet-scale coverage?

Recommended Answer:
- Scope coverage to project-managed hiking regions only.
- Fall back to existing basemaps outside managed regions.
- Do not attempt planet-scale local hosting in this feature.

Answer: agreed

Decision: `Local Topo` is region-scoped and existing basemaps remain the fallback outside covered regions.

### L4

Status: current

Question: What should `local tile server` mean in this project, and what should happen if it is unavailable?

Recommended Answer:
- `Local tile server` means a separately run project-managed HTTP service reachable by the app as a normal `XYZ` basemap host.
- The app must not depend on `localhost` in production use, though localhost is acceptable for development.
- If the selected `Local Topo` server is unavailable or slow, keep the current basemap selection, do not crash, and do not auto-switch.
- Users can manually switch to another basemap.

Answer: agreed

Decision: The app integrates with an external project-managed HTTP tile service and treats failures like any other basemap outage without auto-failover.

Negative Requirements:
- No embedded Flutter renderer.
- No automatic basemap failover.

### L5

Status: current

Question: Should `Local Topo` be produced by a dynamic render stack, and what source data should it use?

Recommended Answer:
- Use a dynamic server-side render stack.
- Use region-scoped `Geofabrik` `.osm.pbf` extracts as the canonical OSM feature source.
- Use a separate DEM source for contours.
- Keep the app on raster `XYZ` tiles rather than direct vector tiles.

Answer: agreed

Decision: The canonical stack uses region-scoped `Geofabrik` OSM extracts plus a separate DEM-derived contour source and serves rendered raster `XYZ` tiles to the app.

### L6

Status: current

Question: How should regional source data be updated?

Recommended Answer:
- Use scheduled fresh regional downloads in the first version.
- Rebuild from fresh region-scoped extracts on a fixed cadence plus a manual refresh path.
- Do not run `Osmosis` or replication diffs in the first version.

Answer: agreed

Decision: V1 uses scheduled fresh source refreshes and manual rebuilds rather than replication-diff infrastructure.

### L7

Status: current

Question: Should the first version standardize on a containerized external tile stack rather than a custom Dart tile server, and how should the build stack look?

Recommended Answer:
- Use a Docker Compose-managed external stack.
- Build regional vector tile artifacts with `Planetiler`.
- Generate contour vector tiles from the chosen DEM source.
- Render raster `XYZ` tiles from the committed `Maputnik`-authored style with `TileServer GL` or `tileserver-gl-light`.
- Keep `PostGIS` + `osm2pgsql` only as a possible future version.

Answer: agreed

Decision: V1 uses a containerized external tile stack with prebuilt regional artifacts and carries `PostGIS` + `osm2pgsql` only as a future alternative.

### L8

Status: current

Question: How should `Peak Bagger` discover and validate the local tile server?

Recommended Answer:
- Add one persisted Settings value labeled `Local tile server base URL`.
- Treat the setting as configured only after the URL is syntactically valid and a live capability check succeeds.
- The capability response must confirm a compatible `Peak Bagger` local tile server, the regions that expose `Local Topo`, the canonical route name, and optional future style variants.
- If validation fails, show the error in Settings and do not surface `Local Topo` in the basemap drawer.
- Do not use mDNS, automatic LAN discovery, or continuous background probing.

Answer: agreed

Decision: `Local Topo` availability is driven by a validated persisted `Local tile server base URL` plus a live server capability contract.

Negative Requirements:
- No automatic host discovery.
- No background health polling.

### L9

Status: current

Question: How should `Local Topo` appear in the basemap drawer, and how should style variants be handled?

Recommended Answer:
- Use one logical basemap label: `Local Topo`.
- Show it only when the current region has a supported local topo route on the validated server.
- Keep v1 to one canonical style.
- Treat future style variants as separate basemap entries such as `Local Topo Dark`, each backed by its own committed style JSON and server route.

Answer: agreed

Decision: V1 exposes one logical `Local Topo` basemap with one canonical style, while future style variants become separate basemap entries.

### L10

Status: current

Question: Which managed region should v1 support first?

Recommended Answer:
- Start with `Tasmania` only.
- Prove the full end-to-end path there before expanding to other regions.

Answer: agreed

Decision: V1 is Tasmania-only for `Local Topo` coverage.

### L11

Status: current

Question: Should the first version require authentication?

Recommended Answer:
- Require no app-managed authentication in v1.
- Assume the server runs in a trusted same-user or trusted-LAN environment.
- Leave stronger network controls to user-managed infrastructure outside the app.

Answer: agreed

Decision: V1 stores only the server base URL and does not add app-managed auth fields, secrets, or custom auth headers.

### L12

Status: current

Question: For Tasmania v1, should contour generation standardize on the existing `theLIST` 25m DEM workflow in this repo?

Recommended Answer:
- Use the existing `tool/download_tasmania_thelist_dem.dart` workflow as the starting point.
- Use `theLIST` 25m DEM as the canonical Tasmania contour source.
- Carry alternative DEM sources only as future expansion or fallback work.

Answer: agreed

Decision: Tasmania v1 contour generation uses the existing repo-supported `theLIST` 25m DEM workflow.
