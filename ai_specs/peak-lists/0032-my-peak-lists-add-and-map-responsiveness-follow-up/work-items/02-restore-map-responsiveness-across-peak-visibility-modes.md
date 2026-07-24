---
type: Work Item
title: Restore Map Responsiveness Across Peak Visibility Modes
parent: ../spec.md
---

## What to build

Restore smooth `Map` pan and zoom responsiveness across `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks` without redesigning the current `Peak visibility mode` state machine. In `Show Peak Clusters` and `Show Peaks`, continuous map motion must avoid requiring a fresh peak-list-derived refresh or a fresh full main-map peak projection or viewport rebuild on every camera tick just to keep the map moving, while settled state still converges to the correct latest accepted result after motion stops. In `Hide Peaks`, keep the map as the cheapest early-gated path by skipping peak marker rendering, clustering, hover hit-testing, and equivalent visible-mode peak processing. Preserve the existing `0027` drawer responsiveness and stale-work contract and the current `0028` labels, icons, low-zoom hide rule, and remembered selection semantics.

## Required context

- `lib/screens/map_screen.dart` already owns the live-camera motion path, settled peak viewport frame, visible-bounds sync, and `onPositionChanged` gesture handling. Treat that `MapScreen` seam as the concrete local source of truth for continuous-motion behavior rather than moving the contract into a new provider-only abstraction.
- `lib/providers/map_provider.dart` already owns `Peak visibility mode`, drawer actions, remembered visible-region selection snapshots, and `Hide Peaks` restore behavior. Preserve the existing `0028` state-machine semantics while tightening the hot path underneath it.
- `lib/providers/peak_list_selection_provider.dart` already owns deferred peak-list-derived refresh work for drawer entries, app-bar chips, metadata-filter scope peaks, and `Peak ownership ring` outputs. Preserve the existing `0027` latest-interaction-wins and stale-work supersession contract while reducing motion-path cost.
- Existing deterministic observability already lives in `test/widget/map_screen_rebuild_test.dart` through `MapRebuildDebugCounters`, with complementary visible-mode and hidden-mode coverage in `test/widget/map_screen_peak_cluster_toggle_test.dart` and selection-path coverage in `test/widget/map_peak_list_selection_test.dart`.
- Preserve current `Peak visibility mode` user-facing copy exactly: `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`. Do not redesign the visible-mode cycle, `Select Peak List`, low-zoom behavior, or remembered selection semantics in this slice.

## Acceptance criteria

- [x] `Map` pan and zoom responsiveness coverage applies across all three `Peak visibility mode` states while preserving the current `0028` labels, icon contract, low-zoom hide rule, and remembered selection semantics.
- [x] In `Show Peak Clusters` and `Show Peaks`, continuous map motion prioritizes smooth camera and basemap interaction over per-tick peak-list-derived recomputation and does not require a fresh peak-list-derived refresh or a fresh full main-map peak projection or viewport rebuild on every camera tick just to keep the map moving.
- [x] Reusing or transforming the last settled peak viewport frame during motion is acceptable, provided the settled map still converges to the correct final state for the latest accepted map state after motion ends.
- [x] Once motion settles in `Show Peak Clusters` or `Show Peaks`, the visible peak rendering and related peak-list-derived state converge to the correct final result for the latest accepted map state within about `250 ms` on the normal development machine. Treat this as a final verification target, not an automated cross-device SLA.
- [x] In `Hide Peaks`, the main map remains the cheapest path and does not continue doing peak marker rendering, clustering, hover hit-testing, or equivalent main-map peak-processing work required for visible modes.
- [x] The hot-path rework does not regress the existing `0027` responsiveness contract for `Map` `Peak Lists` drawer taps, immediate accepted control-state updates, or stale-work supersession while map motion and settle refreshes overlap.
- [x] Deterministic map widget regression coverage through `MapScreen` proves visible-mode motion decoupling and `Hide Peaks` early gating across the three states, reusing `MapRebuildDebugCounters`-style observability and existing widget seams rather than relying on provider-only proof or fragile wall-clock assertions.
- [ ] Final manual verification is performed against the existing real migrated local post-`0024` data that previously reproduced the slowdown, rechecking `Map` pan and zoom responsiveness in `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`, plus `Map` `Peak Lists` drawer responsiveness.

## Covers

- User Stories: 3-4
- Requirements: 1-2, 9-14
- Technical Decisions: 4-5
- Testing Strategy: 1, 5-8
- Interview Ledger: L1-L2, L6-L8

## Blocked by

None - ready to start
