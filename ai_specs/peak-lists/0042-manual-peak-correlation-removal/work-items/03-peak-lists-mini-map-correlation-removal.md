---
type: Work Item
title: Peak Lists Mini-Map Correlation-Removal Flow
parent: ../spec.md
---

## What to build

Wire the shared `PeakInfoPopupCard` correlation-removal control into the Peak Lists mini-map host. Peak Lists owns its confirmation presentation and delegates confirmed `(GpxTrack.gpxTrackId, Peak.osmId)` removal to `MapNotifier`. Keep saving, inline error, and retry state in the initiating popup, and refresh its cached popup content after successful mutation or revision-driven data changes without closing it.

Preserve Peak Lists ascent-label navigation to the selected track on the MapScreen. The compact trailing removal control uses `peak-info-correlation-remove-$trackId-$peakOsmId` and must not navigate. Ensure the successful mutation refreshes `My Ascents`, `My Lists`, peak-list ascent counts, and dashboard summaries through the existing state/revision boundaries.

## Required context

- `lib/screens/peak_lists_screen.dart` contains `_MiniPeakMap`, `_popupContent`, mini-map popup construction, `peaksBaggedRevisionProvider` consumption, and ascent navigation through `_openAscentTrackOnMap()`.
- `lib/screens/map_screen_panels.dart` supplies the shared `PeakInfoPopupCard` ascent-row and removal-control contract added by `02-mapscreen-correlation-removal-controls.md`.
- `lib/providers/my_ascents_summary_provider.dart`, `lib/providers/my_lists_summary_provider.dart`, and `lib/providers/peak_list_provider.dart` consume `peaksBaggedRevisionProvider`; `MapState.tracks` drives track-derived dashboard counts.
- `test/widget/peak_lists_screen_test.dart`, `test/robot/peaks/peak_lists_robot.dart`, and `test/robot/peaks/peak_info_robot.dart` contain existing mini-map selectors, deterministic providers, and robot conventions. Do not add separate test infrastructure.

## Acceptance criteria

- [x] Every displayed Peak Lists mini-map `My Ascents` row exposes `peak-info-correlation-remove-$trackId-$peakOsmId`, opens the exact `Remove Peak Correlation?` confirmation contract, and delegates only the resolved `(GpxTrack.gpxTrackId, Peak.osmId)` pair to the notifier.
- [x] Cancelling or dismissing confirmation leaves the cached popup and persisted data unchanged. While saving, the initiating removal control is disabled with a stable busy-state selector; failure keeps the popup and row open, shows inline `Failed to remove peak correlation: ` plus actionable detail through a stable failure selector, and restores retry.
- [x] On success or successful no-op, the mini-map popup remains open and refreshes its cached content with the removed/stale row gone. No undo affordance, success dialog, toast, or completion dialog is shown.
- [x] Tapping an openable Peak Lists ascent label still navigates to that track on the MapScreen. Tapping its trailing trash control never navigates. MapScreen ascent labels remain non-interactive.
- [x] At text scaling through 200% within the existing 320 px peak-popup width, the mini-map popup control remains keyboard-operable, exposes `Remove peak correlation`, and does not overlap the peak name, ascent date, or existing popup controls.
- [x] Widget and robot coverage uses deterministic repository/provider fakes and the stable selectors from the shared popup contract to prove confirmation/cancel, busy, retryable failure, successful cached-content refresh, ascent navigation separation, and 200% layout without external services.
- [x] Summary and peak-list/widget coverage proves a successful `peaksBaggedRevisionProvider` increment refreshes `My Ascents`, `My Lists`, and peak-list ascent counts, while refreshed `MapState.tracks` updates track-derived Peaks Bagged and Year-to-Date dashboard counts.

## Covers

- User Stories: 2-3
- Requirements: 3-5, 8-11, 13-14
- Technical Decisions: 4-5
- Testing Strategy: 5-6
- Interview Ledger: L1, L3, L4, L5, L6

## Blocked by

01-atomic-peak-correlation-removal.md
02-mapscreen-correlation-removal-controls.md
