---
type: Interview Ledger
parent: spec.md
---

## Records

### L11

Status: current

Source: explicit user request, 2026-10-21: "there are too many theme related tests. update the specs/tests etc. so that testing is only carried on my seed colour and dark mode only - do not test with other colours."

Decision: Future automated, native and visual verification uses only My Seed Colour
(`#7E47EB`, `baseColor`, `MyTheme.dark`) in dark mode. Remove alternate theme/seed
matrices and cross-theme rollback checks while retaining distinct behaviour,
failure, scale, resize and draft-preserving rebuild checks. Runtime theme support,
earlier answers, dated evidence and the inherited Time layout gate are unchanged.
Apply the app profile's theme testing scope across this Spec and its Work Items.

### L1

Status: current

Question: Should this work address all remaining text-field audit findings, or only visual styling?

Recommended Answer:
- Address all remaining field-related findings: styling, visible labels, accessibility and wrapping validation.
- Include Search behaviour, contextual Cmd+F and draft preservation.
- Include pending-operation guards and retained input after recoverable failures.
- Preserve existing domain validation and Map Search debounce rules; exclude unrelated Admin, Settings and navigation redesign.

Answer: "yes - note that coding-rules.md has been updated"

Decision: Close the remaining text-field findings from the current audit, including field-related behaviour and recovery rather than styling alone. Use the updated local standard and profile, not the previous audit's obsolete central-theme or Pending-window findings.

Source: The original request asked for all TextField instances and their alignment needs. The re-audit on 2026-10-21 found 23 direct application constructors (20 TextField / 3 TextFormField), including a shared Admin builder, and ran 79 passing focused tests. Counts describe source organisation, not a fixed runtime field count or proof of full compliance.

### L2

Status: current

Question: Should this work also align the app's existing selection-only dropdowns with the 2026-10-20 supplement?

Recommended Answer:
- Include a shared dropdown presentation and migrate existing single-value selectors.
- Preserve options, selected values, validation and persistence timing.
- Apply macOS rules only; exclude autocomplete, multi-select and unrelated action menus.

Answer: "yes"

Decision: Include existing selection-only dropdowns, including menu-based selectors, under ADS-1.0's adopted 2026-10-20 dropdown supplement. Preserve feature-owned typed values and actions; this is not new selection capability or a platform expansion.

### L3

Status: current

Question: Should the affected Peak Info popup use Elevation instead of Height?

Recommended Answer:
- Use Elevation for the edit-field label and Elevation: for the read-only value.
- Retain metres, existing validation, stored data and calculations.
- Follow the glossary's Peak elevation terminology.

Answer: "yes"

Decision: Rename the affected Peak Info labels exactly as recommended. The glossary already defines Peak elevation; no new glossary concept or change to unrelated height terminology is required.

### L4

Status: current

Question: Should Import Peak List and API key dialogs stay open until their submission succeeds?

Recommended Answer:
- Lock inputs, duplicate submissions and dismissal before awaited checks/saving; keep the existing duplicate-name confirmation usable.
- On recoverable failure, retain entered values/files, show an actionable error and re-enable Import / Save and Cancel.
- Close Import only after background-job acceptance; later failures keep existing Background Jobs behaviour.
- Close API key only after persistence succeeds; on failure keep the previously saved key active.
- Idle Cancel discards the draft without saving or adding confirmation.

Answer: "agreed"

Decision: Move these dialogs' completion boundary to successful hand-off/persistence respectively. Failure returns to the retained editable draft. Keep parent-operation locks distinct from the usable duplicate-name confirmation and from accepted app-owned background work.

### L5

Status: current

Question: Should Admin live Search retain today's per-entity searchable fields, rather than expand to every column?

Recommended Answer:
- Retain and explicitly enumerate current searchable fields, for example Peak Name / Alt Name, Contact name parts and Route Name rather than Description.
- Match complete display values with trimmed, case-insensitive substrings, excluding missing-value placeholders.
- Filter immediately while preserving selection/details/drafts.
- Add no searchable columns or entity Data loaders.

Answer: "agreed"

Decision: Change Search activation and identity/draft handling without broadening its per-entity matching scope or Data coverage. Enumerate the production repository's search fields in the Spec; do not substitute a test helper's narrower generic matching policy.

### L6

Status: current

Question: Should Cmd+F focus and select all text in the Search field belonging to the active surface?

Recommended Answer:
- Map opens Search if closed; otherwise focus/select its existing query.
- Peak Lists and Admin Data focus/select their Search field.
- Add New Peak dialog and Tile Cache settings target their local Search field when active.
- Do nothing when Search is unavailable, mutation-locked or behind another dialog, dropdown or drawer; do not switch modes or replay later.
- Preserve queries, selected records and unsaved drafts.
- Show Search ⌘F on eligible fields, retaining descriptive hints and accessible names.

Answer: "agreed"

Decision: Implement contextual macOS Cmd+F across those five search contexts, with current-boundary eligibility checks before focus/scroll and no query reset, implicit save/cancel/navigation or delayed replay.

### L7

Status: current

Question: When the retained Difficulty filter is unavailable in the newly selected Peak List, how should its dropdown show that selection?

Recommended Answer:
- Keep the filter active.
- Show a checked, disabled entry labelled <difficulty> (<region>) — unavailable for this list.
- Keep Any and the new list's valid choices selectable.
- Do not silently clear or replace the retained filter.

Answer: "agreed"

Decision: Make the unavailable committed selection visible without granting a new selectable value or changing filtering. Use the existing region display-name formatting in the exact label pattern.

### L8

Status: current

Question: How should the calendar Year inputs handle invalid values?

Recommended Answer:
- Validate on Enter or focus loss, not every partial keystroke.
- Retain typed text and show Enter a year from 1 to 9999 beside the field.
- Leave the calendar and selected dates unchanged until valid submission.
- Clear the error after valid submission or picker dismissal.
- Keep Apply governed by the selected start/end dates: Year navigates the calendar and does not select a date.

Answer: "agreed"

Decision: Apply this navigation-only validation independently to both calendar Year inputs. Invalid navigation text does not invalidate an otherwise valid date-range draft or silently alter its dates.

### L9

Status: current

Question: Should shared-dropdown keyboard navigation start from the committed value and wrap at the ends?

Recommended Answer:
- Opening shows the committed checkmark but no highlighted row.
- First Down/j moves to the next enabled option; Up/k to the previous.
- Skip disabled entries and wrap at either end.
- If the committed value is unavailable, start at the first/last enabled option respectively.
- Enter commits and closes; movement alone changes nothing.
- Preserve Dashboard's existing Tab/Shift+Tab card traversal and menu-return focus behaviour.

Answer: "agreed"

Decision: Use the stated keyboard-target/commit distinction in shared dropdowns. Preserve Dashboard's card-owned traversal/focus contracts rather than adding internal controls to its card traversal or changing chart inspection on mere menu return.

### L10

Status: current

Question: Should the Rating dropdown replace its star-graphic labels with text in the shared field/menu presentation?

Recommended Answer:
- Use Any, 3.0+, 3.5+, 4.0+, 4.5+.
- Give accessible names such as Rating at least 4.5 out of 5.
- Keep existing threshold values/filtering unchanged and retain stars elsewhere, such as data displays.

Answer: "agreed"

Decision: Use these exact dropdown labels to express minimum thresholds. Preserve enum identity, option ordering, existing stable selector meaning and non-dropdown domain star displays.
