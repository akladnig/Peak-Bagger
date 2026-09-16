---
type: Work Item
title: Canonical selective-import planning
parent: ../spec.md
---

## What to build

Apply the shared normalisation boundary to GPX metadata names, filename fallbacks, and user-edited selective-import names before duplicate/replacement matching and persistence. Extend selective-import plan/result and completed background-job reporting contracts to carry exact five-count semantics and ordered per-file errors, and produce replacement candidates using canonical matching in selected-file order.

This slice establishes plans and reporting consumed by atomic replacement execution; it must not bulk-update unmatched existing Tracks.

## Required context

- `lib/services/gpx_importer.dart` owns `parseGpxFile()`, `_extractTrackName()`, `deriveDefaultTrackName()`, `planSelectiveImport()`, and current raw-name matching.
- `lib/services/import/gpx_track_import_models.dart` holds the plan/result contracts; it currently lacks `replacedCount` and ordered error records.
- `lib/widgets/gpx_import_dialog.dart` preserves selected-file order, while `lib/widgets/map_action_rail.dart` renders completed background-job summaries and details.
- `lib/models/gpx_track.dart` defines `GpxTrack.hasMetadataTrackDate`; both Tracks must satisfy it for a logical match.
- `test/services/gpx_importer_selective_import_test.dart` and `test/providers/map_provider_import_test.dart` are the importer and provider test conventions.

## Acceptance criteria

- [ ] Every incoming GPX Track name, whether from GPX content, a filename fallback, or a user edit in the selective import dialog, is normalised through the shared boundary before matching and persistence.
- [ ] Duplicate/replacement comparison normalises both incoming and stored names through the same boundary. A logical match requires both Tracks to satisfy `GpxTrack.hasMetadataTrackDate` and to share the normalised name and Track date.
- [ ] Planning preserves selected-file order and never bulk-updates unmatched existing Tracks.
- [ ] The selective-import plan and result retain added, replaced, unchanged, unsupported, and error counts plus ordered per-file errors with exactly `sourcePath` and `reason` fields. Plan counts are prospective parsing-and-matching outcomes; completed-result counts are actual outcomes and include execution-stage errors. Both retain planning-stage errors, and the completed result additionally retains execution-stage errors, all in selected-file order.
- [ ] A later eligible incoming Track that is a logical match for an earlier eligible incoming Track makes no persistence or managed-file changes, is counted as an error, appends exactly `Cannot import Track because another selected Track has the same normalised name and date.` to `import.log`, and retains that exact per-file error.
- [ ] Multiple stored canonical matches make no persistence or managed-file changes and retain exactly `Cannot replace Track because multiple stored Tracks match its name and date.` in `import.log` and completed background-job details.
- [ ] The selective-import summary reports exactly `Added N tracks, replaced N tracks, unchanged N tracks, unsupported N tracks, errors N tracks`, using the app's count formatting for every `N`. After count lines, details include every retained error in selected-file order as exactly `<basename(sourcePath)>: <reason>`.
- [ ] Importer and reporting tests prove metadata, filename-fallback, and edited names use the shared normaliser, verify canonical same-selection and multiple-stored-match planning behavior, exact log/details reasons, ordered errors, and prospective-versus-completed count contracts.

## Covers

- User Stories: 2
- Requirements: 10-11
- Technical Decisions: 1, 7, 9
- Testing Strategy: 4
- Interview Ledger: L1-L2

## Blocked by

01-shared-track-name-normalisation.md
