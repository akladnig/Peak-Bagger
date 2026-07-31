---
type: Work Item
title: Local Topo 50m And 100m Contour Cartography
parent: ../spec.md
---

## What to build
Update Tasmania `Local Topo` `Contour cartography` in the committed canonical style `local_topo/tasmania/styles/local-topo/style.json`, registered as `tasmania-local-topo`, and mirror the same contour-cartography behavior into `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json`. Implement the change through style-layer filtering against the existing `tasmania-contours` vector source, `contours` source layer, and `elev` property so the slice adds a dedicated emphasized `50 m contour` tier, keeps the stronger emphasized `100 m contour` tier, delays `minor contour lines` to zoom `13`, adds `50 m` contour labels alongside `100 m` contour labels from zoom `13`, preserves the `"<elev> m"` label format, and forces both contour label tiers to follow existing contour feature direction without auto-flipping to stay viewport-upright.

## Required context
- Similar contour-style seams already live in `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/styles/local-topo/openstreetmap.json`, and `local_topo/tasmania/tests/style.test.mjs`.
- Keep canonical terminology from `GLOSSARY.md`, especially `Local Topo`, `Contour cartography`, `50 m contour`, `100 m contour`, and `minor contour line`.
- Preserve the project distinction between Tasmania DEM generation and Tasmania `Contour cartography`; do not move this slice into `local_topo/tasmania/scripts/_common.sh`, contour MBTiles generation, or ELVIS DEM-selection workflows.
- `tasmania-openstreetmap-contours-martin` is the active supported preview style for manual cartography verification, but this item must keep `openstreetmap-martin.json` and `openstreetmap.json` aligned for contour-layer behavior.

## Acceptance criteria
- [ ] `local_topo/tasmania/styles/local-topo/style.json` remains the implementation source of truth for the committed canonical Tasmania `Local Topo` contour cartography registered as `tasmania-local-topo`, and this slice does not change ELVIS DEM generation, contour-build scripts, or source-selection workflows.
- [ ] The canonical style introduces a dedicated `50 m contour` tier as an emphasized contour tier that is visually distinct from, but clearly related to, the `100 m contour` tier, and the `50 m contour` tier is not styled through the `minor contour line` path.
- [ ] The canonical style keeps the `100 m contour` tier as the stronger emphasized index contour tier, and both emphasized contour tiers remain visible from zoom `12`.
- [ ] The generic `minor contour line` presentation is restricted so minor contours remain visible from zoom `13`, while the emphasized `50 m contour` and `100 m contour` tiers continue to be excluded from the minor-contour styling path.
- [ ] The canonical style adds `50 m` contour labels alongside the existing `100 m` contour labels, and both label tiers start at zoom `13`.
- [ ] Both `50 m` and `100 m` contour labels keep the text format exactly as `"<elev> m"`.
- [ ] Both `50 m` and `100 m` contour label layers follow existing contour feature direction and explicitly disable viewport-upright auto-flip, treating label orientation as a style-only rule in the label layers rather than a contour-source contract change.
- [ ] The slice continues using the existing `tasmania-contours` vector source, `contours` source layer, and `elev` property contract, and does not change the ELVIS topo DEM contract, contour interval selection workflow, contour artifact generation path, or contour feature geometry direction.
- [ ] `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json` mirror the approved contour-cartography behavior so the OpenStreetMap comparison preview styles preserve contour-layer parity, while MapTiler preview variants remain out of scope.
- [ ] No new Flutter widget, robot, navigation, persistence, or external-service behavior is introduced in this slice because the app-facing basemap selection contract, routes, and async state model remain unchanged.

## Covers
- User Stories: 1-3
- Requirements: 1-8
- Technical Decisions: 1-4
- Interview Ledger: L1-L5

## Blocked by
None - ready to start
