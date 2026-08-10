---
type: Work Item
title: Atomic Peak-Correlation Removal
parent: ../spec.md
---

## What to build

Add a focused `MapNotifier` mutation for removing one peak correlation identified exactly by `(GpxTrack.gpxTrackId, Peak.osmId)`. The mutation must replace the selected track relation through `TrackDerivedDataPersistence`, keeping `GpxTrack.peaks` as the source of truth and synchronizing `PeaksBagged` in the same local ObjectBox write transaction. It must never delete, edit, hide, or otherwise mutate either entity, nor alter correlations outside the selected pair.

After a committed mutation, refresh `MapState.tracks` and correlated peak state, increment `peaksBaggedRevisionProvider`, and refresh MapScreen peak-popup content. An already-absent selected pair is a successful no-op that still refreshes callers; persistence failures retain the exact prior track relation and bagged rows and surface a retryable failure to the caller. The operation remains local ObjectBox persistence only.

## Required context

- `lib/providers/map_provider.dart` contains injected `GpxTrackRepository`, `PeaksBaggedRepository`, and `TrackDerivedDataPersistence` seams, selected-track state, correlated peak state, and `refreshPeakInfoPopupContent()`.
- `lib/services/track_derived_data_persistence.dart` contains the ObjectBox transaction and repository-backed exact-snapshot failure seam to reuse.
- `lib/models/peak.dart`, `lib/models/gpx_track.dart`, and `lib/services/peaks_bagged_repository.dart` establish that derived history uses `Peak.osmId`, while `Peak.id` is the ObjectBox entity ID.
- `test/services/track_derived_data_persistence_test.dart` and `test/gpx_track_test.dart` establish deterministic in-memory repository and injected-failure coverage. Do not use a real ObjectBox database, GPX file, network service, API key, or secret in new automated coverage.

## Acceptance criteria

- [x] Follow TDD for mutation and persistence behavior: add one focused failing service/provider test before each behavior change, then implement the smallest passing change.
- [x] The mutation accepts only `trackId` as `GpxTrack.gpxTrackId` and `peakOsmId` as `Peak.osmId`; no mutation, sync lookup, or selector identity substitutes ObjectBox `Peak.id`.
- [x] A committed removal removes exactly the selected `Peak` from the selected persisted `GpxTrack.peaks` relationship and its matching `(gpxId, peakId)` `PeaksBagged` row, preserving other peaks on that track and the same peak on other tracks.
- [x] The selected track replacement and all bagged-history synchronization changes commit in one ObjectBox write transaction. A failed mutation retains the exact prior selected track relation and every bagged-history row, including bagged identifiers.
- [x] A confirmed pair already absent from the persisted track relation returns successful no-op behavior and leaves unrelated persisted records unchanged.
- [x] After success or successful no-op, `MapState.tracks`, correlated peak state, `peaksBaggedRevisionProvider`, and open MapScreen peak-popup content refresh without clearing the selected track or peak popup.
- [x] A manually removed pair remains absent after repository/provider reconstruction and derived-history synchronization from persisted tracks; explicit selected-track or all-track statistics and peak-correlation rebuild may recreate an eligible pair from stored GPX data and current rules.
- [x] Deterministic service/provider coverage proves exact-pair removal, preservation of unrelated same-track and same-peak correlations, derived-row synchronization, successful no-op behavior, injected failure before track and bagged-history writes with exact rollback, restart/reload persistence, and explicit rebuild restoration.

## Covers

- User Stories: 1-3
- Requirements: 1, 6-12
- Technical Decisions: 1-4, 6
- Testing Strategy: 1-3, 7
- Interview Ledger: L1, L2, L5, L6

## Blocked by

None - ready to start
