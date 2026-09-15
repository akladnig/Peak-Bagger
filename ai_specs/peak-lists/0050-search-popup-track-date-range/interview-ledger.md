---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which track date should date search use?

Recommended Answer:
- Use the canonical `GpxTrack.trackDate` calendar day rather than GPX start or end timestamps.
- A selected day matches that day and a range includes both endpoints.

Answer: agreed

Decision: Track date searches use `GpxTrack.trackDate` as an inclusive calendar-day filter.

### L2

Status: current

Question: How should users choose a Track date range?

Answer: Add a separate date range picker to the right of the search text input that opens a popup for selecting a custom range.

Decision: The desktop Search popup has a separate custom date-range picker immediately to the right of its text input.

### L3

Status: current

Question: Can a date range search run without text input?

Recommended Answer:
- Yes. A selected range independently returns matching results.
- A name query, when present, further narrows relevant results.

Answer: agreed, except include bagged peaks in the query.

Decision: A date range alone is a valid Search popup query; optional text narrows the relevant track or peak names.

### L4

Status: current

Question: What does "peaks bagged" mean for date-range results?

Recommended Answer:
- Include distinct peaks with a persisted bagged-peak association to a matching track.
- Show each peak once, including when it was bagged on multiple matching tracks.

Answer: Agreed. This should use the PeaksBagged entity.

Decision: Date-range search includes distinct peaks represented by `PeaksBagged` associations for matching tracks, using ordinary peak-result selection behavior.

### L5

Status: current

Question: Should the range be evaluated from `PeaksBagged.date` or `GpxTrack.trackDate`?

Recommended Answer:
- Keep `GpxTrack.trackDate` authoritative.
- Use `PeaksBagged` to obtain bagged peak IDs associated with Track-date-matching tracks.

Answer: agreed

Decision: Do not filter `PeaksBagged.date` directly; use `PeaksBagged` only for membership after filtering tracks by `GpxTrack.trackDate`.

Reason: `PeaksBagged.date` can be derived in Australian Eastern time and can differ from `GpxTrack.trackDate`.

### L6

Status: current

Question: How do entity filters apply while a date range is active?

Recommended Answer:
- All shows matching tracks and distinct bagged peaks.
- Peaks shows only distinct bagged peaks.
- Tracks/Routes shows matching tracks only, not routes.
- Maps shows no results.
- Optional text filters tracks by track name and bagged peaks by peak name.

Answer: agreed

Decision: Active date ranges constrain entity-filter behavior to date-matching tracks and bagged peaks as specified; routes and maps have no date-range results.

### L7

Status: current

Question: What are the custom picker apply, cancel, and clear semantics?

Recommended Answer:
- The trigger starts as `Any date` and displays the active day or inclusive range.
- Start-only selection means one day; selecting both dates creates an inclusive range.
- Apply commits, Cancel discards un-applied edits, and Clear removes the range and restores text-only search.

Answer: agreed

Decision: The custom date-range picker follows the stated label, single-day, inclusive-range, Apply, Cancel, and Clear contract.

### L8

Status: current

Question: Does the existing three-character text minimum apply with an active date range?

Recommended Answer:
- No. A date range is sufficient and any optional non-empty text can narrow the results.
- Retain the three-character minimum when no date range is active.

Answer: agreed

Decision: Active date-range search bypasses the text minimum; text-only search retains its existing minimum length.

### L9

Status: current

Question: What responsive behavior is required on narrow layouts?

Answer: Narrow date range is out of scope. The app is desktop only.

Decision: This feature targets desktop layouts only and does not add narrow-screen behavior.

### L10

Status: current

Question: Can typed dates be mixed with a name in the normal input?

Recommended Answer:
- A complete date or date-range expression activates the same date filter as the picker.
- Other input remains a name query.
- Do not support mixed natural-language expressions such as `Bonnet 28 Jul 62`.

Answer: agreed

Decision: The text input accepts complete date expressions as an alternative query grammar but does not support date-and-name text expressions; picker-selected ranges remain the path for combining a range and a name.

### L11

Status: current

Question: What typed date formats and two-digit-year mapping are supported?

Recommended Answer:
- Use day-first Australian date order.
- Map `00`-`49` to `2000`-`2049` and `50`-`99` to `1950`-`1999`.
- Support `d/M/yy`, `d/M/yyyy`, `d MMM yy`, and `d MMM yyyy`.
- Support inclusive `-` and `..` range separators.

Answer: agreed

Decision: Typed date parsing follows the stated deterministic formats, year mapping, and inclusive range separators.

Examples:
- `28/7/62`, `28/07/1962`, and `28 Jul 62` mean 28 July 1962.

### L12

Status: current

Question: What happens for invalid date-like input?

Recommended Answer:
- Show `Enter a valid date or date range` inline and return no results.
- Inputs that are not date-like remain name searches.
- Replacing or clearing a typed date removes its active range.

Answer: agreed

Decision: Invalid date-like input is a visible validation state with no results, never a failed name search.

### L13

Status: current

Question: How do the picker and typed-date range share state?

Recommended Answer:
- A valid typed date updates the active range and picker trigger label.
- Applying a picker range clears a typed date expression so text is available for an optional name query.
- Clearing either date input removes the active range.

Answer: agreed

Decision: The Search popup maintains one active date range shared by typed date expressions and the custom picker, with the stated synchronization behavior.
