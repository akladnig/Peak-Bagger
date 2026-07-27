---
type: Work Item
title: ELVIS Single-File Maintainer Docs And Glossary Alignment
parent: ../spec.md
---

## What to build
Update the maintainer-facing documentation touched by this slice so it matches the approved `Elvis 2m DEM` single-file contract exactly. This item must align `README.tasmania-elvis-local-topo.md`, `GLOSSARY.md`, and any touched ELVIS maintainer usage text with the exact canonical TIFF `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif`, the removal of `bootstrap-manifest` and `--save-vrt` from the active workflow, the retained `--validate` build flag with its updated meaning, the absence of directory scanning and legacy-source fallback, and the unchanged downstream prepared-artifact contract for Flutter runtime elevation and Tasmania `Local Topo`.

## Required context
- `GLOSSARY.md` contains the canonical repo terminology. Preserve the approved distinction between `Elvis 2m DEM` as the raw source and `ELVIS runtime DEM` plus `ELVIS topo DEM` as the prepared derived artifacts.
- `README.tasmania-elvis-local-topo.md` is the main maintainer workflow doc currently describing the old source path, manifest workflow, and `--save-vrt` behavior; update it without broadening scope into downstream contract changes the Spec explicitly excludes.
- Keep any touched usage text synchronized with the active CLI contract implemented in `tool/elvis_dem.dart` so docs, glossary, and command help do not drift.

## Acceptance criteria
- [x] Touched maintainer-facing docs describe `Elvis 2m DEM` as the canonical raw-source term for this slice and identify the exact statewide TIFF `/Volumes/Media/Elvis/tas-elvis/elevation/2m-dem/z55/mosaics/Tasmania_Statewide_2m_DEM_14-08-2021.tif` as the active validation and build input.
- [x] Touched docs and usage text document that the supported `./elvis_dem.sh` subcommands are exactly `validate-source`, `build-runtime`, `build-topo`, and `build-all`, and that `bootstrap-manifest` is removed from the active workflow.
- [x] Touched docs and usage text document that the only supported build flag is `--validate`, that builds skip source validation by default unless `--validate` is passed, and that in this slice `--validate` means checking the exact canonical TIFF for existence, readability, and GDAL-openability before the build.
- [x] Touched docs and usage text no longer describe or imply `--save-vrt`, manifest bootstrapping, manifest-backed validation, directory scanning, alternate filename discovery, or fallback to `/Volumes/Elvis/tas-elvis` or another alternate raw ELVIS location.
- [x] Touched docs preserve the unchanged downstream prepared-artifact contract by continuing to document `ELVIS runtime DEM` and `ELVIS topo DEM` as the maintained prepared outputs used by Flutter runtime elevation and Tasmania `Local Topo`, without changing their names, output paths, or consumer ownership.
- [x] `GLOSSARY.md` updates the `Elvis 2m DEM` entry so it aligns to the exact canonical TIFF contract rather than a broader source-directory contract. If the containing directory is still mentioned, it is described only as the location of the canonical TIFF, not as the active workflow contract itself.

## Covers
- User Stories: 1-3
- Requirements: 1, 3, 6-7, 12-13
- Technical Decisions: 1-3
- Interview Ledger: L1-L6

## Blocked by
None - ready to start
