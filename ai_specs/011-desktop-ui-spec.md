<goal>
Simplify the Peak Lists UI so it is desktop-only and no longer supports compact/mobile layouts.
This reduces layout complexity for maintainers and keeps the desktop browsing workflow clear for users who manage peak lists, inspect details, delete lists, and import CSVs.
This applies only to the Peak Lists body inside the existing shell chrome.
</goal>

<background>
The current Peak Lists screen in `./lib/screens/peak_lists_screen.dart` uses a width breakpoint and nested `LayoutBuilder` branches to swap between a desktop split-pane layout and a compact/mobile stacked layout.
The shared app shell responsiveness in `./lib/router.dart` and `./lib/widgets/side_menu.dart` is separate from this task and must not be changed.
Relevant tests are in `./test/widget/peak_lists_screen_test.dart`, `./test/robot/peaks/peak_lists_journey_test.dart`, and `./test/robot/peaks/peak_lists_robot.dart`.
Validate `PeakListsScreen` in isolation and treat that measured width as the body-width contract.
Robot tests are interaction-only and do not validate the width contract.
</background>

<user_flows>
Primary flow:
1. Open Peak Lists.
2. See one fixed desktop layout with the summary table and details pane visible together.
3. Select a peak list row to update the details pane.
4. Import a CSV peak list and land on the imported list.

Alternative flows:
- First-time or empty state: show the empty-state copy and the import CTA.
- Returning user: sort the summary table, switch the selected row, or delete a list.
- Duplicate import name: update the existing list through the current import flow and keep the selected list in sync.

Error flows:
- Cancel delete: keep the row and selection unchanged.
- Delete selected row: move selection to the next row, previous row, or clear it when the last row is removed.
- Import warning or invalid input: surface the existing dialog/result feedback without changing the screen layout.
</user_flows>

<requirements>
**Functional:**
1. Peak Lists body must render one desktop-only composition when `PeakListsScreen` is measured in isolation at supported body widths of 1024px and above; there must be no compact/mobile branch and no breakpoint-driven layout swap.
2. The outer Peak Lists body must use a default summary/details split of 40/60 with no drag-to-resize splitter. The split may bend away from 40/60 when needed to preserve at least 280px for the summary pane and 600px for the details pane.
3. The details pane must also be desktop-only: keep the peak table and mini-map side-by-side with a default 3/7 split. The split may bend away from 3/7 when needed to preserve at least 240px for the table and 360px for the mini-map; remove the inner `<720px` stacked branch.
4. Summary rows and details rows must wrap text instead of truncating or clipping important content.
5. Row selection, including default selection of the first visible list, sorting, delete confirmation, empty state, and import completion must keep working exactly as they do now.
6. Legacy or unsupported peak lists must remain visible, readable, and deletable with the existing explanatory copy.

**Error Handling:**
6. Canceling delete or import must leave the screen state unchanged.
7. Any import warnings or validation failures must continue to surface through the existing dialog flow and must not fall back to a different layout.

**Edge Cases:**
9. If the selected list is deleted, selection must move to the next or previous visible row, or clear when no rows remain.

**Validation:**
10. Preserve stable keys for the desktop summary pane, details pane, selected title, row actions, import button, and mini-map so tests can verify the fixed layout without brittle selectors.
11. Add at least one long-name fixture so row wrapping is observable in widget tests.
</requirements>

<boundaries>
Edge cases:
- Narrow window sizes: keep the desktop composition and do not introduce a mobile fallback.
- Empty repository: continue showing the import prompt and empty-state copy.
- Unsupported legacy rows: keep the existing unsupported message and delete/reimport guidance.

Error scenarios:
- Delete canceled: no repository mutation and no selection change.
- Import canceled or failed: no screen-state change beyond the current dialog feedback.

Limits:
- Do not change `./lib/router.dart` or `./lib/widgets/side_menu.dart` for this task.
- Do not add a new responsive system, drawer behavior, or alternate compact Peak Lists screen.
- The surrounding app shell may continue to use its existing responsive navigation; this task applies only to the Peak Lists body within that shell.
</boundaries>

<implementation>
Modify `./lib/screens/peak_lists_screen.dart` to remove the width breakpoint branch and the narrow stacked layout.
Keep the current desktop content, but make it a single fixed layout with no drag-to-resize split behavior and no inner details-pane stack branch.
Keep the default selection behavior so the first visible list is selected when Peak Lists loads or when selection is lost.
Update `./test/widget/peak_lists_screen_test.dart` to assert that `PeakListsScreen` renders the desktop layout at the supported body-width floor in isolation.
Delete the old `600px` stacking test and replace it with a supported-floor widget assertion.
Update `./test/robot/peaks/peak_lists_journey_test.dart` and `./test/robot/peaks/peak_lists_robot.dart` only as needed to keep the import, selection, and delete journeys aligned with the fixed desktop layout.
Prefer the existing provider injections and in-memory test harnesses; avoid introducing new abstractions unless a failing test demands them.
</implementation>

<stages>
1. Add or update the widget test that proves `PeakListsScreen` renders the desktop composition at the supported body-width floor in isolation.
2. Remove the responsive layout branch, the outer drag-to-resize splitter, and the inner details-pane stack branch in `./lib/screens/peak_lists_screen.dart`.
3. Re-run the selection, delete, empty-state, legacy-row, and import widget tests until they pass on the fixed layout.
4. Confirm the robot journey still completes on the desktop layout without relying on compact/mobile behavior.
</stages>

<validation>
Use vertical-slice TDD: add one failing test for one behavior slice, implement the minimum change to pass, then move to the next slice.
Keep tests focused on public behavior; do not assert private widget internals.
Prefer fakes and in-memory repositories/file pickers over mocks so the layout change remains deterministic.

Baseline automated coverage outcomes:
- Logic/business rules: existing repository and service tests remain green; if any new helper contains logic, add direct unit coverage for it.
- UI behavior: widget tests cover the desktop layout, default selection, selection updates, sorting, delete confirmation, empty state, legacy rows, import completion, and wrapped rows.
- UI behavior: widget tests prove both panes stay in desktop row layouts at the supported `PeakListsScreen` body-width floor in isolation.
- Unsupported widths below 1024px are out of automated coverage.
- UI behavior: widget tests include a long-name fixture that makes wrapping behavior observable.
- Critical journeys: robot tests cover opening Peak Lists, selecting a row, deleting a row, and completing an import on the fixed desktop layout.

Robot and widget selector contract:
- Keep or replace stable app-owned keys for `peak-lists-summary-pane`, `peak-lists-details-pane`, `peak-lists-row-*`, `peak-lists-selected-title`, `peak-lists-import-fab`, `peak-lists-delete-*`, and `peak-lists-mini-map`.
- Remove any test dependence on a narrow-layout stack or drag divider key if those behaviors are deleted.

TDD expectations:
- Start with a failing widget test for the supported `PeakListsScreen` body-width-floor desktop render in isolation.
- Then remove the responsive branch, any splitter interaction, and the inner stacked-details branch.
- Finish by proving default selection, import/delete/selection journeys, and wrapped-row behavior still pass on the fixed layout.
- Replace the old 600px stacking test with a supported-floor desktop assertion.

Residual risk:
- Unsupported widths below 1024px are not exercised by automated tests and may clip.
</validation>

<done_when>
- Peak Lists renders one fixed desktop layout at supported `PeakListsScreen` body widths of 1024px and above in isolation.
- The compact/mobile Peak Lists branch, breakpoint swap, and drag-to-resize split behavior are gone.
- Default selection, sorting, delete, empty state, legacy rows, and import behavior still work.
- Widget and robot tests pass with the updated desktop-only expectations.
- No shell/navigation responsiveness was changed.
</done_when>
