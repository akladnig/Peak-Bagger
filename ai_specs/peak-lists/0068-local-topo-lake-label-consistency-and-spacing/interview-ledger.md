---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Does Lake Perry show different names or repeated occurrences of the same name above zoom 14?

Answer: The user supplied `~/Desktop/lp15.png`. The screenshot shows two occurrences of “Lake Perry” for the same lake at zoom 15. The original request also identifies Hartz Lake as missing its name at zooms 13 and 14.

Decision: Fix repeated lake names and missing lake names as related Tasmania Local Topo cartography defects, without changing the source names.

Source: Initial request and user-supplied Lake Perry screenshot.

### L2

Status: current

Question: Should lake names use interior labels rather than repeating along the lake, and at which zooms?

Recommended Answer:
- Apply the lake-label consistency fix generally at zooms 13–18, not just to Lake Perry.
- Position labels inside lake outlines and permit multiline wrapping.
- Leave zooms 12 and below unchanged.

Answer: agreed

Decision: At zooms 13–18, use interior lake-label positions and wrapping. The final small-versus-large lake label counts are governed by L7 and L8; zooms 12 and below remain unchanged.

Answer History:
- Initially, the user accepted one interior label for every named lake at zooms 13–18.
- Later, the user requested appropriately spaced repeats for large bodies of water. L7 and L8 replace the universal single-label rule, without changing the zoom range or interior-placement rule.

### L3

Status: current

Question: At zooms 13–14, how strongly should lake names take priority over nearby labels?

Recommended Answer:
- Prefer lake names over contour-elevation and road/path labels.
- Retain collision detection between lake names; do not force overlapping text.
- Anchor names inside their lakes, but permit text to extend beyond the shoreline for small lakes.
- Require Hartz Lake to be readable at both zooms as a regression check.

Answer: agreed

Decision: Prioritize lake names over contour and road/path labels while retaining lake-name collision detection and allowing text to extend beyond shorelines. Hartz Lake must be readable at zooms 13 and 14.

### L4

Status: current

Question: Should the fix target only the default Martin-backed Local Topo preview, allowing lake-label data to be rebuilt if needed?

Recommended Answer:
- Yes; allow lake-label data changes as well as styling where necessary.
- Preserve the Flutter tile URL and basemap controls.
- Leave legacy, MapTiler, and static-bake styles unchanged.
- Avoid lake-specific name overrides and rebuilding unrelated contours or terrain relief.

Answer: yes

Decision: Scope the fix to the default Martin-backed Tasmania Local Topo preview. Permit necessary label-data rebuilding without Flutter changes, lake-specific overrides, or unrelated DEM-derived rebuilds.

### L5

Status: current

Question: For a lake spanning several tiles, should label placement follow the lake rather than each tile or viewport, and how should separate same-named lakes be treated?

Answer: The user initially agreed to one stable interior position per lake, accepting that its name could be offscreen while part of the lake remains visible, and agreed that separate lakes sharing a name each retain their own labels. The subsequent large-lake revision allows spaced repeats instead of a single position for large lakes.

Decision: Do not generate an independent duplicate label for every tile or reposition labels according to the viewport. Preserve separate lake identities even when names match. Small lakes retain a stable interior label position; large lakes may have multiple interior positions under L7 and L8.

Answer History:
- Initial answer: agreed to the single-position/offscreen trade-off for all lakes.
- Revised answer: “For a large body of water multiple labels would be good but should be spaced appropriately e.g. spaced by 1/4 of the screen if this is at all possible?”
- Final large-lake behavior is the fixed map-display spacing and physical-area classification accepted in L7 and L8. The universal single-position/offscreen rule is superseded; no guarantee of a visible label in every possible viewport was adopted.

### L6

Status: current

Question: Should completion require both automated regression tests and visual checks in the running Local Topo map?

Recommended Answer:
- Automated checks for label count, tile-boundary duplication, and collision priority.
- Visual checks for Lake Perry at zooms 15–18, Hartz Lake at 13–14, and a large lake spanning tiles.
- Confirm zooms 12 and below and river/stream labels remain unchanged.
- Use fixture-based automated tests; reserve the live stack for visual verification.

Answer: yes

Decision: Require deterministic automated coverage plus live visual verification. Apply the final area-dependent count and repetition-spacing rules from L7 and L8 rather than the superseded one-label-for-every-lake assertion.

### L7

Status: current

Question: Would fixed map-display spacing be a suitable approximation to quarter-screen spacing for repeated large-lake names?

Recommended Answer:
- Permit repeated labels on large lakes with label centres at least 256 logical map pixels apart and no overlapping text.
- Keep one label for smaller lakes such as Lake Perry.
- Maintain spacing across tile boundaries.
- Replace the earlier universal single-position/offscreen rule.

Answer: yes

Decision: Use a minimum 256-logical-map-pixel centre-to-centre spacing for large-lake repeats, including across tile boundaries, without expanding scope into Flutter viewport reporting.

Reason: Raster XYZ requests do not contain the app viewport dimensions. Fixed spacing approximates quarter-width spacing on a 1024-logical-pixel-wide map; 1024 is an illustration, not an approved app/window dimension.

### L8

Status: current

Question: Should “large lake” depend on actual surface area so smaller lakes do not start repeating names as the user zooms in?

Recommended Answer:
- Below 1 km² (100 hectares): one interior label at zooms 13–18.
- At least 1 km²: permit repeated interior labels only where the 256-logical-pixel minimum spacing fits.
- Verify Lake Perry remains in the single-label category.

Answer: agreed

Decision: Classify lakes by actual surface area, using an inclusive large-lake threshold of 1 km². Zooming alone must not turn a small lake into a repeat-labelled lake. Large-lake status permits, but does not require, additional labels where geometry and collision constraints do not allow them.
