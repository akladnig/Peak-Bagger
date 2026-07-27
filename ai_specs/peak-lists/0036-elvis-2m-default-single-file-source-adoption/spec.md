---
type: Spec
title: Elvis 2m Default Single-File Source Adoption
---

## Problem

The current ELVIS maintainer workflow in `tool/elvis_dem.dart` still assumes the old raw source tree at `/Volumes/Media/Elvis/tas-elvis`, depends on a frozen multi-file manifest, and carries discovery and merge logic for many raw rasters. That no longer matches the available Tasmania source of truth, because the statewide `Elvis 2m DEM` is already one canonical TIFF at `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`. The repo needs the ELVIS tool to default to that single-file source, stop depending on the old manifest-driven raw-source contract, and preserve the existing downstream prepared-artifact contract for Flutter runtime elevation and `Local Topo`. [L1] [L2] [L3] [L4] [L6] [L7]

## Proposed Outcome

Adopt `Elvis 2m DEM` as the canonical raw Tasmania source for `./elvis_dem.sh`, using the exact statewide TIFF `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif` as the active validation and build input. The active CLI contract drops manifest bootstrapping and manifest-backed validation, validates the single TIFF directly, and derives the existing prepared `ELVIS runtime DEM` and `ELVIS topo DEM` artifacts from that one input without scanning directories or merging multiple raw rasters. Flutter runtime elevation and Tasmania `Local Topo` continue consuming the same prepared artifact names and paths they already use today. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## User Stories

1. As a maintainer, I can run `./elvis_dem.sh` against the new statewide `Elvis 2m DEM` default without regenerating or maintaining a raw-source manifest. [L2] [L4] [L5] [L6]
2. As a maintainer, I can validate that the exact canonical statewide TIFF exists and is readable, and I get a clear failure if that file is missing, unreadable, or renamed instead of the tool searching other ELVIS locations. [L2] [L4] [L6]
3. As a Flutter or `Local Topo` maintainer, I keep the existing prepared-artifact contract unchanged while the raw ELVIS derivation input switches to the new single-file `Elvis 2m DEM`. [L1] [L3] [L7]

## Requirements

1. Use `Elvis 2m DEM` as the canonical raw-source term for this slice. It refers to the statewide TIFF at `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`. Keep `ELVIS runtime DEM` and `ELVIS topo DEM` as the names of the prepared derived artifacts. [L1] [L6]
2. `./elvis_dem.sh` must switch fully to `Elvis 2m DEM` as its only normal raw source. The active workflow must not fall back to `/Volumes/Elvis/tas-elvis` or any other alternate raw ELVIS location. [L2]
3. Scope this slice to the ELVIS raw-source maintainer workflow and touched maintainer docs or help text. Flutter runtime elevation must keep using the prepared `ELVIS runtime DEM`, and Tasmania `Local Topo` rebuilds must keep using the prepared `ELVIS topo DEM`. This slice must not change those downstream consumer contracts. [L3]
4. The active raw-source contract is the exact canonical TIFF file `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`. `validate-source`, `build-runtime`, `build-topo`, and `build-all` must validate or consume that exact file directly rather than scanning its containing directory for alternatives. [L4] [L6]
5. Remove the manifest requirement from the active `Elvis 2m DEM` workflow. `validate-source` must verify the exact canonical TIFF directly by confirming that the file exists, is readable, and can be opened by the maintained GDAL-backed validation seam. Build commands must no longer depend on manifest contents or manifest-source-root matching. [L4]
6. `bootstrap-manifest` is removed from the active `./elvis_dem.sh` CLI contract. The supported maintainer subcommands are exactly `validate-source`, `build-runtime`, `build-topo`, and `build-all`. The only supported build flag is `--validate` for `build-runtime`, `build-topo`, and `build-all`. Builds continue skipping source validation by default unless `--validate` is passed; in this slice `--validate` means running the exact canonical TIFF existence, readability, and GDAL-openability checks before the build. `--save-vrt` is removed from the active single-file workflow and must no longer appear in help text, parsing, or touched maintainer docs. [L5]
7. When the canonical `Elvis 2m DEM` TIFF is missing, unreadable, cannot be opened, or has been replaced by a differently named file, the active workflow must fail clearly. It must not search the containing directory, discover alternate filenames, or silently switch to the old ELVIS tree. [L2] [L6]
8. Treat `Elvis 2m DEM` as an already-prepared statewide source TIFF. The active ELVIS raw-source workflow must no longer depend on the old directory-scan, multi-file discovery, projection-group handling, or cross-tile merge contract. The implementation may still use whatever transform or resample steps are needed to derive the existing prepared artifacts from the one canonical TIFF. [L7]
9. `build-runtime`, `build-topo`, and `build-all` must continue producing the existing prepared artifact contract from the canonical single-file source:
   - `<tasmania-dem-root>/elvis_runtime_10m.tif`
   - `<tasmania-dem-root>/elvis_topo/elvis_topo_5m.tif`

   This slice changes the raw source input, not the prepared output names, output locations, or downstream consumer ownership. [L1] [L3] [L7]
10. Apart from the manifest-related contract changes required above, preserve the existing ELVIS build-report and artifact-sidecar behavior for the active commands in this slice, including their existing artifact locations, timestamped report behavior, and machine-readable output role. Replace manifest-shaped provenance in the active workflow with exact-file provenance for the canonical TIFF. Active reports and sidecars must not require or record active manifest provenance such as `manifestPath` or manifest entry summaries; instead they must record the exact canonical TIFF path used for validation or build input and whether exact-file validation was run, skipped, or failed. [L3] [L4] [L5]
11. If `tool/elvis_dem_manifest.json` remains in the repo after this slice, treat it as legacy unreferenced material rather than part of the active `Elvis 2m DEM` contract. The active workflow must not consult it. [L4]
12. Maintainer-facing docs and usage text touched by this slice must document the new single-file `Elvis 2m DEM` default, the exact canonical TIFF path, the removal of `bootstrap-manifest` and `--save-vrt` from the active workflow, the retained `--validate` build flag with its updated meaning, the absence of directory scanning or old-source fallback, and the unchanged downstream use of the prepared `ELVIS runtime DEM` and `ELVIS topo DEM`. [L2] [L3] [L5] [L6]
13. Update `GLOSSARY.md` in this slice so the glossary entry for `Elvis 2m DEM` aligns to the exact canonical TIFF contract rather than a broader source-directory contract. If the containing directory is still referenced, describe it as the location of the canonical TIFF rather than the active workflow contract itself. [L1] [L6]

## Technical Decisions

1. Use an exact-file raw-source contract instead of a source-directory contract. This keeps the implementation aligned with the real dataset shape and avoids carrying obsolete source-discovery logic when the maintained input is one statewide TIFF. [L2] [L6] [L7]
2. Remove manifest-backed validation from the active ELVIS workflow instead of regenerating a new manifest for the `Elvis 2m DEM`. A single-file existence, readability, and openability check is the durable raw-source validation seam for this slice. Keep the existing build-time `--validate` opt-in shape, but repoint it to that exact-file validation seam. Remove `--save-vrt` from the active CLI because the single-file source contract no longer requires preserving an intermediate VRT seam. [L4] [L5] [L6]
3. Preserve the existing prepared `ELVIS runtime DEM` and `ELVIS topo DEM` consumer contract to keep the change minimal and confined to the raw-source derivation tool and its maintainer docs. [L1] [L3]

## Testing Strategy

1. Update deterministic tool coverage under `test/tool/elvis_dem_tool_test.dart` using behavior-first TDD for the active CLI contract. Cover the removal of `bootstrap-manifest` and `--save-vrt` from help and parsing, retained parsing and help coverage for `--validate`, direct validation of the canonical single TIFF, and clear failure when that exact file is missing or unreadable. [L4] [L5] [L6]
2. Add explicit deterministic validation coverage for the exact canonical TIFF existing at the expected path but failing the maintained GDAL-backed openability seam, with a clear failure result and no alternate filename discovery or directory scan. Prefer fake dataset-validation seams over real DEM files. [L4] [L6] [L7]
3. Add or update deterministic build-path tests proving that `build-runtime`, `build-topo`, and `build-all` use the canonical `Elvis 2m DEM` file directly and do not depend on manifest contents, directory scans, alternate filename discovery, or fallback to `/Volumes/Elvis/tas-elvis`. Cover the retained `--validate` flow against the exact-file validation seam, including failure when the TIFF exists but cannot be opened by GDAL. Prefer fake command-runner and dataset-validation seams over real DEM files. [L2] [L4] [L6] [L7]
4. Keep automated coverage free of the real statewide TIFF, mounted external volumes, or generated statewide outputs. Use temp paths, fake GDAL command seams, and synthetic file-presence scenarios instead. [L4] [L6] [L7]
5. No new Flutter widget, robot, or journey coverage is required for this slice because the downstream Flutter and `Local Topo` consumer contracts stay unchanged. [L3]

## Out of Scope

1. Renaming `ELVIS runtime DEM`, `ELVIS topo DEM`, or their existing prepared artifact paths. [L1] [L3]
2. Changing Flutter runtime elevation or Tasmania `Local Topo` to read the raw `Elvis 2m DEM` TIFF directly. [L3]
3. Preserving a manifest-based active validation workflow for the new single-file source. [L4] [L5]
4. Searching the `mosaics/` directory for alternate TIFF names, supporting multiple candidate source files, or falling back to `/Volumes/Elvis/tas-elvis` or another alternate raw ELVIS location. [L2] [L6]
5. Keeping the old multi-file ELVIS raw-source discovery and merge contract as part of the active workflow. [L7]

## Follow-Ups

1. If the legacy `tool/elvis_dem_manifest.json` no longer serves any maintainer purpose after this slice, consider removing it in a later cleanup-only change rather than coupling that cleanup to the raw-source contract update. [L4]

## Notes

1. Likely implementation surfaces include `tool/elvis_dem.dart`, `README.tasmania-elvis-local-topo.md`, `GLOSSARY.md`, and `test/tool/elvis_dem_tool_test.dart`.
2. The existing downstream prepared-artifact consumers under Flutter runtime elevation and `local_topo/tasmania` are context for this slice, but are not expected to change behavior. [L3]
