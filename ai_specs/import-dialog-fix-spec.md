<goal>
Fix the GPX import dialog so it matches the established popup spacing, keeps the title on one line, and handles multi-file imports without clipping the selected-file list.
</goal>

<background>
This is a Flutter UI fix in the shared GPX import dialog used by the track import flow.
The dialog lives in `./lib/widgets/gpx_import_dialog.dart` and the result payload comes from `./lib/services/import/gpx_track_import_models.dart` via `./lib/services/gpx_importer.dart`.
The production dialog is opened from `./lib/widgets/map_action_rail.dart`.

Relevant reference files:
- `./lib/widgets/gpx_import_dialog.dart`
- `./lib/widgets/map_action_rail.dart`
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
1. Use a custom `Dialog` shell with popup-aligned padding and the same spacing rhythm used by the established popup/dialog patterns elsewhere in the app.
2. Keep the `Import GPX File(s)` title on a single line with no wrapping.
3. Keep the title row and action buttons fixed in place.
4. Let the selected-file section grow vertically from real content for smaller selections, and only switch that section to a bounded scrollable region once the available viewport height is exhausted.
5. Preserve the existing success summary counts and failure modal behavior.

**Error Handling:**
6. Picker and import failures must continue to surface through the existing `Import Failed` modal path.
7. Inline name validation must still prevent empty track/route names from reaching the import runner.

**Edge Cases:**
8. A single selected file should not trigger unnecessary scrolling or compressed content.
9. Two or three selected files should increase the dialog height when viewport space allows.
10. A large number of selected files must remain accessible through scrolling without truncating the list.
11. The existing `unchangedCount` summary should still reflect skipped duplicate content and existing content matches exactly as the importer already reports them.

**Validation:**
12. Add tests that prove the title stays single-line and the dialog remains within the viewport constraints on narrow and standard widths.
13. Add tests that prove the dialog grows with more selected files and that the file section becomes scrollable once the viewport-constrained height is exhausted.
14. Keep automated coverage focused on widget behavior and analyzer coverage for this UI fix.
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
Modify `./lib/widgets/gpx_import_dialog.dart` to use a custom `Dialog` shell with popup-aligned spacing, a fixed header/action row, and a selected-file section that expands as plain content before switching to a bounded scrollable region.

Update `./lib/widgets/map_action_rail.dart` so production opens `GpxImportDialog` directly instead of wrapping it in a second `Dialog` with its own `maxHeight` cap.

Update `./test/widget/gpx_import_dialog_test.dart` with layout and summary regressions.

Avoid changing import semantics in `./lib/services/gpx_importer.dart`.
</implementation>

<stages>
Phase 1: Rework dialog layout and sizing
- Implement the constrained custom `Dialog` shell in `./lib/widgets/gpx_import_dialog.dart`.
- Verify the title stays on one line and the selected-file section expands correctly on small and large viewports.
- Confirm cancellation, name validation, and the existing success/failure dialogs still behave the same.

Phase 2: Lock the behavior with tests
- Add widget tests for title wrapping, viewport-constrained multi-file selection, and dialog growth behavior.
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
- UI behavior: confirm layout, scrollability, dialog growth, and title wrapping behavior at the widget level.
- Production path: confirm the real map-action-rail launch path does not add a second dialog-level height cap.

Robot coverage expectations:
- Use key-first selectors for the dialog actions and result close buttons.
- Prefer the existing keys such as `gpx-import-dialog`, `gpx-import-select-files`, `gpx-import-button`, `gpx-import-summary`, `gpx-import-result-close`, and `gpx-import-error-close`.
- Robot coverage is optional for this fix because the current robot harness imports through the notifier and does not open the dialog UI.

Recommended verification:
- `flutter test test/widget/gpx_import_dialog_test.dart`
- `flutter analyze`
</validation>

<done_when>
The import dialog title never wraps.
The selected-file section expands vertically for smaller selections and scrolls correctly within the viewport for larger ones.
The production launch path does not wrap `GpxImportDialog` in a second constrained dialog.
Existing success, validation, and failure behavior remains intact.
The targeted widget tests and analyzer pass.
</done_when>
