---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What part of the peak marker colour contract should change?

Answer: Keep ticked peaks green. Change unticked peaks so each peak list can use a distinct colour instead of one shared reddish unticked colour.

Decision: Ticked peaks remain green, while unticked peaks gain per-peak-list colour identity on the map.

Constraints:
- The change applies to unticked peaks, not ticked peaks.
- Different peak lists must be visually distinguishable by colour on the map.

### L2

Status: current

Question: Is the feature limited to map markers, or should related peak-list controls also change?

Answer: The peak list buttons in the app bar and Select Peaks drawer should also change visually to reflect list identity; background colour is being considered.

Decision: The feature scope includes coordinated colour styling for peak-list controls in the map app bar and Select Peaks drawer, not just map markers.

Constraints:
- Peak-list controls must visually reflect list identity.
- The exact selected and unselected treatment is not yet finalized.

### L3

Status: current

Question: How should peaks that belong to multiple visible lists be rendered?

Answer: Use one winning list colour for unticked peaks that belong to multiple visible lists by taking the visible matching list with the lowest `peakListId`.

Decision: Unticked multi-list peaks use the visible matching list colour with the lowest `peakListId`.

Constraints:
- Preserve the existing white triangle outline.
- Preserve the existing green ticked peak contract.
- Do not introduce a multicolour halo or ring in this feature.

Examples:
- Candidate discussed: keep the existing white triangle outline and add a segmented multicolour outer halo or ring around the marker rather than turning the thin white triangle outline itself multicolour.

### L4

Status: current

Question: What palette should be used for per-list colours?

Answer: Use a fixed default and fallback palette, in order: `0xFF4C8BF5`, `0xFF12B886`, `0xFF6347EA`, `0xFFE67E22`, `0xFFD6336C`, `0xFF0EA5E9`, `0xFFA16207`, `0xFF7C4DFF`.

Decision: New and imported peak lists default to `palette[(peakListId - 1) % palette.length]` once `peakListId` is known, and legacy rows with `colour == 0` use the same fallback rule until an admin save writes a non-zero `colour`.

Constraints:
- Default and fallback colours must avoid colliding with the green ticked marker meaning.
- Admin-entered colours remain unrestricted integer or hex values and are not clamped to the default palette.

### L5

Status: current

Question: How should app-bar and Select Peaks drawer controls use list colours when selected versus unselected?

Answer: Selected list controls use a full list-colour background with contrast-aware foreground text and icons derived from the fill colour. Unselected list controls use a neutral control background with a list-colour accent. `All Peaks` and `None` remain neutral and never use a list colour.

Decision: The map app bar and Select Peaks drawer use the same selected and unselected colour contract for peak-list controls, while neutral controls stay uncoloured.

Constraints:
- Preserve exact neutral handling for `All Peaks` and `None`.
- Keep pinning and selection behavior unchanged; this decision changes styling only.

Examples:
- Candidate discussed: use a full list-colour background when selected, and a smaller accent treatment when unselected.
