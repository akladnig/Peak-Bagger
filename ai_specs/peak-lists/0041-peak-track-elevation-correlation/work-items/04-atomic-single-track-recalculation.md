---
type: Work Item
title: Atomic Single-Track Recalculation
parent: ../spec.md
---

## What to build

Add an injectable derived-track persistence boundary that commits one selected Track replacement and its resulting bagged-history synchronization plan in one ObjectBox write transaction. If processing, persistence, or synchronization fails, retain the exact prior persisted selected Track and every bagged-history row, including each bagged-history identifier. Its test implementation must deterministically fail before the selected-Track write and before the bagged-history write.

Add a focused `MapNotifier` individual-recalculation entry point that reuses the existing `GpxImporter`, `GpxTrackRepairService`, current processing-XML selection, correlation application, repository replacement, and bagged-history synchronization flow. It must rebuild only the selected Track's statistics, filtered/display data, repaired XML when needed, and peak correlation using both current thresholds; update derived bagged history from persisted Tracks; and never recalculate or rewrite unrelated Tracks. Preserve the existing all-Track Settings action and its result behavior while ensuring imports and explicit global rebuilds also use both current thresholds.

Use the existing global track-operation busy state as the mutual-exclusion source of truth, expose selected-Track busy state for the panel, and prevent concurrent global or individual track-derived-data mutations.

## Required context

- `lib/providers/map_provider.dart` contains `recalculateTrackStatistics()`, `_processingXmlForTrack()`, `_applyPeakCorrelation()`, the existing processing flow, and `MapState.isLoadingTracks`.
- `lib/services/gpx_track_repository.dart` and `lib/services/peaks_bagged_repository.dart` currently persist Track and bagged-history changes separately; the new boundary must bridge their shared ObjectBox transaction.
- `lib/models/gpx_track.dart` and `lib/services/peaks_bagged_repository.dart` define Track replacement and identifier-preserving bagged-history synchronization behavior.
- `test/gpx_track_test.dart`, `test/services/peaks_bagged_repository_test.dart`, and `test/harness/test_map_notifier.dart` contain the existing notifier, repository fake, and UI-notifier test seams.

## Acceptance criteria

- [x] Both current correlation thresholds apply to new Track imports and explicit global and individual Track recalculations; changing either setting still does not rebuild existing Tracks.
- [x] Global and individual recalculation use repaired stored GPX XML when it exists, otherwise original stored GPX XML, as the source for statistics and peak correlation.
- [x] Individual recalculation rebuilds only the selected Track's statistics, filtered/display data, repaired XML when needed, and peak correlation; it does not recalculate or rewrite unrelated Tracks.
- [x] The selected Track replacement and all resulting bagged-history synchronization changes commit atomically in one ObjectBox write transaction.
- [x] A failure during selected-Track processing, persistence, or bagged-history synchronization leaves the exact prior selected Track and every prior bagged-history row persisted, including their identifiers.
- [x] The selected operation refreshes Track data, correlated peak state, and derived bagged-history state after successful commit without clearing the selected Track.
- [x] The existing global busy state prevents another global or individual recalculation while either operation is active, and selected-Track busy state is available to the panel.
- [x] Provider/service coverage uses existing repository/provider fakes and proves: current-setting use during new and explicit recalculation; exactly one Track is updated while bagged history is synchronized; and deterministic failure before the selected-Track write and before the bagged-history write restores exact prior Track and bagged-history rows and identifiers. No real GPX files, ObjectBox databases, network services, or SharedPreferences outside established mocks are used.

## Covers

- User Stories: 1-3
- Requirements: 5, 9, 12-13
- Technical Decisions: 2-4
- Testing Strategy: 3
- Interview Ledger: L1, L4, L5, L7, L9

## Blocked by

01-elevation-aware-track-peak-correlation.md
02-persisted-peak-correlation-threshold-settings.md
