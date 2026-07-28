---
type: Work Item
title: ELVIS Single-File CLI Validation And Provenance
parent: ../spec.md
---

## What to build
Update the maintainer-owned ELVIS derivation workflow in `tool/elvis_dem.dart` and its deterministic tool coverage so the active workflow treats `Elvis 2m DEM` as the exact canonical TIFF `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`. This item must remove the manifest-backed active contract, remove `bootstrap-manifest` and `--save-vrt` from the active CLI contract, validate or consume that exact TIFF directly for `validate-source`, `build-runtime`, `build-topo`, and `build-all`, preserve the existing prepared `ELVIS runtime DEM` and `ELVIS topo DEM` output names and locations, and keep the existing report and sidecar artifact behavior while replacing manifest-shaped provenance with exact-file provenance.

## Required context
- `tool/elvis_dem.dart` already contains the active CLI parsing, raw-source validation seam, build orchestration, report-writing, and metadata-sidecar logic that this item must simplify rather than replace with a different downstream artifact contract.
- `test/tool/elvis_dem_tool_test.dart` is the required deterministic coverage seam. Preserve behavior-first TDD expectations from the Spec, keep coverage free of mounted external volumes and real statewide DEM data, and prefer fake GDAL command-runner and dataset-validation seams.
- `elvis_dem.sh` is the existing root wrapper entrypoint. Keep its auto-build macOS maintainer-tool pattern intact while bringing the active CLI behavior and help text into alignment with the approved single-file contract.
- `README.tasmania-elvis-local-topo.md` and `GLOSSARY.md` are touched by this slice and must stay consistent with the exact CLI contract, source path, and maintained terminology introduced here.

## Acceptance criteria
- [ ] The active `./elvis_dem.sh` subcommands are exactly `validate-source`, `build-runtime`, `build-topo`, and `build-all`. `bootstrap-manifest` is removed from active help text and parsing, and `--save-vrt` no longer appears in help text, parsing, or active workflow behavior.
- [ ] The active raw-source contract is the exact canonical TIFF `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`, treated as `Elvis 2m DEM`. The workflow does not scan `mosaics/` or any other directory for alternate filenames, does not discover alternate TIFFs, and does not fall back to `/Volumes/Elvis/tas-elvis` or any other alternate raw ELVIS location.
- [ ] `validate-source` validates that exact TIFF directly by checking that the file exists, is readable, and can be opened by the maintained GDAL-backed validation seam. If the canonical TIFF is missing, unreadable, cannot be opened, or has been replaced by a differently named file, the command fails clearly without directory scanning or alternate filename discovery.
- [ ] `build-runtime`, `build-topo`, and `build-all` consume the exact canonical TIFF directly rather than consulting manifest contents, matching a manifest source root, scanning directories, or merging multiple raw rasters. Builds continue skipping source validation by default unless `--validate` is passed.
- [ ] For `build-runtime`, `build-topo`, and `build-all`, the only supported build flag is `--validate`, and in this slice `--validate` means running the exact canonical TIFF existence, readability, and GDAL-openability checks before the build.
- [ ] `build-runtime`, `build-topo`, and `build-all` continue producing the existing prepared artifact contract unchanged from the canonical single-file source: `<tasmania-dem-root>/elvis_runtime_10m.tif` and `<tasmania-dem-root>/elvis_topo/elvis_topo_5m.tif`.
- [ ] The active commands preserve the existing artifact locations, UTC timestamped build-report behavior, and machine-readable output role, but they no longer require or record active manifest provenance such as `manifestPath` or manifest entry summaries. Reports and sidecars instead record the exact canonical TIFF path used for validation or build input and whether exact-file validation was run, skipped, or failed.
- [ ] If `tool/elvis_dem_manifest.json` remains in the repo after this slice, it is treated as legacy unreferenced material. The active workflow must not consult it.
- [ ] Deterministic tool coverage under `test/tool/elvis_dem_tool_test.dart` uses behavior-first TDD for the active CLI contract and proves removal of `bootstrap-manifest` and `--save-vrt` from help and parsing, retained `--validate` behavior, direct validation of the canonical TIFF, clear failure for missing, unreadable, and GDAL-unopenable exact-file cases, direct single-file build inputs with no manifest or directory-scan dependency, no fallback to `/Volumes/Elvis/tas-elvis`, and no reliance on the real statewide TIFF, mounted external volumes, or generated statewide outputs.

## Covers
- User Stories: 1-3
- Requirements: 1-11
- Technical Decisions: 1-3
- Testing Strategy: 1-5
- Interview Ledger: L1-L7

## Blocked by
None - ready to start
