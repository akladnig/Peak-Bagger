# Tasmania Local Topo Stack

This directory contains the first-version external `Local Topo` server stack for Tasmania.

The stack keeps the Flutter app on its existing raster `XYZ` contract while moving the server-side build and serve workflow into a separately run project-managed HTTP service.

## What is checked in

- A committed v1 `GET /capabilities` contract for `Peak Bagger`
- A small gateway service that exposes the exact Tasmania route shape `/tasmania/local-topo/{z}/{x}/{y}.png`
- Static delivery that serves pre-rendered PNG tiles from the deterministic `tasmania/local-topo/{z}/{x}/{y}.png` layout
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

This default stack mode keeps the public HTTP contract static. It prefers pre-rendered PNG tiles under `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png` and otherwise uses the committed deterministic smoke fixture under the same route layout. It does not fall back from missing static tiles to on-demand rendering.

Start the explicit preview stack that renders the committed style on demand from rebuilt `output/*.mbtiles` inputs:

```bash
npm run stack:up:preview
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
npm run refresh:manual -- --dry-run --skip-prerender
```

Select a prepared DEM source explicitly when you need something other than the default `ELVIS topo DEM`:

```bash
npm run refresh:manual -- --dem-source=elvis-topo
npm run refresh:manual -- --dem-source=thelist
npm run refresh:manual -- --dem-source=copernicus
npm run refresh:manual -- --dem-source=custom --dem-path=/absolute/path/to/tasmania-dem.tif
npm run refresh:manual -- --skip-prerender
```

## Real rebuild flow

The real rebuild path is intentionally separate from the deterministic smoke fixtures and from the explicit preview-only on-demand path.

- OSM cartographic features come from a local override extract when `LOCAL_TOPO_OSM_EXTRACT_OVERRIDE` is supplied, otherwise from the managed Tasmania `Geofabrik` extract cache.
- Scheduled rebuilds refresh the managed `Geofabrik` extract only when it is older than `30` days, and they can continue with stale but still-usable local data if a due refresh fails.
- Manual and scheduled rebuilds stay shell-script entrypoints and consume only prepared DEM inputs. They do not run `dart run`, invoke `./elvis_dem.sh`, or rescan the raw `Elvis 2m DEM` source TIFF inline.
- Rebuilds accept `--dem-source=elvis-topo|thelist|copernicus|custom` and default to `--dem-source=elvis-topo`.
- `--skip-prerender` keeps the MBTiles rebuild but skips `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png` static PNG generation.
- `--dem-source=custom` requires `--dem-path` as an absolute path to a readable `EPSG:28355` GeoTIFF.
- `elvis-topo` resolves to the prepared `ELVIS topo DEM` at `~/Documents/Bushwalking/DEM/Tasmania/elvis_topo/elvis_topo_5m.tif` when `~/Documents/Bushwalking` exists, otherwise `$HOME/DEM/Tasmania/elvis_topo/elvis_topo_5m.tif`. Override that path with `LOCAL_TOPO_ELVIS_TOPO_DEM_TIF` when needed.
- `thelist` resolves only from `LOCAL_TOPO_THELIST_DEM_TIF`, and `copernicus` resolves only from `LOCAL_TOPO_COPERNICUS_DEM_TIF`.
- Named sources and custom inputs must already be readable `EPSG:28355` GeoTIFFs for this slice. The rebuild scripts validate readability, do not inspect or reproject source CRS at runtime, and fail fast instead of auto-selecting or falling back to another DEM source.
- Contours and terrain relief always use the explicitly selected DEM for that rebuild. `thelist` uses the fallback contour interval directly; other selected DEMs prefer `10m` contours and fall back to the configured contour interval on the same DEM when needed.
- OSM vector tile artifacts are built with `Planetiler`.
- Contour vector tile artifacts are built from the selected DEM with `gdal_contour` and `tippecanoe`.
- DEM-derived `terrain relief shading` is built into `output/tasmania-relief.mbtiles` and blended into the richer `Local Topo` style during preview and prerender.
- Production-serving PNG tiles are expected under `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png`.
- Each rebuild writes `output/tiles/tasmania/local-topo/source-metadata.json` beside the prerendered tiles to record which DEM source was used.
- The canonical style is committed here and intended to be authored in `Maputnik`, then served through `TileServer GL`.

`scripts/manual_refresh.sh` is the maintainer-driven rebuild entrypoint.

`scripts/scheduled_refresh.sh` is the fresh-download rebuild entrypoint for cron or launchd style scheduling.

## Style workflow

Use `styles/local-topo/style.json` as the canonical style source of truth.

- Edit the style in `Maputnik`.
- Export back into `styles/local-topo/style.json`.
- Commit any new sprite or glyph assets if the style grows symbol or icon layers.

The richer style now uses committed `Roboto Regular` glyph assets for labels while keeping sprites out of scope so the app remains the sole peak presentation layer.

## Cartography Review

Run each localized MapTiler preview style in preview mode, capture the representative review tiles, and compare them against the committed variant-scoped expectations:

```bash
LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-maptiler-topo npm run stack:up:preview
npm run review:cartography -- --style-id=tasmania-maptiler-topo

LOCAL_TOPO_PREVIEW_STYLE_ID=tasmania-maptiler-outdoor npm run stack:up:preview
npm run review:cartography -- --style-id=tasmania-maptiler-outdoor
```

The review fixture is keyed by preview style id and saves each run under `runtime/review/cartography/<styleId>/` so `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` captures do not overwrite one another.

The printed guidance includes variant-specific notes for the representative low-, mid-, and high-zoom Tasmania tiles. Use those notes to confirm each preview still reads as a close visual port of MapTiler `Topo` or `Outdoor` while remaining a source-limited Tasmania-local style.
