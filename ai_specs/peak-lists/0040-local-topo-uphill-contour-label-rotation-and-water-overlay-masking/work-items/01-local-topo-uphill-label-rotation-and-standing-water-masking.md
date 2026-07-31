---
type: Work Item
title: Local Topo Uphill Label Rotation And Standing-Water Masking
parent: ../spec.md
---

## What to build
Update the committed Tasmania `Local Topo` style `local_topo/tasmania/styles/local-topo/style.json` as the canonical source of truth, and mirror the same contour behavior into `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json` while keeping `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` unchanged. Verify the actual standing-water polygon feature and property contract exposed by each targeted style before changing masking scope, then implement the approved uphill-facing contour-label fix by rotating the current `50 m` and `100 m` contour label layers `180` degrees relative to their current contour-line-aligned orientation without allowing viewport-upright auto-flipping to override the uphill-facing rule. Adjust style ordering or equivalent style-level masking only for the verified polygon features corresponding to ponds, lakes, and reservoirs so the targeted standing-water polygon fill layers fully cover contour line layers and contour label layers inside overlapping polygon areas, while associated water name labels remain visible above the water fill, river and other waterway linework may render above contour lines, and contour visibility on land remains intact right up to the shoreline.

## Required context
- Similar contour-cartography seams already live in `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/styles/local-topo/openstreetmap.json`, and `local_topo/tasmania/tests/style.test.mjs`.
- Use the canonical project term `Uphill-facing contour label` from `GLOSSARY.md` and preserve the existing contour source contract, contour label text format, contour zoom thresholds, and emphasized `50 m contour` and `100 m contour` tier behavior unless a change is strictly required by this Spec.
- `tasmania-openstreetmap-contours-martin` remains the supported manual verification path, but this item must keep both OpenStreetMap comparison styles aligned with the canonical `Local Topo` style for the approved cartography behavior.
- Keep this item confined to style-cartography seams; do not rewrite contour source geometry, change contour MBTiles generation, change ELVIS DEM selection, or change Flutter app navigation, basemap picker behavior, persistence, or other user flows.

## Acceptance criteria
- [ ] The implementation scope is limited to `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, and `local_topo/tasmania/styles/local-topo/openstreetmap.json`, and leaves `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` unchanged.
- [ ] `local_topo/tasmania/styles/local-topo/style.json` remains the canonical source of truth for the cartography change, and the slice stays within existing style-layer and verification seams rather than changing contour-source, DEM, or contour-generation workflows.
- [ ] The `50 m` and `100 m` contour label layers in each targeted style follow the authoritative `Uphill-facing contour label` rule by applying an explicit `180` degree rotation relative to the current contour-line-aligned rendering path.
- [ ] The uphill-facing fix does not reintroduce viewport-upright auto-flipping, and `text-keep-upright` or equivalent upright behavior does not override the uphill-facing orientation rule for either contour label tier.
- [ ] The contour label text format remains exactly `"<elev> m"`, existing contour zoom thresholds remain unchanged, and the existing emphasized `50 m contour` and `100 m contour` tier behavior is preserved unless a strictly required style-level change is needed to satisfy the approved orientation or masking rules.
- [ ] Before applying the masking change, the implementation verifies the actual standing-water polygon feature and property contract exposed by each targeted style and limits the masking rule only to the verified polygon features corresponding to ponds, lakes, and reservoirs rather than assuming raw OSM tags or exact `class` values are exposed unchanged.
- [ ] In each targeted style, the verified standing-water polygon fill layers fully cover contour line layers inside overlapping pond, lake, and reservoir polygon areas.
- [ ] In each targeted style, the verified standing-water polygon fill layers also fully cover contour label layers inside those overlapping pond, lake, and reservoir polygon areas.
- [ ] Water name labels associated with the targeted standing-water polygons remain visible above the water fill after the contour masking change.
- [ ] River and other waterway line layers may render above contour lines, but this slice does not suppress contour labels specifically along river or waterway line paths.
- [ ] Contour lines and contour labels remain visible on land right up to the shoreline and away from the targeted standing-water polygon overlaps rather than being globally suppressed near water.
- [ ] `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json` mirror the approved contour-label rotation and standing-water-over-contour behavior from the canonical style.
- [ ] No new Flutter widget, robot, navigation, persistence, or external-service behavior is introduced because the app-facing basemap route, screen flows, state management, and service boundaries remain unchanged in this slice.

## Covers
- User Stories: 1-3
- Requirements: 1-11
- Technical Decisions: 1-6
- Interview Ledger: L1-L3

## Blocked by
None - ready to start
