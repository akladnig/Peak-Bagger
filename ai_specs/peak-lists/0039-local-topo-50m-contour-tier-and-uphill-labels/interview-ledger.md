---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: For this repo's contour cartography terminology, should the Spec treat `50 m` and `100 m` contours together as the emphasized contour tiers, with `minor contour lines` meaning every remaining non-`50 m` and non-`100 m` contour?

Recommended Answer:
- Yes.
- Canonical terms:
  - `50 m contour`: emphasized intermediate contour line
  - `100 m contour`: emphasized index contour line
  - `minor contour line`: any other contour line that is not a `50 m` or `100 m` contour
- Visibility intent:
  - `50 m` and `100 m` contours remain visible from zoom `12`
  - `minor contour lines` appear from zoom `13`

Answer: agreed

Decision: The Spec uses `50 m contour`, `100 m contour`, and `minor contour line` as the canonical contour cartography terms, with `50 m` and `100 m` as the emphasized contour tiers visible from zoom `12` and all remaining contours treated as minor contours visible from zoom `13`.

Constraints:
- Do not treat `50 m contours` as minor contour lines.
- Do not keep minor contour lines visible from zoom `12`.

### L2

Status: current

Question: Should contour labels remain `100 m`-only, or should the new `50 m` contour tier also receive labels?

Recommended Answer:
- Add `50 m` labels.

Answer: add 50 m labels

Decision: Both `50 m` and `100 m` contour tiers require labels.

Constraints:
- Do not keep contour labels limited to the `100 m` tier.

### L3

Status: current

Question: When `50 m` labels are added, should they appear at the same zoom threshold as the current `100 m` labels, or start one zoom later to reduce label crowding?

Recommended Answer:
- Show both `50 m` and `100 m` labels from zoom `13`.
- Apply the uphill/downhill text orientation rule to both label tiers.
- Keep the existing label text format as `"<elev> m"`.

Answer: agreed

Decision: Both `50 m` and `100 m` labels start at zoom `13`, use the existing `"<elev> m"` text format, and share the same orientation rule.

Constraints:
- Do not introduce a different label zoom threshold for `50 m` labels.
- Do not change the contour label text format.

### L4

Status: current

Question: Should this Spec treat the request as a `Contour cartography` change to `Local Topo`, not a change to ELVIS DEM generation?

Recommended Answer:
- Yes.
- Scope this as a Tasmania `Local Topo` contour cartography change.
- Keep the existing ELVIS contour source generation contract unchanged.
- Apply the styling and label-orientation changes to the committed `Local Topo` style that renders the ELVIS-derived contour tiles.

Answer: agreed

Decision: The slice is a Tasmania `Local Topo` contour cartography change scoped to the committed `Local Topo` style and existing contour rendering contract, not to ELVIS DEM generation.

Constraints:
- Do not change the ELVIS topo DEM selection or contour-generation workflow.
- Do not rewrite this slice as a DEM-source or rebuild-contract change.

### L5

Status: current

Question: When a contour label would otherwise flip to stay screen-upright, should the Spec still force the text so its bottom faces downhill and top faces uphill, even if that makes some labels appear upside down on screen?

Recommended Answer:
- Yes.
- Slope orientation takes priority over viewport uprightness.
- For both `50 m` and `100 m` contour labels, the label baseline should follow the contour so the bottom of the glyphs faces downhill and the top faces uphill.

Answer: agreed

Decision: For `50 m` and `100 m` contour labels, downhill/uphill slope orientation takes priority over viewport-upright text.

Reason: The user explicitly prefers slope-faithful orientation over screen-upright readability for this contour labeling rule.

Constraints:
- Do not silently flip some contour labels back to viewport-upright text when that would break the downhill/uphill rule.
