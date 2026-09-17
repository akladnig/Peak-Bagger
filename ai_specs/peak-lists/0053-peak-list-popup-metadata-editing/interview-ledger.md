---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: `Points` belongs to the current Peak List membership, while `Peak difficulty` and `Peak duration` are global metadata on the `Peak` and therefore appear across lists and filters. Should saving this popup update the peak's shared difficulty and duration for all lists?

Recommended Answer:
- Keep points list-specific.
- Save difficulty and duration to the shared `Peak` record.
- Do not add per-list overrides for difficulty or duration.

Answer: agreed

Decision: The Peak Lists popup keeps points as Peak List membership data and saves Peak difficulty and Peak duration to the shared `Peak` record for all lists and metadata consumers.

### L2

Status: current

Question: How should these values be entered and cleared in the popup?

Recommended Answer:
- Add text fields labelled `Difficulty` and `Duration`, pre-filled from the selected peak.
- Allow either field to be empty to clear its stored value.
- Accept only the existing duration formats: `H:MM`, `N-N hour(s)`, `N-N day(s)`, `1 day`, and `N days`.
- Keep difficulty as free text so imported regional grades such as `Easy`, `EE`, and `T4` remain valid.
- Show the parser's validation error and prevent saving until duration is corrected.

Answer: agreed

Decision: The popup edits Peak difficulty as free text and Peak duration with the existing parser; blank values clear metadata and invalid duration text blocks saving with a visible validation error.

### L3

Status: current

Question: After a successful save, should the popup retain its current behavior of closing, while the Peak Lists table and any active map metadata filters immediately reflect the new shared difficulty and duration?

Recommended Answer:
- Close on success.
- Refresh Peak Lists and map metadata-dependent content immediately.
- On validation or save failure, keep the popup open with all entered values unchanged and show the existing failure feedback.

Answer: agreed

Decision: A successful save closes the popup and refreshes Peak Lists and active map metadata consumers; validation or persistence failures preserve the open form and entered values while showing existing error feedback.
