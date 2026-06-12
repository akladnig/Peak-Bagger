## Overview

Peak-list drawer scoped to current renderable map peaks.
Hide zero-match + malformed lists; if none qualify, leave `All Peaks`; prevent hidden active filters.

**Spec**: `task description` (quick plan; no spec file)

## Context

- **Structure**: feature-first map UI under `lib/widgets`; selection state in `lib/providers`
- **State management**: Riverpod `Notifier` + derived `Provider`
- **Reference implementations**: `lib/widgets/map_peak_lists_drawer.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/providers/map_provider.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/providers/map_peak_list_selection_state_test.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: “current map view” maps to current renderable `MapState.peaks`, not literal camera-frustum geometry; if a selected list leaves scope, prune hidden ids and fall back to `All Peaks` when none remain

## Plan

### Phase 1: Drawer visibility contract

- **Goal**: fail on zero-renderable/malformed rows; keep `All Peaks` fallback
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: drawer shows only decodable lists with `renderableCount > 0`; hides malformed + zero-match lists; when none qualify, only `peak-list-item-All Peaks` remains
- [x] `lib/widgets/map_peak_lists_drawer.dart` - filter drawer rows to positive renderable counts before sort/render; keep repository-failure message path unchanged
- [x] `lib/services/peak_list_visibility.dart` - shared renderable-count helper for drawer + future selection logic
- [x] `test/providers/peak_list_selection_provider_test.dart` - TDD: if a shared visibility helper is introduced, cover valid-list derivation from `state.peaks` + stored lists
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_peak_info_test.dart test/providers/peak_list_selection_provider_test.dart`

### Phase 2: Selection reconciliation

- **Goal**: no hidden active filters after map dataset/view changes
- [x] `test/providers/map_peak_list_selection_state_test.dart` - TDD: selected ids prune to still-renderable valid lists; when none remain, selection falls back to `PeakListSelectionMode.allPeaks`
- [x] `lib/providers/map_provider.dart` - extend selection reconcile path to consider current renderable peaks, not just decode validity; run it after peak reload/refresh paths that replace `state.peaks`
- [x] `lib/providers/peak_list_selection_provider.dart` - not needed; helper shared via `lib/services/peak_list_visibility.dart`
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - robot journey tests + selectors/seams for critical flow: open peaks drawer, confirm off-scope list row absent, `All Peaks` still selectable, hidden selection cannot strand the map empty
- [x] Verify: `flutter analyze` && `flutter test test/providers/map_peak_list_selection_state_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

## Risks / Out of scope

- **Risks**: `MapState.peaks` may represent loaded region, not live camera viewport; fallback mode choice (`allPeaks` vs `none`) changes current UX; helper extraction can sprawl if overdesigned
- **Out of scope**: peak-list data migration, new drawer copy/empty-state UI, literal on-screen geometry filtering beyond the current renderable peak set
