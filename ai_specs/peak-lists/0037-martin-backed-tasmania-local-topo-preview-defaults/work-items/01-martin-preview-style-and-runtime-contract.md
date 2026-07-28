---
type: Work Item
title: Martin Preview Style And Runtime Contract
parent: ../spec.md
---

## What to build
Add the committed Martin comparison style `tasmania-openstreetmap-contours-martin` at `styles/local-topo/openstreetmap-martin.json`, keep the legacy comparison style wiring as style id `tasmania-openstreetmap-contours` backed by `styles/local-topo/openstreetmap.json`, preserve the existing preview style ids `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor`, and wire the internal preview runtime so the unchanged raster route `/tasmania/local-topo/{z}/{x}/{y}.png` can render both the legacy TileServer-backed and Martin-backed OSM comparison paths. Keep the Martin style file as a separate committed file derived from `styles/local-topo/openstreetmap.json`, and limit first-slice Martin divergence to the explicitly allowed source rewrites, source-layer rewrites, and removal or rewrite of references to deferred first-slice layers absent from the Martin-backed preview schema.

## Required context
- Similar stack and routing conventions already live in `local_topo/tasmania/server/app.mjs`, `local_topo/tasmania/config/tileserver-config.json`, `local_topo/tasmania/tests/server.test.mjs`, and `local_topo/tasmania/tests/style.test.mjs`.
- Keep canonical project terminology from `GLOSSARY.md`, especially `Preview style`, `Prerender zoom range`, `Contour cartography`, `Local Topo`, and `Local Topo Legacy`.
- Existing style-variant patterns and maintainer workflow wording already exist in `ai_specs/peak-lists/0031-maptiler-topo-and-outdoor-preview-variants/work-items/02-preview-routing-and-maintainer-workflow.md` and the touched docs under `local_topo/tasmania/styles/local-topo/README.md`.

## Acceptance criteria
- [ ] `styles/local-topo/openstreetmap-martin.json` exists as a separate committed file derived from `styles/local-topo/openstreetmap.json`, and the legacy comparison style id `tasmania-openstreetmap-contours` remains wired to `styles/local-topo/openstreetmap.json`.
- [ ] The Martin comparison path is wired as style id `tasmania-openstreetmap-contours-martin` backed by `styles/local-topo/openstreetmap-martin.json`, and this style becomes the default preview style contract for later startup selection work.
- [ ] The first-slice Martin-backed preview schema is treated as limited to the required OSM vector layers `landcover`, `landuse`, `water`, `water_name`, `waterway`, `transportation`, `transportation_name`, `building`, `place`, `park`, and `boundary`, while explicitly deferring `aerodrome_label`, `aeroway`, `housenumber`, `mountain_peak`, and `poi`.
- [ ] `styles/local-topo/openstreetmap-martin.json` removes or rewrites any references to deferred first-slice layers that are not present in the Martin-backed preview schema: `aerodrome_label`, `aeroway`, `housenumber`, `mountain_peak`, and `poi`.
- [ ] Any first-slice divergence between `styles/local-topo/openstreetmap.json` and `styles/local-topo/openstreetmap-martin.json` is limited to the explicitly allowed source rewrites, source-layer rewrites, and deferred-layer removals or rewrites required for Martin-schema compatibility; this item must not expand the schema solely to preserve deferred legacy layers.
- [ ] The unchanged raster route `/tasmania/local-topo/{z}/{x}/{y}.png` continues serving both the Martin-backed and legacy OSM comparison paths through the style-driven preview rendering path, while raw vector tile endpoints remain internal to the preview stack.
- [ ] `LOCAL_TOPO_TILESERVER` selection applies only to the OSM-backed comparison paths in this slice and does not retarget `tasmania-maptiler-topo` or `tasmania-maptiler-outdoor`, which remain registered and functional with their existing cartography and selector semantics.
- [ ] Deterministic server-side configuration, style-structure, and preview-routing coverage proves the supported OSM-backed comparison styles are registered, `tasmania-openstreetmap-contours-martin` maps to `styles/local-topo/openstreetmap-martin.json`, the Martin style edits stay within the allowed compatibility boundary, the unchanged raster route still works for both OSM-backed comparison paths, and the non-OSM preview styles keep their existing routing contract.

## Covers
- User Stories: 1-2
- Requirements: 1-3, 7, 12-15, 18-23
- Technical Decisions: 1, 3-5
- Testing Strategy: 2-4, 6-7
- Interview Ledger: L1-L4, L7-L13

## Blocked by
None - ready to start
