<goal>
Add a settings-driven export that writes every stored `PeakList` to its own CSV file under `Peak_Lists` inside the resolved Bushwalking root.

This gives the user a repeatable way to extract the app's maintained peak lists into shareable flat files without manually inspecting ObjectBox data. The export must preserve each list's stored ordering, carry over `PeakListItem.points`, and enrich each row with peak metadata resolved from `Peak.osmId`.
</goal>

<background>
The app is a Flutter + Riverpod + ObjectBox application.

This feature is macOS-only. Ignore Windows path and filename semantics for this spec.

Relevant existing patterns and files:
- Settings action and inline status pattern: `@lib/screens/settings_screen.dart`
- Existing single-file peak export service/provider: `@lib/services/peak_csv_export_service.dart`, `@lib/providers/peak_csv_export_provider.dart`
- Peak list entity encoding/decoding: `@lib/models/peak_list.dart`
- Peak list repository access: `@lib/services/peak_list_repository.dart`
- Peak lookup by `osmId`: `@lib/services/peak_repository.dart`
- Existing export tests to mirror structurally: `@test/services/peak_csv_export_service_test.dart`, `@test/widget/peak_csv_export_settings_test.dart`
- Existing settings robot style to mirror: `@test/robot/peaks/peak_refresh_robot.dart`, `@test/robot/peaks/peak_refresh_journey_test.dart`
- Shared Bushwalking root helper to reuse directly: `@lib/services/import_path_helpers.dart`

Implementation should follow the existing export/test style where that stays small and clear, but this feature should get its own service/provider/result types instead of overloading the peak export types. Reuse `resolveBushwalkingRoot()` for path resolution, then append `Peak_Lists` in the new export service.
</background>

<user_flows>
Primary flow:
1. The user opens `Settings`.
2. The user taps a new `Export Peak Lists` action.
3. The screen shows an in-progress status and activates a shared busy gate for the four settings actions that write to the shared inline status area: Refresh Peak Data, Reset Map Data, Export Peak Data, and Export Peak Lists. While any one of those four actions is running, the other three are disabled so they cannot start or overwrite the inline status.
4. The app resolves the existing target directory, exports one CSV file per decodable `PeakList` that resolves at least one peak row, and resolves each row's peak metadata from `PeakRepository`.
5. The screen shows a success status summarizing exported file count and skipped list count.

Alternative flows:
- If one or more `PeakListItem` rows reference a missing `Peak`, those rows are skipped, the rest of the export continues, and the success status includes a warning summary.
- If one or more stored `PeakList.peakList` payloads are malformed and cannot be decoded, those lists are skipped, the rest of the export continues, and the success status includes a warning summary.
- If a decoded `PeakList` contains zero items, the app still writes a header-only CSV for that list and counts it as an exported file.
- If a decoded `PeakList` contains items but none of them resolve to a `Peak`, the app skips writing that file, records warnings for the missing rows, and counts the list as skipped.
- If there are no stored `PeakList` entities, the export succeeds with zero files written and no warnings.
- If all stored lists are skipped for non-fatal reasons, the export still succeeds with zero files written, includes the relevant warning summary, and notes that older files from prior exports may remain on disk for skipped lists.

Error flows:
- If the resolved export directory does not exist, the overall export fails and the settings status shows `Export failed: ...` including the resolved `Peak_Lists` path and a recovery instruction to create the folder and retry.
- If a CSV file cannot be written, the overall export fails and the settings status shows `Export failed: ...` including the target file path and underlying filesystem error.
- Partial files already written before a fatal filesystem error may remain on disk; do not add rollback logic for this feature.
</user_flows>

<requirements>
**Functional:**
1. Add a dedicated `PeakList` CSV export service and provider, for example `@lib/services/peak_list_csv_export_service.dart` and `@lib/providers/peak_list_csv_export_provider.dart`.
2. The service must depend on both `PeakListRepository` and `PeakRepository` so it can enumerate stored lists and resolve peak metadata by `PeakListItem.peakOsmId`.
3. The export destination must be resolved by calling `resolveBushwalkingRoot()` and appending `Peak_Lists`.
4. The export service must not create directories. If the resolved `Peak_Lists` directory does not already exist, fail the export.
5. Reuse `resolveBushwalkingRoot()` from `@lib/services/import_path_helpers.dart` directly so Bushwalking root resolution stays shared. Do not reuse `PeakListFilePicker.resolveImportRoot()` as the export contract.
6. Export one CSV file per decodable `PeakList` entity that has a non-blank normalized filename stem and at least one successfully resolved peak row, except that a decoded list with zero items must still export as a header-only CSV.
7. Derive each CSV filename from `PeakList.name` using this exact algorithm:
   - trim leading and trailing whitespace
   - collapse internal whitespace runs to a single `-`
   - convert the stem to lowercase
   - replace `/`, `\\`, and `:` with `-`
   - remove leading `.` characters
   - remove trailing `.` characters
   - if the resulting stem is blank, skip the list and record a warning identifying the list by `peakListId` and original name
   - append collision suffixes such as `-2`, `-3`, etc. to the stem before appending `-peak-list.csv`
   - append the final suffix `-peak-list.csv`
8. Enumerate `PeakList` entities in deterministic order using a case-insensitive comparator: ascending `name.toLowerCase()`, then ascending `peakListId`. Use that same comparator and traversal order for export traversal, collision suffix assignment, warning aggregation, and filename-slot reservation.
9. Each exported CSV must use exactly these headers in this order:
   - `Name`
   - `Alt Name`
   - `Elevation`
   - `Zone`
   - `mgrs100kId`
   - `Easting`
   - `Northing`
   - `Points`
   - `osmId`
10. For each decoded `PeakListItem`, resolve the matching `Peak` via `PeakRepository.findByOsmId(item.peakOsmId)` or an equally direct repository lookup.
11. Each successful exported row must contain:
   - `Name`: `Peak.name`
   - `Alt Name`: `Peak.altName`
   - `Elevation`: `Peak.elevation`, blank when null
   - `Zone`: `Peak.gridZoneDesignator`
   - `mgrs100kId`: `Peak.mgrs100kId`
   - `Easting`: `Peak.easting`
   - `Northing`: `Peak.northing`
   - `Points`: `PeakListItem.points`
   - `osmId`: the resolved `Peak.osmId`
12. Preserve the stored order of `PeakListItem` entries inside each exported CSV. Do not sort rows during export.
13. Duplicate `peakOsmId` entries inside a list, if present, must be exported as separate rows in stored order. Do not deduplicate.
14. Re-running the export should overwrite previously written files when the same final resolved filename is produced.
15. Add a new settings action for this feature instead of changing the existing `Export Peak Data` behavior.
16. Use stable keys for the new settings affordance and status output. Use app-owned `Key` selectors such as `export-peak-lists-tile` and `peak-list-export-status` so widget and robot tests can target the flow deterministically.
17. Use a single shared busy gate for exactly these four settings actions that write to the shared inline status area so status state cannot be overwritten mid-run. While any one of these four actions is running, the other three must be disabled:
   - Refresh Peak Data
   - Reset Map Data
   - Export Peak Data
   - Export Peak Lists
18. The service result type must expose enough structured data for UI messaging and tests without parsing strings. Model this after the structured warning/result style used by `PeakListImportResult`, not as a single status string. Include at minimum:
    - target output directory path
    - exported file count
    - skipped row count
    - skipped list count, defined exactly as `skippedMalformedListCount + skippedBlankNameListCount + skippedZeroResolvedRowListCount`
    - skipped malformed list count
    - skipped blank-name list count
    - skipped zero-resolved-row list count
    - warning entries in deterministic order, with each entry identifying the affected list and missing `osmId` when applicable
    - optional warning summary or helper getters are fine, but UI and tests must not parse display strings to recover counts

19. If there are no stored `PeakList` entities, the export must succeed with zero exported files and zero warnings.
20. If one or more lists are skipped for non-fatal reasons during a successful run, the export must not delete or clean up any pre-existing export files for those skipped lists from earlier runs.
21. If all stored lists are skipped for non-fatal reasons, the export must still succeed with zero exported files, surface the relevant warnings, and note that older files from prior exports may remain on disk for skipped lists.
22. Filename collision reservation must be computed across all stored `PeakList` entities that produce a non-blank normalized stem, even if a given list is later skipped because of malformed payload or zero resolved rows. A skipped colliding list still reserves its filename slot so a current-run export cannot overwrite an older file that is intentionally being preserved.

**Error Handling:**
23. If a `PeakListItem` references an `osmId` that has no matching `Peak`, skip that row, keep exporting the rest of the current list and remaining lists, and record a warning that identifies the list and missing `osmId`.
24. If a stored `PeakList.peakList` payload cannot be decoded with `decodePeakListItems`, skip the entire file for that list, keep exporting remaining lists, and record a warning that identifies the list.
25. If a list name normalizes to a blank filename stem, skip that list and record a warning.
26. If a decoded non-empty list resolves zero peak rows after missing-row filtering, skip writing the file and record a warning.
27. If the resolved `Peak_Lists` directory is missing, surface that as a fatal export failure to the caller with the resolved directory path and a recovery instruction to create the folder and retry.
28. If file writing throws, surface that as a fatal export failure to the caller with the target file path and underlying filesystem error instead of downgrading it to a warning.
29. If two different `PeakList.name` values normalize to the same filename stem, resolve the collision deterministically within the export run by appending a stable suffix such as `-2`, `-3`, etc. before `-peak-list.csv`, based on the deterministic list traversal order and filename-slot reservation rules, and cover it with tests.

**Edge Cases:**
30. An empty decoded list must still export a header-only CSV and count as one exported file.
31. Lists skipped because of malformed payloads, blank normalized names, or zero resolved rows must not create new placeholder or partial files, and they must not delete any pre-existing export file from an earlier run for the same normalized filename.
32. When a skipped list collides with an exported list after normalization, the skipped list still reserves its deterministic filename slot and the exported list must use the next deterministic collision suffix.
33. Missing-peak rows must not contribute to any exported row count.
34. Warning generation must be deterministic so tests can assert on counts and representative messages without depending on nondeterministic ordering.

**Validation:**
35. Use `ListToCsvConverter(eol: '\n')` or the same newline behavior as the existing peak CSV export so generated files stay consistent with current CSV output.
36. Keep the implementation small: do not merge this feature into the existing `PeakCsvExportService` unless a tiny shared helper is clearly justified and keeps both exports easier to follow.
</requirements>

<boundaries>
Edge cases:
- Normalized filename collisions: resolve with deterministic suffixing before `-peak-list.csv`, including when a skipped list reserves an earlier slot, and verify the resulting files are distinct.
- Names with repeated or surrounding whitespace: trim/collapse for filenames only; do not mutate stored `PeakList.name` values.
- Names that would otherwise normalize to a hidden dotfile: strip leading `.` characters during normalization.
- Blank normalized filename stems: skip the list and warn.
- Empty decoded lists: export headers only.
- Non-empty decoded lists with zero resolved peaks: skip the file and warn.
- Duplicate list items: export duplicates exactly as stored.

Error scenarios:
- Missing `Peak` for a row: warning, skip row, continue.
- Malformed `PeakList.peakList` JSON: warning, skip file, continue.
- Blank normalized filename stem: warning, skip file, continue.
- Zero resolved rows in a non-empty decoded list: warning, skip file, continue.
- Missing resolved `Peak_Lists` directory: fail the export call with the resolved directory path and a recovery instruction to create the folder and retry.
- File write failure after some files are written: fail the export call with the target file path and underlying filesystem error; do not attempt cleanup.

Limits:
- Do not add a folder picker, share sheet, or platform-specific save dialog in this feature.
- Do not broaden this feature beyond macOS semantics.
- Do not change import behavior, peak list persistence format, or existing single-file peak export semantics.
</boundaries>

<implementation>
Create or modify these outputs:
- `./lib/services/peak_list_csv_export_service.dart`
- `./lib/providers/peak_list_csv_export_provider.dart`
- `./lib/screens/settings_screen.dart`
- `./test/services/peak_list_csv_export_service_test.dart`
- `./test/widget/peak_list_csv_export_settings_test.dart`
- `./test/robot/peaks/peak_list_export_robot.dart`
- `./test/robot/peaks/peak_list_export_journey_test.dart`

Implementation notes:
- Mirror the existing peak export service shape where useful: injectable output directory/file-writer seams, small result object, and CSV assembly in one place.
- Use repository-level public APIs and decoding helpers; do not reach into ObjectBox boxes directly from the new service.
- Reuse `resolveBushwalkingRoot()` from `import_path_helpers.dart`, append `Peak_Lists`, and keep the directory existence check in the new export service.
- Keep warning aggregation in the service result so the UI only formats status text, following a structured warning pattern similar to `PeakListImportResult`.
- Reuse the settings screen's inline status area rather than introducing a new dialog flow.
- Add only the new boolean/status plumbing needed in `SettingsScreen`; implement one shared busy gate for Refresh Peak Data, Reset Map Data, Export Peak Data, and Export Peak Lists so all four disable each other whenever any one is active.
- Update existing settings tests affected by the shared busy gate in addition to adding the new export-list coverage.
- Because current create/import flows reject or dedupe duplicate `peakOsmId` entries, duplicate-row export coverage should seed raw `PeakList.peakList` payloads directly in service tests rather than relying on the UI or import flow to create those lists.
</implementation>

<stages>
Phase 1: Export service
- Build the dedicated peak-list CSV export service and result model.
- Add injectable filesystem seams for unit tests.
- Verify completion with focused service tests for happy path, zero stored lists, empty decoded list, blank-name skip, missing peak warnings, malformed list warnings, all-lists-skipped success, zero-resolved-row skipping, deterministic ordering, filename-slot reservation for skipped colliders, and filename collision handling.

Phase 2: Settings integration
- Add Riverpod provider wiring and a new settings tile/status flow.
- Disable the shared busy-gate actions during execution and surface success/failure/warning summaries, including the older-files-may-remain note when lists are skipped.
- Verify completion with widget tests covering loading, four-way busy-gate disabling, success, warning summary, zero-output success states, and fatal failure states.

Phase 3: Journey coverage
- Add a minimal settings export robot following the `peak_refresh_robot` pattern.
- Cover the critical happy-path export journey and one warning-bearing journey.
- Verify completion with deterministic robot tests using fake runners/results rather than real filesystem IO.
</stages>

<validation>
Require baseline automated coverage across service logic, screen behavior, and the critical settings journey.

TDD expectations:
- Implement in vertical slices, one failing test at a time.
- Start with service-level behavior slices before UI wiring.
- For each slice, follow RED -> GREEN -> REFACTOR before adding the next test.
- Exercise public interfaces only: service methods, provider-injected runners, and screen interactions. Do not test private helpers directly.

Behavior-first test slices:
1. Service happy path: exports multiple lists to distinct files with the exact required headers and row values.
2. Service zero-stored-lists behavior: succeeds with zero files written and zero warnings.
3. Service empty-list behavior: writes a header-only CSV for an empty decoded list.
4. Service data-quality tolerance: skips missing-peak rows and reports warning counts/details.
5. Service malformed-list tolerance: skips undecodable lists and reports warning counts/details.
6. Service filename stability: lowercase normalization, explicit sanitization rules including leading-dot stripping, blank-name skipping, deterministic case-insensitive traversal order, filename-slot reservation for skipped colliders, and collision suffixing before `-peak-list.csv` behave deterministically.
7. Service zero-resolved-row behavior: a non-empty decoded list with no resolved peaks is skipped and does not produce a file.
8. Service all-lists-skipped behavior: succeeds with zero files written, surfaces warnings, and includes the older-files-may-remain note.
9. Settings widget loading/success: tapping the new tile shows in-progress status, disables the four shared busy-gate actions, and then shows a success summary that includes exported file count and skipped list count.
10. Settings widget failure: fatal export exceptions show `Export failed: ...` with path/recovery details and re-enable the shared-gate actions.
11. Robot critical journey: user opens settings, runs peak-list export, and sees the final success summary.
12. Robot warning journey: user runs export that succeeds with skipped rows/lists and sees the warning-bearing success summary.

Required testability seams:
- Injectable output directory and file writer for the export service.
- Provider-overridable runner/service for widget and robot tests.
- Stable keys for the new tile and status text.
- Deterministic fake export results in robot/widget tests so the journey lane does not depend on live filesystem state.

Default test split:
- Unit tests: CSV generation, deterministic case-insensitive list ordering, filename derivation, leading-dot stripping, warning aggregation, zero-stored-lists success, all-lists-skipped success, counts, blank-name skipping, zero-resolved-row skipping, skipped-collider slot reservation, and collision handling.
- Widget tests: settings tile loading, four-way shared disabling, zero-output success, failure, and status behavior.
- Robot tests: end-to-end settings happy path and warning-bearing export path.

Suggested verification commands:
- `flutter test test/services/peak_list_csv_export_service_test.dart`
- `flutter test test/widget/peak_list_csv_export_settings_test.dart`
- `flutter test test/robot/peaks/peak_list_export_journey_test.dart`
</validation>

<done_when>
1. Settings includes a dedicated `Export Peak Lists` action with stable keys and inline status reporting.
2. Running the action writes one CSV per eligible `PeakList` into the resolved `Peak_Lists` directory returned by `resolveBushwalkingRoot()` plus `Peak_Lists`.
3. Every exported CSV uses the exact required columns and preserves stored row order.
4. Missing peak references skip only the affected rows and surface warnings.
5. Malformed peak lists, blank normalized names, and non-empty zero-resolved-row lists skip only the affected files and surface warnings.
6. Filename normalization is lowercase, deterministic, and prevents silent overwrites from normalized-name collisions.
7. Final success messaging includes exported file count and skipped list count, and notes that older files may remain when lists are skipped.
8. Fatal filesystem failures surface as failed exports.
9. Exports with zero stored lists or all skipped lists follow the specified non-fatal zero-output behavior.
10. Service, widget, and robot tests covering the required slices exist and pass.
</done_when>
