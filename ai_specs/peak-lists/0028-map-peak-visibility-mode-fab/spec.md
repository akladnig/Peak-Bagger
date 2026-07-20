---
type: Spec
title: Map Peak Visibility Mode FAB
---

## Problem

`MapScreen` currently splits main-map peak behavior across two different controls: the map rail's `Select Peak List` drawer entry and a separate Settings switch `Show Map Peak Clusters`. That split creates conflicting sources of truth for whether the main map shows clustered peaks, individual peaks, or no peaks at all. The current rail also still uses the old peak icon on the drawer FAB, even though that FAB now opens peak-list selection rather than controlling peak visibility directly. The feature needs one explicit map-local `Peak visibility mode` control, exact user-facing copy and icons for each state, and preserved behavior for existing peak-list selection memory and low-zoom gating. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## Proposed Outcome

`MapScreen` gains a dedicated `Peaks` FAB above `Select Peak List` in the `View` rail group. That new FAB is the sole source of truth for main-map peak visibility and cycles exactly through `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`, using the same single-tap state-machine style as `Show Map Grid`. The separate Settings switch `Show Map Peak Clusters` is removed. `Select Peak List` remains a separate drawer-opening control with `Icons.collections`. Hiding peaks clears only the live peak-list selection UI, preserves remembered per-region selection state, shows the existing `None` chip, and suppresses peak rendering and processing until the user either cycles the visibility FAB again or selects a peak list. Exiting hidden mode through the FAB restores the remembered selection snapshot for the current visible region, falling back to `All Peaks` when no snapshot exists, and returns to the default visible state `Show Peak Clusters`. Selecting a peak list from the drawer or from a visible pinned app-bar chip while hidden also returns to `Show Peak Clusters`. The current low-zoom hide contract remains unchanged. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## User Stories

1. As a map user, I can cycle one dedicated `Peaks` control between clustered peaks, individual peaks, and hidden peaks without relying on a separate Settings switch. [L1] [L2] [L3]
2. As a peak-list user, I can keep using `Select Peak List` as a separate drawer action, and choosing a list while peaks are hidden restores the default visible clustered state automatically. [L2] [L3]
3. As a returning user, I get the new default `Show Peak Clusters` behavior on map entry without losing the app's remembered per-region peak-list selection state. [L1] [L5] [L6] [L7]

## Requirements

1. Use `Peak visibility mode` as the canonical term for the new main-map three-state peak display control. It refers only to the main-map control that chooses between hidden peaks, individual peak markers, and peak clusters. Do not use `Show Map Peak Clusters` as an ongoing settings term for this behavior. [L1]
2. Add a new small FAB in `lib/widgets/map_action_rail.dart` above the existing `Select Peak List` FAB in the `View` group. The control is icon-only and follows the existing left-tooltip FAB pattern used elsewhere in the rail.
3. The new `Peak visibility mode` FAB is the sole source of truth for main-map peak visibility and clustering. Remove the Settings screen row and persisted switch `Show Map Peak Clusters` so the main map no longer has two competing controls for the same behavior. [L1]
4. The new FAB cycles on each tap exactly as follows: `Show Peak Clusters` -> `Show Peaks` -> `Hide Peaks` -> `Show Peak Clusters`. Match the interaction style of `Show Map Grid`: one tap advances one state, and the tooltip, semantics, and icon update immediately to the next action the tap will perform. [L1] [L3]
5. The default `Peak visibility mode` on a fresh map entry is `Show Peak Clusters`. This default applies even when the app later restores remembered peak-list selection context. [L1] [L5]
6. `Show Peak Clusters` renders main-map peaks using the existing clustered rendering path. `Show Peaks` renders main-map peaks with clustering disabled so visible peaks render individually. `Hide Peaks` renders no main-map peaks or clusters. [L1] [L2]
7. While `Hide Peaks` is active, the app must not perform main-map peak marker rendering, cluster derivation, hover hit-testing, or equivalent peak-list-driven peak processing for the main map. Hidden mode is an early gate, not just a cosmetic hide-after-processing step. [L2]
8. When the user activates `Hide Peaks`, clear live peak-list selection UI immediately:
   - the app-bar peak-list chips become unselected;
   - the peak-list drawer selections become unselected;
   - the app-bar summary shows the existing `None` chip.
   Do not introduce a separate hidden-only summary chip or blank summary state. [L2] [L6]
9. `Hide Peaks` must not erase or overwrite the app's remembered per-region peak-list selection data behind the scenes. It only clears the live on-screen selection state for the current map session. [L5]
10. While `Hide Peaks` is active, opening `Select Peak List` must keep the live selection UI cleared until the user explicitly chooses `All Peaks` or a specific peak list. Opening the drawer alone must not auto-restore the remembered selection state. [L2] [L5] [L6]
11. `Hide Peaks` is not persisted across map reopen. A fresh map entry always starts in `Show Peak Clusters`, then the app continues to use its normal remembered peak-list selection behavior for the current region. [L5]
12. If the user cycles the `Peak visibility mode` FAB out of `Hide Peaks`, the map must automatically switch back to `Show Peak Clusters` and restore the remembered peak-list selection snapshot for the current visible region. If no remembered snapshot exists for the current visible region, restore `All Peaks`. [L1] [L2] [L5]
13. If the user selects `All Peaks` or any specific peak list from `Select Peak List` while `Hide Peaks` is active, the map must automatically switch the `Peak visibility mode` back to `Show Peak Clusters` before showing peaks. [L2]
14. If the user taps a visible pinned app-bar peak-list chip while `Hide Peaks` is active, the map must automatically switch the `Peak visibility mode` back to `Show Peak Clusters` and select that tapped peak list. [L2] [L5] [L6]
15. Keep `Select Peak List` as a separate drawer-opening control. Its tooltip and semantics label remain exactly `Select Peak List`, and its icon changes to `Icons.collections`. [L3]
16. The `Peak visibility mode` FAB uses these exact tooltip and semantics strings:
   - `Show Peak Clusters`
   - `Show Peaks`
   - `Hide Peaks`
   No persistent text label is shown on the FAB itself. [L3]
17. The `Peak visibility mode` FAB uses these icons by state:
   - `Show Peaks`: `Icons.landscape`
   - `Hide Peaks`: a custom slashed landscape SVG asset saved under `assets/svg`
   - `Show Peak Clusters`: the same icon used by the Settings-screen `Show Peak Ownership Rings` control
   Keep icon colour treatment aligned with the current FAB icon colour contract. [L4]
18. Preserve the existing low-zoom hide rule. Below `MapConstants.peakMinZoom`, `Show Peak Clusters` and `Show Peaks` still render no peaks or clusters; only the selected mode, tooltip, and semantics change. The chosen mode takes visible effect only at or above the existing peak minimum zoom threshold. [L7]
19. This feature must preserve the existing `Select Peak List` drawer behavior, peak-list memory behavior, and low-zoom threshold everywhere this Spec does not explicitly change them. In particular, it must not redesign the app-bar chip system, remove the `None` chip, or rewrite the remembered per-region selection model. [L5] [L6] [L7]

## Technical Decisions

1. Reuse the existing map-owned Flutter state seam in `mapProvider` for the new three-state `Peak visibility mode` rather than continuing to split control between `mapProvider` and `peakMapClusterDisplaySettingsProvider`. The main-map cluster settings provider and its Settings-screen tile should be retired for the main map. Preserve unrelated clustering settings such as peak-list mini-map clustering unless explicitly changed elsewhere. [L1]
2. Model `Peak visibility mode` as an explicit state machine parallel to the existing grid-FAB state machine, with one current state that drives render gating and cluster enablement while the FAB tooltip, semantics, and icon surface the next action in the cycle. Avoid inferring mode indirectly from existing peak-list selection or cluster-setting booleans. [L1] [L2] [L3]
3. `Hide Peaks` is a transient map-session visibility state, not a replacement for the existing remembered per-region peak-list selection model. Entering hidden mode must not write a hidden or `none` state into remembered visible-region snapshots, and exiting hidden mode through the FAB should restore the normal remembered snapshot path for the current visible region. [L2] [L5]
4. Hidden mode should gate peak work as early as practical in the main-map rendering and interaction path so hover, clustering, and related peak processing are skipped instead of performed and then discarded. [L2]
5. Keep the existing remembered peak-list selection persistence contract as-is. Do not persist `Hide Peaks` across map reopen for this feature; use the new default `Show Peak Clusters` on fresh map entry instead. [L5]
6. Reuse existing peak-list summary and drawer-selection seams, including the current `None` chip behavior, instead of inventing a new hidden-state summary surface. [L6]
7. Bundle the custom slashed landscape icon as an app-owned SVG asset under `assets/svg` and register it in `pubspec.yaml` so the `Hide Peaks` state is deterministic and testable. [L4]

## Testing Strategy

1. Add provider or notifier coverage for the `Peak visibility mode` state machine: exact cycle order, default state, auto-restore to `Show Peak Clusters` on peak-list selection from hidden mode, auto-restore to `Show Peak Clusters` on pinned app-bar chip selection from hidden mode, restore of the remembered visible-region selection snapshot or `All Peaks` fallback when cycling the FAB out of hidden mode, preservation of remembered per-region selection state, and non-persistence of hidden mode across fresh map entry. [L1] [L2] [L5]
2. Extend map widget coverage for `lib/widgets/map_action_rail.dart` and related map-screen tests to assert the new FAB ordering, exact tooltip and semantics strings, icon contract, `Select Peak List` icon change, and the continued presence of the existing `None` chip when hidden mode clears live selection. [L3] [L4] [L6]
3. Add deterministic widget or robot journey coverage proving that `Hide Peaks` suppresses main-map peak rendering and gates main-map peak processing before visible rendering or interactivity occurs, selecting a peak list from hidden mode restores `Show Peak Clusters`, tapping a visible pinned app-bar chip from hidden mode restores `Show Peak Clusters` and that chip's list, cycling the visibility FAB out of hidden mode restores the remembered visible-region selection snapshot or `All Peaks` fallback, and the low-zoom hide rule still suppresses visible peaks regardless of current visibility mode. Use existing observable seams where sufficient, and add a focused deterministic Test Seam only if needed to prove the early gate. [L2] [L5] [L7]
4. Add Settings-screen non-regression coverage proving `Show Map Peak Clusters` no longer appears, while unrelated settings such as `Show Peak Ownership Rings` and peak-list mini-map clustering remain available. [L1] [L4]
5. Preserve existing stable selectors where they already anchor current map tests, including `Key('show-peaks-fab')` for the `Select Peak List` drawer control. Add one new stable selector for the new `Peak visibility mode` FAB so widget and robot coverage can target it directly without relying on tooltip text alone.
6. Prefer existing fake repositories, provider overrides, and deterministic widget seams. Automated coverage for this feature must not require live services, map tiles, or secrets.

## Out of Scope

1. Redesigning peak-list mini-map clustering or its Settings control.
2. Changing the remembered per-region peak-list selection model beyond how hidden mode temporarily clears only the live on-screen state. [L5]
3. Changing the existing peak minimum zoom threshold or making low-zoom peaks visible. [L7]
4. Redesigning app-bar peak-list chips beyond continuing to use the existing `None` chip when live selection is cleared. [L6]

## Notes

1. Relevant implementation surfaces are likely `lib/widgets/map_action_rail.dart`, `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `lib/screens/settings_screen.dart`, `lib/providers/peak_map_cluster_display_settings_provider.dart`, `lib/widgets/map_peak_lists_drawer.dart`, `lib/widgets/peak_list_selection_summary.dart`, related peak-list selection providers, `pubspec.yaml`, and map/settings tests.
2. `GLOSSARY.md` now defines `Peak visibility mode` as the canonical term for this feature.
