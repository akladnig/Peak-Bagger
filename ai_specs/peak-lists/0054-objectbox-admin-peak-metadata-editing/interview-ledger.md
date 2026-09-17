---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this scope add only the nine persisted fields from the missing-field review, while leaving the separate `sourceOfTruth` overwrite behavior unchanged?

Recommended Answer:
- Add editable controls for `peakbaggerPid`, `prominence`, `country`, `county`, `range`, `rating`, `difficulty`, `viaFerrata`, and `notes`.
- Preserve the existing `sourceOfTruth` behavior for this change.

Answer: agreed

Decision: ObjectBox Admin must add editing for exactly the nine named Peak metadata fields and must not change `sourceOfTruth` behavior.

### L2

Status: current

Question: What should an empty value or invalid numeric value do for the new fields?

Recommended Answer:
- `peakbaggerPid` is an optional positive integer; blank clears it and invalid input blocks Save with an inline error.
- `prominence` is an optional decimal; blank clears it and invalid input blocks Save.
- `rating` is an optional decimal from `0.0` to `5.0`, rounded to one decimal place; blank clears it and invalid input blocks Save.
- `country`, `county`, `range`, `difficulty`, and `viaFerrata` are optional single-line text; blank saves as an empty string.
- `notes` is optional multiline text; blank saves as an empty string.

Answer: agreed

Decision: The new fields use the specified optional-value, validation, normalization, and clearing contract.

### L3

Status: current

Question: Where and under which labels should the nine fields appear in the Peak edit form?

Recommended Answer:
- After `osmId`: `PeakBagger PID`.
- After `Elevation`: `Prominence`, `Country`, `County`, `Range`, `Rating`.
- After `Peak duration`: `Difficulty`, `Via ferrata`, `Notes`.
- Use the current text-field styling; `Notes` is multiline; retain the existing coordinates, verification, and provenance order.

Answer: agreed

Decision: The edit form uses the agreed labels and sequence while retaining the existing section order after the added fields.

### L4

Status: current

Question: The same `_PeakEditForm` renders both Add Peak and Edit Peak. Should the nine metadata fields be available in both flows?

Recommended Answer:
- Show and save them in both Add Peak and Edit Peak.
- Blank/default behavior remains as agreed.

Answer: agreed

Decision: Add Peak and Edit Peak expose the same nine metadata fields and use the same persistence and validation behavior.
