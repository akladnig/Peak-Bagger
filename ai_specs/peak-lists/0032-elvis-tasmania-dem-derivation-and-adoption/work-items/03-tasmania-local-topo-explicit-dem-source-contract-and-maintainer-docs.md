---
type: Work Item
title: Tasmania Local Topo Explicit DEM Source Contract And Maintainer Docs
parent: ../spec.md
---

## What to build
Rework the Tasmania `Local Topo` rebuild entrypoints so they consume prepared DEM inputs only through the explicit post-adoption DEM-source contract. This item must keep the refresh entrypoints as shell-script consumers of prepared artifacts, default to `--dem-source=elvis-topo`, support only `thelist`, `copernicus`, and `custom` as explicit opt-in alternatives, require all accepted DEM inputs in this slice to already be readable `EPSG:28355` GeoTIFFs, fail fast instead of auto-falling back, preserve contour and terrain-relief generation ownership in the existing rebuild seam, and update maintainer-facing docs or help text so they describe the explicit contract instead of the old auto-selection behavior.

## Required context
- `local_topo/tasmania/scripts/_common.sh`, `local_topo/tasmania/scripts/rebuild_stack.sh`, `local_topo/tasmania/scripts/manual_refresh.sh`, `local_topo/tasmania/scripts/scheduled_refresh.sh`, and `local_topo/tasmania/tests/rebuild_scripts.test.mjs` are the current rebuild-policy seams.
- `local_topo/tasmania/README.md` currently documents DEM auto-selection and fallback behavior that conflicts with the approved Spec and must be brought into alignment.
- Keep the existing split of responsibilities: the ELVIS CLI produces the `ELVIS topo DEM`, while the `Local Topo` rebuild scripts continue to own contour generation, contour GeoJSON or `MBTiles`, terrain relief shading, and topo-side `source-metadata.json` output.
- This item must not make routine refreshes derive ELVIS artifacts inline, require `dart run`, or rescan the raw `260 GB` source during normal refresh operations.

## Acceptance criteria
- [x] Tasmania `Local Topo` refresh entrypoints remain shell-script entrypoints and continue to run normal rebuilds without requiring `dart run`.
- [x] Rebuild entrypoints accept an explicit `--dem-source` flag whose supported values are exactly `elvis-topo`, `thelist`, `copernicus`, and `custom`, with default value `elvis-topo`.
- [x] `--dem-source=custom` requires `--dem-path`, and `--dem-path` must be an absolute path to a readable `EPSG:28355` GeoTIFF.
- [x] Named sources resolve only to maintainer-managed configured locations whose selected DEM input is a readable `EPSG:28355` GeoTIFF.
- [x] Rebuild scripts consume only the selected DEM for a given rebuild, validate that selected input exists and is readable, and never auto-select or silently fall back to another DEM source.
- [x] This slice does not add source-CRS detection, runtime CRS inspection, or alternate-source reprojection behavior to make other DEM coordinate systems work.
- [x] If the selected `elvis-topo` input is missing or invalid, the scripts fail fast with clear maintainer guidance such as `./elvis_dem.sh build-topo`.
- [x] Routine refreshes do not derive ELVIS artifacts inline and do not rescan the raw `/Volumes/Media/Elvis/tas-elvis` source during normal refresh operations.
- [x] The ELVIS CLI still stops at producing the `ELVIS runtime DEM` and `ELVIS topo DEM`, while `Local Topo` rebuild scripts remain responsible for contour generation, contour `MBTiles`, terrain relief shading, and any topo-specific `source-metadata.json` written beside prerendered tile output.
- [x] `local_topo/tasmania/README.md` and any rebuild-script help or usage output touched by this slice stop describing DEM auto-selection or fallback behavior and document the explicit `--dem-source` contract instead.
- [x] Deterministic rebuild-script coverage proves default `--dem-source=elvis-topo`, explicit `thelist`, `copernicus`, and `custom` selection, required `--dem-path` for `custom`, rejection of DEM inputs that are not accepted as readable `EPSG:28355` GeoTIFFs for this slice, clear failure on missing or invalid selected inputs, no auto-fallback, no inline raw-source rescan or ELVIS rebuild, and aligned maintainer-facing README/help expectations where tested through fixtures or output assertions.

## Covers
- User Stories: 4, 5
- Requirements: 1, 4, 8, 10, 20-22
- Technical Decisions: 2-3, 7
- Testing Strategy: 3
- Interview Ledger: L1, L4, L6-L11, L20-L24

## Blocked by
None - ready to start
