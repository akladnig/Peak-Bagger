<goal>
Add a macOS-only local data backup and restore flow so maintainers can recover the app's ObjectBox data and FMTC offline map tiles from a single archive.

This matters because the project stores local state in multiple places: the main ObjectBox database and the `flutter_map_tile_caching` cache. A restore needs both of them to come back together.
</goal>

<background>
Flutter app with ObjectBox, `path_provider`, and `flutter_map_tile_caching`.

Relevant data locations in this project:

| Component | Current source |
| --- | --- |
| Main ObjectBox store | `getApplicationDocumentsDirectory()/objectbox` via `openStore()` |
| FMTC tile cache | FMTC stores managed through `flutter_map_tile_caching`; back up through FMTC external archive export/import |

Relevant files to examine:
- `./lib/main.dart`
- `./lib/objectbox.g.dart`
- `./lib/services/tile_cache_service.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/services/objectbox_schema_guard.dart`
- `./test/...`
</background>

<discovery>
- Confirm the exact macOS path resolution for `getApplicationDocumentsDirectory()` in this app and whether any sandboxed application-group path is in use.
- Verify the exact ObjectBox directory path used by `openStore()` for the closed-store recursive copy implementation.
- Verify the FMTC export/import API names and signatures for the installed `flutter_map_tile_caching` version.
- Verify the exact quit-app mechanism available on macOS for the terminal post-backup/post-restore UI.
</discovery>

<user_flows>
Primary flow:
1. User opens a macOS maintenance entry point in the app.
2. User chooses Backup.
3. App pauses maintenance writes, exports FMTC while its backend remains initialized, safely backs up the ObjectBox store, writes a single ZIP archive file containing the ObjectBox payload and FMTC `.fmtc` export payload, then resumes normal app operation.
4. User later chooses Restore and selects that archive.
5. App validates the archive, imports FMTC with replace semantics, replaces local file data through staging, reports success, and shows a terminal Quit App prompt before restored data is used.

Alternative flows:
- Empty data set: backup still succeeds and produces a valid empty archive.
- Partial local data: backup includes whatever local components exist without failing the whole operation.
- Cancelled restore: no files are changed.
- Corrupt archive: restore fails cleanly and leaves the current data untouched.

Error flows:
- ObjectBox store cannot be closed or copied safely: show a clear error and do not create a partial archive.
- FMTC export fails or no exportable stores exist: mark the FMTC component as `empty` when appropriate, otherwise show a clear error and do not create a partial archive.
- Restore encounters a missing or incompatible payload: abort before replacing existing data.
- Restore copy fails mid-way: roll back to the previous state or refuse to swap until staging completes successfully.
</user_flows>

<requirements>
**Functional:**
1. Add a backup and restore entry point in the app's maintenance surface, most likely in Settings.
2. Backup must include the main ObjectBox store and an FMTC `.fmtc` archive exported through `flutter_map_tile_caching`.
3. The backup format must be a single ZIP archive file so users can move it and restore it later without needing the original directory layout. Add the `archive` package if it is not already available.
4. The archive must preserve directory names relative to the app documents root so restore can recreate the same layout verbatim.
5. Add a small manifest to the archive with at least: creation time, app version, build number, backup format version, ObjectBox schema signature, each component's status, and FMTC store names exported when present.
6. Restore must validate the manifest before modifying any live data.
7. Restore must replace the current local data atomically through a staging directory or equivalent safe swap strategy.
8. Backup must leave the app usable afterward. If backup closes the main ObjectBox store to create a whole-directory copy, it must reopen the store and restore repository/provider access before returning control to the user.
9. The feature must remain local-only; no cloud sync or remote transport is in scope.
10. Backup must capture the main ObjectBox store safely. Prefer an ObjectBox-supported backup/snapshot mechanism that allows the app to continue normally. If implementing closed-store recursive copy, copy the entire ObjectBox directory, including all lock, data, metadata, and auxiliary files, then reopen the store and refresh app data access before reporting success. Do not copy individual ObjectBox files in isolation.
11. Backup must capture FMTC data using FMTC's external archive API, not by manually copying FMTC ObjectBox files. Export all non-empty FMTC stores to a temporary `.fmtc` archive and include that archive as the FMTC payload in the ZIP.
12. Backup and restore actions must be disabled while any other maintenance action is running in Settings, including peak refresh, map reset, track reset, track statistics recalculation, tile downloads, and tile cache clear/delete operations.
13. The manifest must represent each payload component with one of these statuses: `included`, `empty`, or `missing_at_backup_time`.
14. Restore must import the FMTC `.fmtc` payload using `ImportConflictStrategy.replace` so restore semantics replace matching stores instead of merging with stale local cache data.
15. FMTC backup/restore must pause tile downloads and cache writes while keeping the FMTC backend initialized for export/import. Do not close the FMTC backend before calling FMTC export/import APIs.
16. FMTC manifest entries must be evaluated against `TileCacheService.storeNames`: `included` when the expected store is exported, `empty` when the expected store exists but has no exportable tiles, and `missing_at_backup_time` when the expected store cannot be resolved or read during backup.
17. App version/build metadata in the manifest must come from `package_info_plus` through a small app-info seam that can be faked in tests.

**Error Handling:**
18. If the archive is missing a payload that the manifest marks as `included`, show a clear restore error and do not touch the current data.
19. If the archive was created from a different ObjectBox schema signature, refuse restore with no override path in this version.
20. If the archive has an unsupported backup format version, refuse restore before staging.
21. If the restore fails after staging has begun, clean up staging data and keep the original data intact.
22. If there is not enough temporary disk space to create the ZIP, stage ObjectBox data, or export/import FMTC data, fail safely and keep current data intact.

**Edge Cases:**
23. A backup of an empty ObjectBox store and empty FMTC cache is still valid.
24. FMTC stores that cannot be exported because they are empty should be recorded as `empty` in the manifest rather than failing the whole backup.
25. Large tile caches should stream to the archive or be processed incrementally rather than being loaded entirely into memory.
26. The feature should not back up unrelated user documents or generic app preferences unless a later task explicitly adds that scope.

**Validation:**
27. Add deterministic tests that use temp directories and fake archives so backup and restore do not touch the user's real documents directory.
28. Add stable keys for the Settings backup and restore controls, status text, confirmation/cancel actions, failure actions, and terminal success actions.
</requirements>

<boundaries>
Platform boundaries:
- This app is macOS-only for this task; do not add cross-platform backup/restore branching.
- Do not use a network dependency.

Data boundaries:
- Include the main ObjectBox store and FMTC export archive.
- Do not silently migrate schema during restore.
- Do not treat `SharedPreferences` as part of the backup unless a later task explicitly opts in.
- Treat `included`, `empty`, and `missing_at_backup_time` manifest component statuses as restore contract, not incidental metadata.

Operational boundaries:
- Backup should not mutate the live dataset. After backup succeeds, the app should continue normal operation.
- Restore should not partially replace live data.
- Prefer a single archive and a single restore transaction over multiple ad hoc files.
- A successful restore enters a terminal UI state that does not read repositories, disables navigation/actions, and offers only a `Quit App` action. The app must be restarted before restored local stores are used.
</boundaries>

<implementation>
1. Add a new `./lib/services/objectbox_backup_service.dart` (or equivalent) that resolves the macOS application-documents root, enumerates the backup payload, creates the ZIP archive, validates the manifest, and restores into a staging directory.
2. Add or expose an ObjectBox store lifecycle seam that can safely back up the live store and keep or restore normal repository/provider access after backup. If restore closes/replaces the store, prevent further repository use until the user restarts the app.
3. Update `./lib/services/tile_cache_service.dart` only as needed to expose FMTC export/import seams and pause tile cache writes while the FMTC backend remains initialized.
4. Add a Settings entry for backup and restore actions, with file picker integration for save/open locations through a testable `ObjectBoxBackupFilePicker` or equivalent provider seam.
5. Add a shared Riverpod maintenance operation coordinator/provider used by Settings and Tile Cache Settings so backup/restore can disable conflicting maintenance actions across screens.
6. Add `package_info_plus` and expose app version/build through a small app-info seam that can be faked in tests.
7. Reuse `objectbox_schema_guard.dart` concepts for manifest validation, but keep the backup manifest separate from the existing preferences-based guard.
8. Add tests under `./test/services/` for archive contents, manifest validation, and restore failure rollback.
9. Add widget tests for the Settings entry.
10. Keep the backup code path isolated from normal app startup so a failed backup cannot block launching the app.
11. Make the post-restore state explicit: after a successful restore closes/replaces local stores, show a minimal terminal screen/dialog that does not read repositories, disables navigation/actions, and offers only `Quit App`.
12. Use stable Settings keys including `settings-backup-data`, `settings-restore-data`, `settings-backup-status`, `settings-restore-status`, `settings-backup-confirm`, `settings-backup-cancel`, `settings-restore-confirm`, `settings-restore-cancel`, `settings-backup-failure-close`, `settings-restore-failure-close`, and `settings-restore-quit-app`.
</implementation>

<stages>
Phase 1: Define the ZIP archive layout, manifest contents, ObjectBox backup strategy that allows normal post-backup app use, FMTC export/import strategy, app-info seam, maintenance coordinator, and macOS path resolution.
Phase 2: Implement backup creation and unit tests for the ObjectBox payload, FMTC `.fmtc` export, and archive payload.
Phase 3: Implement restore order: validate ZIP/manifest/schema/payloads, stage ObjectBox replacement, pause FMTC writes and import `.fmtc` with replace strategy while FMTC remains initialized, close/quiesce main ObjectBox, swap staged ObjectBox data, then enter terminal Quit App UI.
Phase 4: Wire the Settings entry and cover the UI surface with widget tests.
</stages>

<validation>
1. Add tests that verify the archive contains the expected directories and manifest fields.
2. Add tests that verify restore rejects corrupt or incomplete archives without touching existing data.
3. Add tests that verify a staged restore can be rolled back when a copy step fails.
4. Use stable selectors for backup and restore actions so tests do not rely on text alone.
5. Prefer temp directories and fakes over the real macOS documents location.
6. Add a test that backup/restore are disabled while other maintenance actions are running, including tile downloads or tile cache clear/delete operations.
7. Add tests that restore rejects schema-signature mismatch and unsupported manifest format versions.
8. Add tests that ObjectBox backup captures the whole store payload safely and that restore replaces the whole ObjectBox store from staging.
9. Add tests that FMTC backup/export and restore/import are invoked through the TileCacheService seam, including empty-store manifest behavior.
10. Add robot-style happy-path journey tests using fake backup service and fake file picker: backup returns to normal Settings usage after success, while restore ends in the Quit App terminal UI.
11. Add tests for the maintenance operation coordinator so Settings and Tile Cache Settings disable conflicting controls across screens.
12. Add tests for app-info manifest metadata using a fake app-info provider.
</validation>

<done_when>
1. A macOS-only backup archive can be created from the app's local data.
2. The archive captures the main ObjectBox store payload and FMTC `.fmtc` export payload.
3. A restore can replace local ObjectBox data, import FMTC data with replace semantics, and require restart before restored stores are used.
4. Corrupt or incompatible backups fail safely without overwriting current data.
5. Automated tests cover backup contents, restore validation, and rollback behavior.
</done_when>
