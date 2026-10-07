---
type: Work Item
title: Resolve Route Elevation DEM from Mapping Catalog
parent: ../spec.md
---

## What to build

Move route-elevation DEM selection from legacy roots to the validated `MappingCatalog` and resolver. Tasmania-only routes use only `demSources.elvisRuntime`; retain injectable `gdal_dart` dataset and host-library seams and defer host-library failure until the DEM is opened.

## Required context

- Update `route_elevation_sampler.dart`, legacy DEM-root helpers/constants, and the map provider's elevation failure integration.
- `thelist25m` remains available to explicitly named maintainer workflows only. It is never a route-elevation fallback.

## Acceptance criteria

- [x] Resolve Tasmania route elevation exclusively through `DEM/Elvis/elvis_runtime_10m.tif` as `demSources.elvisRuntime`; a route not entirely in Tasmania has no runtime elevation source.
- [x] Missing, unreadable, malformed, or outside-root ELVIS data becomes the typed Mapping `DEM read` failure for the canonical DEM source, route geometry identity, and geometry version. It never falls back to `thelist25m` or another DEM.
- [x] Preserve in-process `gdal_dart` use and injected opener/library-resolution seams. Do not bundle GDAL/PROJ libraries/data and do not make a missing/incompatible host GDAL library a startup error.
- [x] When an elevation DEM is opened with a missing or incompatible host library, report exactly `RouteElevationSamplingException.tasmaniaDataUnavailable`.
- [x] Add deterministic unit/provider tests with fake `DemDatasetOpener` and host-library seams for successful sampling, Mapping failures, no fallback, and lazy host-library failure without a mounted store, GDAL install, or external DEM.

## Covers

- User Stories: 1, 2
- Requirements: 4, 9, 13, 25
- Technical Decisions: 2, 4, 9
- Testing Strategy: 4-5, 14
- Interview Ledger: L1, L3-L6, L9

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md

## Implementation and verification

- Runtime selection now receives the ready-scope `MappingCatalog`. The opaque
  dataset opener runs through `MappingStoreOperationFileAccess`, revalidating
  canonical containment and readability even for cached datasets. Failed opens
  and malformed raster samples invalidate the dataset cache for repaired retries.
- Draft point elevations and summary commit together after successful sampling.
  Failures retain prior results and geometry; the coordinator owns the `DEM read`
  key, original geometry/version, and retry. The stable route-planning unavailable
  controls persist after dialog dismissal, and stale retries cannot overwrite a
  newer draft. Single-flight dispatch uses microtasks rather than timers.
- `GdalDemDatasetOpener` injects host-library path resolution and loading, both
  deferred until open. The legacy `resolveTasmaniaDemRoot` remains explicitly
  documented as a maintainer-tool workspace pending Work Item 12's tool cutover.
- `flutter test --reporter expanded`: **2,065 passed, 5 skipped**.
- `flutter analyze`: nine existing diagnostics (two warnings and seven infos),
  confirmed against baseline commit `a5a9c64`; no new diagnostics.
- `flutter build macos --release`: succeeded. Inspected the resulting
  `build/macos/Build/Products/Release/peak_bagger.app`: code-signing entitlements
  do not enable `com.apple.security.app-sandbox`, and the bundle contains no
  GDAL/PROJ libraries or data.
- Mounted-store/manual packaged-app journeys were not performed. Source and
  host-library failure verification uses deterministic injected seams.
