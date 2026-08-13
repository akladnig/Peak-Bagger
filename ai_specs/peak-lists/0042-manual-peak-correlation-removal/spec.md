---
type: Spec
title: Manual Peak Correlation Removal
---

## Problem

Peak Bagger automatically creates a peak correlation between an imported completed `Track` and nearby `Peak` records. Users can inspect those correlations as `Peaks Climbed` in the track information panel and as `My Ascents` in the peak info popup, but cannot correct a false positive without deleting the track or peak itself. The derived bagged-history rows and progress summaries must remain consistent with any correction.

## Proposed Outcome

Allow a user to remove one persisted peak correlation from either existing popup surface. The removal updates the selected track's `Peaks Climbed`, the selected peak's `My Ascents`, and all ascent-derived summaries atomically. It persists through normal app use, while an explicit peak-correlation rebuild remains free to recreate a matching correlation from GPX data and current settings.

## User Stories

1. As a peak bagger reviewing a completed track, I want to remove an incorrectly correlated peak from `Peaks Climbed` without deleting the track or peak.
2. As a peak bagger reviewing a peak, I want to remove one incorrect track from `My Ascents` without losing the track or the peak.
3. As a peak bagger, I want totals and progress views to reflect a correction immediately so my ascent history is trustworthy.

## Requirements

1. Treat this feature as removal of one **peak correlation**: the association of one `Peak` with one completed `Track`, identified as `(GpxTrack.gpxTrackId, Peak.osmId)`. Do not delete, edit, hide, or otherwise mutate the `Peak` or `GpxTrack` entity itself. [L1]
2. In `MapTrackInfoPanel`, add a compact trailing trash-icon control to every non-empty `Peaks Climbed` row, after the existing peak name and elevation. The control's tooltip and accessible label are `Remove peak correlation`. [L4]
3. In `PeakInfoPopupCard`, add the same compact trailing trash-icon control to every `My Ascents` row in both the MapScreen peak popup and the Peak Lists mini-map popup. In the Peak Lists mini-map popup, retain the existing tap behavior on the track-label portion of the row for opening that ascent's track; activating the trash control must not trigger track navigation. MapScreen ascent labels remain non-interactive. [L4]
4. Either control must identify the same peak-correlation pair and open a confirmation dialog titled `Remove Peak Correlation?`. Its message must name the affected peak and track. It must provide `Cancel` and `Remove` actions. [L3]
5. Cancelling or dismissing the confirmation dialog must leave every persisted record and visible view unchanged. [L3]
6. Confirming `Remove` must remove the selected peak from the selected track's persisted peak-correlation relationship. It must remove the corresponding derived `PeaksBagged` history row for that exact track-and-peak pair, but must not affect correlations for the same peak on other tracks or other peaks on the same track. [L1]
7. Commit the track-correlation mutation and its derived bagged-history synchronization as one atomic local operation. A committed result must leave the relation and derived rows mutually consistent; a failed operation must retain their exact prior persisted state. [L5]
8. After a successful operation, keep the initiating `MapTrackInfoPanel`, MapScreen peak popup, or Peak Lists mini-map popup open and remove its row immediately. If the selected pair is already absent when confirmed, treat it as a successful no-op and refresh the initiating surface to remove its stale row. Refresh each open peak-info popup for the same data, including cached Peak Lists mini-map popup content, so `My Ascents` and `Peaks Climbed` do not show stale correlations. Do not show an undo affordance or a success/completion dialog. [L3] [L6]
9. Invalidate and refresh all ascent-derived views after success, including peak-list ascent counts and dashboard summaries. [L6]
10. While a confirmed removal is saving, disable its removal control to prevent duplicate requests. On a successful commit, refresh visible state. On failure, restore the control to an enabled retryable state without removing its row. [L5]
11. If the operation fails, keep the initiating popup open and show an inline error beginning exactly `Failed to remove peak correlation: ` followed by actionable failure detail. The user must be able to retry from that popup. [L5]
12. A manually removed correlation must persist through ordinary app restarts and any synchronization that derives `PeaksBagged` rows from the persisted track relationship. It is not a permanent exclusion: an explicit all-track or selected-track rebuild of statistics and peak correlation may recreate the correlation if stored GPX data matches the current rules. [L2]
13. Preserve the existing popup entry, close, and back behavior. The controls operate only on displayed correlations; empty `Peaks Climbed` and absent `My Ascents` retain their current empty states. [L1] [L4]
14. Preserve current popup sizing and styling. The new controls must remain keyboard-operable, expose the accessible label from requirement 2, and not obscure or overlap peak names, elevations, ascent dates, or existing popup controls at text scaling through 200% within the existing 360 px track-panel and 320 px peak-popup widths. [L4]

## Technical Decisions

1. `GpxTrack.peaks` is the source of truth for a peak correlation. `PeaksBagged` remains derived bagged history, rebuilt or synchronized from persisted tracks; do not make a direct `PeaksBagged` deletion the only mutation. [L1] [L2]
2. Add a focused `MapNotifier` mutation boundary for a single `(trackId, peakOsmId)` removal, where `trackId` is `GpxTrack.gpxTrackId` and `peakOsmId` is `Peak.osmId`. Each supported host owns its confirmation presentation: MapScreen for `MapTrackInfoPanel` and its peak popup, and Peak Lists for its mini-map popup. Each delegates mutation and resulting refreshes to the notifier rather than duplicating persistence logic. [L1] [L3]
3. Reuse the existing `TrackDerivedDataPersistence` pattern to persist a replacement track relationship and synchronize its `PeaksBagged` plan in one ObjectBox write transaction. Its repository-backed test implementation must preserve exact snapshots on a deterministic injected failure. [L5]
4. On success, update `MapState.tracks`, recalculate correlated peak IDs, increment `peaksBaggedRevisionProvider`, call the existing MapScreen peak-popup refresh path, and refresh cached Peak Lists mini-map popup content. These are the source-of-truth state and side-effect boundaries for map markers, peak-list counts, dashboard summaries, and open popup content. [L6]
5. Extend popup callback contracts only as needed to carry the selected pair and asynchronous failure result for all three hosts. Keep saving state owned by the initiating popup/card and dispose any controllers or other resources using the existing widget lifecycle pattern. Use host-namespaced stable removal-control keys containing both IDs: `map-track-correlation-remove-$trackId-$peakOsmId` for `MapTrackInfoPanel` and `peak-info-correlation-remove-$trackId-$peakOsmId` for each `PeakInfoPopupCard` host. [L4] [L5]
6. The operation is local ObjectBox persistence only. It must not issue network requests, require API keys, add secrets or configuration, or depend on external services.

## Testing Strategy

1. Use TDD for the mutation and persistence behavior: add one focused failing service/provider test before each behavior change, then implement the smallest passing change. [L1] [L2] [L5]
2. Add service/provider tests using the existing in-memory `GpxTrackRepository`, `PeaksBaggedRepository`, and `RepositoryTrackDerivedDataPersistence` seams. Cover removal of exactly one `(GpxTrack.gpxTrackId, Peak.osmId)` pair, preservation of unrelated same-track and same-peak correlations, derived-row synchronization, a confirmed already-absent pair as a successful no-op, and explicit recalculation restoring a removed eligible correlation. [L1] [L2]
3. Add deterministic failure-injection coverage for failures before the track write and before the bagged-history write. Assert the exact pre-mutation track correlation and bagged rows, including bagged identifiers, remain after failure. No real ObjectBox database, GPX file, network service, API key, or secret may be required by automated tests. [L5]
4. Extend `MapTrackInfoPanel` widget tests to cover the trailing control, its tooltip/accessibility, confirmation/cancel behavior, disabled saving state, successful in-place row removal, inline retryable failure, and layout at 200% text scaling. Use the host-namespaced stable key from technical decision 5 for the track-row removal control, plus stable keys for confirmation actions, busy state, and failure surface. [L3] [L4] [L5]
5. Extend MapScreen peak-info and Peak Lists mini-map widget and robot journey coverage to verify every `My Ascents` row exposes its host-namespaced stable removal control, confirmation/cancel behavior, disabled saving state, retryable inline failure, and successful removal refreshes the visible ascent list in both hosts. Verify Peak Lists ascent-label taps still navigate, its trash control does not navigate, and MapScreen ascent labels remain non-interactive. Cover each popup layout at 200% text scaling. Use deterministic repository/provider fakes and stable selectors; do not call external services. [L3] [L4] [L5] [L6]
6. Extend summary and peak-list/widget coverage to prove a `peaksBaggedRevisionProvider` increment refreshes `My Ascents`, `My Lists`, and peak-list ascent counts after a successful removal. Separately prove the refreshed `MapState.tracks` updates the track-derived Peaks Bagged and Year-to-Date dashboard counts. [L6]
7. Add a repository-reload persistence test: remove one pair, reconstruct repository and provider state from the persisted track data, synchronize `PeaksBagged`, and assert that the removed pair remains absent while unrelated correlations remain intact. This test must not require a real ObjectBox database. [L1] [L2]

## Out of Scope

1. Deleting a `Peak`, `GpxTrack`, or any unrelated correlation.
2. Adding, editing, bulk-removing, or manually creating peak correlations.
3. An undo action, success dialog, toast, or permanent manual-exclusion list.
4. Changing peak-correlation settings, correlation thresholds, GPX parsing, or the behavior of explicit rebuild actions beyond allowing them to recreate a matching removed correlation.
5. Changing non-correlation track statistics, such as distance, elevation, time, or speed.
