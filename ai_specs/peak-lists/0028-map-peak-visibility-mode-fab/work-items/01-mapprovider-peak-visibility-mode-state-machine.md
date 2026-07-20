---
type: Work Item
title: Add MapProvider Peak Visibility Mode State Machine
parent: ../spec.md
---

## What to build

Add explicit `Peak visibility mode` state to the map-owned seam in `mapProvider` so the main map no longer depends on `peakMapClusterDisplaySettingsProvider` to decide between `Show Peak Clusters`, `Show Peaks`, and `Hide Peaks`. The provider slice must own the exact cycle order, fresh-entry default `Show Peak Clusters`, hidden-mode transient behavior, restore-to-clusters behavior when the user selects `All Peaks` or a specific peak list while hidden, restore-to-clusters behavior when the user taps a visible pinned app-bar chip while hidden, and restore of the remembered visible-region snapshot or `All Peaks` fallback when cycling the FAB out of hidden mode. Preserve the existing remembered per-region peak-list selection contract behind the scenes, do not persist `Hide Peaks` across fresh map reopen, and keep unrelated clustering settings such as peak-list mini-map clustering unchanged.

## Required context

- `lib/providers/map_provider.dart` already owns `Map` state, visible-region snapshot persistence, `PeakListSelectionMode`, drawer actions, pinned peak-list actions, and the `Show Map Grid` state-machine pattern. Extend that seam rather than splitting `Peak visibility mode` across another provider.
- `lib/providers/peak_map_cluster_display_settings_provider.dart` is currently persisted `SharedPreferences` state for the main-map cluster toggle. This Work Item retires it as a main-map source of truth, but does not change `Peak list mini-map` clustering behavior.
- `lib/providers/peak_list_selection_provider.dart` already derives the app-bar summary, `None` chip, and drawer selection state from `mapProvider`. Reuse those existing selection and summary semantics instead of inventing a hidden-only surface.
- Existing deterministic persistence and selection coverage already lives in `test/providers/map_peak_list_selection_persistence_test.dart`, `test/providers/map_peak_list_selection_state_test.dart`, and `test/providers/peak_map_cluster_display_settings_provider_test.dart`.

## Acceptance criteria

- [ ] `mapProvider` owns one explicit `Peak visibility mode` state machine for the main map, and that state cycles exactly `Show Peak Clusters` -> `Show Peaks` -> `Hide Peaks` -> `Show Peak Clusters`.
- [ ] A fresh `Map` entry defaults to `Show Peak Clusters` even when peak-list selection state is later reconciled from the existing remembered visible-region snapshot path.
- [ ] Entering `Hide Peaks` clears only the live on-screen peak-list selection state for the current map session, causing the existing `None` summary path to become active without erasing or overwriting remembered per-region peak-list selection data.
- [ ] While hidden, opening `Select Peak List` keeps drawer selections visually cleared until the user explicitly chooses `All Peaks` or a specific peak list; opening the drawer alone does not restore remembered selection.
- [ ] Selecting `All Peaks` or any specific peak list from `Select Peak List` while hidden automatically switches `Peak visibility mode` back to `Show Peak Clusters` before peaks are shown.
- [ ] Tapping a visible pinned app-bar peak-list chip while hidden automatically switches `Peak visibility mode` back to `Show Peak Clusters` and selects that tapped list.
- [ ] Cycling the `Peak visibility mode` FAB out of `Hide Peaks` automatically returns to `Show Peak Clusters` and restores the remembered visible-region selection snapshot, falling back to `All Peaks` when no snapshot exists for the current visible region.
- [ ] The implementation does not persist `Hide Peaks` across map reopen and does not write hidden or live-cleared state into the remembered visible-region snapshot store.
- [ ] Unrelated clustering settings, including `Show Peak List Mini-Map Clusters`, remain separately persisted and behaviorally unchanged.
- [ ] Deterministic provider or notifier coverage proves the exact cycle order, default state, hidden-mode restore paths, remembered-selection preservation, `All Peaks` fallback, and non-persistence of hidden mode without requiring live services or secrets.

## Covers

- User Stories: 1-3
- Requirements: 1, 3-14, 18-19
- Technical Decisions: 1-6
- Testing Strategy: 1
- Interview Ledger: L1-L7

## Blocked by

None - ready to start
