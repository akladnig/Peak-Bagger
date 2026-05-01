<goal>
Add a new peak-list creation flow from the Peak Lists screen so users can name a fresh list, create it, and immediately start adding peaks to it.

This helps users who are starting a new peak list from scratch and want to move straight from list creation into peak selection without leaving the screen.
</goal>

<background>
Flutter app using Riverpod and ObjectBox.

Relevant files:
- ./lib/screens/peak_lists_screen.dart - peak lists screen toolbar and selection handoff
- ./lib/widgets/peak_list_import_dialog.dart - existing list-name dialog styling and validation pattern
- ./lib/widgets/peak_list_peak_dialog.dart - existing add-peak selector flow to open after create
- ./lib/services/peak_list_repository.dart - persistence for creating and selecting peak lists
- ./test/widget/peak_lists_screen_test.dart - existing peak-list screen coverage
- ./test/robot/peaks/peak_lists_robot.dart - robot selectors/helpers for peak-list journeys
- ./test/robot/peaks/peak_lists_journey_test.dart - critical end-to-end peak-list journeys

Current behavior:
- Peak Lists screen already has an `Import Peak List` button in the toolbar.
- The import dialog already contains the list-name field styling and validation pattern to mirror.
- The existing `Add New Peak` flow already opens the peak selector for an existing selected list; the new flow should hand off into that same peak-selector behavior after list creation.
</background>

<user_flows>
Primary flow:
1. User opens the Peak Lists screen.
2. User taps `Add New Peak List` to the left of `Import Peak List`.
3. A dialog titled `Add New Peak List` opens with a list-name field, Cancel, and Create.
4. User enters a unique name and taps Create.
5. App creates a new empty peak list and returns its `peakListId` on success; `PeakListsScreen` then selects it and opens the existing peak selector for that new list.
6. User selects peaks and saves them into the new list.

Alternative flows:
- User cancels the name dialog: nothing is created and the current selection stays unchanged.
- User submits a duplicate name: the dialog stays open and shows a validation error.
- User enters leading/trailing whitespace: the name is trimmed before validation and save.

Error flows:
- Empty or whitespace-only name: show an inline validation error and do not create the list.
- Duplicate name: block creation with an inline error and keep the dialog open.
- Repository save failure: show a visible failure state, do not open the peak selector, and do not change the current selection.
</user_flows>

<requirements>
**Functional:**
1. Add a new toolbar button to the left of `Import Peak List` on `PeakListsScreen`.
2. The new button uses the same icon as `Add New Peak` and a stable key for widget/robot tests.
3. Tapping the button opens a dialog titled `Add New Peak List`.
4. The dialog contains a list-name text field that matches the import dialog styling and validation behavior.
   - Field label: `List Name`
5. The dialog contains Cancel and Create actions.
6. Create trims the entered name before validation and save.
7. Create rejects duplicate names and does not persist a second list with the same trimmed name.
8. Successful create persists a new empty peak list before opening the peak selector.
9. After create, the new list becomes the active selected list in the screen.
10. After create, the existing add-peak selector opens for the new list without changing its behavior.
11. New peak lists must be initialized with `encodePeakListItems([])` so downstream views can decode the stored payload.
12. The create dialog returns the created `peakListId` on success; `PeakListsScreen` owns the post-create selection and add-peak handoff.
13. If create fails, the dialog shows a failure dialog and keeps the current selection unchanged.
   - The failure dialog remains open until the user dismisses it.

**Error Handling:**
14. Empty or whitespace-only names show an inline required-field error.
15. Duplicate names show an inline duplicate-name error distinct from the import dialog’s copy and keep the dialog open.
   - Error copy: `This peak list already exists.`
   - The error clears as soon as the name changes.
16. Repository failures surface via a failure dialog from the create dialog and leave the current selection unchanged.
17. Cancelling the dialog must never create or select a new list.

**Edge Cases:**
18. The button remains available even when no peak lists exist yet.
19. The newly created list remains selected if the user cancels out of the peak selector after create.
20. Creating a new list must not disturb import behavior or existing selected-list deletion behavior.

**Validation:**
21. The list-name field reuses the project’s required-name validation copy pattern from the import dialog, but duplicate-name copy is new and specific to create.
22. Create is only accepted for a non-empty trimmed name.
23. Stable keys exist for the new toolbar button, dialog, name field, Cancel, and Create actions:
   - `peak-lists-add-list-fab`
   - `peak-list-create-dialog`
   - `peak-list-create-name-field`
   - `peak-list-create-cancel`
   - `peak-list-create-button`
   - `peak-list-create` (heroTag)
</requirements>

<boundaries>
Edge cases:
- Leading/trailing spaces: trim before duplicate checks and persistence.
- Duplicate names: compare against existing peak lists using the stored name after trim.
- No existing lists: the new button still opens the create dialog.
- Minimum supported width: at 320px, the toolbar must still render both actions without clipped labels.
- No helper text or placeholder is shown in the name field.

Error scenarios:
- Save/create failure: show a failure dialog visible from the create dialog; do not open the peak selector.
- Peak selector dismissed after create: the new list remains created and selected.
- While create is in flight, disable both Cancel and Create so the request cannot be double-submitted.

Limits:
- No new list-name length limit is introduced beyond the existing import-dialog behavior.
</boundaries>

<implementation>
Files to modify:

1. ./lib/screens/peak_lists_screen.dart
   - Add the `Add New Peak List` toolbar action and hook it into the create-list flow.
   - Select the new list after creation and launch the existing peak-selector flow.
   - Own the post-create handoff after the dialog returns the created `peakListId`.

2. ./lib/widgets/peak_list_import_dialog.dart or a new shared dialog widget
   - Reuse the same list-name field styling and validation pattern as the import dialog.
   - Prefer extracting a shared list-name field/helper instead of duplicating validation logic.
   - Keep the existing validation copy pattern for required-name errors; duplicate-name copy is specific to create.

3. ./lib/services/peak_list_repository.dart
   - Use the existing repository API to persist a new empty `PeakList`.
   - Do not add a new persistence abstraction unless the current API is insufficient.

4. ./test/widget/peak_lists_screen_test.dart
   - Cover toolbar placement, dialog opening, required-name validation, duplicate-name blocking, cancel behavior, and successful create handoff.

5. ./test/robot/peaks/peak_lists_robot.dart
   - Add stable selectors/actions for the new create-list toolbar button and dialog fields.

6. ./test/robot/peaks/peak_lists_journey_test.dart
   - Cover the critical end-to-end journey: create list, open peak selector, add peaks, and verify the new list is selected.

Patterns to use:
- Keep list creation and peak selection in the existing screen flow rather than introducing a new screen.
- Keep validation visible and inline for name errors.
- Use key-first robot selectors only.
- Return the created `peakListId` from the dialog on success, then let the screen select the list and open the peak selector.

What to avoid:
- Do not reuse the import dialog’s update-existing-list path for create.
- Do not create a duplicate list-name workflow that bypasses the existing validation pattern.
- Do not change the existing import flow unless it is required to share name-field code.
</implementation>

<stages>
Phase 1: Create dialog and validation
- Add the toolbar button and dialog.
- Verify required-name and duplicate-name validation.
- Verify cancel is a no-op.

Phase 2: Persist and hand off
- Persist a new empty list.
- Select the new list.
- Open the existing peak selector for that list.

Phase 3: Automated coverage
- Add/adjust widget tests for dialog behavior and selection handoff.
- Add/update the robot journey test for the create-list flow.
</stages>

<validation>
**TDD Expectations:**
- Use vertical-slice TDD: write one failing test at a time, make it pass with the smallest implementation, then refactor while staying green.
- Start with the toolbar button and dialog opening, then required-name validation, then duplicate-name blocking, then successful create handoff.
- Keep the implementation testable by injecting the peak list repository and using the existing peak-selector harness.

**Unit/Widget Coverage:**
- Toolbar button renders in the correct position and opens the create dialog.
- Empty submit shows the required-name error.
- Duplicate submit shows a duplicate-name error and keeps the dialog open.
- Cancel closes the dialog without creating a list.
- Successful create persists an empty list and selects it.
- Successful create opens the peak selector for the new list.
- Create returns the created `peakListId` on success and any failure is shown visibly without changing selection.

**Robot Coverage:**
- Critical journey: Open Peak Lists → create a new list → add peaks through the selector → verify the new list is selected and populated.
- Use stable keys for the toolbar action, dialog title, name field, Cancel, Create, and the peak-selector flow.

**Baseline Automated Coverage Outcomes:**
- Logic/state: list-name validation, duplicate-name blocking, create/save handoff.
- UI behavior: button placement, dialog copy, validation messages, cancel/create actions.
- Critical journey: create-list flow through peak selection.
- Async behavior: create reports failures visibly without changing selection.
</validation>

<done_when>
1. The Peak Lists screen shows `Add New Peak List` left of `Import Peak List`.
2. The create dialog opens and validates the list name inline.
3. Duplicate names are blocked.
4. Creating a list persists an empty peak list and selects it.
5. The existing peak selector opens immediately after create.
6. Cancel leaves the screen unchanged.
7. Widget and robot tests cover the create-list flow.
</done_when>
