---
type: Spec
title: Local Topo Uphill Contour Label Rotation And Water Overlay Masking
---

## Problem

The committed Tasmania `Local Topo` contour cartography currently leaves contour labels aligned with contour feature direction in a way that appears downhill-facing in the reported map output, which conflicts with the newly agreed `Uphill-facing contour label` rule. The same rendered output also shows contour lines and contour labels visible inside standing-water polygons such as lakes because the contour layers draw above the water fill. This is a cartography follow-up to the existing contour styling work, not a DEM-generation or contour-source rebuild change. [L1] [L2] [L3]

## Proposed Outcome

Update the canonical Tasmania `Local Topo` style and both OpenStreetMap comparison preview styles so contour labels face uphill by rotating the current contour-aligned labels `180` degrees, and so the verified standing-water polygons corresponding to ponds, lakes, and reservoirs visually cover contour lines and contour labels inside overlapping polygon areas while preserving water name labels above the water fill, allowing river and other waterway linework to render above contour lines, and preserving contour visibility on land up to the shoreline. Keep the MapTiler-derived preview variants unchanged. [L1] [L2] [L3]

## User Stories

1. As a user reading contour labels on Tasmania `Local Topo`, I see the top of each contour label point uphill instead of downhill, even when that makes some labels non-upright on screen. [L1]
2. As a user viewing ponds, lakes, and reservoirs on Tasmania `Local Topo`, I do not see contour lines or contour elevation labels running through the standing-water polygon. [L2]
3. As a maintainer validating Tasmania preview cartography, I can verify the same uphill-facing contour-label and standing-water-over-contour behavior in the canonical `Local Topo` style and both OpenStreetMap comparison preview styles without changing the MapTiler-derived variants. [L3]

## Requirements

1. Scope this slice to the committed Tasmania `Local Topo` style `local_topo/tasmania/styles/local-topo/style.json` and mirror the same behavior into `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json`. Keep `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` out of scope. [L3]
2. Treat `Uphill-facing contour label` as the canonical contour-label orientation rule for this project. Existing contour labels must no longer render as downhill-facing in the current reported map output. [L1]
3. Apply the uphill-facing rule to both `50 m` and `100 m` contour label layers. Do not allow viewport-upright auto-flipping to override the uphill-facing rule. [L1]
4. For the current committed contour-label rendering path, implement the approved fix by rotating each contour label `180` degrees relative to its current contour-line-aligned orientation. [L1]
5. Before implementing the masking change, verify the actual standing-water polygon feature and property contract exposed by `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, and `local_topo/tasmania/styles/local-topo/openstreetmap.json`, then scope masking only to the verified polygon features corresponding to ponds, lakes, and reservoirs in each targeted style. Do not assume raw OSM tags or exact `class` values are exposed unchanged without verification.
6. The targeted standing-water polygon fill layers must fully cover contour line layers inside overlapping pond, lake, and reservoir polygon areas. [L2]
7. The targeted standing-water polygon fill layers must also fully cover contour label layers inside those overlapping polygon areas. [L2]
8. Water name labels associated with those targeted standing-water polygons must remain visible above the water fill after the contour masking change. [L2]
9. River and other waterway line layers may render above contour lines, but this slice must not suppress contour labels specifically along river or waterway line paths.
10. Contour lines and contour labels must remain visible on land right up to the shoreline and away from the targeted standing-water polygon overlaps rather than being globally suppressed near water. [L2]
11. Preserve the existing contour source contract, contour label text format, contour zoom thresholds, and emphasized `50 m contour` and `100 m contour` tier behavior unless a change is strictly required to satisfy the uphill-facing orientation or standing-water-over-contour masking rules.

## Technical Decisions

1. Treat this slice as a style-cartography follow-up rather than a contour-source, DEM, or contour-generation workflow change. The fix must stay within the existing style-layer and verification seams. [L1] [L2] [L3]
2. This slice supersedes the prior line-direction-only contour-label orientation assumption from `ai_specs/peak-lists/0039-local-topo-50m-contour-tier-and-uphill-labels/spec.md`. Uphill-facing contour labels are now the authoritative project contract. [L1]
3. Implement the approved uphill-facing fix as an explicit `180` degree rotation on the existing contour label layers for the current rendering path rather than rewriting contour source geometry or changing contour tile generation. [L1]
4. Resolve the standing-water masking scope from the actual committed style/source contracts first, then implement the pond, lake, and reservoir masking rule through style ordering or equivalent style-level masking that preserves existing on-land contour behavior while keeping the targeted standing-water fills above contour lines and contour labels in overlapping polygon areas and keeping associated water name labels above the fill. [L2]
5. Treat river and other waterway handling as line-over-contour layering only in this slice: waterway line layers may render above contour lines, but the slice does not introduce contour-label suppression along river or waterway line paths.
6. Keep the canonical `Local Topo` style as the source of truth for the cartography change, and keep both OpenStreetMap comparison styles aligned for the same contour behavior. `tasmania-openstreetmap-contours-martin` remains the supported manual verification path. [L3]

## Testing Strategy

1. Extend deterministic `local_topo/tasmania/tests/style.test.mjs` coverage for `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, and `local_topo/tasmania/styles/local-topo/openstreetmap.json` so tests assert the contour label layers carry the explicit uphill-facing rotation rule required by this slice rather than only the prior downhill-facing line-direction behavior. [L1] [L3]
2. Add deterministic style-structure assertions proving the verified pond, lake, and reservoir polygon fill layers render above contour lines and contour labels, while associated water name labels remain above the water fill, for the canonical style and both OpenStreetMap comparison styles. Also assert that any river or waterway layering changes do not introduce contour-label suppression along line paths. [L2] [L3]
3. Update the committed manual cartography review fixture and maintainer guidance for the supported `tasmania-openstreetmap-contours-martin` path so representative review captures confirm uphill-facing contour labels and the absence of contour lines or contour labels inside overlapping targeted standing-water polygons. [L1] [L2] [L3]
4. No Flutter widget, robot, navigation, persistence, or external-service tests are required in this slice because the app-facing basemap route, screen flows, state management, and service boundaries remain unchanged; the work is confined to local-topo style cartography and its existing verification seams. [L3]

## Out of Scope

1. Rewriting contour source geometry, changing contour MBTiles generation, or changing ELVIS DEM selection or contour-build workflows. [L1] [L3]
2. Restyling `tasmania-maptiler-topo` or `tasmania-maptiler-outdoor`. [L3]
3. Masking wetlands, marshes, swamps, bogs, or other non-target landcover features in this slice.
4. Suppressing contour labels specifically along river or other waterway line paths.
5. Changing contour label copy, changing the existing `50 m contour` and `100 m contour` tier thresholds, or broadening the slice into unrelated contour-cartography redesign work.
6. Changing Flutter app navigation, basemap picker behavior, persistence, or other user flows outside Tasmania `Local Topo` cartography. [L3]

## Notes

1. Likely touchpoints include `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/styles/local-topo/openstreetmap.json`, `local_topo/tasmania/tests/style.test.mjs`, `local_topo/tasmania/fixtures/cartography-review.json`, and the relevant Local Topo maintainer docs.
2. `GLOSSARY.md` now defines `Uphill-facing contour label` as the canonical project term for this orientation rule. [L1]
