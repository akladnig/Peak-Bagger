---
type: Work Item
title: Gate Main-Map Peak Work And Cover Hidden-Mode Journeys
parent: ../spec.md
---

## What to build

Update the main-map rendering and interaction path so `Peak visibility mode` drives clustered rendering, individual rendering, and hidden-mode early gating in `MapScreen` and related peak-layer seams. `Show Peak Clusters` must continue to use the clustered rendering path, `Show Peaks` must disable clustering so visible peaks render individually, and `Hide Peaks` must skip main-map peak marker rendering, cluster derivation, hover hit-testing, and equivalent peak-list-driven peak processing before that work occurs. Preserve the existing low-zoom contract below `MapConstants.peakMinZoom`, and add deterministic widget or robot journey coverage for hidden-mode restore behavior through the FAB, `Select Peak List`, and visible pinned app-bar chips.

## Required context

- `lib/screens/map_screen.dart` currently gates peak hover and hit testing through `mapState.showPeaks` plus `MapConstants.peakMinZoom`, and currently reads `peakMapClusterDisplaySettingsProvider` when building peak viewport data. Convert that path to the new `Peak visibility mode` seam and keep hidden-mode gating as early as practical.
- `lib/screens/map_screen_peak_layer.dart`, `lib/widgets/peak_marker_glyph.dart`, and related map rendering seams already distinguish marker and cluster layers. Reuse those existing observable layers and painter seams before introducing any new test seam.
- `lib/widgets/map_peak_lists_drawer.dart` and `lib/widgets/peak_list_selection_summary.dart` already expose the visible drawer-selection and `None` chip behavior that hidden mode must preserve.
- Relevant deterministic coverage already exists in `test/widget/map_screen_peak_cluster_toggle_test.dart`, `test/widget/map_peak_list_selection_test.dart`, `test/widget/tasmap_map_screen_test.dart`, and `test/robot/map/peak_list_pins_robot.dart`.
- Prefer existing fake repositories, provider overrides, and test harnesses. Add a focused deterministic `Test Seam` only if the current observable layers cannot prove the early hidden-mode gate.

## Acceptance criteria

- [ ] At or above `MapConstants.peakMinZoom`, `Show Peak Clusters` renders through the existing clustered main-map path, `Show Peaks` renders visible peaks with clustering disabled, and `Hide Peaks` renders no main-map peaks or clusters.
- [ ] While `Hide Peaks` is active, the main map skips peak marker rendering, cluster derivation, hover hit-testing, and equivalent peak-list-driven peak processing before that work would otherwise occur.
- [ ] Below `MapConstants.peakMinZoom`, `Show Peak Clusters` and `Show Peaks` still render no peaks or clusters, while the selected mode remains unchanged and the FAB tooltip, semantics, and icon continue to reflect the next action in the user's current `Peak visibility mode` cycle.
- [ ] When hidden mode clears the live selection state, the app-bar summary continues to show the existing `None` chip rather than a new hidden-only summary chip or a blank state.
- [ ] Selecting `All Peaks` or any specific peak list from the drawer while hidden restores `Show Peak Clusters` before showing peaks.
- [ ] Tapping a visible pinned app-bar peak-list chip while hidden restores `Show Peak Clusters` and selects that chip's peak list.
- [ ] Cycling the `Peak visibility mode` FAB out of hidden mode restores `Show Peak Clusters` and the remembered visible-region selection snapshot, or `All Peaks` when no snapshot exists.
- [ ] Deterministic widget or robot coverage proves the early hidden-mode gate, the drawer and pinned-chip restore journeys, the `None` chip behavior, and the low-zoom non-regression without live map tiles, live services, or secrets.

## Covers

- User Stories: 1-3
- Requirements: 6-14, 18-19
- Technical Decisions: 3-6
- Testing Strategy: 3, 5-6
- Interview Ledger: L2, L5-L7

## Blocked by

- 01-mapprovider-peak-visibility-mode-state-machine.md
- 02-map-rail-asset-and-settings-ui.md
