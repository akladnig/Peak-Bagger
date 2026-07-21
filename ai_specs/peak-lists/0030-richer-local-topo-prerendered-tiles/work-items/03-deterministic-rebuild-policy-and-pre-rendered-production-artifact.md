---
type: Work Item
title: Deterministic Rebuild Policy And Pre Rendered Production Artifact
parent: ../spec.md
---

## What to build
Rework the Tasmania `Local Topo` rebuild pipeline so manual and scheduled rebuilds produce the deterministic production artifact for this slice: a full Tasmania static `XYZ` PNG tile tree laid out as `tasmania/local-topo/{z}/{x}/{y}.png` with complete supported coverage for zooms `0-16`. This slice must also enforce the exact DEM and OSM source-policy contract from the Spec, including local-only DEM consumption, DEM source precedence, `10m`-preferred contour selection with `25m` fallback, monthly scheduled OSM refresh gating, local OSM override support, stale-valid OSM fallback rules, and simple source metadata written beside the output identifying which DEM source was used.

## Required context
- `local_topo/tasmania/scripts/rebuild_stack.sh`, `local_topo/tasmania/scripts/_common.sh`, `local_topo/tasmania/scripts/manual_refresh.sh`, `local_topo/tasmania/scripts/scheduled_refresh.sh`, and `local_topo/tasmania/tests/rebuild_scripts.test.mjs` are the current rebuild-policy seams.
- Reuse the repo-supported Tasmania DEM tooling where applicable, including `tool/download_tasmania_thelist_dem.dart`, but do not keep automatic DEM internet fetching in the manual or scheduled rebuild path for this slice.
- Preserve the existing vector generation scope around `Planetiler` and `tippecanoe`; this item changes rebuild policy and production artifact shape, not the underlying decision to keep those tools.

## Acceptance criteria
- [ ] The canonical production artifact for this slice is a static `XYZ` PNG tile tree laid out exactly as `tasmania/local-topo/{z}/{x}/{y}.png`, and the rebuild path supports full Tasmania prerender output for zooms `0-16`.
- [ ] Missing tiles inside the supported Tasmania footprint or supported zoom range are treated as build or deployment defects rather than normal runtime behavior.
- [ ] Manual and scheduled rebuild paths do not automatically fetch DEM data from the internet and instead consume only pre-supplied local DEM input, failing clearly when no accepted local DEM is available.
- [ ] DEM source priority is implemented exactly as specified: prefer a suitable higher-detail local DEM when available and viable, otherwise fall back to local `theLIST 25m DEM`, while local `Copernicus GLO 30` remains reserve-only rather than the normal fallback when local `theLIST 25m DEM` is available.
- [ ] Contour generation prefers `10m` contours when the chosen local DEM supports acceptable output and otherwise falls back to `25m` contours from local `theLIST 25m DEM`.
- [ ] Each rebuild writes simple source metadata beside the output identifying which DEM source was used.
- [ ] OSM cartographic feature input supports both the Tasmania `Geofabrik` extract with automatic download allowed and a pre-supplied local OSM extract override for offline or pinned rebuilds.
- [ ] Scheduled OSM refresh is age-gated monthly so a refresh is due only when the local extract is older than `30` days by file modification time; manual rebuild keeps reusing the local extract unless it is missing, unusable by the same checks, or explicitly force-refreshed.
- [ ] A local OSM extract is treated as usable only when it exists and exceeds the configured minimum size threshold; if a due scheduled refresh download fails, the rebuild continues only when the existing local extract remains usable by those same checks and logs clearly that stale OSM data was used, otherwise the rebuild fails.
- [ ] The first richer pre-rendered version uses full Tasmania tileset rebuilds only and does not require incremental or changed-area-only tile regeneration.
- [ ] Deterministic rebuild-script coverage proves DEM acceptance checks, DEM source precedence, contour fallback behavior, monthly OSM refresh gating, local OSM override behavior, stale-valid OSM fallback, and metadata output using local fixtures and fakes instead of live DEM or `Geofabrik` calls.

## Covers
- User Stories: 3, 5
- Requirements: 5-6, 10-15, 19-20
- Technical Decisions: 3-5, 7
- Testing Strategy: 2
- Interview Ledger: L5-L6, L8-L9, L12-L13

## Blocked by
None - ready to start
