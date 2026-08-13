---
type: Work Item
title: Render All Peaks Cluster Rings Proportionally
parent: ../spec.md
---

## What to build

On the main map, use `PeakClusterRingStyle.proportionalTickedUnticked` only while the active `PeakListSelectionMode` is `allPeaks`. The proportional ring must use `untickedColour` and `tickedColour`, with contiguous unticked then ticked arcs from the established top-of-ring start angle and sweeps derived from the cluster's current filtered members.

Preserve `PeakClusterRingStyle.ownershipHybrid` for a specific peak-list selection, including peak-list colour segments for unticked members and the standard ticked segment. Do not change individual peak-marker colours or rings, peak-list mini-map cluster rings, map navigation, selection persistence, filter controls, ticked/correlated peak persistence, clustering algorithms, cluster geometry, or hit-testing.

Add deterministic main-map widget regressions using in-memory nearby peaks, correlation IDs, `PeakVisibilityMode.showPeakClusters`, and a low-zoom camera:

- `All Peaks` with a mixed-status cluster retrieves `PeakViewportPainter` from the `peak-marker-paint` `CustomPaint` key and asserts `PeakClusterRingStyle.proportionalTickedUnticked`.
- Mixed, fully unticked, and fully ticked clusters retain the existing `peak_cluster_engine_test.dart` fraction coverage.
- An `All Peaks` cluster of at least three nearby peaks applies a rating, peak difficulty, or peak duration map metadata filter that removes one known member while leaving a cluster; the painter excludes that member and reports updated fractions.
- A specific-list selection retrieves the same painter and asserts `PeakClusterRingStyle.ownershipHybrid`.

Keep the existing unit/widget split. Robot coverage is not required.

## Required context

- `lib/screens/map_screen.dart` already passes `filteredPeaksProvider` output to `_PeakViewportInputs` and `PeakProjectionCache`; use the active `PeakListSelectionMode` only to choose the `MapScreenPeakLayer` style, without adding parallel counts or persistence state.
- `lib/screens/map_screen_peak_layer.dart` contains the `PeakClusterRingStyle` and `PeakViewportPainter` seam. `peak-marker-paint` is the stable `CustomPaint` key.
- `lib/services/peak_cluster_engine.dart` exposes `PeakCluster.untickedFraction` and `PeakCluster.tickedFraction`; retain the existing engine tests in `test/services/peak_cluster_engine_test.dart`.
- Follow deterministic main-map widget setup in `test/widget/map_screen_peak_cluster_toggle_test.dart` and metadata-filter interaction setup in `test/widget/map_screen_metadata_filter_test.dart`.
- The peak-list mini-map explicitly uses the proportional style in `lib/screens/peak_lists_screen.dart`; leave that behavior unchanged.

## Acceptance criteria

- [x] With `All Peaks` active on the main map, clustered rendering uses `PeakClusterRingStyle.proportionalTickedUnticked`; unticked members render with `untickedColour` and ticked members with `tickedColour`.
- [x] A mixed-status cluster renders contiguous unticked then ticked segments from the established top-of-ring start angle, proportionally to member counts; three unticked and one ticked member yields 75% unticked and 25% ticked sweeps.
- [x] A cluster with no ticked members renders a fully unticked ring, and one with no unticked members renders a fully ticked ring.
- [x] In `All Peaks`, rating, peak difficulty, and peak duration filtering affects the exact collection supplied to the cluster projection, so excluded peaks do not contribute to cluster members or fractions.
- [x] A deterministic main-map widget test retrieves `PeakViewportPainter` using `const Key('peak-marker-paint')` and verifies proportional style for an `All Peaks` mixed-status cluster.
- [x] A deterministic main-map widget test filters one member from an `All Peaks` cluster of at least three nearby peaks, keeps a cluster visible, and verifies the painter excludes that member and reports updated fractions.
- [x] A deterministic widget regression verifies a specific peak-list selection uses `PeakClusterRingStyle.ownershipHybrid`.
- [x] Existing `test/services/peak_cluster_engine_test.dart` coverage for mixed, fully unticked, and fully ticked fractions remains.
- [x] Individual peak-marker rendering, peak-list mini-map rings, map navigation, selection persistence, filter controls, ticked/correlated peak persistence, clustering, cluster geometry, and hit-testing are unchanged.
- [x] Relevant unit and widget tests pass without external services or API keys; robot coverage is not added.

## Covers

- User Stories: 1-2
- Requirements: 1-6
- Technical Decisions: 1-2
- Testing Strategy: 1-5
- Interview Ledger: L1-L2

## Blocked by

None - ready to start
