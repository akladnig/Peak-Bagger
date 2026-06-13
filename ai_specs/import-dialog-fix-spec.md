<goal>
Fix the GPX import dialog so it matches the established popup spacing, keeps the title on one line, and handles multi-file imports without clipping the selected-file list.
</goal>

<background>
This is a Flutter UI fix in the shared GPX import dialog used by the track import flow.
The dialog lives in `./lib/widgets/gpx_import_dialog.dart` and the result payload comes from `./lib/services/import/gpx_track_import_models.dart` via `./lib/services/gpx_importer.dart`.

Relevant reference files:
- `./lib/widgets/gpx_import_dialog.dart`
- `./lib/widgets/dialog_helpers.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./lib/screens/map_screen.dart`
- `./lib/core/constants.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/import/gpx_track_import_models.dart`
- `./test/widget/gpx_import_dialog_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

Use the existing dialog margin and popup sizing conventions from the peak-info/peak-dialog code instead of inventing a new spacing system.
</background>

<user_flows>
Primary flow:
1. User opens the GPX import dialog.
2. User selects one or more GPX files.
3. The dialog shows all selected files, the title stays single-line, and the import action remains usable.
4. User imports the files and receives a success dialog with the normal counts.

Alternative flows:
- Single-file import: the dialog stays compact and does not force a scrollable content area unnecessarily.
- Route-mode import: the same shared dialog layout rules still apply when the widget is used for routes.

Error flows:
- File picker failure: show the existing import failure dialog and preserve the picker error text behavior.
- Import runner failure: show the existing import failure dialog with the thrown error text.
- Empty or invalid edited names: keep inline validation and block import before the runner is called.
</user_flows>

<requirements>
**Functional:**
1. Keep the import dialog on the existing `AlertDialog` shell, but give its content area the same outer spacing rhythm used by the established popup/dialog patterns elsewhere in the app.
2. Keep the `Import GPX File(s)` title on a single line with no wrapping.
3. Keep the title row and action buttons fixed in place, and let only the selected-file list/content area scroll when the selection exceeds the available viewport height minus top and bottom padding.
4. Preserve the existing success summary counts and failure modal behavior.

**Error Handling:**
5. Picker and import failures must continue to surface through the existing `Import Failed` modal path.
6. Inline name validation must still prevent empty track/route names from reaching the import runner.

**Edge Cases:**
7. A single selected file should not trigger unnecessary scrolling or compressed content.
8. A large number of selected files must remain accessible through scrolling without truncating the list.
9. The existing `unchangedCount` summary should still reflect skipped duplicate content and existing content matches exactly as the importer already reports them.

**Validation:**
10. Add tests that prove the title stays single-line and the dialog remains within the viewport constraints on narrow and standard widths.
11. Add tests that prove multiple selected files produce a scrollable dialog body once the content exceeds the max height.
12. Keep automated coverage split across widget behavior, business/result mapping, and the critical user journey.
</requirements>

<boundaries>
Edge cases:
- One file selected: no forced scroll state, no excess empty space.
- Many files selected: content stays readable and scrollable.
- Long filenames: do not reintroduce title wrapping or overflow regressions.

Error scenarios:
- Picker cancellation: keep the dialog open with no failure modal.
- Picker error: keep the current failure modal and error text format.
- Import exception: keep the current failure modal and error text format.

Limits:
- Do not change GPX parsing, duplicate detection, or import persistence rules.
- Do not add extra UI chrome or new import states beyond what is needed to fix the dialog behavior.
</boundaries>

<implementation>
Modify `./lib/widgets/gpx_import_dialog.dart` to keep the current `AlertDialog` shell but add a more deliberate constrained layout inside it, using the app's existing dialog margin constants and a scrollable content area that grows to the available viewport height while keeping the title and action row fixed.

Update `./test/widget/gpx_import_dialog_test.dart` with layout and summary regressions.

Avoid changing import semantics in `./lib/services/gpx_importer.dart`.
</implementation>

<stages>
Phase 1: Rework dialog layout and sizing
- Implement the constrained, scrollable dialog shell in `./lib/widgets/gpx_import_dialog.dart`.
- Verify the title stays on one line and the selected-file list expands correctly on small and large viewports.
- Confirm cancellation, name validation, and the existing success/failure dialogs still behave the same.

Phase 2: Lock the behavior with tests
- Add widget tests for title wrapping, viewport-constrained multi-file selection, and result summary visibility.
- Run the targeted test files, then `flutter analyze`.
</stages>

<validation>
Use strict TDD order for the implementation:
1. Write the smallest failing widget test for the title/no-wrap regression.
2. Add the multi-file viewport/scroll regression.
3. Implement just enough UI code to pass each test before moving to the next.

Testing seams:
- Reuse the existing `filePicker` and `onImport` injection points in `./lib/widgets/gpx_import_dialog.dart`.
- Use deterministic fakes for file selection and import results.
- Do not introduce hidden time, network, or filesystem dependencies into the dialog tests.

Automated coverage outcomes:
- Logic/result mapping: confirm the existing import result counts still surface correctly in the success dialog.
- UI behavior: confirm layout, scrollability, and title wrapping behavior at the widget level.
- Critical journey: confirm a user can select GPX files, import them, and see the expected success dialog summary in the GPX import flow.

Robot coverage expectations:
- Use key-first selectors for the dialog actions and result close buttons.
- Prefer the existing keys such as `gpx-import-dialog`, `gpx-import-select-files`, `gpx-import-button`, `gpx-import-summary`, `gpx-import-result-close`, and `gpx-import-error-close`.
- Robot coverage is optional for this fix because the current robot harness imports through the notifier and does not open the dialog UI.

Recommended verification:
- `flutter test test/widget/gpx_import_dialog_test.dart`
- `flutter test test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `flutter analyze`
</validation>

<done_when>
The import dialog title never wraps.
The selected-file list expands and scrolls correctly within the viewport.
Existing success, validation, and failure behavior remains intact.
The targeted widget and robot tests pass.
</done_when>
