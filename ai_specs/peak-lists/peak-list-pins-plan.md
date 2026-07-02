## Overview

Map-only peak-list app-bar row; per-region pins + bounds-derived visible-region union.
Follow existing Riverpod/shared-app-bar patterns; replace center-based region logic.

**Spec**: `ai_specs/peak-lists/peak-list-pins-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `widgets/`, `providers/`, `services/`, `test/`
- **State management**: Riverpod `Notifier` + derived `Provider`
- **Reference implementations**: `lib/widgets/map_peak_lists_drawer.dart`, `lib/widgets/peak_list_selection_summary.dart`, `test/widget/map_peak_list_selection_test.dart`
- **Assumptions/Gaps**: non-map right lane = empty placeholder; keep `Key('peak-list-selection-summary')` on map-route replacement row only

## Plan

### Phase 1: Vertical Slice

- **Goal**: map-route interactive row; pinned-state core; selector continuity
- [x] `pubspec.yaml` - declare `assets/svg/pin.svg`, `assets/svg/unpin.svg`
- [x] `lib/services/peak_list_visibility.dart` - add normalized visible-region `Set<String>` helper(s); extend single-region filters to union-aware variants
- [x] `lib/providers/map_provider.dart` - add per-region pinned ids + prefs encode/decode + basic pin/unpin mutations; keep selection independent
- [x] `lib/providers/peak_list_selection_provider.dart` - derive map-route row model from selected ids + pinned ids + labels + visible-region set
- [x] `lib/widgets/peak_list_selection_summary.dart` - repurpose to interactive map-route row; keep root `Key('peak-list-selection-summary')`
- [x] `lib/router.dart` - map route uses interactive row; non-map routes use empty right-lane placeholder
- [x] TDD: pin/unpin persists per-region ids without mutating `selectedPeakListIds`
- [x] TDD: map-route row renders selected transient list + pinned list; non-map routes omit row container
- [x] TDD: `peak-list-selection-summary` root key remains on map route only
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Bounds Semantics

- **Goal**: zero-region/multi-region correctness; reconcile via visible bounds
- [x] `lib/providers/map_provider.dart` - trigger visible-region updates from `updateVisibleBounds`; bounds-based reconcile rules: zero => skip prune, multi => union prune
- [x] `lib/widgets/map_peak_lists_drawer.dart` - swap `state.center` region lookup for visible-region-set filtering; union visible lists; zero-region empty state
- [x] `lib/providers/peak_list_selection_provider.dart` - `All Peaks`/`None` chips + pinned union + zero-region hide rules
- [x] `test/providers/map_peak_list_selection_state_test.dart` - cover zero/multi-region reconcile behavior
- [x] `test/providers/map_peak_list_selection_persistence_test.dart` - cover pinned prefs restore/corrupt payload path
- [x] `test/widget/map_peak_list_selection_test.dart` - cover zero-region hidden row, multi-region union row, constrained-width layout
- [x] TDD: visible-bounds helper returns normalized region sets; multi-region union includes all applicable lists
- [x] TDD: zero visible regions hides map-route right-lane peak-list UI and preserves in-memory state
- [x] TDD: reconcile prunes against visible union only; zero-region never forces fallback mode
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Drawer Actions + Journeys

- **Goal**: split drawer actions; full map journey coverage
- [x] `lib/widgets/drawer_outline_button.dart` - extend only if needed for trailing action slot without breaking existing drawer styling
- [x] `lib/widgets/map_peak_lists_drawer.dart` - add trailing pin action + stable keys; preserve existing list-button keys
- [x] `lib/widgets/peak_list_selection_summary.dart` - add app-bar pin/unpin/toggle controls + stable keys + width-safe scroll behavior
- [x] `test/widget/map_screen_peak_info_test.dart` - cover drawer filtering against visible-region-set rules
- [x] `test/robot/map/peak_list_pins_robot.dart` - helpers: open drawer, pin, toggle, unpin, set visible bounds deterministically
- [x] `test/robot/map/peak_list_pins_journey_test.dart` - critical flows: select, transient app-bar row, pin, deselect while visible, multi-region union, zero-region hide, return, unpin
- [x] TDD: drawer main tap toggles selection; trailing tap pins only
- [x] TDD: pinned deselect stays visible; unpinned deselect disappears
- [x] TDD: robot journey one assertion slice at a time; selectors + deterministic bounds seam
- [x] Robot journey tests + selectors/seams for critical flows
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: shared app-bar centering regression; visible-bounds updates may fire often; union filtering may require helper/API reshaping across provider/service tests
- **Out of scope**: peak filtering algorithm changes beyond region-source swap; non-map peak-list UI redesign; legacy pin-data migration
