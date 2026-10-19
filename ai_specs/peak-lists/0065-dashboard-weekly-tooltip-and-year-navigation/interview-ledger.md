---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What Dashboard changes are requested?

Answer: Shorten the date ranges in Last 3 Months and Last 6 Months; change `Mon, 10 Aug - Sun, 16 Aug 2026` to `10-16 Aug 2026`, and a week spanning months to `28 Sep – 4 Oct 2026`. Add previous/next and endpoint navigation for complete January–December years to Year to Date. Do not show tooltips for disabled buttons. Capitalise the endpoint tooltips exactly as `First` and `Last`.

Decision: Update the shared Dashboard timeline presentation and yearly navigation. The weekly-formatting surface is narrowed by L3, and the yearly navigation contract is resolved in L2.

Constraints:
- `First` and `Last` are the exact requested text, rather than all-capital `FIRST` and `LAST`.
- Disabled button tooltip suppression concerns Dashboard navigation; retain accessible action labels and disabled feedback.

### L2

Status: current

Question: Should the preset keep the label `Year to Date` when browsing previous years?

Recommended Answer:
- Keep `Year to Date` as the preset label.
- Open on the current year, retaining its year-to-date totals and elapsed-month average.
- Previous/Next move one calendar year; historical years show January–December, with averages calculated over all 12 months.
- First/Last jump to the years containing the earliest/latest qualifying activity.
- Allow navigation through empty years, bounded by the earliest qualifying year and the current year.

Answer: yes

Decision: Retain the familiar preset label while enabling complete historical-year browsing for the Peaks Bagged, Elevation, and Distance timeline cards.

Reason: The preceding Dashboard calendar-navigation Spec and current code fix this preset to the current year. This decision deliberately replaces that restriction and its all-four-controls-disabled behavior.

### L3

Status: current

Question: Should the shorter format apply to both the date-range label underneath the dropdown/navigation controls and the weekly chart tooltip titles, or only the weekly chart tooltips?

Answer: only to the weekly chart tooltips

Decision: Apply the shorter weekly titles only to Last 3 Months and Last 6 Months chart tooltips, across Peaks Bagged, Elevation, and Distance in line and column modes. Preserve the overall date-range label underneath the dropdown in its existing format.

Answer History:
- The interviewer recommended shortening both surfaces.
- The user asked whether “overall date-range label” meant the label underneath the dropdown; the interviewer confirmed that location.
- Final answer explicitly selects only weekly chart tooltips.

Negative Requirements:
- Do not globally replace `formatSummaryDateRange` in a way that changes the overall date-range label or unrelated date displays.
