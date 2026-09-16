---
type: Work Item
title: Settings Track-name normalisation
parent: ../spec.md
---

## What to build

Expose the committed batch operation through the existing `MapNotifier`/`mapProvider` Track-operation boundary, returning updated and unchanged counts. Add the exact Settings maintenance action, confirmation, success, and error behavior; refresh persisted Tracks into provider state and refresh peak-info label consumers after success.

## Required context

- `lib/providers/map_provider.dart` contains the injectable `MapNotifier` dependencies, `MapState.isLoadingTracks`, `trackImportError`, `refreshPeakInfoPopupContent()`, and `recalculateTrackStatistics()` maintenance-operation pattern.
- `lib/screens/settings_screen.dart` places `reset-track-data-tile`, `recalculate-track-statistics-tile`, and the always-available `track-speed-analysis-tile` in the required order. It uses the standard 20x20 compact `CircularProgressIndicator`.
- `lib/widgets/dialog_helpers.dart` contains the key-driven Settings dialog conventions.
- `test/harness/test_map_notifier.dart`, `test/widget/gpx_tracks_shell_test.dart`, and `test/robot/gpx_tracks/gpx_tracks_robot.dart` establish deterministic notifier, Settings widget, and robot patterns.

## Acceptance criteria

- [x] Add a Settings `ListTile` directly below `Recalculate Track Statistics` with key `normalise-track-names-tile`, title `Normalise Track Names`, and subtitle `Remove trailing dates from stored track names`.
- [x] Tapping the tile shows a confirmation dialog titled `Normalise Track Names?` with the message `This will remove trailing dates from stored track names. Track dates will be kept. Do you wish to proceed?`, `Cancel`, and `Normalise` actions. The actions use keys `normalise-track-names-cancel` and `normalise-track-names-confirm`; cancelling makes no persistence changes.
- [x] The notifier sets and clears `MapState.isLoadingTracks` through the established Track-operation boundary, returns updated and unchanged counts only after the repository commits, and surfaces failures through the established Track-operation error state.
- [x] On success, reload persisted Tracks into the in-memory map Track list and refresh peak-info popup content without requiring an app restart or navigation refresh. The label-only operation does not recalculate statistics or peak correlation.
- [x] The success dialog is titled `Track Names Normalised`, uses close key `normalise-track-names-result-close`, and reports exactly `Updated N tracks, unchanged N tracks` using the app's count formatting.
- [x] On failure, set `trackImportError` to exactly `Failed to normalise track names: $e`, show `Track Name Normalisation Failed` with close key `normalise-track-names-error-close` and that error detail, and retain all stored Track names from before the operation.
- [x] While Track name normalisation, Track-data reset, or Track-statistics recalculation is in progress, disable only `Reset Track Data`, `Recalculate Track Statistics`, and `Normalise Track Names` consistently with `MapState.isLoadingTracks`; keep `Track Speed Analysis` available and show the standard compact progress indicator in the active tile.
- [x] Provider tests use the existing `TestMapNotifier` pattern to verify refreshed Tracks, busy-state exclusion, counts, and failure state. Settings widget tests use a deterministic fake notifier, require no filesystem GPX imports, network access, or ObjectBox storage, and verify exact copy, stable keys, placement, cancel-without-write, loading state, success counts, and failure detail.
- [x] At a supported desktop viewport with `2.0` text scale, widget coverage verifies the tile, confirmation message, `Cancel`, and `Normalise` action remain reachable.
- [x] Extend the GPX Tracks robot journey with the normalisation action and result dialog if its Settings helpers can exercise it without a new nondeterministic seam.

## Covers

- User Stories: 1, 3
- Requirements: 1-9
- Technical Decisions: 3, 5
- Testing Strategy: 3, 5-6
- Interview Ledger: L1-L3

## Blocked by

02-transactional-track-name-normalisation.md
