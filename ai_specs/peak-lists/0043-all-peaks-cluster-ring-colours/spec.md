---
type: Spec
title: All Peaks Cluster Ring Colours
---

## Problem

The main map currently uses the peak ownership-ring cluster style even when `All Peaks` is selected. That mode has no active peak-list ownership segments, so a cluster containing unticked peaks can render as fully ticked rather than communicating its actual ascent status.

## Proposed Outcome

When `All Peaks` is selected on the main map, every peak cluster presents its current visible members as a proportional ring: unticked peaks use the standard unticked colour and ticked peaks use the standard ticked colour.

## User Stories

1. As a map user viewing all peaks, I can see the unticked and ticked composition of each cluster without selecting a peak list.
2. As a map user applying metadata filters in `All Peaks` mode, I can see a cluster ring that represents only the filtered peaks currently displayed.

## Requirements

1. On the main map, selecting `All Peaks` must render clusters with `PeakClusterRingStyle.proportionalTickedUnticked`. The unticked arc uses `untickedColour`; the ticked arc uses `tickedColour`; each arc sweep is proportional to the corresponding count in the cluster. [L1]
2. A cluster containing both statuses must show both contiguous segments, starting with the unticked segment at the established top-of-ring start angle, followed by the ticked segment. For example, three unticked and one ticked member renders a 75% unticked arc and a 25% ticked arc. [L1]
3. A cluster with no ticked members must render a fully unticked ring, and a cluster with no unticked members must render a fully ticked ring. [L1]
4. The ring composition must derive from the same filtered peak collection used to build the main-map viewport data. Peaks removed by rating, difficulty, or duration filters must not contribute to the cluster count or either arc. [L2]
5. When a specific peak list is selected, preserve the existing ownership-hybrid cluster-ring behavior, including peak-list colour segments for unticked peaks and the standard ticked segment. [L1]
6. Do not change individual peak-marker colours or rings, peak-list mini-map cluster rings, map navigation, selection persistence, or filter controls. [L1]

## Technical Decisions

1. Use the existing `PeakClusterRingStyle` selection seam at `MapScreenPeakLayer`/`PeakViewportPainter`; choose the proportional style from the main map only when the active `PeakListSelectionMode` is `allPeaks`. The mini-map must retain its explicit proportional style. [L1]
2. Continue using `PeakCluster.untickedFraction` and `PeakCluster.tickedFraction`, which are computed from the cluster members produced by the existing projection cache. The main map already supplies its filtered peak collection to that cache, so no parallel count or persistence state is needed. [L2]

## Testing Strategy

1. Retain the existing `peak_cluster_engine_test.dart` unit coverage for mixed, fully unticked, and fully ticked fraction outputs. The main-map regression tests below must use deterministic in-memory peaks and correlation IDs; no external service or API key is involved. [L1] [L2]
2. Add a main-map widget regression test that selects `All Peaks`, supplies a mixed-status clustered viewport, and asserts that the `peak-marker-paint` painter uses `PeakClusterRingStyle.proportionalTickedUnticked`. Seed `PeakVisibilityMode.showPeakClusters`, a low-zoom camera, and nearby deterministic peaks so the viewport contains a cluster.
3. Add a main-map widget regression test that starts with a mixed-status cluster of at least three nearby peaks in `All Peaks` mode, applies a rating, peak difficulty, or peak duration map metadata filter that removes a known member while leaving a cluster, and asserts the `PeakViewportPainter` retrieved from `peak-marker-paint` excludes that member and reports the updated fractions. [L2]
4. Add or extend a widget regression test for specific-list selection to assert the main map still uses `PeakClusterRingStyle.ownershipHybrid`. Use the same deterministic clustered setup and retrieve `PeakViewportPainter` from the `peak-marker-paint` `CustomPaint` key for style assertions.
5. Keep tests at the existing unit/widget split. Robot coverage is not required because this is a deterministic rendering-style selection with an established `CustomPaint` key test seam.

## Out of Scope

1. Redesigning peak ownership rings or changing peak-list colours.
2. Changing the definition or persistence of ticked/correlated peaks.
3. Changing clustering algorithms, cluster geometry, or hit-testing.
