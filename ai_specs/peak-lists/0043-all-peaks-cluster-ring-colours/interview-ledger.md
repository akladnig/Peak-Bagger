---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this behavior apply only to main-map clusters while `All Peaks` is active, using the standard unticked red segment and ticked green segment proportionally by peak count?

Recommended Answer:
- Yes. Leave individual markers and peak-list mini-maps unchanged.
- A cluster with 3 unticked and 1 ticked peak shows 75% red and 25% green.

Answer: agreed

Decision: Main-map clusters in `All Peaks` mode must use the proportional unticked/ticked ring: the unticked segment uses `untickedColour`, the ticked segment uses `tickedColour`, and each segment sweep equals its share of cluster members.

Negative Requirements:
- Do not change individual marker rendering.
- Do not change peak-list mini-map rendering.

### L2

Status: current

Question: When `All Peaks` is combined with map metadata filters, should each cluster's red/green proportions reflect only the currently visible filtered peaks?

Recommended Answer:
- Yes. The ring represents the peaks currently rendered in that cluster; filtering peaks updates its proportions.

Answer: agreed

Decision: In `All Peaks` mode, cluster ring proportions must be calculated from the current filtered map render set, not from peaks excluded by metadata filters.
