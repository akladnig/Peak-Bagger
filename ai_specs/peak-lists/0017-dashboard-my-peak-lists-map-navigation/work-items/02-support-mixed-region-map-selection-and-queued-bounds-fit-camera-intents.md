---
type: Work Item
title: Support Mixed Region Map Selection And Queued Bounds Fit Camera Intents
parent: ../spec.md
---

## What to build

Extend the existing map provider and map screen camera-intent flow so a selected peak list can queue a bounds-fit request while `/map` is inactive, and consume that request once the map branch becomes available without adding new `/map` route arguments or query parameters. Update region-aware peak-list renderability and reconciliation logic touched by this slice so a selected list with `PeakList.region == mixed` is not dropped solely for lacking one canonical region key, and instead remains selectable and renderable when its cached bounds or current member peaks intersect the currently visible region set. Reuse the app's existing single-point camera fallback when the requested derived bounds collapse to one coordinate.

## Required context

- `lib/providers/map_provider.dart` already owns selected peak-list state, visible-region reconciliation, persisted peak-list selection, and `PendingCameraRequest` state.
- `lib/screens/map_screen.dart` already consumes queued camera requests when the map branch becomes active and already contains bounds-fit behavior for selected track and route extent zooming.
- `lib/services/peak_list_visibility.dart` is the current region-aware visibility gate that would drop `PeakList.region == mixed` without explicit handling.
- `test/harness/test_map_notifier.dart`, `test/providers/map_peak_list_selection_state_test.dart`, `test/providers/map_peak_list_selection_persistence_test.dart`, and `test/widget/map_screen_camera_request_test.dart` provide the current deterministic seams for provider state, queued camera requests, and shell-driven map-route entry behavior.
- Preserve the established `go_router` shell structure in `lib/router.dart`: `/map` remains a route without new arguments, and selection or camera intent must continue to flow through provider state.

## Acceptance criteria

- [x] Selecting a peak list for dashboard-driven map navigation can queue a pending bounds-fit camera intent while the `/map` shell branch is inactive, and the map route consumes that intent once it becomes available instead of requiring an immediate visible-map controller call.
- [x] The queued camera-intent seam remains compatible with the existing shell-based navigation pattern and does not add new `/map` route arguments or query parameters.
- [x] The queued camera intent represents bounds derived from persisted or on-demand `PeakList` coverage data and reaches the map route in a deterministic form that tests can assert without live map gestures.
- [x] If derived bounds collapse to one coordinate, the map route uses the app's existing single-point camera fallback rather than attempting a zero-area bounds fit.
- [x] Region-aware renderability and reconciliation logic touched by this slice does not drop a selected list solely because `PeakList.region == mixed`.
- [x] A mixed-region selected list remains selectable and renderable on the map when its cached bounds or current member peaks intersect the currently visible region set, while single-region list behavior remains unchanged.
- [x] Provider or widget coverage verifies queued camera-intent creation and consumption across shell route entry, mixed-region reconciliation behavior, and the single-point fallback path using existing deterministic seams such as `TestMapNotifier` or equivalent pending-camera assertions.
- [x] Automated tests continue to use fake or in-memory data only and do not depend on live ObjectBox data, external services, or real map networking.

## Covers

- User Stories: 1, 2
- Requirements: 2-6, 14-15
- Technical Decisions: 2-3
- Testing Strategy: 1, 4-6, 8, 10
- Interview Ledger: L1-L2

## Blocked by

- 1. `work-items/01-persist-peak-list-coverage-bounds-and-mixed-region-classification.md`
