---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the moved control retain the `Map metadata filter` meaning and filter the selected Peak List's displayed peaks by rating, difficulty, and duration?

Recommended Answer:
- Keep `Map metadata filter` as the canonical term.
- Move its existing `Filter` control and popup from the map app bar to the Peak List details header.
- Apply it to the Peak List detail table only.

Answer: agreed

Decision: The `Map metadata filter` moves from the Map app bar to the Peak List details header and filters only the selected Peak List detail table.

### L2

Status: current

Question: What matching and combination behavior should the new name search use?

Recommended Answer:
- Use the `Search peaks` label and placeholder.
- Update immediately for a trimmed, case-insensitive substring match on peak names.
- Treat empty or whitespace-only text as no search filter.
- Combine name search and metadata criteria with AND logic.
- Clear the query when the user selects another Peak List.

Answer: agreed

Decision: The Peak List name search filters immediately by trimmed, case-insensitive substring; it combines with metadata criteria using AND logic, treats blank input as unfiltered, and resets on list selection changes.

### L3

Status: current

Question: The Map screen has an outlined `Search` trigger that opens the `Search popup`, while the new Peak List control is an always-visible text field. What should the Map search style mean here?

Recommended Answer:
- Keep an always-visible text field.
- Reuse the Map search control's outlined visual treatment with a search icon and the `Search peaks` placeholder.
- Do not add a separate button or open the `Search popup`.

Answer: agreed

Decision: The Peak List name search is an always-visible, Map-styled outlined text field, not a trigger for the `Search popup`.

### L4

Status: current

Question: Should selected Map metadata criteria persist while users switch Peak Lists and leave or re-enter the Peak Lists screen?

Recommended Answer:
- Keep criteria for the current app session and apply them to every selected Peak List's detail table.
- Clear them only through `Clear filters`.
- Keep the name query list-specific and clear it on list change.

Answer: agreed

Decision: Metadata criteria persist for the app session across Peak List selection and Peak Lists route revisits, while name-search text resets when selection changes.

### L5

Status: current

Question: What should the details table show when the name query and/or metadata filter matches no peaks?

Recommended Answer:
- Keep table headers visible.
- Show `No peaks match the current search and filters.` in the body.
- Preserve the selected list, query, and active criteria for revision or clearing.

Answer: agreed

Decision: Zero matches retain the current controls and table headers and show the exact empty-result message.

### L6

Status: current

Question: How should the details header behave when its title and controls do not fit?

Answer History:
- Initial recommendation: wrap title and controls across two lines, including at 200% text scale.
- Final answer: keep a single line; ellipsize the title with a tooltip, reserve at least 120 px for search, keep `Filter` and Add Peak fixed-width, and do not wrap or horizontally scroll the header.

Decision: The Peak List details header must remain one line. Long titles ellipsize with a full-name tooltip, search remains at least 120 px wide, and the fixed-width controls do not wrap or horizontally scroll.

### L7

Status: current

Question: Should verification use the existing widget-test pattern with no external-service fakes?

Recommended Answer:
- Add Peak Lists widget coverage for layout, search, combined filters, reset, persistence, and empty results.
- Update Map filter tests to prove the app-bar trigger is gone and metadata filtering no longer changes map markers.
- Cover constrained-width behavior.
- Require no external services or secrets.

Answer: agreed

Decision: Use deterministic widget tests and existing in-memory repositories/provider overrides; do not require robot tests, network services, or secrets.

### L8

Status: current

Question: How should the Peak List details header expose search and metadata filtering after implementation feedback?

Answer: Use `Search ⌘F` as the visible search field label, retain `Search Peaks` as its placeholder and tooltip, use a 160 px search field and 120 px icon-and-label `Filter` button on wider panes, and compact those controls at the 360 px details-pane constraint to avoid overflow.

Decision: Keep the details controls on one line with the manual wider-pane sizes and a compact 132 px search/96 px filter fallback. Every Rating, Difficulty, and Duration popup option invokes its criterion callback directly; selecting an option immediately removes non-matching detail rows.
