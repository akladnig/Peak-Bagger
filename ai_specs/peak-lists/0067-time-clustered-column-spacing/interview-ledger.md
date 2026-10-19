---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should Time's Clustered column view literally exchange the current visible gaps, or should each Total Time/Moving Time pair have less internal space and more separation from neighbouring clusters?

Recommended Answer:
- Use the visual grouping rule across every Time period: tightly paired columns with a larger gap between clusters.
- Preserve Total Time on the left and Moving Time on the right.
- Keep the grouping consistent when resizing or changing periods; a literal gap swap could produce unsuitable spacing.

Answer: "agreed"

Decision: Correct Time's Clustered column view so the visible gap between the two columns in a bucket is smaller than the visible gap between neighbouring bucket clusters, across periods and chart widths. Preserve series order. An exact numerical exchange of the old gaps is not required.

Answer History:
- Initial request: "fix: in the time chart Clustered Column View, swap the spacing so that the spacing between each cluster is swapped with the spacing between the columns in each cluster."
- After source inspection identified a fixed six-logical-pixel internal gap and a width-dependent external gap, the user accepted the visual grouping recommendation above.

Reason: Users should be able to distinguish each bucket's paired durations from the next bucket, including denser calendar views and resized charts.
