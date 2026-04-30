<goal>
Add a Settings-based List Exports flow that exports local peak-list data and peak data to CSV files.

This matters because users maintain curated peak lists and edited peak metadata inside the app. CSV export gives them readable local files for external use without needing to inspect ObjectBox directly.
</goal>

<background>
Peak Bagger is a Flutter app using Riverpod, ObjectBox repositories, `file_picker`, `csv`, and existing Settings confirmation/result dialogs.

The task source is `./ai_specs/list-export.md`. The generated implementation should save code changes in the existing app structure and should not create a new app or command-line tool.

Relevant files to examine before implementation:
- `./lib/screens/settings_screen.dart`
- `./lib/widgets/dialog_helpers.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_repository.dart`
- `./lib/models/peak_list.dart`
- `./lib/models/peak.dart`
- `./lib/services/peak_list_file_picker.dart`
- `./lib/services/data_export_file_picker.dart` (create)
- `./lib/providers/peak_list_provider.dart`
- `./lib/providers/peak_provider.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/peaks/peak_lists_robot.dart`
- `./test/robot/peaks/peak_lists_journey_test.dart`
</background>

<discovery>
1. `file_picker` is pinned to `^10.3.10`; use `FilePicker.platform.getDirectoryPath(initialDirectory: ...)` for output directory selection on macOS.
2. `PeakListFilePicker.resolveImportRoot()` already implements the default root convention: `~/Documents/Bushwalking` when present, otherwise home, otherwise `Directory.current.path`.
3. Existing Settings tests use provider overrides and stable keys; follow the patterns in `./test/widget/peak_refresh_settings_test.dart`.
4. Existing peak-list robot tests live under `./test/robot/peaks/`; add List Exports journey coverage there or in a new `./test/robot/settings/` folder.
5. There is no shared filesystem/log-writing seam for this feature. Add a minimal export-specific seam.
</discovery>

<user_flows>
Primary flow:
1. User opens Settings.
2. User scrolls to the bottom and sees a `List Exports` section.
3. User taps `Export Peak Lists` or `Export Peaks`.
4. App shows a confirmation dialog using the same confirmation pattern as existing Settings maintenance actions.
5. User confirms the export.
6. App opens a directory picker, initially rooted at `~/Documents/Bushwalking` when that directory exists.
7. User selects an output folder.
8. App prepares an export plan by snapshotting repository data, generating target paths, final CSV payloads, row counts, and warnings without writing CSV files or appending warning logs.
9. If generated output files already exist, app shows an overwrite confirmation before writing anything.
10. App commits the approved export plan and writes the requested CSV output.
11. App shows a success dialog with exported file count, exported row count, warning count, and the `export.log` path when warnings were logged.

Alternative flows:
- User cancels the initial confirmation: app writes no files and leaves Settings unchanged.
- User cancels directory selection: app writes no files and leaves Settings unchanged.
- User declines overwrite: app writes no files and returns to Settings with a non-error cancelled status.
- Empty `PeakList` store: `Export Peak Lists` completes successfully with `0` files and a clear result message.
- Empty `Peak` store: `Export Peaks` writes `peaks.csv` with only the header row and reports `0` rows exported.
- Peak list with no valid rows: app still writes that list's CSV with only headers unless the entire stored list payload is malformed.
- All peak-list payloads malformed: app writes no CSV files, appends warning entries to `export.log`, and shows a successful result with `0` files exported, `0` rows exported, warning count, and the `export.log` path.

Error flows:
- Directory picker throws or returns an unusable directory: show a failure dialog and write no CSV files.
- CSV generation throws for unexpected data: show a failure dialog and write no CSV files.
- Filesystem write fails before final replacement: show a failure dialog with the failing path when safe to disclose and clean up temporary files.
- Filesystem write fails during final replacement: show a failure dialog that explains the export may be partially written, preserves unrelated pre-existing files, and reports the failing path when safe to disclose.
- Logging to `export.log` fails: CSV export should still succeed, and the result dialog should mention that warning log writing failed.
- Malformed peak-list payload: skip that peak list, create no CSV file for it, append a warning to `export.log`, and include it in the success-dialog warning count.
- Peak-list item references a missing `Peak.osmId`: skip that row, append a warning to `export.log`, and include it in the success-dialog warning count.
</user_flows>

<requirements>
**Functional:**
1. Add a `List Exports` section at the bottom of `./lib/screens/settings_screen.dart`.
2. The section must contain two actions: `Export Peak Lists` and `Export Peaks`.
3. `Export Peak Lists` must export one CSV file per stored `PeakList` entity with a decodable `PeakList.peakList` payload. Malformed peak-list payloads must not create CSV files.
4. Each peak-list CSV filename must be based on the `PeakList.name`, with whitespace replaced by `-`, invalid filename/path-separator characters removed or replaced, duplicate dashes collapsed, and `-peak-list.csv` appended.
5. If filename sanitisation would produce an empty base name, use `peak-list` as the base name before appending `-peak-list.csv`.
6. If two peak lists generate the same filename, make filenames unique deterministically by appending `-2`, `-3`, and so on before `-peak-list.csv`.
7. Each peak-list CSV must use this exact header order: `Name`, `Height`, `gridZoneDesignator`, `mgrs100kId`, `Easting`, `Northing`, `Latitude`, `Longitude`, `Points`.
8. In peak-list CSV rows, `Name`, `Height`, `gridZoneDesignator`, `mgrs100kId`, `Easting`, `Northing`, `Latitude`, and `Longitude` must come from the `Peak` whose `osmId` matches the `PeakListItem.peakOsmId`.
9. In peak-list CSV rows, `Points` must come from `PeakListItem.points`.
10. Peak-list CSV row order must preserve the decoded `PeakListItem` order stored in `PeakList.peakList`.
10a. Peak-list files must be processed deterministically by `PeakList.name` case-insensitively, then by `PeakList.peakListId`.
10b. Peak-list export must build one `Map<int, Peak>` from a single `PeakRepository.getAllPeaks()` snapshot and resolve all `PeakListItem.peakOsmId` values from that map.
11. `Export Peaks` must write a single CSV file named `peaks.csv`.
12. The peaks CSV must include all stored `Peak` entities.
13. The peaks CSV must use this exact header order: `name`, `elevation`, `Latitude`, `longitude`, `area`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `osmId`, `sourceOfTruth`.
14. Peaks CSV rows must be ordered deterministically by `Peak.name` case-insensitively, then by `Peak.osmId`.
15. Null values, including `Peak.elevation` and `Peak.area`, must be exported as empty CSV fields.
16. CSV output must use the existing `csv` package rather than manual comma concatenation.
16a. CSV files must be written as UTF-8 text using `ListToCsvConverter(eol: '\n')`.
16b. Stored string fields must be exported unchanged except for CSV escaping performed by the converter.
16c. Numeric fields must be serialized with Dart's default `toString()` unless a value is null, in which case the field must be empty.
17. The user must choose an output folder for each export action.
18. The initial output-folder root must reuse the existing import-root convention from `PeakListFilePicker`: `~/Documents/Bushwalking` when it exists, otherwise the user home directory, otherwise the current directory.
19. Append warning log entries to `export.log` in the resolved default root, not necessarily the selected output folder.
20. Warning log entries must include an ISO-8601 timestamp from the injected clock's `toIso8601String()`, export type, affected list name or target filename when available, and the warning message.
21. Successful exports with skipped rows/lists must still show a success dialog, not a failure dialog.
22. The success dialog must report exported file count, exported row count, warning count, and the absolute `export.log` path when warnings were logged.
22a. If CSV export succeeds but appending `export.log` fails, the success dialog must show `Could not update export.log.`.
23. Use stable keys for the new Settings controls, dialogs, and status text. Use the `list-export-*` prefix for new List Exports selectors. The existing dialog helpers only key action buttons, so do not require title/content keys unless the helper is explicitly extended.

**Error Handling:**
24. Before overwriting any existing generated CSV, prepare an export plan and show a single overwrite confirmation listing the number of existing target files and enough path detail for the user to understand what will be replaced.
25. If the user declines overwrite, do not write any files and do not append warning log entries for that cancelled attempt.
26. If output directory selection is cancelled, do not write files and do not show a failure dialog.
27. If a selected output directory does not exist or is not writable, show a failure dialog and do not create CSV output.
28. If writing temporary CSV content fails before final replacement begins, show a failure dialog and clean up temporary files created for that attempt.
28a. If final replacement fails after one or more target files have already been created or replaced, perform best-effort cleanup of temporary files, do not delete unrelated pre-existing files, and show a failure dialog that explains the export may be partially written.
29. Append `export.log` only after final CSV replacement succeeds. If appending to `export.log` fails after CSV output succeeds, keep the CSV files and show the export as successful with an additional warning that log writing failed.
29a. If final replacement partially fails, do not append warning log entries for that attempt; show the partial-write failure dialog instead.
29b. If an approved export plan has warning log entries but zero CSV targets, such as an all-malformed peak-list export, commit may append `export.log` without final CSV replacement and must show a successful `0` files exported result.
30. If a peak-list payload cannot be decoded with `decodePeakListItems`, skip that list entirely, create no CSV file for it, and log/report a warning.
31. If a decoded `PeakListItem.peakOsmId` cannot be resolved to a `Peak`, skip that row and log/report a warning.

**Edge Cases:**
32. Peak list names containing slashes, colons, repeated whitespace, leading/trailing whitespace, or other invalid filename characters must not produce invalid paths.
33. Duplicate sanitized peak-list names must not overwrite each other in the same export run.
34. Empty exports must still produce valid CSV headers where a file is created.
35. Large peak and peak-list exports should build CSV content predictably from `PeakRepository.getAllPeaks()` and `PeakListRepository.getAllPeakLists()` only; do not query unrelated repositories or app state.
36. Both export actions and other Settings maintenance actions must be disabled while any export action is running.
36a. Export actions must also be disabled while any relevant Settings maintenance operation is already running, including peak refresh, map reset, track reset, and track-statistics recalculation.
36b. The Map Tile Cache Settings tile must be disabled while an export is running to avoid overlapping Settings maintenance workflows.
37. The export service must snapshot all required `Peak` and `PeakList` data before async filesystem writes so later in-app edits or refreshes cannot change the export contents mid-write.
37a. Other Settings actions must not be invoked by the export service; they are only disabled by the Settings UI while export is running.

**Validation:**
38. The implementation must be testable without touching the real `~/Documents/Bushwalking` directory or the user's real filesystem.
39. The export service must be testable with fake repositories, fake filesystem writes, fake clock, and fake root resolver/file picker seams.
40. Widget and robot tests must use stable keys rather than text-only selectors for the new controls and dialogs.
</requirements>

<boundaries>
Data boundaries:
- Include only `PeakList` and `Peak` entity data in this task.
- Do not export GPX tracks, bagged peaks, map tiles, Tasmap rows, SharedPreferences, ObjectBox files, or backup archives.
- Do not add import/restore behavior for these CSV exports.
- These CSVs are not required to be import-compatible in this task. Future import compatibility is intended, and a later importer update will accept the exported `gridZoneDesignator` or `mgrs100kId` peak-list fields.
- Do not mutate ObjectBox data during export.

Filesystem boundaries:
- The selected output folder receives CSV files only.
- The resolved default root receives `export.log` warning entries only.
- Do not create nested export directories unless the user-selected folder already exists and is used as the target.
- Do not silently overwrite existing CSV files without overwrite confirmation.

Platform boundaries:
- Implement using Flutter/Dart APIs and existing dependencies where possible.
- The app currently targets local desktop use; do not add cloud sync, network upload, or mobile sharing flows in this task.

Operational boundaries:
- Export cancellation is not an error.
- Warnings for skipped malformed data do not fail the whole export.
- Unexpected service, picker, CSV, or filesystem exceptions must fail safely and surface a clear dialog.
</boundaries>

<implementation>
1. Add a small export service, for example `./lib/services/data_export_service.dart`, responsible for transforming repository data into CSV rows, resolving warnings, creating deterministic filenames, detecting overwrite targets, and coordinating writes through injected seams.
1a. Use a prepare/commit service API. The prepare step takes the selected output directory, snapshots repository data, returns an immutable self-contained export plan, and performs no writes or log appends. The plan must contain target paths, row counts, warnings, overwrite conflicts, warning log entries, and final UTF-8 CSV payload strings or bytes. The commit step takes an approved plan, must not re-read repositories, and performs filesystem/log I/O only.
2. Add a new file picker seam, for example `./lib/services/data_export_file_picker.dart`, with `pickOutputDirectory()` and `resolveDefaultExportRoot()`.
3. Add a filesystem seam for existence checks, directory validation/writability checks, temporary-file writes, final replacement/rename, temporary-file cleanup, and appending `export.log` so service tests do not touch the real filesystem.
4. Add Riverpod providers for the export service and file picker/filesystem seams, likely near existing repository providers in `./lib/providers/peak_list_provider.dart` or a new focused provider file.
5. Update `./lib/screens/settings_screen.dart` to render the `List Exports` section at the bottom of the Settings `ListView`.
6. Reuse `showDangerConfirmDialog` for initial export confirmation and overwrite confirmation.
7. Reuse `showSingleActionDialog` for success and failure results.
8. Add stable keys, including at minimum: `list-export-section`, `list-export-peak-lists-tile`, `list-export-peaks-tile`, `list-export-peak-lists-confirm`, `list-export-peak-lists-cancel`, `list-export-peaks-confirm`, `list-export-peaks-cancel`, `list-export-overwrite-confirm`, `list-export-overwrite-cancel`, `list-export-status`, `list-export-result-close`, and `list-export-error-close`.
9. Keep UI state local and minimal unless existing Settings patterns require a provider; `_isExportingPeakLists`, `_isExportingPeaks`, and a separate List Exports status string rendered with `list-export-status` are acceptable.
10. Use temporary files in the selected output directory where practical: generate all CSV content first, write temporary CSV files, then replace/create final filenames only after all temporary writes have succeeded. Final replacement is best-effort across multiple files; if it fails, clean up remaining temp files and report that the export may be partially written.
11. Prefer small data/result classes such as `DataExportResult`, `DataExportWarning`, and `DataExportTarget` only if they make service testing clearer.
12. Avoid backup terminology in UI labels; the user-facing feature name is `List Exports`, and warning logs use `export.log`.
13. Do not add new packages unless required after discovery; `csv`, `file_picker`, and `path` already exist in `./pubspec.yaml`.
</implementation>

<stages>
Phase 1: Add export service tests and the minimal service API for peak CSV export.
Verify with one failing test first, then implement the smallest service code needed to pass.

Phase 2: Extend service behavior to peak-list CSV export, including row resolution from `PeakListItem.peakOsmId` to `Peak` metadata.
Verify malformed list payloads and missing peak references are skipped and surfaced as warnings.

Phase 3: Add filename sanitisation, duplicate filename handling, prepare/commit overwrite detection, best-effort final replacement behavior, and warning-log writing through fake filesystem/root seams.
Verify no real user directories are touched in tests.

Phase 4: Wire Settings UI actions, confirmation dialogs, directory picker seam, overwrite confirmation, loading state, success dialog, and failure dialog.
Verify with widget tests using provider overrides and stable keys.

Phase 5: Add robot-style Settings journey coverage for the critical happy path and warning path.
Verify the journey starts from Settings, exports through fake picker/service seams, and reports success/warnings deterministically.
</stages>

<validation>
TDD expectations:
1. Implement using vertical-slice RED-GREEN-REFACTOR cycles, one failing test at a time.
2. Start with behavior-level service tests for `Export Peaks`, then add peak-list export behavior, then filesystem and UI wiring.
3. Each test must exercise a public service/UI interface; do not test private helper methods directly.
4. Refactor only after the current slice is green.
5. Use fakes for repositories, file picker, filesystem, root resolver, and clock; mock only true external boundaries if a fake is impractical.

Unit/service coverage:
6. Test `Export Peaks` writes `peaks.csv` with exact headers, deterministic row order, null values as empty fields, and correct field mapping.
7. Test `Export Peak Lists` writes one CSV per list with exact headers, filename format, decoded item order, peak metadata lookup, and points mapping.
8. Test malformed `PeakList.peakList` payloads are skipped and produce warning entries.
9. Test missing peak references are skipped and produce warning entries.
10. Test filename sanitisation for whitespace, path separators, invalid characters, empty sanitized names, and duplicate sanitized names.
10a. Test peak lists are processed deterministically by case-insensitive name, then `peakListId`.
10b. Test peak-list export uses one `getAllPeaks()` snapshot to resolve rows rather than repeated per-row repository lookups.
11. Test prepare/commit behavior: prepare reports overwrite conflicts and warnings, generates final CSV payloads, and does not write CSV files or append `export.log`; commit writes only after overwrite is approved and does not re-read repositories.
12. Test warning log entries are appended to `export.log` in the resolved default root with ISO-8601 timestamp, export type, context, and message.
13. Test log append failure does not fail successful CSV output but is reflected in the result warning.
14. Test temporary write failure cleans up temporary files and returns a failure result without reporting success.
14a. Test final replacement failure reports that output may be partially written and does not delete unrelated pre-existing files.
14b. Test final replacement failure does not append `export.log` entries.
14c. Test commit uses the prepared plan without re-reading repositories.
14d. Test an all-malformed peak-list export writes no CSV files, appends `export.log`, and returns success with `0` files and warnings.

Widget coverage:
15. Test Settings renders the `List Exports` section at the bottom with both export actions.
16. Test tapping `Export Peak Lists` shows confirmation, cancellation writes nothing, confirmation opens the fake directory picker, and success dialog reports file/row counts.
17. Test tapping `Export Peaks` follows the same confirmation, picker, overwrite, and result behavior.
18. Test overwrite confirmation appears when the fake filesystem reports existing target files and that declining overwrite writes nothing.
19. Test failure dialog appears when the export service returns or throws a filesystem/picker failure.
20. Test export actions and other Settings maintenance actions are disabled or show loading state while an export is in progress.
20a. Test export actions are disabled while relevant Settings maintenance actions are already running.
20aa. Test the Map Tile Cache Settings tile is disabled while export is running.
20b. Test the List Exports status uses `list-export-status` and does not reuse `peak-refresh-status`.

Robot-driven journey coverage:
21. Add or extend a robot under `./test/robot/settings/` or an existing suitable robot location for Settings export journeys.
22. Cover the critical happy path: open Settings, trigger `Export Peak Lists`, confirm, select fake folder, complete export, and verify success result.
23. Cover the warning path: fake export reports skipped malformed/missing data, success dialog shows warnings, and the visible result includes the `export.log` path or log-write failure message.
24. Use key-first selectors for all robot interactions; do not rely on localized text where a stable key is available.

Test-type mapping:
25. Use unit/service tests for CSV mapping, filename generation, warning generation, overwrite decisions, and filesystem/logging behavior.
26. Use widget tests for screen-level confirmation, cancellation, overwrite, loading, success, and failure states.
27. Use robot tests for the cross-widget Settings journey happy path and visible warning path. Verify exact warning log entries in service tests or focused widget tests, not robot tests.

Manual verification:
28. Run `flutter test`.
29. Manually run the app on macOS if feasible, export peaks and peak lists to a temporary folder, inspect the generated CSV files, and confirm `export.log` appears in `~/Documents/Bushwalking` when warnings occur.
</validation>

<done_when>
1. `./lib/screens/settings_screen.dart` shows a `List Exports` section with `Export Peak Lists` and `Export Peaks` actions.
2. `Export Peak Lists` writes one CSV per decodable peak list to a user-selected folder with the required headers, filename format, row mapping, and warning behavior; malformed peak-list payloads produce no CSV files.
3. `Export Peaks` writes `peaks.csv` to a user-selected folder with the required headers and row mapping.
4. Existing generated CSV files are never overwritten without explicit overwrite confirmation.
5. Malformed peak-list payloads and missing peak references are skipped, reported in the success dialog, and appended to `export.log` in the resolved default root with the log path shown to the user.
6. Cancellation and temporary-write failure paths do not create final CSV output; final-replacement failures may be partially written and must be reported clearly as potentially partial.
7. Prepare performs no filesystem writes or log appends, and commit uses the prepared final CSV payloads without re-reading repositories.
8. Final replacement failure is reported as potentially partial and does not append `export.log` entries.
9. Automated coverage exists for service behavior, Settings UI behavior, and robot-driven critical journeys.
10. `flutter test` passes.
</done_when>
