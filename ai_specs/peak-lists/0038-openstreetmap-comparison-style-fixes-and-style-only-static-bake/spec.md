---
type: Spec
title: OpenStreetMap Comparison Style Fixes And Style-Only Static Bake
---

## Problem

The active Tasmania OpenStreetMap comparison preview currently shows at least two visible cartography regressions: water is rendering grey instead of blue, and scrub treatment around Mount Wellington is missing its expected sprite-backed vegetation pattern. The same comparison cartography is represented by both `styles/local-topo/openstreetmap-martin.json` and `styles/local-topo/openstreetmap.json`, so a fix in only one file would let the comparison paths drift apart. At the same time, maintainers do not have an acceptable fast static publish path for cartography-only changes because even `npm run refresh:manual -- --skip-prerender` still takes hours by rebuilding MBTiles and other upstream artifacts instead of only rerendering static PNG tiles from valid existing outputs. [L1] [L2] [L3] [L5]

## Proposed Outcome

Restore the expected OpenStreetMap comparison cartography in both OpenStreetMap comparison styles, with the Martin-backed preview path as the primary validation target, while preserving the canonical `Local Topo` style and other preview variants unchanged. Add a dedicated `style-only static bake` maintainer workflow exposed as `npm run refresh:style-only-static` that rerenders the canonical static Tasmania `Local Topo` PNG tile tree from existing MBTiles inputs without rebuilding upstream OSM, contour, relief, or preview-runtime artifacts. [L1] [L3] [L4] [L5]

## User Stories

1. As a maintainer comparing the Tasmania OpenStreetMap preview against an OpenStreetMap reference, I can see blue water and restored scrub patterning around Mount Wellington instead of the current grey water and missing scrub sprites. [L2] [L5]
2. As a maintainer switching between the Martin-backed and legacy OpenStreetMap comparison styles, I can keep both comparison paths visually aligned for the same regression fixes instead of correcting only one path. [L1]
3. As a maintainer publishing a cartography-only change into the static Tasmania tile tree, I can run `npm run refresh:style-only-static`, which reuses existing MBTiles inputs and avoids the hours-long full rebuild path. [L3] [L4]

## Requirements

1. Scope this slice to the OpenStreetMap comparison styles `styles/local-topo/openstreetmap-martin.json` and `styles/local-topo/openstreetmap.json`. Treat `openstreetmap-martin.json` as the primary validation target because it is the active default preview path. Leave the canonical `styles/local-topo/style.json` and the MapTiler-derived preview variants unchanged in this slice. [L1]
2. Keep both OpenStreetMap comparison styles aligned for the agreed regression fixes unless a narrow source-compatibility difference forces an explicit documented exception. [L1]
3. Water in both OpenStreetMap comparison styles must render as blue water cartography consistent with the OpenStreetMap reference rather than the current grey presentation. This includes the visible water fill and any touched matching waterway presentation needed to restore that comparison behavior. [L2]
4. Scrub around Mount Wellington in both OpenStreetMap comparison styles must restore the expected vegetation treatment instead of the current missing pattern or icon presentation. This slice must restore the local sprite-backed scrub pattern specifically rather than substituting a new non-sprite treatment. [L2] [L5]
5. The local sprite source of truth for this scrub restoration remains the committed `local_topo/tasmania/sprites/` directory through the existing style contract `"sprite": "sprite"`. This slice must not introduce remote sprite dependencies. [L5]
6. The visual success bar is limited to the reported regression fixes shown by the provided local preview and OpenStreetMap reference captures around Mount Wellington. Do not broaden the work into a general comparison-style restyle or a canonical `Local Topo` redesign. [L2]
7. Add a dedicated maintainer workflow for a `style-only static bake` exposed as `npm run refresh:style-only-static`. That workflow must rerender `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png` from existing `output/tasmania-osm.mbtiles`, `output/tasmania-contours.mbtiles`, and `output/tasmania-relief.mbtiles` inputs without rebuilding upstream source artifacts. [L3] [L4]
8. The `style-only static bake` workflow must fail fast if any required MBTiles input is missing or unreadable. It must not download source data or rebuild OSM, contour, relief, or preview-runtime artifacts as part of the static rerender path. [L3]
9. The `style-only static bake` workflow must use the existing TileServer GL prerender path and the registered style id `tasmania-local-topo` to rerender the canonical static `Local Topo` output. It must not switch on preview-only `LOCAL_TOPO_STYLE`, must not use Martin, and must not change the existing preview-style selection contract. [L1] [L3]
10. The `style-only static bake` workflow must preserve the existing `output/tiles/tasmania/local-topo/source-metadata.json` contract and keep it aligned with the reused existing MBTiles inputs. [L3]
11. `npm run refresh:manual` remains the full rebuild path for source-data or DEM changes. The new `style-only static bake` workflow becomes the documented default path for cartography-only static output updates when existing MBTiles inputs are already valid. [L3] [L4]
12. Maintain the existing preview-iteration contract: style-only preview edits must remain testable through `npm run stack:up` or `npm run stack:up:preview` with existing MBTiles inputs, without requiring the new static bake workflow. This slice improves the static publish path, not the preview route or app-facing basemap contract.

## Technical Decisions

1. Preserve the project distinction between the canonical `Local Topo` style and the OpenStreetMap comparison styles by limiting the fix to the comparison-style files rather than mutating `styles/local-topo/style.json`. [L1]
2. Treat missing scrub sprites as a regression in the existing local sprite contract and repair that contract directly instead of redesigning the scrub treatment. [L5]
3. Implement the `style-only static bake` as the maintainer-facing command `npm run refresh:style-only-static` on top of the existing TileServer GL-backed static prerender path so it can reuse valid MBTiles artifacts and rerender only the canonical static `Local Topo` PNG output tree. [L3] [L4]
4. Keep preview inspection and static publication as separate maintainer workflows: preview remains the fast visual iteration path, while `style-only static bake` becomes the fast static publication path for cartography-only changes. [L3] [L4]

## Testing Strategy

1. Extend deterministic `local_topo/tasmania/tests/style.test.mjs` coverage for both OpenStreetMap comparison styles so the tests prove the styles continue using the local sprite base, preserve the local sprite asset contract, and keep the expected water and scrub layer wiring required for this regression fix. [L1] [L2] [L5]
2. Add deterministic script or command coverage for `npm run refresh:style-only-static` proving it reuses existing MBTiles inputs, fails fast when required MBTiles inputs are missing, preserves the `source-metadata.json` contract, rerenders through the registered `tasmania-local-topo` TileServer GL static prerender path, and does not invoke the upstream OSM, contour, relief, or preview-runtime rebuild steps. [L3] [L4]
3. Update touched maintainer docs and any command-registration assertions so `npm run refresh:style-only-static` is presented as the default static publication path for cartography-only changes, while `refresh:manual` remains the full rebuild path. [L3] [L4]
4. Run manual cartography validation against the active Martin-backed preview around Mount Wellington using the provided local comparison screenshots as the regression target, then confirm the legacy OpenStreetMap comparison style remains visually aligned for the same cases. [L1] [L2]
5. No new Flutter widget or robot coverage is required in this slice because the app-facing basemap selection flow, route shape, and capability contract are unchanged. Optional smoke verification through the existing stack or app remains sufficient for end-to-end confirmation.

## Out of Scope

1. Restyling the canonical `styles/local-topo/style.json` `Local Topo` cartography in this slice. [L1]
2. Restyling the MapTiler-derived preview variants. [L1]
3. General comparison-style parity work beyond the reported water and scrub regressions around Mount Wellington. [L2]
4. Rebuilding or changing DEM, OSM extract, contour-generation, relief-generation, or preview-runtime data contracts beyond adding the dedicated static rerender workflow. [L3]
5. Changing the Flutter app basemap drawer, labels, or any app-facing route or capability contract.

## Follow-Ups

1. If the restored OpenStreetMap comparison fixes reveal a generally better cartography treatment worth adopting more broadly, evaluate a later intentional port into the canonical `Local Topo` style instead of folding that restyle into this regression slice. [L1] [L2]

## Notes

1. Likely touchpoints include `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/styles/local-topo/openstreetmap.json`, `local_topo/tasmania/package.json`, `local_topo/tasmania/scripts/rebuild_stack.sh`, `local_topo/tasmania/scripts/_common.sh`, `local_topo/tasmania/scripts/prerender_tiles.mjs`, `local_topo/tasmania/README.md`, `README.tasmania-elvis-local-topo.md`, `local_topo/tasmania/tests/style.test.mjs`, and `local_topo/tasmania/tests/rebuild_scripts.test.mjs`.
2. The local screenshot references supplied during interview were `~/Desktop/lt.png` for the current Local Topo comparison output and `~/Desktop/osm.png` for the OpenStreetMap reference.
3. `GLOSSARY.md` now defines `Style-only static bake` as the canonical maintainer term for the fast static rerender workflow. [L4]
