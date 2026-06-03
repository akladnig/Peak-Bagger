## Overview

Multi-select peak-list filtering in map drawer; route-global chip strip in shared app bar.
Approach: thin state slice first, then drawer UI, then shell chrome + robot coverage.

**Spec**: `ai_specs/peak-list-selection-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-by-area; map state in `lib/providers/map_provider.dart`, drawer widgets in `lib/widgets/`, shell chrome in `lib/router.dart`
- **State management**: Riverpod `Notifier`; `MapNotifier` owns peak-list mode/persistence, provider layer derives filtered peaks and summaries
- **Reference implementations**: `lib/widgets/map_tracks_routes_drawer.dart`, `lib/widgets/map_peak_lists_drawer.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/providers/map_peak_list_selection_persistence_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: use new `*_v2` prefs only; add failure-aware peak-list loading seam near `peakListsProvider`; keep chip strip read-only and app-wide via shared `AppBar.actions`

## Plan

### Phase 1: State Contract + Persistence Slice

- **Goal**: thin end-to-end state path; new mode/set contract, v2 prefs, filtered peaks stay honest
- [x] `lib/providers/map_provider.dart` - replace `selectedPeakListId` active contract with `selectedPeakListIds` + `previousSpecificPeakListIds`; keep `PeakListSelectionMode.none|allPeaks|specificList`
- [x] `lib/providers/map_provider.dart` - add immutable copy-on-write set updates, `All Peaks` snapshot rules, `none` transition on last switch off
- [x] `lib/providers/map_provider.dart` - load/save `peak_list_selection_mode_v2`, `peak_list_selected_ids_v2`, `peak_list_previous_specific_ids_v2`; ignore legacy single-id keys; recover from corrupt v2 payloads; serialize writes last-write-wins
- [x] `lib/providers/peak_list_selection_provider.dart` - replace single-id filtering with multi-id union filtering; dedupe by peak id; preserve `state.peaks` order
- [x] `test/providers/map_peak_list_selection_persistence_test.dart` - rewrite around v2 prefs, corrupt payload reset, legacy-key ignore, camera-pref non-regression
- [x] `test/providers/peak_list_selection_provider_test.dart` - extend for multi-select union, `none`, missing-id cleanup, decode-error skip behavior
- [x] TDD: first launch defaults to `allPeaks`; turning off all specific switches yields `none`
- [x] TDD: `All Peaks` on captures non-empty specific set; off restores remembered set or stays `allPeaks`
- [x] TDD: rapid toggle persistence saves final v2 state only; corrupt v2 payload resets to defaults
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Failure-Aware List Loading + Drawer UI

- **Goal**: working multi-select drawer; decodable lists visible; failure state non-destructive
- [x] `lib/providers/peak_list_selection_provider.dart` - add failure-aware list-loading seam/status object so success-empty and repository-failure diverge cleanly
- [x] `lib/widgets/map_peak_lists_drawer.dart` - convert single-select tiles to switch rows with `IgnorePointer` + row tap parity; keep drawer open on toggle
- [x] `lib/widgets/map_peak_lists_drawer.dart` - remove `None` row; add `All Peaks` master row/switch; show all decodable lists including `0 renderable peaks`; skip malformed lists only
- [x] `lib/widgets/map_peak_lists_drawer.dart` - show unavailable message + `All Peaks` control on repository failure; add required stable keys
- [x] `test/widget/map_screen_peak_info_test.dart` - migrate drawer assertions from old `None` tile / name keys to switch-row keys and open-drawer persistence behavior
- [x] `test/providers/map_peak_list_selection_persistence_test.dart` - cover repository-failure preservation / no destructive normalization path if provider seam lives here
- [x] TDD: drawer shows zero-renderable-count decodable rows, malformed rows skipped
- [x] TDD: toggling a specific list while `All Peaks` is active exits `All Peaks` and updates remembered snapshot
- [ ] TDD: repository failure keeps active selection/chips intact and shows `Key('peak-list-selection-unavailable-message')`
  Blocker: chip-strip assertions land with Phase 3 app-bar work; Phase 2 covers selection preservation state and unavailable-message drawer behavior only.
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: App-Bar Chip Strip + Journey Coverage

- **Goal**: route-global summary strip; selectors stable; critical user flow proven
- [ ] `lib/providers/peak_list_selection_provider.dart` - expose summary model for chip strip with rendered-label ordering and fallback labels like `List #<id>`
- [ ] `lib/router.dart` - add read-only chip strip immediately before `Key('app-bar-theme-action')`; preserve theme toggle visibility with horizontal scrolling
- [ ] `lib/widgets/peak_list_selection_summary.dart` - optional small presentation-only chip-strip widget if `router.dart` becomes crowded
- [ ] `test/widget/map_peak_list_selection_test.dart` - add focused shell-chip coverage if extending `map_screen_peak_info_test.dart` becomes noisy
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add key-first helpers for new drawer rows/switches, chip strip, unavailable message
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - extend journey for multi-select, `All Peaks`, restore previous set, `none`, chip-strip sync across route changes
- [ ] TDD: chip strip always exists; `allPeaks` and `none` show exactly one chip; `specificList` shows one chip per selected list
- [ ] TDD: chip ordering uses rendered label; unresolved labels fall back deterministically without stale chips after normalization
- [ ] Robot journey tests + selectors/seams for critical flows
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `MapState` contract change touches many tests; failure-aware list seam can sprawl if not kept local; app-bar action layout may regress on narrow desktop widths
- **Out of scope**: ObjectBox/schema work; interactive chip actions; new global navigation surfaces; migration of legacy single-id peak-list prefs
