## Overview

Peak List Screen stale after list rename/update.
Make screen reactive to peak-list revision; keep selection/title in sync.

**Spec**: task description

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `widgets/`, `services/`
- **State management**: Riverpod `NotifierProvider` + derived `Provider`
- **Reference implementations**: `lib/providers/peak_list_selection_provider.dart`, `lib/widgets/dashboard/my_lists_card.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `test/providers/my_lists_summary_provider_test.dart`
- **Assumptions/Gaps**: rename path already persists peak-list changes; bug is missing UI invalidation on `PeakListsScreen`

## Plan

### Phase 1: Reactive list refresh

- **Goal**: Peak List Screen rebuilds on list mutation
- [x] `lib/screens/peak_lists_screen.dart` - watch `peakListsProvider` instead of raw repo snapshot; keep local selection logic unchanged
- [x] `lib/screens/peak_lists_screen.dart` - confirm selected summary row/title re-resolve from refreshed rows after name change
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: rename/update current list refreshes title and row label without switching away and back
- [x] `test/providers/my_lists_summary_provider_test.dart` - TDD: existing revision-based refresh contract stays aligned with screen behavior
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: in-place peak-list update/rename path shows new name immediately; selectors remain key-based
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: full suite has unrelated existing failures in gpx/tasmap/filter tests)

## Risks / Out of scope

- **Risks**: other direct repository reads may still be stale if not watched; rename flow might live outside current screen if hidden behind another dialog; full `flutter test` currently red on unrelated existing gpx/tasmap/filter tests
- **Out of scope**: persistence schema changes; map-selection reconciliation behavior; dashboard card changes
