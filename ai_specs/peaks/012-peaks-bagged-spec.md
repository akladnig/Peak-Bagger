<goal>
Build a durable ObjectBox `PeaksBagged` entity that records bagged peaks from persisted `GpxTrack.peaks` correlations during track rebuild flows.
This gives future features and the existing ObjectBox Admin screen a stable bagged-history data source without changing the current peak-correlation algorithm or map rendering behavior.
</goal>

<background>
The app is a Flutter + Riverpod + ObjectBox application.
Track-to-peak correlation already exists and is currently stored on `GpxTrack` through `ToMany<Peak> peaks` plus `peakCorrelationProcessed`.
The user-facing entry points for this work already exist in Settings through `Reset Track Data` and `Recalculate Track Statistics`.
ObjectBox Admin discovers entities from generated schema metadata, but row loading and per-entity display behavior are implemented manually, so a new entity must be wired into both schema generation and admin row loading.
`SettingsScreen` already treats track reset/recalc as success when `resetTrackData()` / `recalculateTrackStatistics()` return a non-null result and as failure when they return `null` with `trackImportError` populated.

Files to examine:
- `./ai_specs/012-peaks-bagged.md`
- `./lib/models/gpx_track.dart`
- `./lib/models/peak.dart`
- `./lib/providers/map_provider.dart`
- `./lib/router.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/services/objectbox_schema_guard.dart`
- `./lib/services/track_migration_marker_store.dart`
- `./test/harness/test_map_notifier.dart`
- `./test/harness/test_objectbox_admin_repository.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/widget/gpx_tracks_shell_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/services/objectbox_schema_guard_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens Settings and chooses `Reset Track Data`.
2. The app re-imports tracks and re-runs peak correlation exactly as it does today.
3. After the final `GpxTrack` set has been stored, the app rebuilds `PeaksBagged` from that stored data in the same overall reset operation.
4. The rebuild creates one row per `track + peak` pair from each track's `peaks` relation, using `trackDate` as the ascent date when present.
5. The existing success dialog is shown only after the bagged-data rebuild succeeds.
6. Reset rebuild ordering is deterministic: source tracks are processed in ascending `gpxTrackId`, and each track contributes unique correlated peaks in ascending `Peak.osmId` order before `baggedId` values are assigned.

Alternative flows:
- User chooses `Recalculate Track Statistics`: existing stored tracks are reprocessed, skipped tracks keep their previously stored `GpxTrack` row, and `PeaksBagged` is synchronized to the final post-recalc repository state.
- User opens ObjectBox Admin after either operation: `PeaksBagged` appears as a browsable entity with rows showing `baggedId`, `peakId`, `gpxId`, and `date`, and uses `gpxId` as the admin `primaryNameField`.
- First app launch after this schema ships with pre-existing stored tracks: on the persisted-track startup branches (`loadTracks` and `showRecovery`), after persisted tracks are loaded, the app checks a centralized migration marker and performs a one-time `PeaksBagged` clear-and-rebuild backfill from the already persisted `GpxTrack` rows using reset-style deterministic ordering and `baggedId` restart at `1`, without requiring the user to visit Settings.

Error flows:
- A track has an empty `peaks` relation: generate no `PeaksBagged` rows for that track and continue.
- A track has `trackDate == null`: generate rows with a null `date`; do not substitute `startDateTime`.
- Recalculate skips some tracks: the bagged sync must use the final stored track set, including unchanged tracks that were kept after a recalculation failure.
- `PeaksBagged` persistence fails after track writes already completed: abort the bagged write transaction, leave the previously committed `PeaksBagged` snapshot untouched, refresh in-memory tracks from store so `MapState` matches the committed `GpxTrack` rows, clear any success status, suppress any queued success snackbar, surface an explicit stale-derived-data error, and do not report a false success to the user.
- Startup backfill fails: do not mark the migration complete, leave existing tracks usable, and surface a one-shot shell-level `SnackBar` from the shared app shell across branches with an `Open Settings` action keyed `startup-backfill-warning-open-settings`, while mirroring the detail in Settings so the user can rerun reset or recalc.
</user_flows>

<requirements>
**Functional:**
1. Create `./lib/models/peaks_bagged.dart` with an ObjectBox entity named `PeaksBagged`.
2. The entity must contain only scalar fields in v1: `@Id(assignable: true) int baggedId = 0`, `int peakId`, `int gpxId`, and `@Property(type: PropertyType.dateUtc) DateTime? date`.
3. Do not add `ToOne` or `ToMany` relations from `PeaksBagged` to `Peak` or `GpxTrack`; `peakId` must store `Peak.osmId` and `gpxId` must store `GpxTrack.gpxTrackId` exactly as requested.
4. Create `./lib/services/peaks_bagged_repository.dart` to encapsulate `PeaksBagged` reads and writes plus the sync logic driven from stored `GpxTrack` rows.
5. Define row semantics as one row per unique `GpxTrack.gpxTrackId + Peak.osmId` pair. If one track contains two correlated peaks, create two rows. If two tracks reference the same peak, create two rows. If the same peak appears twice within one track relation, persist only one row for that pair.
6. `Reset Track Data` must clear all `PeaksBagged` rows and rebuild them from the final stored `GpxTrack` set after import/correlation completes and before the existing success UI is emitted.
7. The reset rebuild must restart `baggedId` numbering at `1` and assign contiguous ids using deterministic ordering: sort tracks by `gpxTrackId` ascending, then sort each track's unique valid `peakId` values ascending.
8. `Recalculate Track Statistics` must synchronize `PeaksBagged` to exactly match the final stored `GpxTrack` set after recalculation finishes.
9. The recalc sync must preserve the existing `baggedId` for unchanged `gpxId + peakId` pairs, remove rows whose pair no longer exists, and assign new ids above the current max for newly introduced pairs.
10. Use `GpxTrack.trackDate` as the nullable ascent date. If `trackDate` is missing, store `null` in `PeaksBagged.date` rather than skipping the row or deriving a fallback from `startDateTime`.
11. Skip derived rows only when required ids are invalid (`gpxTrackId <= 0` or `peak.osmId <= 0`) or when the track has no correlated peaks.
12. Regenerate the ObjectBox schema output in `./lib/objectbox.g.dart` after adding the new entity.
13. Update `./lib/services/objectbox_admin_repository.dart` so `PeaksBagged` is included in admin row loading, metadata, and row mapping without adding a synthetic persisted label field just for admin display; use `gpxId` as `PeaksBagged.primaryNameField`.
14. Update `./lib/services/objectbox_schema_guard.dart` so the schema signature changes when `PeaksBagged` is present.
15. `PeaksBagged` derivation must read from `GpxTrack` rows reloaded from the repository/store after the track import or track replacement loop finishes; do not derive from a partially updated in-memory list.
16. Rename `./lib/services/track_migration_marker_store.dart` to `./lib/services/migration_marker_store.dart` and centralize startup migration flags there; keep `TrackStartupAction`, `TrackStartupDecision`, and the existing track-specific startup decision semantics intact.
17. Add a dedicated `peaks_bagged_backfill_v1_complete` marker in `MigrationMarkerStore`; do not reuse the existing track optimization marker.
18. Add a one-time startup backfill path for pre-existing stored tracks that runs only on the persisted-track startup branches (`loadTracks` and `showRecovery`), checks the dedicated bagged-backfill marker independently of the existing track startup action flow, and populates `PeaksBagged` without requiring users to manually run reset/recalc.
19. Startup backfill must use clear-and-rebuild semantics from the persisted `GpxTrack` set, reuse reset-style deterministic ordering, and restart `baggedId` at `1` on each retry.
20. Mark `peaks_bagged_backfill_v1_complete` complete after any successful operation that leaves `PeaksBagged` fully synchronized with persisted `GpxTrack` data, including startup backfill, successful reset/import rebuilds, startup import or wipe-and-import rebuilds, and successful recalc sync.

**Error Handling:**
21. Execute each `PeaksBagged` rebuild/sync inside one ObjectBox write transaction so partial bagged results are never committed.
22. If `PeaksBagged` sync fails during reset or recalc, route the failure through the existing track-operation error surface (`trackImportError` and the existing failure dialogs) instead of silently claiming success.
23. Recalculate must continue to respect current skipped-track behavior: if a track cannot be recalculated and its previous `GpxTrack` row remains stored, the final bagged sync must keep that track's bagged rows unless its persisted `peaks` relation changed.
24. The bagged sync does not need to share a single transaction with the entire track import/recalc operation; it must be atomic for `PeaksBagged` itself and must run only after the final `GpxTrack` writes for that operation have completed.
25. When bagged sync fails after track writes already committed, treat that as a partial-commit failure: reload tracks from the store into `MapState`, clear any success status/warning for the just-failed operation, clear any queued track success snackbar, set `trackImportError` to explain that tracks were updated but bagged history is stale, and direct the user to retry reset or recalc.
26. Success snackbar emission for reset/import flows must be deferred until `PeaksBagged` sync succeeds; do not queue a success snackbar before the derived-data step is complete.
27. Expose startup backfill failure to the shared shell through a dedicated message-based `MapNotifier` consume API, e.g. `String? consumeStartupBackfillWarningMessage()`, consumed by `router.dart`; do not overload the existing track success snackbar queue or recovery signal, and clear the pending startup warning message on consume.
28. If the one-time startup backfill fails, do not mark the migration complete; leave existing tracks available and surface a one-shot shell-level `SnackBar` from the shared app shell with an `Open Settings` action keyed `startup-backfill-warning-open-settings` rather than blocking app startup.
29. Mirror startup backfill failure details into `trackImportError` so Settings shows the same failure context, and clear both that field and any pending startup warning message after successful startup backfill, reset, or recalc.

**Edge Cases:**
30. Zero stored tracks or zero correlated peaks must leave a valid empty `PeaksBagged` table.
31. Running `Reset Track Data` multiple times in a row must produce the same derived rows in the same deterministic order and restart `baggedId` from `1` each time.
32. Running startup backfill multiple times after failure must also produce the same derived rows in the same deterministic order and restart `baggedId` from `1` each time.
33. Running recalc after a previous reset or startup backfill must not renumber unchanged rows; only reset and startup clear-and-rebuild backfill are allowed to restart ids.
34. Duplicate peaks within a single `GpxTrack.peaks` relation must collapse to one derived row for that `gpxId + peakId` pair.
35. Because the four-field model does not enforce schema-level uniqueness, recalc sync must collapse any pre-existing duplicate `PeaksBagged` rows that share the same `gpxId + peakId` before applying preserve/delete/insert logic.

**Validation:**
36. `PeaksBagged` must always be derived from stored `GpxTrack` data already in ObjectBox; do not recompute peak correlation from UI state, search state, or transient map data.
37. Keep the current Settings entry points, dialog titles, and stable keys intact unless an additional explicit stale-derived-data failure message is required to surface a real error.
</requirements>

<boundaries>
Edge cases:
- Track with no correlated peaks: no `PeaksBagged` rows for that track.
- Track with `trackDate == null`: persist rows with `date == null`.
- Same peak in two different tracks: persist two rows, one per `gpxId + peakId` pair.
- Same peak repeated inside one track relation: persist one row for that pair.
- No tracks present after reset: `PeaksBagged` ends empty and the next reset still restarts ids from `1`.

Error scenarios:
- Bagged sync transaction throws: leave the previous `PeaksBagged` state untouched, surface the failure through the existing track failure flow, and do not show a misleading success dialog.
- Bagged sync transaction throws after tracks were already rewritten: accept that `GpxTrack` may now be newer than `PeaksBagged`, but immediately reload tracks from store into `MapState`, leave the old `PeaksBagged` snapshot untouched, fail the overall user operation, suppress any queued success snackbar, and tell the user that bagged history is stale until retry.
- Track recalculation partially fails: derive the final bagged table from the stored tracks that remain after the recalculation loop, including preserved unchanged tracks.
- Legacy or malformed stored ids (`gpxTrackId <= 0` or `osmId <= 0`): skip those derived rows rather than creating invalid bagged records.
- Startup backfill fails: do not mark the migration complete, keep the app usable, surface a one-shot shell-level `SnackBar` from the shared app shell with an `Open Settings` action keyed `startup-backfill-warning-open-settings`, and mirror the detail in Settings so reset/recalc can rebuild bagged history.

Limits:
- Do not change `TrackPeakCorrelationService`, GPX import semantics, or map overlay rendering as part of this task.
- Do not add a new manual-edit UI or a dedicated bagged-peaks screen in this task.
- Do not move bagged history into `Peak` or `GpxTrack`; `PeaksBagged` is a derived mirror, not a replacement for the existing correlation relation.
- ObjectBox Admin support is browse-only for this entity; no export or editing flow is required.
- Do not add ongoing background repair for `PeaksBagged`; after the one-time startup backfill migration path, maintenance remains the responsibility of migration gating plus the existing reset/recalc entry points.
</boundaries>

<discovery>
Confirm the generated ObjectBox entity order and field names after `build_runner` so admin tests do not rely on a stale four-entity schema.
Confirm whether the existing failure dialogs already surface `trackImportError` clearly enough for a bagged-sync failure; if not, add only the minimum message change needed to avoid a silent stale-data state.
Confirm the chosen integrated notifier/orchestration test seam can exercise startup branch selection and marker lifecycle without depending on production-only startup side effects.
</discovery>

<implementation>
Create:
- `./lib/models/peaks_bagged.dart`
- `./lib/services/peaks_bagged_repository.dart`
- `./test/services/peaks_bagged_repository_test.dart`
- `./test/services/migration_marker_store_test.dart`

Modify:
- `./lib/providers/map_provider.dart`
- `./lib/router.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/services/objectbox_schema_guard.dart`
- `./lib/services/track_migration_marker_store.dart` (rename to `./lib/services/migration_marker_store.dart`)
- `./lib/objectbox.g.dart` (generated)
- `./test/harness/test_map_notifier.dart`
- `./test/harness/test_objectbox_admin_repository.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/services/objectbox_schema_guard_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/widget/gpx_tracks_shell_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

Implementation notes:
- Keep the track-to-bagged derivation rules in a small public helper or repository method that accepts `Iterable<GpxTrack>` so the logic is directly unit-testable.
- Keep ObjectBox writes behind an ObjectBox-backed `PeaksBaggedRepository`; do not inline bagged sync queries and transaction handling directly inside the widget layer.
- Construct `PeaksBaggedRepository` directly in `MapNotifier`, matching the existing `GpxTrackRepository` wiring pattern.
- Call the reset rebuild only after `_importTracks(... resetExisting: true)` has produced the final stored tracks.
- Call the recalc sync only after `refreshedTracks = _gpxTrackRepository.getAllTracks()` is available, so skipped-track preservation is naturally reflected in the sync source.
- For recalc, determine row identity strictly by `gpxId + peakId`; `date` is an updatable payload on that identity, not part of uniqueness.
- Treat `gpxId + peakId` uniqueness as repository-enforced, not schema-enforced, and make sync defensively collapse duplicate stored rows before applying preserve/delete/insert logic.
- For reset numbering and recalc insertion order, use explicit sorting rather than relying on `box.getAll()` or relation iteration order.
- Centralize startup migration flags in `MigrationMarkerStore`, keep `TrackStartupAction` and `TrackStartupDecision` as the existing track-specific startup decision types, and check the dedicated `PeaksBagged` backfill marker independently only on the persisted-track branches after tracks are loaded.
- Mark `peaks_bagged_backfill_v1_complete` after any successful operation that leaves `PeaksBagged` synchronized, not only after startup backfill.
- On late bagged-sync failure, reload committed tracks from store into `MapState` before surfacing the error so the UI does not retain stale pre-operation track state.
- Defer success snackbar emission until the bagged sync step completes successfully.
- Surface startup backfill failures from `router.dart` as a one-shot shared-shell `SnackBar` available from any branch, driven by a dedicated message-based `MapNotifier` consume API such as `consumeStartupBackfillWarningMessage()`, with action key `startup-backfill-warning-open-settings`, and mirror the detailed error in Settings through `trackImportError`.
- Update `./test/harness/test_map_notifier.dart` to expose startup-warning fixtures plus `consumeStartupBackfillWarningMessage()` so widget and robot tests can drive the shared-shell warning path deterministically.
- Update `./test/robot/gpx_tracks/gpx_tracks_robot.dart` with helpers for the startup warning `Open Settings` action and for asserting mirrored startup failure detail in Settings.
- Update `./test/harness/test_objectbox_admin_repository.dart` and `./test/widget/objectbox_admin_shell_test.dart` so admin widget fixtures and shell expectations include the new `PeaksBagged` entity where relevant.
- Preserve existing settings copy where possible. Only change user-visible strings if required to explain a real bagged-data failure.
- Avoid introducing a second source of truth for bagged peaks in `MapState`; this task is about durable persistence, not live overlay state.
- Regenerate ObjectBox code with the repo's existing build flow, e.g. `dart run build_runner build --delete-conflicting-outputs`.
</implementation>

<stages>
Phase 1: Add the `PeaksBagged` model, repository, renamed `MigrationMarkerStore`, dedicated bagged-backfill marker, one-time startup backfill path, and generated ObjectBox schema.
Verify completion by running the model/schema/migration tests and confirming the generated schema includes `PeaksBagged`, startup backfill is gated by the dedicated marker, it only runs on `loadTracks` and `showRecovery`, and the helper rename does not change the existing track startup decision behavior.

Phase 2: Implement deterministic derivation and sync behavior for reset and recalc.
Verify completion with helper/repository tests that cover reset rebuild numbering, recalc preserve/delete/insert behavior, null dates, invalid ids, in-track dedupe, and duplicate-row collapse.

Phase 3: Wire admin visibility and protect existing user flows.
Verify completion with admin repository tests plus widget/robot tests showing the existing settings journeys still succeed or fail cleanly with bagged sync included, startup failures surface visibly through the shared-shell snackbar contract, `Open Settings` from that snackbar navigates to Settings, mirrored `trackImportError` detail is visible there, and admin tests no longer rely on stale entity order/count assumptions.
</stages>

<illustrations>
Desired behavior example:
- Stored tracks after reset:
  - `gpxId=7`, `trackDate=2024-01-15`, peaks `[11, 22]`
  - `gpxId=8`, `trackDate=null`, peaks `[11]`
- Resulting `PeaksBagged` rows after reset:
  - `baggedId=1`, `peakId=11`, `gpxId=7`, `date=2024-01-15`
  - `baggedId=2`, `peakId=22`, `gpxId=7`, `date=2024-01-15`
  - `baggedId=3`, `peakId=11`, `gpxId=8`, `date=null`

Desired recalc sync example:
- Existing rows before recalc:
  - `baggedId=3`, `peakId=11`, `gpxId=7`
  - `baggedId=4`, `peakId=22`, `gpxId=7`
  - `baggedId=5`, `peakId=11`, `gpxId=8`
- Desired rows after recalc:
  - `peakId=11`, `gpxId=7`
  - `peakId=33`, `gpxId=8`
- Expected sync result:
  - Preserve `baggedId=3` for `(gpxId=7, peakId=11)`
  - Delete rows `4` and `5`
  - Insert `(gpxId=8, peakId=33)` as `baggedId=6`

Counter-examples:
- Do not collapse all rows to one record per `peakId` across the whole app.
- Do not use `startDateTime` when `trackDate` is null.
- Do not leave stale `PeaksBagged` rows behind after recalc removes a `gpxId + peakId` pair.
- Do not leave `MapState.tracks` pointing at pre-operation data if track writes succeeded but bagged sync failed.
- Do not emit a success snackbar before `PeaksBagged` sync completes successfully.
</illustrations>

<validation>
Use vertical-slice TDD: write one failing test at a time, implement the smallest passing change, then refactor only after green.

Behavior-first test slices:
1. Add a failing pure/repository test for deriving rows from tracks: one row per `gpxId + peakId`, cross-track duplicates retained, in-track duplicates collapsed.
2. Add a failing test for nullable dates and invalid-id skipping.
3. Add a failing temporary-store test for the one-time startup backfill path and dedicated migration-marker gating, including deterministic clear-and-rebuild semantics.
4. Add a failing test for reset rebuild behavior: clear all rows and restart ids from `1`.
5. Add a failing test for reset rebuild ordering: ids are stable because tracks are ordered by `gpxId` and peaks by `peakId`.
6. Add a failing test for recalc sync behavior: preserve ids for unchanged pairs, delete removed pairs, collapse duplicate stored rows, and append new ids above the current max.
7. Add a failing test for admin exposure: `PeaksBagged` appears in schema metadata, uses `gpxId` as `primaryNameField`, and row loading returns the mapped values.
8. Add/update failing widget and robot tests only after the persistence behavior is green, to verify the settings-driven journeys still surface success and failure correctly, including the stale-derived-data failure path, deferred success snackbar, and startup backfill shared-shell snackbar surface.

Baseline automated coverage must include:
- Logic/business rules: derivation from `GpxTrack.peaks`, in-track dedupe, cross-track duplication, null dates, invalid-id skipping, deterministic reset ordering, reset id restart, repository-enforced duplicate collapse, and recalc preserve/delete/insert rules.
- UI behavior: `Reset Track Data` and `Recalculate Track Statistics` still show the correct existing dialogs or failure surfaces when bagged sync is part of the operation, late bagged-sync failures refresh tracks before surfacing the error, and no success snackbar appears before the derived-data step succeeds.
- Startup behavior: pre-existing persisted tracks are backfilled once through the dedicated migration marker flow, only on `loadTracks` and `showRecovery`, any successful sync path marks the backfill marker complete, failed startup backfill remains retryable, and startup failure is surfaced through the shared-shell snackbar with `Open Settings`.
- Critical user journeys: Settings -> `Reset Track Data` -> confirm -> success/failure dialog; Settings -> `Recalculate Track Statistics` -> success/failure dialog with existing track visibility behavior preserved; App startup with existing persisted tracks -> bagged backfill failure -> shared-shell snackbar with `Open Settings` -> Settings shows mirrored detail.

Test split:
- Pure helper tests plus temporary-store tests in `./test/services/peaks_bagged_repository_test.dart` for derivation, sync, duplicate collapse, and transaction behavior.
- Service tests in `./test/services/objectbox_admin_repository_test.dart` and `./test/services/objectbox_schema_guard_test.dart` for schema/admin integration.
- Service tests in `./test/services/migration_marker_store_test.dart` for the centralized migration flags and dedicated backfill marker persistence semantics only.
- Notifier/orchestration tests using a realistic integration-style notifier seam, not the current `TestMapNotifier` fake alone, for marker lifecycle across successful startup backfill, reset/import rebuild, recalc sync paths, and startup warning emission.
- Widget tests in `./test/widget/gpx_tracks_shell_test.dart` for result and failure dialogs when bagged sync is included, plus shared-shell startup snackbar behavior.
- Robot tests in `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` for the settings-driven reset and recalc journeys plus the startup warning -> `Open Settings` -> Settings mirrored-detail journey.
- Widget tests in `./test/widget/objectbox_admin_shell_test.dart` with `./test/harness/test_objectbox_admin_repository.dart` updated so admin shell fixtures remain consistent with the new `PeaksBagged` entity.

Stable selectors and seams:
- Reuse the existing stable keys `reset-track-data-tile`, `reset-track-data-confirm`, `track-reset-result-close`, `recalculate-track-statistics-tile`, `track-stats-recalc-result-close`, and `startup-backfill-warning-open-settings` for robot/widget coverage.
- Keep bagged derivation behind a pure helper seam that accepts deterministic `GpxTrack` fixtures, and keep sync/transaction behavior behind the ObjectBox-backed repository.
- Prefer temporary ObjectBox stores for persistence behavior over mocks, because the risk surface is transactionality and row replacement, not collaborator interaction.
- If transaction semantics cannot be honestly covered in a pure test, add focused integration-style temporary-store tests and keep the rest of the suite fast and deterministic.

Known testing risk to report explicitly:
- Existing robot harnesses around `TestMapNotifier` verify user journeys but do not prove real ObjectBox writes. Treat repository/service tests as the source of truth for persistence correctness and use robot tests only for journey regression coverage.
- The current `TestMapNotifier` fake is not sufficient by itself to prove startup branch selection or marker lifecycle across real sync paths; cover those behaviors with a more integrated notifier/orchestration seam.
</validation>

<done_when>
`PeaksBagged` exists in the ObjectBox schema, is populated deterministically from final stored `GpxTrack` correlations during reset and recalc, reset restarts `baggedId` at `1`, recalc preserves ids for unchanged `gpxId + peakId` pairs without duplicates, successful startup/rebuild sync paths mark the dedicated backfill marker complete, startup backfill runs only on `loadTracks` and `showRecovery`, startup backfill failure surfaces through the shared-shell `SnackBar` with `Open Settings` and is mirrored in Settings through `trackImportError`, pending startup warning state is cleared on consume and on successful recovery, ObjectBox Admin can inspect the rows, and automated tests cover logic, UI behavior, startup migration behavior, and the critical user journeys.
</done_when>
