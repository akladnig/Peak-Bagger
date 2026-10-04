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

- [ ] Resolve Tasmania route elevation exclusively through `DEM/Elvis/elvis_runtime_10m.tif` as `demSources.elvisRuntime`; a route not entirely in Tasmania has no runtime elevation source.
- [ ] Missing, unreadable, malformed, or outside-root ELVIS data becomes the typed Mapping `DEM read` failure for the canonical DEM source, route geometry identity, and geometry version. It never falls back to `thelist25m` or another DEM.
- [ ] Preserve in-process `gdal_dart` use and injected opener/library-resolution seams. Do not bundle GDAL/PROJ libraries/data and do not make a missing/incompatible host GDAL library a startup error.
- [ ] When an elevation DEM is opened with a missing or incompatible host library, report exactly `RouteElevationSamplingException.tasmaniaDataUnavailable`.
- [ ] Add deterministic unit/provider tests with fake `DemDatasetOpener` and host-library seams for successful sampling, Mapping failures, no fallback, and lazy host-library failure without a mounted store, GDAL install, or external DEM.

## Covers

- User Stories: 1, 2
- Requirements: 4, 9, 13, 25
- Technical Decisions: 2, 4, 9
- Testing Strategy: 4-5, 14
- Interview Ledger: L1, L3-L6, L9

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
