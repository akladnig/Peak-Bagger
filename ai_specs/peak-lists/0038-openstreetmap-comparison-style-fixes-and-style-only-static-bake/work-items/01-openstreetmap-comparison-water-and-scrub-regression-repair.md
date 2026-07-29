---
type: Work Item
title: OpenStreetMap Comparison Water And Scrub Regression Repair
parent: ../spec.md
---

## What to build
Update both OpenStreetMap comparison styles at `styles/local-topo/openstreetmap-martin.json` and `styles/local-topo/openstreetmap.json` so they stay aligned for the agreed regression fixes, restore blue water cartography instead of the current grey presentation, and restore the local sprite-backed scrub treatment around Mount Wellington instead of the current missing pattern or icon presentation. Treat `openstreetmap-martin.json` as the primary validation target because it is the active default preview path, leave `styles/local-topo/style.json` and the MapTiler-derived preview variants unchanged in this slice, and document any narrow compatibility exception only if one comparison style cannot take the exact same change.

## Required context
- Similar comparison-style and preview-runtime conventions already live in `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/styles/local-topo/openstreetmap.json`, `local_topo/tasmania/config/tileserver-config.json`, and `local_topo/tasmania/tests/style.test.mjs`.
- Keep canonical project terminology from `GLOSSARY.md`, especially `Preview style`, `Local Topo`, `Contour cartography`, and `Style-only static bake`.
- The local sprite source of truth remains `local_topo/tasmania/sprites/` through the existing style contract `"sprite": "sprite"`; do not introduce remote sprite dependencies.
- Manual cartography validation for this slice is against the active Martin-backed preview around Mount Wellington using the provided reference captures `~/Desktop/lt.png` and `~/Desktop/osm.png`, then confirming the legacy OpenStreetMap comparison style remains visually aligned for the same cases.

## Acceptance criteria
- [ ] Only `styles/local-topo/openstreetmap-martin.json` and `styles/local-topo/openstreetmap.json` are changed for the comparison-style cartography fix in this slice; `styles/local-topo/style.json` and the MapTiler-derived preview variants remain unchanged.
- [x] `styles/local-topo/openstreetmap-martin.json` remains the primary validation target because it is the active default preview path, and `styles/local-topo/openstreetmap.json` stays aligned for the same regression fixes unless a narrow documented source-compatibility exception is required.
- [x] Water in both OpenStreetMap comparison styles renders as blue water cartography consistent with the OpenStreetMap reference instead of the current grey presentation, including any touched matching waterway presentation needed to restore that comparison behavior.
- [x] Scrub around Mount Wellington in both OpenStreetMap comparison styles restores the expected vegetation treatment through the local sprite-backed scrub pattern specifically, rather than a new non-sprite substitute.
- [x] Both OpenStreetMap comparison styles continue sourcing sprites from the committed local `local_topo/tasmania/sprites/` bundle through the existing style contract `"sprite": "sprite"`, and this slice does not introduce remote sprite dependencies.
- [x] The visual success bar stays limited to the reported water and scrub regressions shown by the provided local preview and OpenStreetMap reference captures around Mount Wellington; this item does not broaden into a general comparison-style restyle or a canonical `Local Topo` redesign.
- [x] Deterministic `local_topo/tasmania/tests/style.test.mjs` coverage proves both OpenStreetMap comparison styles continue using the local sprite base, preserve the local sprite asset contract, and keep the expected water and scrub layer wiring required for this regression fix.
- [ ] Manual cartography validation is run against the active Martin-backed preview around Mount Wellington using the provided local comparison screenshots as the regression target, and the legacy OpenStreetMap comparison style is then confirmed visually aligned for the same cases.
- [x] No new Flutter widget or robot coverage is added in this slice because the app-facing basemap selection flow, route shape, and capability contract are unchanged; optional smoke verification through the existing stack or app remains sufficient for end-to-end confirmation.

## Covers
- User Stories: 1-2
- Requirements: 1-6, 12
- Technical Decisions: 1-2
- Testing Strategy: 1, 4-5
- Interview Ledger: L1-L2, L5

## Blocked by
None - ready to start
