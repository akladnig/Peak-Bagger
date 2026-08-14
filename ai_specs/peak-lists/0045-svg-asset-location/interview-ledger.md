---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Where should the moved peak-marker and route SVG assets be referenced from?

Answer: All three SVG assets are in `assets/svg/`.

Decision: Reference `peak_marker.svg`, `peak_marker_ticked.svg`, and `route.svg` from `assets/svg/`; do not retain root-level `assets/` paths for these moved assets.

Source: The user confirmed the intended location after the working tree showed the former root-level files deleted and all three SVGs present in `assets/svg/`.
