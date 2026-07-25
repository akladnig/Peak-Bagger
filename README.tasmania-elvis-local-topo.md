# Tasmania ELVIS And Local Topo Workflow

This README is for maintainers who need to:

- validate the raw Tasmania ELVIS source
- build the prepared ELVIS DEM artifacts
- rebuild the Tasmania Local Topo stack
- run the local Tasmania topo server

## Inputs And Outputs

Raw source:

- `/Volumes/Media/Elvis/tas-elvis`

Prepared ELVIS outputs:

- `~/Documents/Bushwalking/DEM/Tasmania/elvis_runtime_10m.tif`
- `~/Documents/Bushwalking/DEM/Tasmania/elvis_topo/elvis_topo_5m.tif`

If `~/Documents/Bushwalking` does not exist, the outputs go under:

- `$HOME/DEM/Tasmania/`

Tasmania Local Topo output:

- `local_topo/tasmania/output/tiles/tasmania/local-topo/{z}/{x}/{y}.png`

## One-Time Prerequisites

You need these tools available on your machine:

- Flutter
- Node.js and npm
- GDAL tools such as `gdalinfo`, `gdalwarp`, `gdalbuildvrt`, `gdal_contour`, `gdaldem`, `ogr2ogr`, `gdal_translate`, and `gdaladdo`
- Docker

## 1. Validate Or Build ELVIS Artifacts

From the repo root:

```bash
./elvis_dem.sh validate-source
./elvis_dem.sh build-all
```

`./elvis_dem.sh` auto-builds the macOS maintainer binary on first run.

If you only need one artifact:

```bash
./elvis_dem.sh build-runtime
./elvis_dem.sh build-topo
```

Useful checks:

```bash
./elvis_dem.sh
./elvis_dem.sh build-topo --help
```

## 2. Rebuild Tasmania Local Topo

From `local_topo/tasmania`:

```bash
npm run refresh:manual
```

This defaults to:

```bash
--dem-source=elvis-topo
```

So if `./elvis_dem.sh build-topo` succeeded, no extra DEM flags are needed.

Dry-run preview:

```bash
npm run refresh:manual -- --dry-run
npm run refresh:scheduled -- --dry-run
```

## 3. Use Another DEM Source Explicitly

Named alternatives:

```bash
npm run refresh:manual -- --dem-source=thelist
npm run refresh:manual -- --dem-source=copernicus
```

Configure named-source paths with environment variables:

```bash
LOCAL_TOPO_THELIST_DEM_TIF=/absolute/path/to/thelist.tif
LOCAL_TOPO_COPERNICUS_DEM_TIF=/absolute/path/to/copernicus.tif
```

Custom DEM:

```bash
npm run refresh:manual -- --dem-source=custom --dem-path=/absolute/path/to/dem.tif
```

Rules for Local Topo DEM inputs in this slice:

- supported sources are exactly `elvis-topo`, `thelist`, `copernicus`, and `custom`
- `custom` requires `--dem-path`
- `--dem-path` must be an absolute path
- all selected DEM inputs must already be readable `EPSG:28355` GeoTIFFs
- rebuild scripts fail fast and do not auto-fallback to another DEM source

## 4. Run The Tasmania Local Topo Stack

From `local_topo/tasmania`:

```bash
npm run stack:up
```

Preview mode:

```bash
npm run stack:up:preview
```

Smoke test:

```bash
npm run smoke
```

Stop the stack:

```bash
npm run stack:down
```

## 5. Flutter App Runtime DEM

The macOS app resolves Tasmania route elevation from the prepared `ELVIS runtime DEM` automatically.

There is no in-app DEM file picker for this workflow. Once `./elvis_dem.sh build-runtime` or `./elvis_dem.sh build-all` has succeeded, the app uses the fixed maintainer-managed path.

## Fastest End-To-End Path

```bash
./elvis_dem.sh build-all
cd local_topo/tasmania
npm run refresh:manual
npm run stack:up
```

## Related Docs

- `local_topo/tasmania/README.md`
- `ai_specs/peak-lists/0032-elvis-tasmania-dem-derivation-and-adoption/spec.md`
