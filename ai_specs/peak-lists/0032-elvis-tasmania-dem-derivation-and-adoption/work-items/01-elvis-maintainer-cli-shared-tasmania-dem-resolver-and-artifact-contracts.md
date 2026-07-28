---
type: Work Item
title: ELVIS Maintainer CLI Shared Tasmania DEM Resolver And Artifact Contracts
parent: ../spec.md
---

## What to build
Build the maintainer-owned ELVIS derivation workflow for this slice: `tool/elvis_dem.dart`, the root shell wrapper `./elvis_dem.sh`, the committed frozen manifest at `tool/elvis_dem_manifest.json`, and the shared Tasmania DEM-root resolver contract used by the tool and later repo consumers. This item must validate the canonical raw source at `/Volumes/Media/Elvis/tas-elvis`, preserve the frozen explicit-file manifest contract, derive the stable `ELVIS runtime DEM` and `ELVIS topo DEM` GeoTIFF outputs under the resolved Tasmania DEM root, and write the exact report and sidecar metadata outputs required by the Spec without changing repo-wide `resolveBushwalkingRoot()` semantics.

## Required context
- `tool/download_tasmania_thelist_dem.dart` and `lib/services/import_path_helpers.dart` show the current Bushwalking-root local-data convention and the existing helper behavior that this slice must not broaden or silently change.
- `sync_peakbagger_csv.sh`, `peak_prominence_csv.sh`, and `slovenia_hribi_source_peak_list.sh` are the closest existing root wrapper conventions for the auto-build macOS maintainer-tool pattern.
- `test/tool/slovenia_hribi_source_peak_list_tool_test.dart` is the reference wrapper-testing pattern for the injectable fake-binary seam required by the Spec.
- Keep all automated coverage free of the real `260 GB` source, mounted volumes, or generated statewide GeoTIFF dependencies; use temp directories, fixture manifests, fake checksum inputs, and fake command seams instead.

## Acceptance criteria
- [x] `tool/elvis_dem.dart` implements the exact subcommands `bootstrap-manifest`, `validate-source`, `build-runtime`, `build-topo`, and `build-all`, and `./elvis_dem.sh` follows the repo's existing auto-build macOS maintainer-tool pattern so the ELVIS workflow runs as a shell command rather than via `dart run`.
- [x] Invoking `./elvis_dem.sh` without a subcommand prints help and exits non-zero.
- [x] `bootstrap-manifest` uses `/Volumes/Media/Elvis/tas-elvis` as the canonical raw source root, ignores transient OS metadata such as `.DS_Store`, writes the frozen manifest to `tool/elvis_dem_manifest.json`, and prints the raw source path plus the manifest path it wrote.
- [x] The frozen manifest enumerates every expected payload file explicitly and records at least relative path, byte size, lowercase-hex `sha256`, manifest-level file count, and manifest-level total bytes, with no wildcard or pattern-based expectations.
- [x] `validate-source`, `build-runtime`, `build-topo`, and `build-all` refuse to proceed unless the committed manifest already exists and validation succeeds against the canonical raw source.
- [x] The shared Tasmania DEM-root resolver used by this item writes generated artifacts under `~/Documents/Bushwalking/DEM/Tasmania/` when `~/Documents/Bushwalking` exists, otherwise under `$HOME/DEM/Tasmania/`, fails clearly when `HOME` is unavailable, and does not change broader `resolveBushwalkingRoot()` behavior for unrelated features.
- [x] `build-runtime` writes exactly `<tasmania-dem-root>/elvis_runtime_10m.tif` plus `elvis_runtime_10m.metadata.json`, and `build-topo` writes exactly `<tasmania-dem-root>/elvis_topo/elvis_topo_5m.tif` plus `elvis_topo_5m.metadata.json`, with the topo artifact written as `EPSG:28355`.
- [x] `validate-source`, `build-runtime`, `build-topo`, and `build-all` write machine-readable reports under `<tasmania-dem-root>/elvis_reports/` using UTC timestamped filenames shaped exactly as `<command>-YYYYMMDDTHHMMSSZ.report.json`, and each command prints the raw source path it validated or used, the generated artifact path or paths, and the report path it wrote.
- [x] Sidecar metadata records provenance including source completeness state, generation time, and key derivation parameters for each generated GeoTIFF output.
- [x] The workflow treats `ELVIS runtime DEM` and `ELVIS topo DEM` as distinct consumer artifacts rather than a shared statewide output, and does not commit generated GeoTIFFs, VRTs, caches, temp directories, or local validation or build reports.
- [x] Deterministic coverage under `test/tool/` proves manifest bootstrap output, source validation success, wrong-size failure, checksum-mismatch failure, missing-file failure, build planning, build-metadata output, timestamped report naming, and root-wrapper forwarding through an injectable fake-binary seam.

## Covers
- User Stories: 1, 2, 5
- Requirements: 1-10, 14-19
- Technical Decisions: 1-4
- Testing Strategy: 1-2
- Interview Ledger: L1-L3, L7-L21, L25-L26

## Blocked by
None - ready to start
