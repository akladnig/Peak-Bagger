---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which orientation rule should be canonical for contour labels in `Local Topo`?

Answer: Use the stricter face uphill rule. Currently it seems like all labels are facing downhill, so for now simply rotate each label by 180 degrees; they are currently following and aligned with the contour line.

Decision: `Uphill-facing contour labels` are the canonical contour-label orientation rule, and the current fix should rotate each contour label `180` degrees relative to the current contour-line-aligned rendering.

Answer History:
- Initial recommendation: keep labels aligned to the contour line but flip only as needed so text never appears upside down on screen.
- Final answer: prioritize the stricter uphill-facing rule instead, even if labels are not viewport-upright.

Constraints:
- Do not preserve the current downhill-facing contour label orientation.
- Do not reintroduce viewport-upright auto-flipping when it conflicts with uphill-facing labels.
- Apply the same uphill-facing fix to each current contour label layer.

### L2

Status: current

Question: When a lake or other mapped water body overlaps contours, which contour elements should remain visible above the water fill?

Recommended Answer:
- Water fill fully covers contour lines inside the water polygon.
- Water fill also covers contour labels inside the water polygon.
- Water name labels remain visible above the water fill.
- Contours and contour labels remain visible on land right up to the shoreline.

Answer: agreed

Decision: Water fill must cover contour lines and contour labels inside overlapping water polygons, while water name labels remain visible and land contours remain visible up to the shoreline.

Constraints:
- Do not leave contour lines visible inside water polygons.
- Do not leave contour labels visible inside water polygons.
- Do not hide water name labels under the water fill.

### L3

Status: current

Question: Should this contour fix apply only to the active OpenStreetMap comparison preview, or should it stay aligned across the same style set as the existing contour-cartography work?

Recommended Answer:
- Apply the fix to `local_topo/tasmania/styles/local-topo/style.json`.
- Mirror the same contour-label uphill rotation and water-over-contour stacking into `local_topo/tasmania/styles/local-topo/openstreetmap-martin.json` and `local_topo/tasmania/styles/local-topo/openstreetmap.json`.
- Keep `tasmania-maptiler-topo` and `tasmania-maptiler-outdoor` unchanged for this slice.

Answer: agreed

Decision: The slice applies to the canonical `Local Topo` style plus both OpenStreetMap comparison preview styles, while the MapTiler-derived preview variants stay out of scope.

Constraints:
- Do not limit the fix to only one OpenStreetMap comparison style.
- Do not expand this slice into `tasmania-maptiler-topo` or `tasmania-maptiler-outdoor`.
