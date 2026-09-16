---
type: Work Item
title: Transactional Track-name normalisation
parent: ../spec.md
---

## What to build

Expose a repository-level batch Track-name normalisation operation backed by one ObjectBox write transaction. It must return updated and unchanged counts only after commit succeeds, update only supported `GpxTrack.trackName` values, and roll back every name change on failure.

Provide an in-memory transactional implementation or injectable batch-write failure seam so the rollback is deterministic in tests.

## Required context

- `lib/services/gpx_track_repository.dart` contains `GpxTrackStorage`, `ObjectBoxGpxTrackStorage`, `InMemoryGpxTrackStorage`, and the repository test constructor.
- `lib/services/track_derived_data_persistence.dart` and `test/services/track_derived_data_persistence_test.dart` establish the ObjectBox write-transaction and temporary-store relation-test patterns.
- `lib/models/gpx_track.dart` owns the persisted Track fields and `GpxTrack.peaks` relation.
- The normalisation boundary is provided by `01-shared-track-name-normalisation.md`; do not duplicate date matching in storage or repository code.

## Acceptance criteria

- [x] Start with failing tests for bulk-operation result and error behavior, then implement the minimum code needed to make them pass.
- [x] The batch operation inspects every persisted `GpxTrack`, changes only a supported trailing date suffix in `trackName`, returns updated and unchanged counts, and does not parse, overwrite, or delete `trackDate`.
- [x] A committed batch preserves each Track's identifier, GPX XML, derived statistics, peak relations, visibility, and every other persisted field; it does not recalculate statistics or peak correlation and does not rewrite `PeaksBagged` associations.
- [x] ObjectBox performs all batch name writes in one write transaction. A controlled write failure rolls back all name changes, and callers cannot refresh state or report counts before a successful commit.
- [x] Repository tests use the existing in-memory `GpxTrackStorage` pattern to verify updated and unchanged counts, all non-name fields, and deterministic all-or-nothing recovery from the batch-write failure seam.
- [x] A temporary ObjectBox-backed test with populated `GpxTrack.peaks` relations verifies those relations survive both a committed batch and a controlled rollback.

## Covers

- User Stories: 1, 3
- Requirements: 3-5, 7
- Technical Decisions: 1-2, 4-5
- Testing Strategy: 1, 3
- Interview Ledger: L1-L3

## Blocked by

01-shared-track-name-normalisation.md
