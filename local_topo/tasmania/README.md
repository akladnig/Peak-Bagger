# Tasmania Local Topo Stack

This directory contains the first-version external `Local Topo` server stack for Tasmania.

The stack keeps the Flutter app on its existing raster `XYZ` contract while moving the server-side build and serve workflow into a separately run project-managed HTTP service.

## What is checked in

- A committed v1 `GET /capabilities` contract for `Peak Bagger`
- A small gateway service that exposes the exact Tasmania route shape `/tasmania/local-topo/{z}/{x}/{y}.png`
- A Docker Compose stack that pairs the gateway with `TileServer GL`
- A committed `Maputnik`-owned canonical style under `styles/local-topo/style.json`
- Rebuild entrypoints for manual and scheduled refreshes
- Deterministic tests and smoke verification that run from local fixtures instead of live `Geofabrik` or `theLIST` downloads

## Commands

Run the automated server-side tests:

```bash
npm test
```

Start the local stack on `http://127.0.0.1:8090`:

```bash
npm run stack:up
```

Run the committed smoke verification against the running stack:

```bash
npm run smoke
```

Stop the stack:

```bash
npm run stack:down
```

Preview the scheduled and manual rebuild paths without downloading or building real data:

```bash
npm run refresh:manual -- --dry-run
npm run refresh:scheduled -- --dry-run
```

## Real rebuild flow

The real rebuild path is intentionally separate from the deterministic smoke fixtures.

- OSM cartographic features come from the Tasmania `Geofabrik` extract.
- Contours reuse the repo-supported `dart run tool/download_tasmania_thelist_dem.dart` workflow.
- OSM vector tile artifacts are built with `Planetiler`.
- Contour vector tile artifacts are built from the merged DEM with `gdal_contour` and `tippecanoe`.
- The canonical style is committed here and intended to be authored in `Maputnik`, then served through `TileServer GL`.

`scripts/manual_refresh.sh` is the maintainer-driven rebuild entrypoint.

`scripts/scheduled_refresh.sh` is the fresh-download rebuild entrypoint for cron or launchd style scheduling.

## Style workflow

Use `styles/local-topo/style.json` as the canonical style source of truth.

- Edit the style in `Maputnik`.
- Export back into `styles/local-topo/style.json`.
- Commit any new sprite or glyph assets if the style grows symbol or icon layers.

The current v1 style keeps the server contract focused on Tasmania raster `XYZ` delivery and does not require checked-in binary sprite or glyph files yet. Placeholder `sprites/` and `fonts/` directories are included so future label and icon work can stay inside this stack boundary.
