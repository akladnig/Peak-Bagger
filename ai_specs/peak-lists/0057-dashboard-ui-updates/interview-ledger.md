---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which Dashboard UI updates are required?

Answer:
- Use `formatTrackDateShortMonth` in My Ascents and Latest Walk.
- Add yearly climb counts to My Ascents headings.
- Correct My Year to Date metrics and use sentence case for its metric labels.
- Show a single space between dashboard card summary-metric labels and values instead of fixed-width value justification.
- Rename the My Lists `% Climbed` column to `Climbed %`.
- Show a pointing cursor for the requested selectable dashboard controls.

Decision: Implement the requested Dashboard presentation, metric, copy, date-format, and cursor updates while preserving unrelated Dashboard behavior.

### L2

Status: current

Question: Should Peaks climbed count every recorded climb in the selected year, including repeated climbs of the same peak, or only distinct peaks?

Recommended Answer:
- Count every dated `PeaksBagged` association in the selected calendar year.
- Repeated climbs of one peak count separately.

Answer: agreed

Decision: The My Year to Date `Peaks climbed` metric counts dated `PeaksBagged` associations in the selected calendar year, not distinct peak identities.

Reason: This produces the intended value of 74 and matches My Ascents' recorded-climb concept.

### L3

Status: current

Question: Does Headers mean only the dashboard card summary metrics, such as `Total: 74` and `Average: 6`, on the Distance, Elevation, and Peaks Bagged cards?

Recommended Answer:
- Limit the change to dashboard card summary metrics.
- Separate each label and value by exactly one space without a fixed-width value field.
- Keep the complete metric group right-aligned in its card header.
- Do not change My Ascents or My Lists table-column alignment.

Answer: agreed

Decision: Only the Distance, Elevation, and Peaks Bagged header summary metrics lose fixed-width value justification; their groups remain right-aligned and table columns remain unchanged.

### L4

Status: current

Question: Should the pointing cursor change apply only to the listed controls on the Dashboard, or to every equivalent dropdown and navigation control throughout the app?

Recommended Answer:
- Limit it to the Dashboard's Summary controls, Latest Walk navigation controls, My Year to Date navigation controls, and My Ascents sort button.
- Enabled controls use a pointing cursor; disabled controls retain the default cursor.

Answer: agreed

Decision: Pointing cursor behavior is limited to the named, enabled Dashboard controls and does not expand app-wide.
