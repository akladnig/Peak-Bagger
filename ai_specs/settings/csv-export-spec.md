<goal>
Build a Settings-screen action that exports all ObjectBox `Peak` rows to CSV so the user can use the app's peak database outside Peak Bagger.

The export is for the app owner/user, who will open Settings, trigger a one-shot export, and then find the generated CSV at `/Users/adrian/Documents/Bushwalking/Features/peaks.csv`.
</goal>

<background>
This is a macOS-only Flutter app using Riverpod, ObjectBox, `path`, and the `csv` package.

Relevant files to examine before implementation:
- `./lib/screens/settings_screen.dart` for the existing Settings list actions, loading flags, `_status` behavior, dialogs, keys, and snack/status patterns.
- `./lib/models/peak.dart` for the exact `Peak` fields to export.
- `./lib/services/peak_repository.dart` for `PeakRepository.getAllPeaks()` and test storage seams.
- `./lib/providers/peak_provider.dart` for repository provider wiring.
- `./lib/main.dart` for production provider overrides.
- `./lib/services/objectbox_admin_repository.dart` for existing Downloads-style export behavior and directory creation patterns.
- `./test/widget/peak_refresh_settings_test.dart` for Settings widget test style and provider overrides.
- `./test/services/peak_repository_test.dart` and `./test/services/peak_model_test.dart` for service/model test conventions.

The source request is `./ai_specs/settings/csv-export.md`.
</background>

<user_flows>
Primary flow:
1. User opens the app Settings screen.
2. User taps an `Export Peak Data` list tile.
3. The tile is disabled and shows an in-progress state while the export runs.
4. The app reads all `Peak` rows from ObjectBox in repository order, writes CSV to `/Users/adrian/Documents/Bushwalking/Features/peaks.csv`, and creates the directory if needed.
5. The app reports success with the exported row count and full output path using the Settings status area.

Alternative flows:
- Empty database: export a valid CSV containing only the header row, report that `0` peaks were exported, and still show the full output path.
- Existing file: overwrite `/Users/adrian/Documents/Bushwalking/Features/peaks.csv` with the latest export so repeated exports are deterministic.
- Returning user: repeated taps after completion run a fresh export and replace the previous file.

Error flows:
- Directory creation fails: leave existing app state intact, stop the loading state, and show `Export failed: {error}` in the Settings status area.
- File write fails: leave existing peak data untouched, stop the loading state, and show `Export failed: {error}` in the Settings status area.
- Export service throws unexpectedly: catch at the Settings boundary, stop the loading state, and allow retry.
</user_flows>

<requirements>
**Functional:**
1. Add a Settings `ListTile` for peak export with key `export-peak-data-tile`, title `Export Peak Data`, and a clear subtitle such as `Export all peaks to CSV`.
2. The export must produce exactly one CSV file at `/Users/adrian/Documents/Bushwalking/Features/peaks.csv`.
3. The export must create `/Users/adrian/Documents/Bushwalking/Features` recursively when it does not exist.
4. The export must overwrite an existing `peaks.csv` file rather than appending or creating duplicate filenames.
5. The CSV header row must contain these columns in this exact order: `Name`, `Alt Name`, `Elevation`, `Latitude`, `Longitude`, `Area`, `Zone`, `mgrs100kId`, `Easting`, `Northing`, `Verified`, `osmId`.
6. Each `Peak` row must map fields as follows: `Name` from `name`, `Alt Name` from `altName`, `Elevation` from `elevation`, `Latitude` from `latitude`, `Longitude` from `longitude`, `Area` from `area`, `Zone` from `gridZoneDesignator`, `mgrs100kId` from `mgrs100kId`, `Easting` from `easting`, `Northing` from `northing`, `Verified` from `verified`, and `osmId` from `osmId`.
7. Numeric fields must serialize with Dart invariant `toString()` output: `latitude.toString()`, `longitude.toString()`, `osmId.toString()`, and `elevation.toString()` when elevation is non-null. Do not apply locale formatting, thousands separators, or fixed decimal rounding.
8. Preserve the row order returned by `PeakRepository.getAllPeaks()`; do not sort exported rows.
9. Use the existing `csv` package to serialize rows so commas, quotes, and newlines in names/areas are escaped correctly.
10. Use LF line endings for generated CSV output.
11. Return an export result that includes the output path and exported peak count so the UI can report the result without parsing the file.

**Error Handling:**
12. A failed export must not mutate `Peak` data or other ObjectBox entities.
13. Settings must catch export failures and show user-visible text beginning with `Export failed:` followed by the error detail.
14. The export tile must be re-enabled after success or failure.
15. This app is macOS-only for this feature. If `/Users/adrian/Documents/Bushwalking/Features` cannot be created or written, show the export failure and do not fall back to another directory.
16. Disable `Export Peak Data` while `_isRefreshingPeaks` is true, and disable Refresh Peak Data while `_isExportingPeaks` is true by setting each tile's `onTap` to null.

**Edge Cases:**
17. Null `elevation` and null `area` values must be written as blank CSV cells.
18. Empty strings in text fields must be written as blank CSV cells.
19. `verified` must be exported as Dart boolean text, `true` or `false`.
20. Empty peak database must still create a header-only CSV.

**Validation:**
21. The export behavior must be testable without touching the real `/Users/adrian/Documents/Bushwalking/Features` directory.
22. The Settings widget tests must be able to inject a fake export runner or file sink and deterministic peak data.
23. The UI must include stable keys for the export tile and export status text.
24. Settings must reuse `_status` for export feedback, render export status with key `peak-export-status`, show `Exporting peak data...` while pending, show `Exported {count} peaks to {path}` on success, and show `Export failed: {error}` on failure.
25. Settings must preserve existing status-key behavior for non-export actions. Use a small `_statusKey` state field or equivalent so export status renders with `peak-export-status` while existing refresh/reset status assertions remain stable.
</requirements>

<boundaries>
Edge cases:
- No peaks: create a header-only CSV and report success with `0` rows.
- Peak names with commas, quotes, or line breaks: rely on `csv` serialization and verify escaped output in tests.
- Null model values: use blank cells, not `null`, `0`, or placeholder strings.
- Existing output file: overwrite it atomically enough for a local app export; no merge or append behavior.

Error scenarios:
- Output directory unavailable or permission denied: show `Export failed: ...`, keep the app usable, allow retry, and do not choose an alternate directory.
- File write interrupted: surface the error and do not show a success message.
- User navigates away during export: avoid calling `setState` or showing UI feedback after the widget is unmounted.

Limits:
- Export all peaks in memory using `PeakRepository.getAllPeaks()`. Do not introduce pagination unless profiling shows the current peak volume cannot fit comfortably in memory.
- Repository/ObjectBox row order is intentionally accepted for this export; do not add sorting to stabilize order unless a future requirement asks for it.
- Treat the fixed export directory as a macOS-only local requirement for this app.
- Do not add CSV import behavior in this task.
- Do not change the `Peak` ObjectBox schema for this task.
</boundaries>

<implementation>
Create or modify these files:
- `./lib/services/peak_csv_export_service.dart`: new service responsible for converting `Peak` objects to CSV rows and writing the file.
- `./lib/providers/peak_csv_export_provider.dart`: provider wiring for the export service.
- `./lib/screens/settings_screen.dart`: add the export tile, loading flag, status/result handling, and provider call.
- `./lib/main.dart`: do not modify unless implementation proves the derived provider cannot be built from existing providers.
- `./test/services/peak_csv_export_service_test.dart`: service tests for CSV output, repository row order, blanks, escaping, and empty export.
- `./test/widget/peak_csv_export_settings_test.dart` or extend `./test/widget/peak_refresh_settings_test.dart`: widget tests for Settings trigger, loading state, success, and failure.

Recommended service shape:
- Define `PeakCsvExportResult` with `String path` and `int exportedCount`.
- Define a service class that accepts `PeakRepository`, an export directory resolver or fixed `Directory`, and a file-writing seam.
- Define `peakCsvExportServiceProvider` as a derived provider that constructs `PeakCsvExportService(peakRepository: ref.watch(peakRepositoryProvider))`, with any file/directory seam overridable in tests.
- Define `typedef PeakCsvExportRunner = Future<PeakCsvExportResult> Function();` and a derived `peakCsvExportRunnerProvider` that returns `ref.watch(peakCsvExportServiceProvider).exportPeaks`. Settings should read the runner provider, not instantiate or call the concrete service directly. Widget tests should override the runner provider with a completer-controlled fake function.
- Keep `/Users/adrian/Documents/Bushwalking/Features` as the production default directory, but inject a temp directory or fake writer in tests.
- Keep filename `peaks.csv` as a constant in the service.
- Keep CSV row construction in a public or package-visible method only if needed for focused service tests; otherwise test through the public export method.

UI guidance:
- Place the new tile near existing data-management Settings actions such as Refresh Peak Data and Reset Map Data.
- Use an icon that communicates export/download, such as `Icons.file_download` or `Icons.ios_share` if consistent with project style.
- Track a dedicated `_isExportingPeaks` flag so exporting does not interfere with refresh/reset loading states.
- Disable `Export Peak Data` while `_isRefreshingPeaks` is true, and disable Refresh Peak Data while `_isExportingPeaks` is true by setting each tile's `onTap` to null.
- Reuse existing Settings `_status` style for export feedback. Render export status with key `peak-export-status`, show `Exporting peak data...` while pending, show `Exported {count} peaks to {path}` on success, and show `Export failed: {error}` on failure.
- Preserve existing status-key behavior for non-export actions by adding a small `_statusKey` state field or equivalent. Export sets `_statusKey = const Key('peak-export-status')`; existing refresh/reset status flows keep their current key expectations.

Avoid:
- Manual comma-joining CSV strings, because names and areas may contain commas, quotes, or newlines.
- Writing to the real export directory during automated tests.
- Adding a save dialog; this spec requires the fixed directory `/Users/adrian/Documents/Bushwalking/Features`.
- Adding new dependencies unless implementation proves the existing `csv`, `path`, and Dart `io` APIs are insufficient.
</implementation>

<validation>
Use vertical-slice TDD. Add one failing test, make the minimal implementation pass, then refactor while green before moving to the next behavior. Do not write a batch of speculative tests before implementation.

Behavior-first test slices:
1. Service happy path exports one or more peaks with the exact header order, field mapping, numeric `toString()` formatting, and LF line endings.
2. Service preserves the row order returned by `PeakRepository.getAllPeaks()`.
3. Service writes blank cells for null `elevation`/`area` and empty text fields.
4. Service uses CSV escaping for names/areas containing commas, quotes, or newlines.
5. Service creates a header-only file and returns `exportedCount == 0` when no peaks exist.
6. Settings widget starts export when `export-peak-data-tile` is tapped, disables the tile while the future is pending, and shows `Exporting peak data...` with key `peak-export-status`.
7. Settings widget disables `Export Peak Data` while peak refresh is running and disables Refresh Peak Data while export is running by setting each tile's `onTap` to null.
8. Settings widget shows `Exported {count} peaks to {path}` on success.
9. Settings widget catches export failure, re-enables the tile, and shows `Export failed: {error}`.

Required testability seams:
- Inject `PeakRepository` or an equivalent read port so service tests can use `InMemoryPeakStorage` without ObjectBox.
- Inject export directory/file writing so tests use a temp directory or fake writer instead of `/Users/adrian/Documents/Bushwalking/Features`.
- Inject the Settings export runner provider so widget tests can use a completer-controlled fake for loading and failure states.

Mocking policy:
- Prefer fakes and in-memory repositories over mocks.
- Mock only true external boundaries if needed, such as platform file system behavior that cannot be represented by a temp directory.

Automated coverage outcomes:
- Unit/service tests must verify CSV structure, repository row order, numeric formatting, LF line endings, null/empty handling, escaping, overwrite behavior, and empty export.
- Widget tests must verify the Settings user interaction, pending state, success feedback, and failure recovery.
- No new full robot journey is required unless implementation adds cross-screen navigation beyond opening Settings; this is a single-screen Settings action and should be covered by widget tests with stable keys. If a robot is added, place it under the existing `./test/robot/` conventions and use key-first selectors.

Run these checks before completion:
- `flutter test test/services/peak_csv_export_service_test.dart`
- `flutter test test/widget/peak_csv_export_settings_test.dart` or the actual widget test file chosen by the implementation
- `flutter test`
- `flutter analyze`
</validation>

<done_when>
The task is complete when:
1. Settings contains an `Export Peak Data` action with stable test keys.
2. Tapping the action writes `/Users/adrian/Documents/Bushwalking/Features/peaks.csv` with the exact requested headers and all `Peak` rows.
3. Rows preserve the order returned by `PeakRepository.getAllPeaks()`.
4. Numeric values use Dart `toString()` output and generated CSV uses LF line endings.
5. Null and empty model values appear as blank CSV cells.
6. CSV escaping is handled by the `csv` package.
7. Success feedback includes the exported count and full file path in `peak-export-status`.
8. Failure feedback is user-visible in `peak-export-status`, non-crashing, and leaves the tile retryable.
9. Service and widget tests cover the required behaviors without writing to the real export directory.
10. `flutter test` and `flutter analyze` pass, or any failure is documented with the exact reason and residual risk.
</done_when>
