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

## Prerequisite review — 2026-10-05 (resolved)

**Incomplete runtime integration; blocks Work Item 12.** The checked parser,
filesystem, fixture, and cache criteria above do not establish completion of
this Work Item's required runtime replacement and catalog injection.

- `lib/services/region_manifest_catalog.dart` still includes the generated
  catalog as a `part` and defines the global `regionManifestCatalog` backed by
  generated region, basemap, and polygon data.
- `lib/providers/peak_list_region_filter_provider.dart` still returns generated
  regions instead of reading `mappingCatalogProvider`. A temporary focused
  provider probe injected a `MappingCatalog` with no regions and expected no
  region options; `flutter test` failed with four generated
  `RegionManifestRegionData` options. The temporary probe was removed after
  recording the result; no mounted store or external service was used.
- `lib/screens/map_screen_layers.dart` still obtains tile URLs and zoom metadata
  from that global catalog. `map_provider.dart`, map search/filter services,
  peak-list visibility/import, peak repository, Slovenia correlation, and Local
  Topo settings also retain global generated-catalog consumers.
- `Basemap` exists both in `mapping_store_core.dart` and in the generated
  catalog. Runtime map consumers still use the generated enum.

Complete constructor/provider injection for every runtime consumer, consolidate
the app-owned `Basemap`, and add behavioral tests showing ready-scope manifest
metadata and geometry govern these consumers without a generated fallback.
Work Item 12 can then remove the generator/output and their tests as specified.

### Resolution — 2026-10-06

The runtime integration gap is closed during the approved Work Item 12 execution.
All former global-catalog consumers now receive ready-scope `MappingCatalog`
metadata through constructors, providers, or explicit function arguments.
`region_manifest_catalog.dart` contains map operations over that immutable
catalog, with no generated `part`, global data, or enum. `Basemap` is the single
app-owned enum in the pure-Dart Mapping boundary. Map URLs, basemap availability,
region options/filtering, search, peak-list import/visibility, Slovenia correlation,
and Local Topo validation use the injected catalog. Ready GPX destination lookup
does not use the legacy standalone test adapter's geographic fallback.

`test/unit/mapping_catalog_map_operations_test.dart` permanently covers the
formerly failing empty-catalog provider probe, a changed injected tile URL,
manifest priority/geometry, and scoped access. Test harness metadata comes from
the v1 fixtures through the shared parser with deterministic synthetic geometry;
no generated data or mounted store is needed. The generator/output and obsolete
generated-catalog tests are retired in Work Item 12, with a named source guard.

Verification: `flutter analyze` is clean; full suite **2,136 passed, 5 skipped**;
`flutter build macos --release` succeeds.

## Covers

- User Stories: 1, 3
- Requirements: 3-7, 10, 23
- Technical Decisions: 1-2, 6, 8, 13-14, 21-23
- Testing Strategy: 1, 9, 10, 13
- Interview Ledger: L1, L3, L7, L9, L10

## Blocked by
01-mapping-data-contract-inventory.md
