---
type: Work Item
title: Style-Only Static Bake Maintainer Workflow
parent: ../spec.md
---

## What to build
Add the dedicated maintainer workflow exposed as `npm run refresh:style-only-static` so cartography-only changes can rerender the canonical static Tasmania `Local Topo` PNG tile tree at `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png` from existing `output/tasmania-osm.mbtiles`, `output/tasmania-contours.mbtiles`, and `output/tasmania-relief.mbtiles` inputs without rebuilding upstream OSM, contour, relief, or preview-runtime artifacts. The workflow must use the existing TileServer GL prerender path and the registered style id `tasmania-local-topo`, must preserve the existing `output/tiles/tasmania/local-topo/source-metadata.json` contract, must fail fast if any required MBTiles input is missing or unreadable, and must not change the existing preview-style selection contract based on `LOCAL_TOPO_STYLE` or switch the static rerender path to Martin.

## Required context
- Current rebuild, prerender, and source-metadata seams live in `local_topo/tasmania/package.json`, `local_topo/tasmania/scripts/rebuild_stack.sh`, `local_topo/tasmania/scripts/manual_refresh.sh`, `local_topo/tasmania/scripts/_common.sh`, `local_topo/tasmania/scripts/prerender_tiles.mjs`, and `local_topo/tasmania/tests/rebuild_scripts.test.mjs`.
- Preserve the existing TileServer GL static prerender contract registered as style id `tasmania-local-topo` in `local_topo/tasmania/config/tileserver-config.json`; this item must not repurpose `LOCAL_TOPO_STYLE` preview selection or the Martin preview runtime.
- Maintainer-facing wording already lives in `local_topo/tasmania/README.md`, `README.tasmania-elvis-local-topo.md`, and `GLOSSARY.md`, which defines `Style-only static bake` as the canonical workflow term.
- Deterministic script-level seams are preferred over live Docker or network dependencies for regression coverage of this workflow.

## Acceptance criteria
- [ ] `local_topo/tasmania/package.json` exposes the dedicated maintainer command exactly as `npm run refresh:style-only-static`.
- [ ] `npm run refresh:style-only-static` rerenders `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png` from existing `output/tasmania-osm.mbtiles`, `output/tasmania-contours.mbtiles`, and `output/tasmania-relief.mbtiles` inputs without rebuilding upstream OSM, contour, relief, or preview-runtime artifacts.
- [ ] The workflow fails fast with clear maintainer-facing output if any required MBTiles input is missing or unreadable.
- [ ] The workflow uses the existing TileServer GL prerender path and the registered style id `tasmania-local-topo` for the static rerender path.
- [ ] The workflow does not switch on preview-only `LOCAL_TOPO_STYLE`, does not use Martin, and does not change the existing preview-style selection contract.
- [ ] The workflow preserves the existing `output/tiles/tasmania/local-topo/source-metadata.json` contract and keeps it aligned with the reused existing MBTiles inputs instead of rebuilding or rewriting upstream provenance.
- [ ] `npm run refresh:manual` remains the full rebuild path for source-data or DEM changes, while `npm run refresh:style-only-static` becomes the documented default static publication path for cartography-only changes when existing MBTiles inputs are already valid.
- [ ] The existing preview-iteration contract remains unchanged: style-only preview edits are still testable through `npm run stack:up` or `npm run stack:up:preview` with existing MBTiles inputs, without requiring `npm run refresh:style-only-static`.
- [ ] Deterministic script or command coverage proves `npm run refresh:style-only-static` reuses existing MBTiles inputs, fails fast when required MBTiles inputs are missing, preserves the `source-metadata.json` contract, rerenders through the registered `tasmania-local-topo` TileServer GL static prerender path, and does not invoke the upstream OSM, contour, relief, or preview-runtime rebuild steps.
- [ ] Touched maintainer docs and any command-registration assertions present `npm run refresh:style-only-static` as the default static publication path for cartography-only changes, while `npm run refresh:manual` remains the full rebuild path.
- [ ] No new Flutter widget or robot coverage is added in this slice because the app-facing basemap selection flow, route shape, and capability contract are unchanged; optional smoke verification through the existing stack or app remains sufficient for end-to-end confirmation.

## Covers
- User Stories: 3
- Requirements: 7-12
- Technical Decisions: 3-4
- Testing Strategy: 2-3, 5
- Interview Ledger: L3-L4

## Blocked by
None - ready to start
