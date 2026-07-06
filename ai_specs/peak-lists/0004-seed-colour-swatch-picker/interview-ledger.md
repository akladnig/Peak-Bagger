---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What should happen to the existing Catppuccin/Seeded palette selector?

Answer: Remove it from Settings and make the app use only seeded colours, with the selected seed colour driving theme generation.

Decision: The user-facing palette toggle is replaced by a seed-colour-only theme flow.

Constraints:
- Do not leave a Catppuccin option visible.
- Keep the rest of the theme controls intact.

### L2

Status: current

Question: What seed colours and picker behavior should the new settings control use?

Answer: Use the exact swatch list in the requested order, default to `M3 Baseline` `Color(0xff7e47eb)`, show the choices as rounded-square swatches in a single horizontal row, and persist the selected swatch.

Decision: Settings exposes a horizontal seed-colour swatch picker with the exact requested palette and persistence behavior.

Constraints:
- Selected swatch sets the seed colour immediately.
- The picker must stay usable on narrow screens and large text scales.
