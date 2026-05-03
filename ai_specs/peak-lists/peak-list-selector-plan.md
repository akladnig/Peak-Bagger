## Overview

Replace peak toggle with peak-list selection drawer.
Thin slice first; then reactive list data; then persistence/reconciliation.

**Spec**: `ai_specs/peak-lists/peak-list-selector-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `widgets/`, `providers/`, `services/`, `models/`
- **State management**: Riverpod `NotifierProvider` + plain `Provider`
- **Reference implementations**: `lib/widgets/map_basemaps_drawer.dart`, `lib/providers/map_provider.dart`, `lib/screens/peak_lists_screen.dart`, `lib/providers/peak_list_provider.dart`
- **Assumptions/Gaps**: startup selection restore async after default state; repo error fallback = drawer shows `None`/`All Peaks`, map shows all peaks if `specificList` was active

## Plan

### Phase 1: Vertical Slice

- **Goal**: end-to-end selection path; no repository-backed list data yet
- [x] `lib/providers/map_provider.dart` - add `PeakListSelectionMode`, `EndDrawerMode`, derived `showPeaks`, `selectPeakList()`, drawer mode state
- [x] `lib/widgets/map_action_rail.dart` - rename FAB, route peaks/basemaps entry points through `endDrawerMode`
- [x] `lib/screens/map_screen.dart` - dynamic `endDrawer`; use filtered peaks for markers, hover, hit-testing; keep zoom gate
- [x] `lib/widgets/map_peak_lists_drawer.dart` - add drawer skeleton with `None` + `All Peaks`, stable keys, close-on-select
- [x] `lib/providers/peak_list_selection_provider.dart` - add pure `filteredPeaksProvider` for `none`/`allPeaks` path
- [x] TDD: `showPeaks` false only for `none`; `selectPeakList()` clears popup/hover on filter change; markers/hover use filtered peaks
- [x] TDD: peaks FAB opens peak-lists drawer; basemaps FAB + `B` reopen basemaps drawer; `None` hides peaks; `All Peaks` restores them
- [x] Robot journey tests + selectors/seams for drawer open/select `None`/`All Peaks`; preserve `Key('show-peaks-fab')`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Reactive Peak-List Drawer

- **Goal**: real list data; counts; error-safe drawer
- [x] `lib/providers/peak_list_selection_provider.dart` - add `peakListRevisionProvider`, `peakListsProvider`, repo error catch/log `[]`, `specificList` filtering
- [x] `lib/widgets/map_peak_lists_drawer.dart` - watch `peakListsProvider`; sort A-Z; skip invalid JSON lists; render count subtitles; selected checkmark
- [x] `lib/screens/map_screen.dart` - consume final `filteredPeaksProvider` behavior for `specificList` mode
- [x] TDD: `filteredPeaksProvider` returns matching peaks for valid list; returns all peaks on repo error during `specificList`; stays pure
- [x] TDD: drawer omits invalid JSON lists, shows `None`/`All Peaks` on repo error, renders renderable-count subtitles
- [x] Robot journey tests + selectors/seams for selecting a specific list and asserting only its peaks render
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Persistence And Mutation Reconciliation

- **Goal**: async startup restore; in-app mutation invalidation; stale-selection correction
- [ ] `lib/providers/map_provider.dart` - load/save selection prefs; add `reconcileSelectedPeakList()`; async startup reconciliation; normalize missing/corrupt saved list to `allPeaks`
- [ ] `lib/screens/peak_lists_screen.dart` - after delete/create/save, bump revision + call `reconcileSelectedPeakList()`
- [ ] `lib/widgets/peak_list_peak_dialog.dart` - after add/edit/remove, bump revision + reconcile; for partial-success multi-add, do one bump/reconcile if any add succeeded
- [ ] `lib/providers/peak_list_provider.dart` - inside `peakListImportRunnerProvider`, bump revision + reconcile after successful import result
- [ ] TDD: startup restores saved selection asynchronously; stale saved `specificList` normalizes to `allPeaks` and persists correction
- [ ] TDD: delete/edit/import/item mutation invalidates `peakListsProvider` and reconciles active selection
- [ ] Robot journey tests + selectors/seams for switching drawers, choosing a specific list, then verifying `None` clears popup/hover and mutation-driven fallback remains stable
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: async startup may briefly show default `allPeaks`; mutation hooks spread across UI/provider boundaries; repo-error fallback may mask stale `specificList` selection until recovery
- **Out of scope**: external ObjectBox change reactivity; pagination/virtualization for very large lists; redesign of peak-lists management screens beyond hooks/selectors needed for this feature
