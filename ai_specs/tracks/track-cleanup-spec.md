<goal>
Remove stale GPX placement metadata from import/persistence.
Keep import behavior driven by the real on-disk file path and current filename only; no shadow path state.
</goal>

<background>
Flutter app. Riverpod state. ObjectBox persistence.
This cleanup targets import bookkeeping, schema shape, and tests that still assume persisted managed-path fields.

Files to examine:
@lib/models/gpx_track.dart
@lib/services/import/gpx_track_import_models.dart
@lib/services/gpx_importer.dart
@lib/providers/map_provider.dart
@lib/objectbox.g.dart
@lib/services/objectbox_schema_guard.dart
@test/services/gpx_track_managed_placement_test.dart
@test/providers/map_provider_import_test.dart
@test/widget/gpx_track_import_dialog_test.dart
@test/robot/gpx_tracks/gpx_tracks_robot.dart
@test/robot/gpx_tracks/gpx_tracks_journey_test.dart
@test/services/objectbox_schema_guard_test.dart
</background>

<discovery>
1. Search all `lib/` and `test/` code for `managedRelativePath`, `managedPlacementPending`, `Selected Track_`, and `Correlated Track_`.
2. Confirm whether any production path still reads persisted placement metadata after import completes.
3. Confirm whether the special filename forms are real business rules or only test/data fixtures; keep generic collision suffixing in production.
4. Confirm whether old ObjectBox records or serialized maps still need tolerant reads after the field removal.
</discovery>

<user_flows>
Primary flow:
1. User selects GPX files.
2. App filters, names, and imports Tasmanian tracks.
3. App moves the source file to managed storage using the actual filename/path.
4. App persists the track only after the move succeeds, then refreshes map state and selects the imported track.

Alternative flows:
- Duplicate or unchanged file: skip add, keep existing selection state.
- Non-Tasmanian file: skip add, report count only.
- Filename collision in managed storage: use generic suffixing, no special-case sentinel names.

Error flows:
- Invalid GPX / parse failure: skip the file, keep the rest of the batch moving.
- Move/rename failure before persistence: skip that file, report an error count, and do not write a database row.
- Persistence failure after move: keep a retryable recovery state, surface the new file location to the user, and allow manual re-import from that location.
- Legacy stored record missing removed fields: load without crash.
</user_flows>

<requirements>
**Functional:**
1. Remove `managedRelativePath` from `GpxTrack`.
2. Remove `managedPlacementPending` too; the move-first contract makes the recovery breadcrumb obsolete.
3. Remove every production read/write of the removed placement fields.
4. Import/placement logic must move first, then persist the track only after rename success.
5. Import/placement logic must derive target behavior from the actual source path and final on-disk filename, not persisted relative-path state.
6. Delete any special-case production code that exists only to create or interpret `Selected Track_*` / `Correlated Track_*` filenames; generic suffixing stays.
7. If persistence fails after a successful move, keep a retryable recovery state keyed by the actual destination path and surface it to the user; do not add a new persisted shadow-path field.

**Error Handling:**
7. Legacy maps / ObjectBox rows must tolerate removed fields during read.
8. If a move fails before persistence, skip that file and surface the failure through import counts / warning text.
9. If persistence fails after move, surface the recovery state and let the user retry manual import from the new file location.

**Edge Cases:**
8. Collision rename logic stays generic and deterministic.
9. Cleanup must not change GPX parsing, peak correlation, or map selection semantics.
10. Any schema change must be reflected in generated ObjectBox code, not handwritten patching.

**Validation:**
11. Model round-trip tests must cover removed-field absence and legacy-map tolerance.
12. Import/provider tests must cover selection of newly imported tracks and unchanged/non-Tasmanian counts.
13. Robot coverage must still prove the import journey end-to-end with stable selectors.
</requirements>

<boundaries>
Edge cases:
- Old persisted tracks with removed keys: read cleanly, no migration crash.
- Mixed import batches: one failure must not poison the whole batch.
- Managed-storage filename collisions: suffix only, no sentinel-name branch.
- `Selected Track` / `Correlated Track` strings may remain in tests and fixtures; do not add production branches for them.

Error scenarios:
- File move fails: do not persist a half-imported track.
- Persistence fails after move: keep a retryable recovery state, not a new persisted placement field.
- Schema signature changes after field removal: update expectations, do not suppress the mismatch.

Limits:
- Do not add backward-compatibility shadow fields unless a real consumer still depends on them.
- Do not add new UX for recovery unless the codebase proves it is needed.
</boundaries>

<stages>
1. Audit usage and confirm no surviving reads/writes of removed placement fields.
2. Remove `managedRelativePath`, `managedPlacementPending`, and any dead filename-special-case logic.
3. Regenerate ObjectBox schema and update tests.
4. Re-run import journey coverage and fix any stale assertions/selectors.
</stages>

<implementation>
Update `./lib/models/gpx_track.dart`, `./lib/services/import/gpx_track_import_models.dart`, `./lib/services/gpx_importer.dart`, and `./lib/providers/map_provider.dart` to remove shadow path storage and rely on on-disk state.
Regenerate `./lib/objectbox.g.dart` from the model change.
Adjust `./test/services/gpx_track_managed_placement_test.dart`, `./test/providers/map_provider_import_test.dart`, `./test/widget/gpx_track_import_dialog_test.dart`, `./test/robot/gpx_tracks/gpx_tracks_robot.dart`, `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`, and `./test/services/objectbox_schema_guard_test.dart` as needed.

Use existing Riverpod test seams and in-memory fakes. Keep selectors app-owned and stable.
Avoid broad refactors outside the cleanup boundary.
</implementation>

<validation>
Use TDD slices in this order:
1. `managedRelativePath` removal and legacy-map round-trip behavior.
2. `managedPlacementPending` removal and move-first import behavior.
3. UI + robot assertions for the import flow.

Expected coverage:
- Unit/business logic: model serialization, import path planning, schema guard expectations.
- Widget behavior: import dialog summary and cancel / close behavior remain stable.
- Robot journey: import a Tasmanian track through the import dialog via `GpxTracksRobot`, confirm the imported track is selected, and confirm the flow still completes with stable keys.
- Recovery path: after a failed persist post-move, user sees the destination path and retry guidance.

Required seams:
- Fake file picker.
- In-memory track repository / storage.
- Deterministic temp home/import directories.
- SharedPreferences mock for schema guard and importer state.

Required commands:
- `flutter analyze`
- `flutter test`

Keep tests behavior-first. One failing slice at a time; no bulk test batch before implementation.
</validation>

<done_when>
`managedRelativePath` is gone from production code, schema, and tests.
`managedPlacementPending` is gone from production code, schema, and tests.
Import moves files before persistence.
Post-move persistence failure leaves a retryable recovery state, not a new persisted path field.
No production branch depends on `Selected Track_*` or `Correlated Track_*` special cases.
Import, widget, robot, and schema tests pass.
</done_when>
