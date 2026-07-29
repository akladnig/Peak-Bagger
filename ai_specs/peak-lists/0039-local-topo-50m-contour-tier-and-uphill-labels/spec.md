---
type: Spec
title: Local Topo 50m Contour Tier And Uphill Labels
---

## Problem

The committed canonical Tasmania `Local Topo` style currently renders a generic contour layer from zoom `12`, a dedicated `100 m` emphasized contour layer from zoom `12`, and `100 m` contour labels from zoom `13`. That leaves no dedicated `50 m contour` tier, keeps `minor contour lines` visible earlier than requested, and does not encode the requested style rule that contour labels must follow existing contour feature direction instead of prioritizing screen-upright text. The user wants this resolved as a `Contour cartography` change to `Local Topo`, not as an ELVIS DEM generation change. [L1] [L3] [L4] [L5]

## Proposed Outcome

Update the canonical Tasmania `Local Topo` contour cartography so `50 m contours` and `100 m contours` are both emphasized and visible from zoom `12`, `minor contour lines` remain visible from zoom `13`, and both `50 m` and `100 m` contour labels appear from zoom `13` using the existing `"<elev> m"` label format while following existing contour feature direction and not auto-flipping to stay screen-upright. Preserve the existing ELVIS-derived contour source and DEM-generation contract. [L1] [L2] [L3] [L4] [L5]

## User Stories

1. As a user viewing Tasmania `Local Topo`, I can see both `50 m contours` and `100 m contours` from zoom `12` so the terrain structure is clearer before the map becomes dense with minor contours. [L1]
2. As a user zooming into Tasmania `Local Topo`, I see `minor contour lines` starting at zoom `13` while the emphasized `50 m` and `100 m` tiers remain visible. [L1]
3. As a user reading contour labels on Tasmania `Local Topo`, I can see both `50 m` and `100 m` labels from zoom `13`, and the labels follow existing contour feature direction instead of auto-flipping upright on screen. [L2] [L3] [L5]

## Requirements

1. Scope this slice to Tasmania `Local Topo` `Contour cartography` in the committed canonical style `local_topo/tasmania/styles/local-topo/style.json`, which is registered as `tasmania-local-topo`. Do not treat this as an ELVIS DEM generation, contour-build, or source-selection change. [L4]
2. Introduce a dedicated `50 m contour` tier in the canonical `Local Topo` style as an emphasized contour tier that is visually distinct from, but clearly related to, the `100 m contour` tier. The `50 m contour` tier is not a minor contour line. [L1]
3. Keep the `100 m contour` tier as the stronger emphasized index contour tier in the canonical `Local Topo` style. Both emphasized contour tiers must remain visible from zoom `12`. [L1]
4. Restrict the generic `minor contour line` presentation so minor contours remain visible from zoom `13`, while continuing to exclude the emphasized `50 m` and `100 m` contour tiers from the minor-contour styling path. [L1]
5. Add `50 m` contour labels alongside the existing `100 m` contour labels. Both label tiers must start at zoom `13`. [L2] [L3]
6. Keep the contour label text format as `"<elev> m"` for both `50 m` and `100 m` labels. [L3]
7. Both `50 m` and `100 m` contour labels must follow existing contour feature direction and must not auto-flip to stay viewport-upright on screen. Treat this as a style-only orientation rule implemented in the label layers, not as a change to the contour source contract. [L3] [L5]
8. The slice must continue using the existing `tasmania-contours` vector source, `contours` source layer, and `elev` property contract from the existing contour tiles. Do not change the ELVIS topo DEM contract, contour interval selection workflow, contour artifact generation path, or contour feature geometry direction in this slice. [L4]

## Technical Decisions

1. Preserve the project distinction between Tasmania DEM generation and Tasmania `Contour cartography` by implementing the change in the committed canonical `Local Topo` style rather than in `local_topo/tasmania/scripts/_common.sh`, contour MBTiles generation, or ELVIS DEM-selection workflows. [L4]
2. Implement the new `50 m contour`, `100 m contour`, and `minor contour line` behavior through style-layer filtering against the existing `elev` attribute so the existing contour source contract stays unchanged. Keep `50 m` visually distinct from `100 m`, with `100 m` remaining the stronger emphasized tier. [L1] [L4]
3. Treat contour label orientation as an explicit style behavior for the contour label layers by following existing contour feature direction and disabling viewport-upright auto-flip, rather than relying on default symbol-placement behavior. This slice does not guarantee downhill/uphill correctness beyond the direction already present in the contour features. [L3] [L5]
4. Mirror the contour-cartography changes into both `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json` so the OpenStreetMap comparison preview styles preserve contour-layer parity while `tasmania-openstreetmap-contours-martin` remains the manual verification path. Keep the MapTiler preview variants out of scope for this slice. [L4]

## Testing Strategy

1. Extend deterministic `local_topo/tasmania/tests/style.test.mjs` coverage for the canonical `tasmania-local-topo` style plus both OpenStreetMap comparison preview styles, `tasmania-openstreetmap-contours-martin` and `tasmania-openstreetmap-contours`, so tests assert the presence and filters of the dedicated `50 m` contour tier, the retained `100 m` contour tier, the delayed `minor contour line` visibility threshold, the presence of both `50 m` and `100 m` contour label layers, the intended stronger `100 m` styling relative to `50 m`, and the existing local glyph contract where applicable. [L1] [L2] [L3]
2. Add deterministic assertions proving the contour label layers follow existing contour feature direction and disable viewport-upright auto-flip rather than leaving label orientation to default upright behavior, and keep the two OpenStreetMap comparison preview styles aligned for contour-layer behavior. [L3] [L5]
3. Add a committed `local_topo/tasmania/fixtures/cartography-review.json` review entry for `tasmania-openstreetmap-contours-martin` and run manual cartography verification against that supported preview style at representative zoom `12` and zoom `13` terrain tiles so maintainers confirm the emphasized tiers, minor-contour threshold, and non-upright line-direction label behavior. [L1] [L3] [L4] [L5]
4. No new Flutter widget, robot, navigation, persistence, or external-service tests are required in this slice because the app-facing basemap selection contract, routes, and async state model remain unchanged; the work is confined to style cartography and its local-topo verification seams. [L4]

## Out of Scope

1. Changing ELVIS DEM source selection, contour interval selection, or contour artifact generation scripts. [L4]
2. Restyling preview variants beyond the required contour-cartography updates to `openstreetmap-martin` and `openstreetmap`, or restyling the MapTiler-derived preview variants as part of this slice. [L4]
3. Changing the contour label text copy away from the existing `"<elev> m"` format. [L3]
4. Rewriting contour source geometry direction to guarantee true downhill/uphill label correctness beyond existing feature direction. [L5]
5. Changing Flutter app navigation, basemap drawer behavior, persistence, or other user flows outside Tasmania `Local Topo` cartography. [L4]

## Notes

1. Likely touchpoints include `local_topo/tasmania/styles/local-topo/style.json`, `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json`, `local_topo/tasmania/styles/local-topo/openstreetmap.json`, `local_topo/tasmania/tests/style.test.mjs`, `local_topo/tasmania/fixtures/cartography-review.json`, and maintainer docs updated to explain the `tasmania-openstreetmap-contours-martin` verification path.
2. `GLOSSARY.md` now defines `50 m contour`, `100 m contour`, and `minor contour line` as the canonical project terms for this slice. [L1]
