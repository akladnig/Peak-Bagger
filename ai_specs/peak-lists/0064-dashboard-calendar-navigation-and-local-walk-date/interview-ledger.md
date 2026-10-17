---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which Dashboard fixes and updates are required?

Answer:
- Confirm and correct local-time conversion of the Latest Walk date.
- Apply timeline changes consistently to Peaks Bagged, Elevation, and Distance.
- Week starts on Monday; Prev/Next navigate between Monday-based weeks.
- Week and Month must reach all recorded history rather than stopping within recent months.
- Month hover dates include the weekday, for example `Thu 15 Oct`.
- Month Prev/Next show complete adjacent calendar months rather than half-month scrolling.
- Weekly buckets in Last 3 Months and Last 6 Months start on Monday.
- Add first/last around prev/next, in the sequence first, prev, next, last; use first-page/last-page icons and exact lowercase tooltips `first` and `last`.
- Replace generic Previous/Next window tooltips with period-specific descriptions, including `Previous Week`, `Next Week`, `Previous Month`, and `Next Month`.

Decision: Correct the Latest Walk timestamp display and replace the three shared timeline cards' navigation with consistent calendar-period browsing and first/last destinations.

Source: Initial user request, Dashboard UI fixes and updates.

### L2

Status: current

Question: Should Latest Walk display the walk's start timestamp converted to the Mac's local timezone rather than its separate Track date?

Recommended Answer:
- Keep selecting the latest walk by `startDateTime`.
- Convert the displayed start timestamp to the Mac's local timezone.
- Preserve the existing short-month date format, such as `Thu, 15 Oct 2026`.
- Leave the separate Track date unchanged.

Answer: yes. What is the separate track date? is the date from teh original gpx file?

Decision: Latest Walk displays the locally converted `startDateTime` using the existing short-month formatter; it does not substitute or modify `trackDate`.

Reason: A timestamp near midnight UTC can belong to the next local calendar day. The separate Track date is a calendar-day concept. Source inspection explained that the importer normally derives it from the first GPX point's time converted locally and stripped to its calendar day, falling back to the file's last-modified date when that point lacks a usable time. This explanation did not approve importer or persistence changes.

### L3

Status: current

Question: Should Week and Month initially display the current calendar period or the period containing the latest walk?

Recommended Answer:
- Initially show the current calendar week/month.
- Week shows Monday–Sunday; Month shows the complete calendar month.
- first opens the period containing the earliest qualifying record.
- last opens the period containing the latest qualifying record.

Answer: agreed

Decision: Selecting Week or Month opens the current calendar period; first/last locate recorded activity rather than acting as aliases for today.

### L4

Status: current

Question: Should Prev/Next move by a complete displayed period for Last 3 Months, Last 6 Months, and Last 12 Months?

Recommended Answer:
- Move three, six, or twelve calendar months respectively.
- In Last 3 Months, August–October moves back to May–July.
- Use `Previous 3 Months` / `Next 3 Months`, with equivalent wording for 6 and 12 months.

Answer: yes

Decision: Multi-month navigation advances complete calendar-month pages rather than half-window offsets.

### L5

Status: current

Question: How should Monday–Sunday weeks crossing a displayed month boundary be counted in Last 3 Months and Last 6 Months?

Recommended Answer:
- Group weeks Monday–Sunday, with partial first/last weeks at calendar-month boundaries.
- Count only dates inside the selected calendar months.
- In an August–October view, the week beginning Monday 27 July contributes only 1–2 August.
- Hover shows the included date range for a partial week.
- Exclude dates outside the selected months from page totals, preventing double-counting between consecutive pages.

Answer: agreed

Decision: Monday-based weekly grouping does not expand the selected calendar-month range; edge-week values and hover ranges are clipped to the page.

### L6

Status: current

Question: Should Prev/Next visit empty periods and allow navigation forward to the current period when the latest walk is older?

Recommended Answer:
- Visit consecutive periods, including empty ones with zero-valued charts and summaries.
- Stop backwards at the period containing the earliest qualifying record and forwards at the current period.
- last still opens the latest qualifying record's period.
- Disable a button when its destination is already displayed; do not wrap.
- If the latest walk is in August and today is in October, last opens August and Next Month can then visit September and October.

Answer: agreed

Decision: History navigation is contiguous and bounded; the latest recorded activity and the current-period forward boundary are distinct destinations.

### L7

Status: current

Question: Should Year to Date remain fixed to the current year and All Time retain yearly-bucket browsing?

Recommended Answer:
- Year to Date remains the current-year view with all four navigation buttons disabled.
- All Time retains yearly buckets with up to 12 years visible; Prev/Next move 12 years and clamp at history/current-year boundaries.
- All Time first/last reveal the earliest/latest qualifying record's year.
- All Time arrow tooltips are `Previous 12 Years` and `Next 12 Years`; first/last remain lowercase.

Answer: agreed

Decision: The calendar navigation update does not turn Year to Date into a historical-year selector or change All Time to daily/monthly buckets.

### L8

Status: current

Question: Should direct horizontal scrolling or trackpad panning snap to the same complete periods as Prev/Next?

Recommended Answer:
- Retain horizontal browsing but settle on complete period pages with the agreed navigation boundaries.
- Date range, chart, total, and average describe the same settled page.
- Switching line/column view keeps the selected page.

Answer: yes

Decision: All navigation input methods share page destinations, and changing chart rendering mode preserves page selection.

### L9

Status: current

Question: Should the expanded toolbar wrap onto a second row if its controls do not fit?

Recommended Answer: Reflow controls using available card width, keeping first → prev → next → last together without clipping or reducing text scaling.

Answer: no. the cards are wide enough

Decision: Keep the toolbar on one row, including the four ordered navigation buttons, period selector, and line/column toggle. A wrapping-toolbar redesign is rejected.

Reason: The user considers the existing cards wide enough. This is not approval of numerical minimum window dimensions, which remain Pending in the app profile.

### L10

Status: current

Question: Should multi-month first/last destinations use the same page sequence as Prev/Next?

Recommended Answer:
- Anchor the page sequence to the current period.
- In October 2026, Last 3 Months pages are August–October, May–July, February–April, and so on.
- If the latest record is in June, last opens May–July, not a newly aligned April–June range.
- Apply the consistent-page rule to 6-month, 12-month, and All Time views too.

Answer: agreed

Decision: first/last locate records within the established current-period-anchored page sequence; they do not create alternative page alignments.
