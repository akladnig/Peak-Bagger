<goal>
Import named peak lists from a CSV through `PeakListsScreen`, persist them in ObjectBox, and keep matching/logging deterministic for later bagging features.
This matters because users need a repeatable way to build peak-bagging lists and verify them later in ObjectBox Admin.
</goal>

<background>
Flutter app using ObjectBox, Riverpod, `csv`, `mgrs_dart`, `path_provider`, and the existing import/logging patterns.
Current `PeakListsScreen` is a stub, but the route already exists in `./lib/router.dart` and the side menu already exposes the Peaks branch.
Current patterns to follow: keyed dialogs in `./lib/screens/settings_screen.dart`, repository test doubles in `./lib/services/peak_repository.dart`, MGRS helpers in `./lib/services/peak_mgrs_converter.dart`, `import.log` handling in `./lib/services/gpx_importer.dart`, and ObjectBox Admin entity wiring in `./lib/services/objectbox_admin_repository.dart`.

Dependencies already present: `csv`, `mgrs_dart`, and `path_provider`. Add `file_picker` and `path`.

Path conventions:
- Resolve the Bushwalking import root to an absolute path at runtime; do not use a literal `~` path string.
- Preferred root: `<documents>/Bushwalking`.
- Fallback root: the user's home directory if the Documents path cannot be resolved.

Files to examine:
- `./lib/screens/peak_lists_screen.dart`
- `./lib/router.dart`
- `./lib/widgets/side_menu.dart`
- `./lib/models/peak.dart`
- `./lib/providers/objectbox_admin_provider.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peak_mgrs_converter.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/csv_importer.dart`
- `./lib/main.dart`
- `./lib/objectbox-model.json`
- `./lib/services/objectbox_schema_guard.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./test/harness/test_objectbox_admin_repository.dart`
- `./test/services/peak_repository_test.dart`
- `./test/services/peak_mgrs_converter_test.dart`
- `./test/csv_importer_test.dart`
- `./test/widget/peak_refresh_settings_test.dart`
- `./test/robot/peaks/peak_refresh_robot.dart`
- `./ai_docs/solutions/cross-cutting/010-peak-track-correlation-objectbox-schema-and-admin.md`
- `./ai_docs/solutions/bug-fixes/004-tasmap-reset-import-live-csv.md`
</background>

<user_flows>
Primary flow:
1. User opens `Peak Lists` from the side menu.
2. User taps the `Import Peak List` FAB.
3. Dialog opens with a `Select Peak Lists` button, a `List Name` text field, and an import button.
4. File picker opens in the resolved Bushwalking import root, user selects one CSV, enters a non-empty name, and imports.
5. Import stays disabled until a CSV file has been selected.
6. While import is running, the import button is disabled and shows a spinner.
7. The list is persisted to ObjectBox and is visible in ObjectBox Admin.
8. A result dialog reports whether the action created or updated a list, plus the number of peaks imported and the number skipped.

Alternative flows:
- Duplicate name: user imports with an existing list name, sees a warning, confirms update, and the existing list is replaced in place.
- Cancel: user cancels the picker or the dialog and no data changes.
- Returning user: user imports another CSV with a different name from the same screen.

Error flows:
- Empty name: show `A list name is required` and block the import.
- Missing file, malformed CSV, or missing columns: show an error and persist nothing.
- Row-level mismatch: skip the row, log a warning to `import.log`, and continue importing.
</user_flows>

<requirements>
**Functional:**
1. `./lib/screens/peak_lists_screen.dart` must show a keyed `Import Peak List` FAB and open an import dialog.
2. The dialog must show the exact controls from the source: `Select Peak Lists` button, `List Name` text field, import button, and duplicate-name warning prompt (`This list already exists - do you want to update the existing list?`).
    - The `List Name` field starts empty.
    - Selecting a file does not change the `List Name` field.
    - The import button stays disabled until a file has been selected.
3. Add `file_picker` and `path` to `./pubspec.yaml`; use `path` for path manipulation, and keep the default browse root at the resolved Bushwalking import root.
4. Extend `./lib/models/peak.dart` with a persisted `sourceOfTruth` field.
    - Store `HWC` for any `Peak` row that has been successfully matched by the CSV importer, even when the imported match keeps the existing peak location, grid, and height fields unchanged.
    - Store `HWC` when the import updates any of `latitude`, `longitude`, `elevation`, `easting`, or `northing` from CSV-derived values.
    - Later `Refresh Peak Data` flows must only overwrite rows whose `sourceOfTruth` is `null`, empty, or `OSM`; rows marked `HWC` are treated as protected CSV-corrected data.
    - During `Refresh Peak Data`, if a protected `HWC` row still uses a synthetic negative `osmId` because the peak was previously missing from OSM, and the refresh data now provides a unique real OSM id for that same peak, update the stored row to use the real non-negative `osmId` without dropping the protected `HWC` data.
5. Add an ObjectBox entity `PeakList` in `./lib/models/peak_list.dart`.
    - Fields: `peakListId` primary key, `name`, `peakList`.
    - `name` is unique and must come from user input.
    - `peakList` is a JSON string storing an ordered array of objects `{peakOsmId, points}`.
    - Preserve CSV row order in the stored array.
6. Add a peak-list import service in `./lib/services/peak_list_import_service.dart`.
    - Public API accepts a list name and an absolute CSV path selected by the user.
    - Add a path helper that resolves the default browse root to an absolute Bushwalking import root, with fallback to the user's home directory.
    - Return structured counts and warnings: created/updated id, created-vs-updated outcome, imported, skipped, matched, ambiguous, warning entries, and log entries.
    - `warningEntries` are user-facing raw warnings without timestamps.
    - `logEntries` are timestamped lines written to `import.log`.
7. Parse CSV with the `csv` package, not ad hoc string splitting.
    - Support quoted commas, UTF-8, and standard CSV escaping.
    - Require columns: Name, Height, Zone, Easting, Northing, Latitude, Longitude, Points.
    - Treat `Points` as an opaque string copy.
8. Match each CSV row to at most one `Peak`.
    - Hard match rules: zone equals `gridZoneDesignator`, normalized `mgrs100kId` equals the `Peak.mgrs100kId` field, and normalized UTM/MGRS components compared numerically against the `Peak` fields.
    - Use `./lib/services/peak_mgrs_converter.dart` or a helper there to normalize CSV UTM fields into comparable MGRS components.
    - Matching must search progressively from `50m` up to `2km` in `50m` steps using both lat/lon distance and converted easting/northing absolute numeric differences against stored `Peak` values.
    - A row may auto-match on spatial rules alone only within the first `50m` band.
    - For any accepted match above `50m`, a strong normalized or fuzzy name confirmation is required.
    - Converted easting and northing comparisons use the current threshold at each search step.
    - If the converted easting or northing difference is greater than 50 metres for an accepted row, log a warning to `import.log` that includes the measured difference.
    - Rounded height mismatch does not block a unique match; it triggers a `Peak.elevation` update from the CSV value and must also be logged to `import.log`.
    - Name normalization must at least handle case, punctuation, slashes, leading/trailing `The`, and `Mt`/`Mount` variants before fuzzy comparison.
    - If multiple spatial candidates exist at a threshold, a unique strong normalized/fuzzy name match may resolve the ambiguity.
    - If zero candidates are found by `2km`, create a new `Peak` entity from the CSV row, persist it to ObjectBox, and include that new peak in the imported list.
    - If no unique name-confirmed candidate exists above `50m`, skip the row and log a warning.
9. Persist successful imports, peak corrections, and warnings.
    - Every successful import creates a new list or updates the existing list in place when the name already exists and the user confirms.
    - Updating an existing list preserves `peakListId` and replaces the stored payload.
    - Duplicate-name updates must be transactional: the existing list remains unchanged if parsing, matching, or persistence fails.
    - When a uniquely matched row disagrees with the stored `Peak` on latitude, longitude, elevation, easting, or northing, update the stored `Peak` entity from the CSV-derived values before completing the import only when the stored row has `sourceOfTruth` `null`, empty, or `OSM`.
    - When a uniquely matched row already has `Peak.sourceOfTruth == HWC`, treat the stored `Peak` row as protected CSV-corrected data: create or update the `PeakList` entry, but do not overwrite the stored `Peak` latitude, longitude, elevation, easting, or northing fields.
    - When a row is successfully matched by the CSV importer and the stored row is not already protected as `HWC`, set `Peak.sourceOfTruth` to `HWC` and do not revert it to `OSM` on later matching imports.
    - When no match is found, create a new `Peak` row from the CSV values, persist it before saving the `PeakList`, and set `Peak.sourceOfTruth` to `HWC`.
    - Append timestamped warnings to `import.log` under the resolved Bushwalking import root.
    - If log writing fails, keep the import result and surface the warning in memory.
10. `PeakList` must be visible in ObjectBox Admin in both schema and data workflows.
    - The entity must appear in the ObjectBox Admin entity dropdown.
    - Data mode must render at least `peakListId`, `name`, and a readable preview of `peakList` using the existing `objectBoxAdminPreviewValue()` pattern.

**Error Handling:**
11. If the list name is empty, block the import with `A list name is required`.
12. If the CSV is missing required columns, cannot be parsed, or the selected file does not exist, fail the import before persistence.
13. If a row has bad data, skip only that row and continue importing the rest.
14. If import is in progress, prevent duplicate submissions until the current import completes.
15. Use inline validation for pre-submit dialog errors and the existing modal failure pattern from `./lib/screens/settings_screen.dart:475-496` for post-submit import failures.

**Edge Cases:**
16. Re-importing the same CSV with a different name creates a separate `PeakList` record.
17. Re-importing the same CSV with the same name triggers the duplicate-name update flow.
18. `Peak.elevation == null` must not prevent a unique match when the other hard-match rules succeed; the CSV height should populate the stored peak and set `sourceOfTruth` to `HWC`.

**Validation:**
19. The implementation must expose deterministic seams for tests: file picker, peak lookup, peak-list storage, clock/time, filesystem root, CSV source, and log writer.
20. Use behavior-first TDD slices: dialog happy path, duplicate-name warning, parse happy path, matching rules, peak correction/source-of-truth updates, persistence/logging, then error paths.
    - Matching-rule slices must cover progressive threshold search, ambiguous nearby peaks, and name-confirmed acceptance above the initial `50m` band.
21. Keep transient dialog UI state local to `PeakListsScreen` and/or `peak_list_import_dialog.dart`.
    - Use Riverpod providers for injected services and repositories only.
    - Do not move text-field state, selected-file state, or dialog open/close state into a dedicated feature notifier unless a later requirement needs shared cross-screen state.
</requirements>

<boundaries>
UI boundaries:
- Keep `PeakListsScreen` import-focused for now; do not add bagging summary/tick UI.
- No multi-file import workflow.
- No edit/delete list management beyond duplicate-name update.

Storage boundaries:
- Keep `peakList` as a stable JSON schema, not ad hoc text.
- Do not use `line.split(',')`; quoted commas must parse correctly.
- Keep `import.log` under the resolved Bushwalking import root to match the existing import convention.
</boundaries>

<implementation>
Create or modify these files:
- `./pubspec.yaml` - add `file_picker` and `path`
- `./lib/screens/peak_lists_screen.dart` - import FAB, import dialog wiring, keys
- `./lib/widgets/peak_list_import_dialog.dart` - dialog UI and duplicate-name warning flow
- `./lib/services/peak_list_file_picker.dart` - abstraction over `file_picker`
- `./lib/models/peak.dart` - add persisted `sourceOfTruth` field and any CSV-driven field update support needed by the importer
- `./lib/models/peak_list.dart` - ObjectBox entity + JSON item DTO
- `./lib/services/peak_list_import_service.dart` - CSV parse, match, persist, log
- `./lib/services/peak_list_repository.dart` - ObjectBox wrapper + in-memory test storage
- `./lib/services/peak_repository.dart` - add `findByOsmId`/equivalent lookup
- `./lib/services/peak_mgrs_converter.dart` - add CSV UTM normalization helper
- `./lib/services/objectbox_schema_guard.dart` - include `PeakList` in the startup schema signature
- `./lib/services/objectbox_admin_repository.dart` - expose `PeakList` rows in ObjectBox Admin
- `./lib/objectbox-model.json` - regenerated schema
- `./lib/objectbox.g.dart` - regenerated bindings
- `./test/widget/peak_lists_screen_test.dart` - dialog/import/duplicate/empty-name coverage
- `./test/robot/peaks/peak_lists_robot.dart` - key-first robot harness
- `./test/robot/peaks/peak_lists_journey_test.dart` - import journey coverage
- `./test/services/peak_list_import_service_test.dart` - parser/matcher/persist/log slices
- `./test/services/peak_list_repository_test.dart` - repository behavior
- `./test/services/peak_repository_test.dart` - osmId lookup regression
- `./test/services/peak_mgrs_converter_test.dart` - CSV UTM normalization regression
- `./test/services/objectbox_schema_guard_test.dart` - schema signature regression for `PeakList`
- `./test/services/objectbox_admin_repository_test.dart` - update schema expectations for `PeakList`
- `./test/harness/test_peak_list_file_picker.dart` - fake picker for widget/robot tests

Patterns to use:
- Match existing repository/test-double style (`PeakRepository.test`, `InMemoryPeakStorage`).
- Prefer a focused importer service over embedding CSV logic in screens or providers.
- Keep the serialized `peakList` schema stable and explicit.
- Keep form and dialog state local; use Riverpod for service/repository injection only.
- Treat any new provider file as optional DI wiring, not feature-state ownership.
- Use keyed dialog controls and a fake file-picker seam so widget and robot tests stay deterministic.

What to avoid:
- Do not couple import logic to `BuildContext` or widget state.
- Do not invent a second CSV parser path.
- Do not add bagging/tick UI yet.
</implementation>

<stages>
Phase 1: UI + picker seam
- Add `PeakListsScreen` FAB/dialog, list-name validation, duplicate-name prompt, and file-picker abstraction.
- Verify with widget tests for open/cancel/empty-name/duplicate-name/loading/result flows.

Phase 2: schema + repositories
- Add `PeakList` model, repository wrapper, and `PeakRepository` osmId lookup.
- Add schema-guard updates for `PeakList`.
- Verify with unit tests for persistence, lookup behavior, and schema signature behavior.

Phase 3: import service
- Add CSV parsing, row matching, JSON serialization, and `import.log` writes.
- Verify with one failing test at a time: quoted CSV row, hard match, name-warning match, ambiguous skip, malformed-row skip.

Phase 4: codegen + admin + robot cleanup
- Regenerate ObjectBox artifacts, expose `PeakList` in ObjectBox Admin, and add the robot journey.
- Verify whole suite passes with the new entity in the schema.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for CSV parsing, row matching, name warning behavior, ambiguous-match rejection, duplicate-name update, and import-log emission.
- UI behavior: widget tests for FAB/dialog open, file-picker cancel, empty-name validation, duplicate-name warning/update prompt, import loading state, result dialog summary, and modal post-submit failure dialog.
- UI behavior: widget tests for FAB/dialog open, file-picker cancel, disabled import before file selection, empty-name validation, duplicate-name warning/update prompt, import loading state, result dialog summary, and modal post-submit failure dialog.
- Critical journeys: robot-driven import journey from `PeakListsScreen` through the dialog and list persistence.
- Persistence: unit tests for `PeakList` repository save/load and `PeakRepository` osmId lookup.
- Schema: tests that the ObjectBox metadata now includes `PeakList` and that the schema guard signature changes when `PeakList` is expected.

TDD expectations:
- One failing test at a time.
- First slice: FAB opens dialog and empty name blocks import.
- Next slices: file-picker cancel, loading state, result dialog summary, duplicate-name warning/update, quoted CSV row with comma in the name, matching rules, persistence, then log failures.
- When warnings exist or log writing fails, the result dialog must report warning count and direct the user to `import.log`.
- The result dialog must distinguish `Created peak list` from `Updated peak list`.
- Use fakes/in-memory storage for peak lookup, peak-list storage, file picker, clock, and log writer.

Robot test expectations:
- Use stable app-owned keys: `peak-lists-import-fab`, `peak-list-import-dialog`, `peak-list-name-field`, `peak-list-select-file`, `peak-list-import-button`, `peak-list-update-confirm`, `peak-list-update-cancel`.
- Prefer a fake file-picker seam over live platform dialogs.
- Assert journey behavior, not pixels: dialog opens, list name required, duplicate update path, and persisted ObjectBox record.

Verification:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- `PeakListsScreen` imports a single CSV via a dialog and stores a named `PeakList` in ObjectBox.
- Duplicate names update the existing record in place after confirmation.
- Unique peak matches update stored `Peak` latitude/longitude/easting/northing/elevation fields from CSV when they differ only if the stored row is not already protected as `HWC`; protected `HWC` rows remain unchanged while the `PeakList` import still succeeds.
- Refresh data upgrades protected peaks from synthetic negative `osmId` values to real OSM ids when a unique OSM match becomes available, without losing the protected `HWC` fields.
- The import button is disabled and shows a spinner while import is running, and success shows imported/skipped counts.
- Import cannot be submitted until a CSV file has been selected.
- The result dialog distinguishes list creation from list update.
- When warnings exist, the result dialog also shows warning count and directs the user to `import.log`.
- CSV parsing, matching, warnings, and logging follow the source document.
- The imported list is visible in ObjectBox Admin.
- Widget, robot, and unit coverage pass.
</done_when>
