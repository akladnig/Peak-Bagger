---
type: Work Item
title: Map Motion Decoupled Peak Rendering
parent: ../spec.md
---

## What to build

Decouple continuous `Map` camera motion from peak-list-dependent recomputation so pan and zoom prioritize smooth basemap and camera interaction over per-tick membership-derived work. Peak-list-dependent peak rendering may lag while motion is still active, but once motion settles the app must converge to the correct final rendered result for the latest accepted selection without stale deferred work winning.

## Required context

- `lib/screens/map_screen.dart` already owns continuous camera updates, trackpad gesture handling, pointer motion boundaries, and post-motion persistence. Keep motion detection and settle boundaries inside this existing screen-level map seam unless a very small helper is clearly needed.
- `lib/providers/peak_list_selection_provider.dart` and `lib/services/peak_list_visibility.dart` currently derive visible-region-dependent peak-list behavior from `visibleBounds` and synchronous membership reads. This item should separate camera-tick updates from expensive peak-list-derived refresh work without changing the settled visibility contract.
- `lib/widgets/map_rebuild_debug_counters.dart` and `test/widget/map_screen_rebuild_test.dart` already provide map rebuild instrumentation that can be extended to prove the expensive peak-list-dependent work no longer runs on every camera tick.
- `test/widget/map_peak_list_selection_test.dart` and related map widget tests already cover visible-region and peak-list-selection behavior; extend those seams instead of introducing a new benchmark harness.
- Preserve the relational membership source-of-truth behavior from `ai_specs/peak-lists/0024-peak-list-membership-performance-and-export-responsiveness/spec.md`; this slice changes when derived work runs, not what data is authoritative.

## Acceptance criteria

- [x] Continuous `Map` zoom and pan no longer force peak-list-dependent recomputation on every camera tick in the affected regression path.
- [x] During in-motion camera updates, the app prioritizes smooth basemap and camera motion over per-tick peak-list-dependent filtering, visibility derivation, or ownership rendering work.
- [x] Brief in-motion lag for peak-list-dependent peak rendering is acceptable only while the user is still moving the map; once motion settles, the visible rendered peaks converge to the correct final state for the latest accepted selection.
- [x] Deferred post-motion peak-list-dependent rendering cannot allow stale work from an earlier motion or selection state to overwrite a newer accepted settled state.
- [x] The implementation preserves current settled labels, visibility rules, and selection semantics for `Map` peak-list rendering surfaces.
- [x] Deterministic widget-level regression coverage proves the hot camera path is decoupled from the expensive peak-list-dependent work, using existing rebuild counters or an equivalent existing debug seam rather than wall-clock performance assertions.
- [x] Deterministic coverage also proves settled rendering honors `latest interaction wins` when motion and rapid selection changes overlap.
- [ ] Final manual verification for this slice is performed against the existing real migrated local post-`0024` data that reproduces the slowdown, confirming smooth `Map` pan and zoom and correct post-motion settle behavior on the normal development machine.

## Covers

- User Stories: 1, 4
- Requirements: 1-4, 7-12
- Technical Decisions: 1-3, 5-6
- Testing Strategy: 1, 3-6
- Interview Ledger: L1-L8

## Blocked by

- `01-map-peak-list-selection-refresh-pipeline.md`
