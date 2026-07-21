---
type: Work Item
title: Richer Tasmania Cartography And Tile Verification
parent: ../spec.md
---

## What to build
Upgrade the committed Tasmania `Local Topo` cartography so the first richer pre-rendered release becomes a project-owned topographic basemap with more terrain depth and hiking utility while preserving the app as the sole peak presentation layer. This slice must add DEM-derived `terrain relief shading`, closer contours when viable from the chosen DEM path, richer hiking-oriented transport styling, and selected labels for place and locality names, road and track labels where legible, and major named water features, while explicitly excluding peak or summit labels or symbols and adding deterministic representative tile verification for the richer output.

## Required context
- `local_topo/tasmania/styles/local-topo/style.json` is the canonical committed style source of truth, and `local_topo/tasmania/fonts/` plus `local_topo/tasmania/sprites/` are the committed asset boundaries when label or symbol layers require checked-in assets.
- Preserve project vocabulary from `GLOSSARY.md`, especially `Local Topo`, `Local Topo tile source`, `terrain relief shading`, and `theLIST 25m DEM`.
- Reuse existing Tasmania local_topo test and smoke conventions for deterministic verification. If robot-style image review is not feasible, capture an explicit manual screenshot review loop with committed expectations instead of relying on ad hoc visual inspection.

## Acceptance criteria
- [x] The committed `Local Topo` style is upgraded toward a richer project-owned topo basemap that approaches OSM and Tracestrack information density without requiring pixel-for-pixel visual parity or cloning a third-party style exactly.
- [x] The richer style includes DEM-derived `terrain relief shading` blended into the north-up 2D topo basemap to create terrain depth and does not require true 3D terrain, pitched camera views, or extruded terrain.
- [x] The richer style renders closer contours when viable from the chosen DEM path while staying aligned with the contour-preference rules defined by the rebuild pipeline.
- [x] The richer transport layer is hiking-oriented and includes hiking paths and footways, tracks and unsealed access roads, and relevant service roads, with visible class or surface differentiation where source data supports it.
- [x] The richer basemap includes labels for place and locality names, road and track labels where legible, and major named water features.
- [x] The richer basemap does not include peak or summit labels or symbols, and app-owned peak markers, clusters, and labels remain the sole peak presentation layer.
- [x] The first richer version does not require dedicated hiking-route overlays, colored trail-relation styling, or named route labels.
- [x] Deterministic visual verification covers representative Tasmania tiles across low, mid, and high supported zooms and proves visible `terrain relief shading`, contour density, hiking-path detail, place or road or water labels, and the absence of basemap peak labels.
- [x] Visual verification prefers stable fixture-driven image comparison when feasible; otherwise the repo captures an explicit manual screenshot review loop with committed expectations.

## Covers
- User Stories: 2-3
- Requirements: 8-9, 16-18
- Technical Decisions: 5-7
- Testing Strategy: 5
- Interview Ledger: L7-L8, L10-L11

## Blocked by
- 02-shared-http-delivery-contract-for-static-and-on-demand-local-topo.md
- 03-deterministic-rebuild-policy-and-pre-rendered-production-artifact.md
