---
type: Work Item
title: Build Mapping Store Manifest Boundary and Catalog
parent: ../spec.md
---

## What to build

Implement the shared runtime read-only Mapping data store boundary at `/Volumes/Services/Mapping`, the immutable `MappingCatalog`, and `mappingCatalogProvider`. Replace the generated runtime catalog with catalog data built from validated `region_manifest.json` and required `Polygons/manifest.json`; retain only the app-created `localTopo` descriptor and move `Basemap` to an app-owned non-generated enum with exactly `tasmapTopo`, `tasmap50k`, `tasmap25k`, `tracestrack`, `openstreetmap`, `mapyCz`, `nswImagery`, `nswBasemap`, `nswTopo`, `sloveniaTopo`, `fvgTopo`, and `localTopo`.

Add `test/fixtures/mapping_store/v1/region_manifest.json`, `Polygons/manifest.json`, and `tool_manifest.json` as the retained-contract baseline. The fixture directory is the parser-owned schema revision, not a Mapping data manifest field.

## Required context

- Replace `lib/services/region_manifest_catalog.dart` and `lib/generated/region_manifest_catalog.g.dart` runtime behavior without creating a global fallback. Consumers receive `MappingCatalog` by constructor or read/watch `mappingCatalogProvider` only inside the ready `ProviderScope`.
- Reuse `lib/services/polygon_geometry.dart`; catalog-required regional and coverage-polygon geometry belongs to this boundary, while optional polygon display parsing remains lazy in Work Item 09.
- Use injected root, filesystem, text reader, and platform seams for tests. Do not require the mounted store in automated tests.

## Acceptance criteria

- [x] Parse only `tasmap`, `naturalFeatures`, `demSources`, and `routingCoverages` as root metadata; reject unknown metadata with RFC 6901 JSON Pointers. Every other root entry validates as the exact base, seedable, routing source, supporting, or composite facet contract, including boolean and boolean-string `showInPeakList`.
- [x] Require `tasmap.catalog = Maps/tasmap50k.csv`, `naturalFeatures.catalog = Features/tasmania_natural_features.json`, and exactly `demSources.elvisRuntime = DEM/Elvis/elvis_runtime_10m.tif`, `thelist25m = DEM/tasmania_dem_25m.tif`, and `copernicus = DEM/cop30_hh.tif` in the retained fixture contract.
- [x] Validate exactly `routingCoverages.tasmania` and `routingCoverages.northeast-alps`; derive membership from regional `routingCoverage`, requiring Tasmania only and Northeast Alps exactly FVG, Veneto, and Slovenia with `Highways/slovenia-highways.json`.
- [x] Validate safe non-empty forward-slash store-relative paths for every manifest path-bearing field. Reject absolute, backslash-containing, `.`, `..`, and escaped or outside-root canonical targets; permit symlinks only when their canonical targets remain below the store root. Aggregate and lexically sort/deduplicate invalid, missing, and unreadable displayed paths.
- [x] Require `Polygons/manifest.json` to be a JSON list of safe store-relative `.poly` paths. Ensure every regional `poly` and basemap `coveragePoly` appears in that allowlist, structurally validate all entries, and check only catalog-required paths for readability during preflight.
- [x] Preflight reads and structurally validates only the manifest pair and performs non-content existence/access checks for referenced peak, highway, TasMap CSV, Natural Features, DEM, and required polygon files. It must not parse, hash, or open source content for peak, highway, CSV, or GeoTIFF files.
- [x] Report a structural error as `<manifest-relative-path>#<RFC 6901 JSON Pointer>` when known and only the manifest-relative path for unlocatable JSON syntax errors.
- [x] Validate basemap keys, descriptors, map-set relationships, duplicate rules, and exact supported enum compatibility. Retain one canonical descriptor for identical shared keys and report every conflicting pointer location.
- [x] Build required geometry through a versioned macOS app-support `MappingCatalogCache`; reuse entries only when schema version, manifest hash, relative path, size, modified time, and content hash match. Corrupt/missing/changed entries are reparsed; cache read/delete/replacement-write failures are non-blocking after valid source parsing.
- [x] Unit and provider tests cover all parser, path, fixture, cache, manifest, routing, basemap, map-set, symlink, JSON Pointer, and no-source-content-read contracts in Testing Strategy items 1, 9, 10, and 13.

## Covers

- User Stories: 1, 3
- Requirements: 3-7, 10, 23
- Technical Decisions: 1-2, 6, 8, 13-14, 21-23
- Testing Strategy: 1, 9, 10, 13
- Interview Ledger: L1, L3, L7, L9, L10

## Blocked by
01-mapping-data-contract-inventory.md
