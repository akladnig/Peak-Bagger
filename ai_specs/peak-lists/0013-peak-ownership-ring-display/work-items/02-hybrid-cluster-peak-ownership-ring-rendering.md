---
type: Work Item
title: Hybrid Cluster Peak Ownership Ring Rendering
parent: ../spec.md
---

## What to build

Extend the same main-map `Peak ownership ring` presentation seam and rendering path so peak clusters always keep a ring on the main map route and follow the approved hybrid contract. Cluster rings must keep the ticked share as one solid green aggregate arc sized by ticked peak count, segment only the unticked remainder by currently selected app-bar peak lists represented by unticked peaks in the cluster, make unticked list segments equal per contributing selected list, keep clusters fully green when there are no unticked peaks, keep clusters fully list-segmented when there are no ticked peaks, and intentionally collapse per-list ownership inside the green ticked arc in this slice. Peak-list mini-map clusters are out of scope for this work item and keep their prior proportional ticked and unticked ring behaviour.

## Required context

- Build on the deterministic presentation seam from `01-individual-peak-ownership-ring-setting-and-presentation.md` instead of adding a second cluster-only painter contract.
- `lib/services/peak_cluster_engine.dart` already owns cluster member aggregation, ticked counts, and viewport projection, and should remain the source of truth for testable cluster ring presentation data.
- `lib/screens/map_screen_peak_layer.dart` currently paints the existing cluster ring and count overlay. Preserve current cluster interactions and count labeling while upgrading the ring contract.
- `lib/screens/peak_lists_screen.dart` reuses the shared peak layer for peak-list mini-maps, but those mini-map clusters must keep their prior proportional ticked and unticked ring display instead of inheriting the main-map ownership-ring contract.
- Reuse the current peak-list colour and selected-list membership rules from the map-owned peak-list state instead of introducing separate cluster selection logic.
- Existing focused coverage lives in `test/services/peak_cluster_engine_test.dart` and `test/widget/map_screen_peak_cluster_toggle_test.dart`. Keep deterministic presentation-model assertions ahead of painter-only or screenshot-style checks.

## Acceptance criteria

- [ ] Behavior-first TDD drives the hybrid cluster `Peak ownership ring` presentation rules before the rendering path is finalized.
- [ ] Main-map peak clusters continue to show a ring even when `Show Peak Ownership Rings` is off for individual markers.
- [ ] Each cluster `Peak ownership ring` keeps the ticked share as one solid green aggregate arc sized by the number of ticked peaks in the cluster.
- [ ] Only the unticked remainder is segmented by currently selected app-bar peak lists represented by unticked peaks in the cluster.
- [ ] Unticked cluster list segments are equal per contributing selected list, not proportional to unticked counts per list.
- [ ] If a cluster has no unticked peaks, the ring is fully green.
- [ ] If a cluster has no ticked peaks, the ring is fully list-segmented.
- [ ] This item does not preserve per-list ownership inside the green ticked cluster arc; ticked cluster ownership remains intentionally collapsed into one aggregate green share.
- [ ] Peak-list mini-map clusters keep their prior proportional ticked and unticked ring display and do not adopt the main-map hybrid ownership-ring contract in this item.
- [ ] Unticked cluster segments are built only from peak lists that are currently selected in the app bar for the active map state; hidden, unselected, pinned-only, or otherwise inactive lists do not contribute segments.
- [ ] For cluster unticked segments, segment order starts at 12 o'clock and proceeds clockwise, applying the current app-owned list-priority contract so Tasmania uses `Abels`, `HWC Peak Baggers`, `Poimenas`, `Tassy Full` and non-Tasmania falls back to ascending `peakListId`.
- [ ] Service or unit tests cover hybrid ring generation with green ticked share plus equal unticked selected-list segments derived only from currently selected lists represented by unticked cluster members, including fully green and fully list-segmented edge cases and deterministic segment ordering.
- [ ] Widget tests cover the main-map cluster rendering path keeping cluster rings visible when `Show Peak Ownership Rings` is off while preserving the cluster count overlay and deterministic behavior.

## Covers

- User Stories: 2
- Requirements: 1-2, 8, 12-13, 18, 21-23
- Technical Decisions: 1, 4-5
- Testing Strategy: 1, 2.7-2.8, 4.3, 6
- Interview Ledger: L1, L3, L5

## Blocked by

- `01-individual-peak-ownership-ring-setting-and-presentation.md`
