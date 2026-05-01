<goal>
Update the Peak ObjectBox admin experience so peak metadata can be edited without stale coordinate data or ambiguous form state.
This matters for admins who verify peaks in the database: they need a reliable way to mark verification, record alternate names, and switch between latitude/longitude and MGRS without manual cleanup.
</goal>

<background>
Flutter app with ObjectBox-backed admin screens, Riverpod state, and a shared `Peak` model used across import, edit, and display flows.
This task touches the peak entity schema, the peak admin edit form, coordinate validation/recalculation logic, and the admin journey tests.

Files to examine:
- `./lib/models/peak.dart`
- `./lib/services/peak_admin_editor.dart`
- `./lib/screens/objectbox_admin_screen_details.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/screens/objectbox_admin_screen_controls.dart`
- `./test/services/peak_admin_editor_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/robot/objectbox_admin/objectbox_admin_robot.dart`

Assumptions:
- The existing ObjectBox admin peak details pane is the editing surface; do not create a new admin screen.
- `Recalculate` updates the draft form only and does not persist by itself.
- The clear `x` applies to editable peak form text fields only, not to read-only fields or unrelated screens.
</background>

<discovery>
Before implementing, inspect the current peak edit form and the `PeakAdminEditor` helper thoroughly.
Confirm how the ObjectBox schema is regenerated for entity field additions, and identify the smallest set of stable keys needed for the new checkbox, alternate-name field, and recalculate button.
Reuse the existing admin shell and robot harness patterns rather than introducing a new testing architecture.
</discovery>

<stages>
Phase 1: Add peak schema fields and pure editor support.
Verify `Peak` can carry `verified` and `altName`, default them correctly, and round-trip through normalize/build helpers.

Phase 2: Update the peak admin form layout and interactions.
Verify the form shows the new fields, clears opposite coordinate groups as editing begins, and exposes the recalculate and clear/select-all behaviors.

Phase 3: Wire recalculation and persistence rules.
Verify the form tracks an active coordinate mode, `Recalculate` fills missing coordinate values from the active complete group, and `Save` uses the same derivation path before validation and persistence.

Phase 4: Extend automated coverage.
Verify the new model, form behavior, and full admin journey are covered by unit, widget, and robot tests.
</stages>

<user_flows>
Primary flow:
1. Admin opens the ObjectBox admin Peak details pane.
2. Admin edits `Name`, `Alt Name`, toggles `Verified`, and enters either latitude/longitude or MGRS.
3. Admin presses `Recalculate` or `Save`.
4. The missing coordinate group is filled in, the peak is persisted, and the updated peak remains selectable in the admin view.

Alternative flows:
- New peak: `Verified` starts unchecked and `Alt Name` starts empty.
- Existing peak: the current `Verified` value and `Alt Name` load from storage and can be edited in place.
- Legacy peak with both coordinate groups populated: the current stored values are shown as-is until the user edits one side, then the edited side becomes the active source and clears the opposite side.
- Coordinate mode switch: if the admin starts editing MGRS after typing lat/long, the lat/long fields clear immediately, and vice versa.
- Keyboard/mouse power user: the suffix `x` clears that field.

Error flows:
- Partial coordinates: `Recalculate` and `Save` must not persist; inline validation explains what is missing.
- Invalid coordinates: malformed lat/long or MGRS input stays on the form and does not produce a guessed value.
- Conflicting coordinate groups: stale opposite-group values must never be saved.
</user_flows>

<requirements>
**Functional:**
1. Add a new boolean `verified` field to `Peak`, persist it through ObjectBox, and expose it in the peak admin editor as a checkbox labeled `Verified` with a default of `false` for new peaks.
2. Add a new string `altName` field to `Peak`, persist it through ObjectBox, and expose it in the peak admin editor as an editable text field labeled `Alt Name` placed to the right of `Name`.
3. Keep the current fixed `gridZoneDesignator` behavior intact; the new work must not change the existing HWC/source-of-truth flow or peak search/map behavior.
4. When the user edits any field in the MGRS group (`mgrs100kId`, `easting`, `northing`), clear latitude/longitude immediately so stale values are not visible or persisted.
5. When the user edits either latitude or longitude, clear the MGRS group immediately so stale values are not visible or persisted.
6. Add a `Recalculate` button above `Save` that derives the missing coordinate group from the current complete source group and updates the draft form without closing the editor.
7. Make `Save` use the same derivation path as `Recalculate` so persisted peaks always contain a complete, internally consistent coordinate set.
8. Add a clear `x` affordance to each editable peak text field.
9. Track an active coordinate mode in the form. The first edit in a session selects the active mode, and that mode determines which complete group is used for derivation on `Recalculate` or `Save`.
10. After a successful save, keep the same peak selected and refresh the existing details pane in place instead of clearing the admin context.

**Error Handling:**
11. If a coordinate group is incomplete or invalid, `Recalculate` and `Save` must not silently guess values; they must keep the form open and show the existing validation state.
12. If the derived coordinate conversion fails, the peak must not be saved and the user must stay on the same edit surface.

**Edge Cases:**
13. Switching between coordinate groups multiple times must always clear the opposite group, with the last actively edited group winning.
14. Existing records missing the new fields must load as `verified == false` and `altName == ''`.
15. The clear `x` should preserve focus and trigger validation/update logic the same way any other field change does.
16. `Recalculate` should be disabled while the form is saving and should be enabled only when a complete source coordinate group is present.
17. If a legacy row loads with both coordinate groups present and the user does not edit either side, save must preserve the stored values instead of rewriting them.

**Validation:**
18. Add explicit tests for the behavior order: model defaults first, coordinate normalization/recalculation second, form interactions third, full admin journey last.
</requirements>

<boundaries>
Edge cases:
- Existing peak with populated lat/long and MGRS: editing either side must clear the other side immediately before save.
- Empty alternate name: store and display it as an empty string, not `null`.
- Checkbox default: new peaks must start unchecked even if the rest of the form is prefilled.

Error scenarios:
- Partial coordinate entry: show inline validation and keep the form editable.
- Bad conversion input: do not persist a half-updated coordinate pair.
- Save failure from the repository: keep the editor open so the admin can correct and retry.

Limits:
- Do not change peak list search, delete, map view, or other ObjectBox entity screens as part of this task.
- Do not auto-save when `Recalculate` is pressed; that action only mutates the draft form.
</boundaries>

<implementation>
Modify `./lib/models/peak.dart` to add the new entity fields, update the constructor and `copyWith`, and initialize defaults on object creation/import paths.

Extend `./lib/services/peak_admin_editor.dart` so the form state and validation/build logic understand `verified`, `altName`, and a pure coordinate recalc helper that can be reused by both `Recalculate` and `Save`. The helper should accept an explicit active coordinate mode and return a validation result without throwing on invalid input.

When the helper succeeds, it should return the derived draft values so the form can update in place; when it fails, it should preserve the current text and expose validation errors without persisting.

Update `./lib/screens/objectbox_admin_screen_details.dart` to render the new checkbox and text field, add the `Recalculate` button, clear the opposite coordinate group on edit, and add suffix clear buttons to editable peak text fields.

Refresh any generated ObjectBox schema/code as required by the model change, but avoid introducing separate persistence logic in the widget layer.

Prefer the existing Riverpod/ObjectBox admin conventions and the current `PeakAdminEditor` helper instead of adding new form frameworks or duplicating validation in the widget tree.
</implementation>

<validation>
Use vertical-slice TDD for the pure logic first: one failing test for defaults and model shape, then one for coordinate recalc behavior, then one for form interaction rules, then one for the end-to-end admin journey. Write one failing test at a time and keep each implementation change minimal until green.

Require baseline automated coverage outcomes:
- Logic/business rules: unit tests in `./test/services/peak_model_test.dart` and `./test/services/peak_admin_editor_test.dart` cover `verified`/`altName` defaults, normalization, active-mode selection, coordinate derivation, and invalid-input failures.
- UI behavior: widget tests in `./test/widget/objectbox_admin_shell_test.dart` cover the new checkbox, alternate-name field placement, clear button behavior, coordinate-group clearing, post-save selection retention, and the `Recalculate` button state.
- Critical user journeys: robot coverage in `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` covers opening a peak, editing the new fields, recalculating coordinates, saving, and verifying the persisted values in the admin view.

Testability seams:
- Keep coordinate conversion in a pure helper so unit tests can exercise it without widget pumping.
- Use the existing `TestObjectBoxAdminRepository` and admin robot harness for persistence and journey coverage.
- Add stable keys for the new controls, for example `objectbox-admin-peak-verified`, `objectbox-admin-peak-alt-name`, and `objectbox-admin-peak-recalculate`.

Behavior-first slices:
1. `verified` defaults to false and `altName` defaults to empty.
2. Editing a coordinate group clears the opposite group.
3. `Recalculate` populates the missing group from the active complete group.
4. `Save` persists the recalculated values.
5. Clear affordances work on editable peak text fields.

Prefer fakes over mocks for repository behavior, and avoid testing private widget internals when a public field, button, or journey can express the same behavior.
</validation>

<done_when>
The Peak admin editor can store `verified` and `altName`, safely switch between MGRS and latitude/longitude editing, recalculate missing coordinates on demand or on save, and pass unit, widget, and robot coverage for the new behavior.
</done_when>
