---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Which search-results surfaces should receive the Peak List details table styling?

Recommended Answer:
- Apply it to `PeakMultiSelectResultsList` and the map `Search popup` (`MapSearchResultsList`).
- Apply it to all ObjectBox Admin tables through their shared grid implementation.

Answer: Apply to `PeakMultiSelectResultsList` and Search popup (`MapSearchResultsList`); ObjectBox Admin tables are also in scope.

Decision: Extend the shared styling to Peak List details, both search-result surfaces, and the generic ObjectBox Admin data grid.

### L2

Status: current

Question: What is the canonical name for the shared visual contract?

Recommended Answer: Use `Data grid style`, covering tables and row-based data-browsing surfaces without calling every surface a table.

Answer: yes

Decision: `Data grid style` is the canonical project term for the shared visual treatment.

### L3

Status: current

Question: Should Data grid style standardize presentation only while each surface retains its existing content and interaction structure?

Recommended Answer:
- Keep Peak List details sorting and headers.
- Keep peak multi-select checkboxes and columns without adding headers.
- Keep Search popup icons, title/subtitle, trailing metadata, grouping, and pagination.
- Keep ObjectBox Admin columns, sorting, deletion, and scrolling.

Answer: agreed

Decision: Adopt shared presentation only; preserve each surface's existing structure and behavior.

### L4

Status: current

Question: Should persistent selection use one theme-aware Data grid style selected-row decoration?

Recommended Answer: Yes. Replace peak multi-select's green row background and ObjectBox Admin's seed-color highlight with the Peak List details selected-row treatment, while retaining the green checked-checkbox indicator. Search popup has no persistent local selection and uses hover and pressed feedback only.

Answer: agreed

Decision: Use the shared selected-row treatment for persistent selection while retaining checkbox semantics and avoiding persistent selection in Search popup.

### L5

Status: current

Question: What responsive and accessibility behavior should the shared Data grid style guarantee?

Recommended Answer:
- Retain existing desktop scroll models and avoid clipped or overlapping text at supported text scales.
- Retain touch targets, keyboard activation, hover-independent selection, and screen-reader labels.
- Do not introduce a compact or mobile-specific layout.

Answer: agreed. This is a desktop-only app.

Decision: Preserve desktop interaction, scrolling, and accessible text/keyboard behavior; do not add a mobile layout.

### L6

Status: current

Question: Should Data grid style derive from the active app theme and seed colour without a new Settings control?

Recommended Answer: Yes. Add a `ThemeExtension` in `theme.dart` with light and dark variants derived from the active `ColorScheme`.

Answer: yes

Decision: Data grid style is an automatic theme-derived extension, not a user-configurable setting.

### L7

Status: current

Question: What verification should this visual refactor require?

Recommended Answer: Add widget tests for light/dark theme installation and each updated surface's selected, hover, header, and padding treatment; preserve existing interaction tests; do not add robot tests because journeys do not change.

Answer: agreed

Decision: Use widget-level coverage for the shared theme and updated surfaces, retain current interaction coverage, and exclude new robot coverage.
