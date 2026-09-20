---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should `Hgt`, `Date`, `Asc`, `Diff`, and `Time` be compact peak-details column labels while Peak elevation remains the canonical domain term elsewhere?

Recommended Answer:
- Yes. Use `Hgt`, `Date`, `Asc`, `Diff`, and `Time` only as compact labels in the peak-details table header.
- Keep Peak elevation as the canonical domain term outside that constrained table presentation.

Answer: yes

Decision: The peak-details table must use compact header labels without renaming domain terminology or unrelated user interfaces.

### L2

Status: current

Question: Should `dd/MM/yy` apply only to the peak-details table's Ascent Date cells, leaving narrative dates unchanged?

Recommended Answer:
- Yes. Add a reusable compact date formatter for the table.
- Retain readable prose dates and leave ascent dates blank when absent.

Answer: yes

Decision: Peak-details ascent-date cells must use a reusable `dd/MM/yy` formatter; prose date formatting and blank-date behavior must remain unchanged.

### L3

Status: current

Question: Should the peak-details table retain text-scale-aware measured sizing with one horizontal-padding contribution, fixed Rating/peak-name/difficulty measurement baselines, and single-line `Date` and `Time` headers?

Recommended Answer:
- Yes. Preserve responsive width measurement, sorting controls, and overflow handling while applying the compact column measurements.

Answer: yes

Decision: Retain the measured column-width algorithm with one horizontal-padding contribution, one-pixel Rating-star gaps, `Boggy Marsh sugarloaf` and `Medium` measurement baselines, and single-line `Date` and `Time` headers.
