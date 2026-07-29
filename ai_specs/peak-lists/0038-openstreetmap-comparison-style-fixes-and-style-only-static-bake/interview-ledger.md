---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this fix target only the active Martin-backed preview style or keep both OpenStreetMap comparison styles aligned?

Recommended Answer:
- Fix both `styles/local-topo/openstreetmap-martin.json` and `styles/local-topo/openstreetmap.json` where the change is style-contract compatible.
- Treat `openstreetmap-martin.json` as the active preview validation target.
- Keep the canonical `styles/local-topo/style.json` and the MapTiler-derived preview variants out of scope unless a later slice intentionally ports the change.

Answer: agreed

Decision: The fix must keep both OpenStreetMap comparison styles aligned, validate primarily through the active Martin-backed preview style, and leave the canonical `Local Topo` style out of scope.

Constraints:
- Preserve `styles/local-topo/style.json` unchanged in this slice.
- Document any narrow compatibility exception if one comparison style cannot take the exact same change.

### L2

Status: current

Question: What is the visible success bar for the OpenStreetMap comparison preview?

Recommended Answer:
- Match the OpenStreetMap reference closely for the reported regressions only.
- Water should render with blue water fill and matching waterway styling instead of grey.
- Scrub around Mount Wellington should render with the expected vegetation treatment instead of missing icons.
- No broader restyling pass is in scope beyond changes needed to restore those behaviors.

Answer: agreed

Decision: The visible success bar is a targeted regression fix for blue water styling and restored scrub treatment around Mount Wellington without widening the change into a broader cartography pass.

Examples:
- Compare the local preview against `~/Desktop/lt.png` and `~/Desktop/osm.png` around Mount Wellington.

Negative Requirements:
- Do not turn this slice into a general OpenStreetMap parity restyle.

### L3

Status: current

Question: When only the style JSON or sprite assets change and the existing `output/*.mbtiles` inputs are still valid, should maintainers get a dedicated fast workflow that rerenders static PNG tiles without rebuilding upstream artifacts?

Recommended Answer:
- Yes.
- Add a dedicated maintainer workflow that rerenders `output/tiles/tasmania/local-topo/{z}/{x}/{y}.png` from existing `output/tasmania-osm.mbtiles`, `output/tasmania-contours.mbtiles`, and `output/tasmania-relief.mbtiles`.
- Fail fast if any required MBTiles input is missing.
- Do not download source data or regenerate OSM, contour, relief, or preview-runtime artifacts.
- Document this as the default path for cartography-only changes.
- Keep the full `refresh:manual` rebuild path for source-data or DEM changes.

Answer: agreed

Decision: The workflow must add a dedicated fast static rerender path for cartography-only changes that reuses existing MBTiles inputs and avoids the hours-long rebuild path.

Reason: The current `npm run refresh:manual -- --skip-prerender` path still takes hours, so the existing split is not an acceptable cartography-only workflow.

### L4

Status: current

Question: What should the maintainer-facing canonical term be for the fast workflow that rerenders static PNG tiles from existing MBTiles after a cartography-only change?

Recommended Answer:
- `style-only static bake`

Answer: agreed

Decision: `style-only static bake` is the canonical term for the fast static rerender workflow.

### L5

Status: current

Question: Should the scrub regression restore the sprite-backed treatment specifically, and is the sprite source the local `sprites/` directory?

Recommended Answer:
- Restore the local sprite-backed scrub pattern in both OpenStreetMap comparison styles.
- Treat missing scrub sprites as a regression in the comparison-style contract, not as a redesign opportunity.
- Keep the committed local sprite bundle as the source of truth.
- Confirm the sprite source is the local `sprites/` directory referenced by the style `"sprite": "sprite"` contract.

Answer: agreed

Decision: The fix must restore the local sprite-backed scrub pattern and continue sourcing sprites from the committed local `sprites/` directory.

Constraints:
- Do not replace the scrub treatment with a non-sprite substitute in this slice.
- Do not introduce remote sprite dependencies.
