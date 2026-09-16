---
type: Work Item
title: Atomic Track replacement and recovery
parent: ../spec.md
---

## What to build

Execute canonical single-match selective-import replacements atomically across managed files, Track persistence, peak relations, and `PeaksBagged` rows. Introduce one injectable managed-file operations boundary, durable replacement-recovery issues, Track-operation blocking while an issue is pending, and a Settings recovery action that reconciles the recorded paths before clearing the issue.

Wire actual replacement outcomes into `MapNotifier` selection and the five-count completed result. Run the required focused verification command and the post-implementation full test suite.

## Required context

- `lib/providers/map_provider.dart` owns selective import, Track operation state, post-import selection, and the `hasTrackRecoveryIssue` guard; current replacement persistence and file movement are not atomic.
- `lib/services/gpx_importer.dart` contains the current direct `dart:io` replacement helper and existing replacement-destination rule. Replace its file operations with one injectable boundary.
- `lib/services/track_derived_data_persistence.dart` establishes the ObjectBox transaction pattern for replacing a Track, its `peaks` relation, and affected `PeaksBagged` rows.
- `lib/objectbox-model.json` and `lib/objectbox.g.dart` are versioned ObjectBox artifacts. A persisted `TrackReplacementRecoveryIssue` requires the project's ObjectBox generation workflow.
- `test/services/gpx_importer_selective_import_test.dart`, `test/services/track_derived_data_persistence_test.dart`, `test/widget/gpx_tracks_recovery_test.dart`, and `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` establish the relevant importer, transaction, recovery UI, and robot patterns.

## Acceptance criteria

- [x] For exactly one logical match, retain the stored `gpxTrackId`, `visible`, and `trackColour`; replace imported and derived Track content with incoming content; recompute peak correlation using existing import behavior; and select the replaced Track when import completes.
- [x] Resolve the managed destination through the existing replacement-destination rule. When a managed file already exists there, back it up, move the incoming file into its place, persist the Track replacement, then remove the backup. Process selected incoming files in selected-file order and count each completed replacement as replaced.
- [x] The replacement persistence stage is one ObjectBox write transaction replacing the Track, its `peaks` relation, and affected `PeaksBagged` rows. A controlled persistence failure commits none of those changes.
- [x] Managed-file operations use one injectable boundary with deterministic failures for destination resolution, backup, incoming move, source restoration, managed-file restoration, and backup cleanup.
- [x] Any managed-file or database failure restores the managed file and incoming source file to their pre-operation locations, leaves the stored Track unchanged, and counts that incoming Track as an error. A backup-cleanup failure is a replacement failure and also attempts restoration of the Track, its `peaks` relation, and affected `PeaksBagged` rows.
- [x] Execution failures retain these exact reasons: `Cannot replace Track because its managed-file destination could not be resolved.`, `Cannot replace Track because the existing managed file could not be backed up.`, `Cannot replace Track because the incoming managed file could not be moved.`, `Cannot replace Track because the Track replacement could not be persisted.`, `Cannot replace Track because the managed-file rollback could not be completed.`, `Cannot replace Track because the managed-file backup could not be removed.`, and `Cannot replace Track because restoration could not be completed. Recovery is required.`
- [x] If restoration cannot complete, persist a `TrackReplacementRecoveryIssue` containing exactly affected `sourcePath`, `destinationPath`, nullable `backupPath`, and failure `reason`; leave the stored Track unchanged and report the replacement as an error. A pending issue blocks all Track operations.
- [x] Provide a Settings recovery action that reconciles the recorded paths to their pre-operation state and clears the issue only after successful reconciliation.
- [x] Deterministic importer tests verify unique replacement identity/display preservation, correlation, selected replacement, managed-file mutations and compensation, every execution failure reason, durable-recovery behavior, unchanged unmatched Tracks, and rollback of the Track, `peaks`, and `PeaksBagged` rows without real filesystem failure behavior.
- [x] Run `flutter analyze` and `flutter test test/services/track_name_normalisation_test.dart test/services/gpx_track_repository_test.dart test/services/gpx_importer_selective_import_test.dart test/providers/map_provider_track_name_normalisation_test.dart test/widget/track_name_normalisation_settings_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`. Run `flutter test` after implementation and report its full-suite result; unrelated failures present in the baseline do not block this work.

## Covers

- User Stories: 2
- Requirements: 10-11
- Technical Decisions: 7-11
- Testing Strategy: 4, 7
- Interview Ledger: L1-L2

## Blocked by

04-canonical-selective-import-planning.md
