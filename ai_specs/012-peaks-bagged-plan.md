## Overview

Persist derived `PeaksBagged` from stored `GpxTrack.peaks`.
Schema + repo + reset/recalc/startup sync + admin + tests.

**Spec**: `ai_specs/012-peaks-bagged-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first app; `models/`, `services/`, `providers/`, `screens/`, `widgets/`
- **State management**: Riverpod `Notifier`; shell via `go_router`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/router.dart`, `lib/services/objectbox_admin_repository.dart`
- **Assumptions/Gaps**: no major gaps; prefer repo conventions over new abstractions; notifier/orchestration tests need more realism than `TestMapNotifier` alone

## Plan

### Phase 1: Reset Vertical Slice

- **Goal**: schema + repo + reset rebuild proved end-to-end
- [x] `lib/models/peaks_bagged.dart` - add ObjectBox entity; four scalar fields only
- [x] `lib/services/peaks_bagged_repository.dart` - add derivation helper + reset clear/rebuild path + deterministic ordering
- [x] `lib/objectbox.g.dart` - regenerate schema
- [x] `lib/services/objectbox_schema_guard.dart` - include `PeaksBagged` in schema signature
- [x] `lib/providers/map_provider.dart` - construct `PeaksBaggedRepository`; run reset rebuild after final stored tracks; defer success snackbar until sync success
- [x] `test/services/peaks_bagged_repository_test.dart` - add repo/helper lane
- [x] `test/widget/gpx_tracks_shell_test.dart` - extend reset success/failure coverage if sync is in path
- [x] TDD: derive rows from stored tracks; cross-track duplicates kept; in-track duplicates collapsed; null dates + invalid ids handled
- [x] TDD: reset rebuild clears rows, restarts `baggedId` at `1`, uses deterministic `gpxId`/`peakId` ordering
- [x] TDD: reset failure after bagged-sync error returns failure surface; no early success snackbar
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Startup Migration + Warning Path

- **Goal**: migration marker + startup backfill + shell warning path
- [x] `lib/services/track_migration_marker_store.dart` - rename to `lib/services/migration_marker_store.dart`; add dedicated `peaks_bagged_backfill_v1_complete` marker; keep `TrackStartupAction` / `TrackStartupDecision`
- [x] `lib/providers/map_provider.dart` - run startup backfill only on `loadTracks` / `showRecovery`; mark marker on successful sync paths; expose `consumeStartupBackfillWarningMessage()`; clear pending startup warning on consume and on successful recovery
- [x] `lib/router.dart` - consume startup warning message; show shared-shell snackbar; wire `startup-backfill-warning-open-settings`
- [x] `test/services/migration_marker_store_test.dart` - marker persistence semantics only
- [x] `test/harness/test_map_notifier.dart` - add startup-warning fixtures + consume API for shell tests
- [x] `test/widget/gpx_tracks_shell_test.dart` - startup snackbar visibility + action path
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - helper for startup warning action + mirrored Settings assertion
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - startup warning -> `Open Settings` -> mirrored Settings detail
- [x] TDD: startup backfill clear/rebuild semantics; marker gating; `baggedId` restart on retry
- [x] TDD: marker completes after successful startup backfill, startup import/wipe-import rebuild, reset rebuild, recalc sync
- [x] TDD: startup failure sets `trackImportError`, emits one-shot warning message, clears warning on consume and successful recovery
- [x] Robot journey tests + selectors/seams for critical flows: reuse `startup-backfill-warning-open-settings`; keep notifier warning seam deterministic
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Recalc Sync + Admin Surface

- **Goal**: recalc preserve/delete/insert + admin entity visibility
- [x] `lib/providers/map_provider.dart` - run recalc sync after refreshed stored tracks; partial-commit failure handling; preserve unchanged ids
- [x] `lib/services/peaks_bagged_repository.dart` - add recalc sync: preserve/delete/insert; collapse duplicate stored pairs; append ids above current max
- [x] `lib/services/objectbox_admin_repository.dart` - add `PeaksBagged` entity rows + `gpxId` primary name field
- [x] `test/services/objectbox_admin_repository_test.dart` - schema/admin row mapping for `PeaksBagged`
- [x] `test/services/objectbox_schema_guard_test.dart` - schema guard includes new entity
- [x] `test/harness/test_objectbox_admin_repository.dart` - add `PeaksBagged` fixture entity/rows
- [x] `test/widget/objectbox_admin_shell_test.dart` - keep admin shell fixtures consistent with new entity
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - keep reset/recalc journeys green with new sync behavior
- [x] TDD: recalc sync preserves ids for unchanged `(gpxId, peakId)`; deletes removed pairs; appends new ids; leaves skipped-track rows intact
- [x] TDD: late bagged-sync failure reloads tracks from store, sets stale-derived-data error, suppresses queued success snackbar
- [x] TDD: admin entity metadata + rows expose `PeaksBagged` with `gpxId` primary name field
- [x] Robot journey tests + selectors/seams for critical flows: existing reset/recalc keys remain stable; no extra selectors beyond startup warning unless needed
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: ObjectBox schema/codegen churn; startup orchestration tests need realistic seams; partial-commit failure path easy to regress
- **Out of scope**: new bagged-peaks UI; manual editing/export for `PeaksBagged`; changes to peak-correlation algorithm or map overlays
