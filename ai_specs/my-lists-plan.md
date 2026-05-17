## Overview
My Lists dashboard card from peak-list progress.
Single derived Riverpod provider, compact table card, legacy slot migration.

**Spec**: `ai_specs/my-lists-spec.md`

## Context
- **Structure**: feature-first (`lib/services`, `lib/providers`, `lib/widgets/dashboard`, `lib/screens`)
- **State management**: Riverpod + synchronous ObjectBox-backed repos
- **Reference implementations**: `lib/screens/peak_lists_screen.dart`, `lib/widgets/dashboard/peaks_bagged_card.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/providers/peak_list_selection_provider.dart`
- **Assumptions/Gaps**: single derived provider watches peak-list + climb-data seam; `top-5-highest` migrates to `my-lists`; tests use in-memory deterministic fixtures

## Plan

### Phase 1: Summary pipeline

- **Goal**: ranked rows + reactive seam + layout migration
- [x] `lib/services/peak_list_summary_service.dart` - build ranked rows; unique peak counts; climbed/unclimbed; % climbed; top-5 cap; malformed payload skip
- [x] `lib/providers/my_lists_summary_provider.dart` - single derived provider; watch peak-list + climb-data seam; expose sync empty state
- [x] `lib/providers/dashboard_layout_provider.dart` - rename card id/title to `my-lists`; sanitize `top-5-highest` -> `my-lists`
- [x] `test/services/peak_list_summary_service_test.dart` - TDD: sort/tie-breaks, dedupe, zero peaks, malformed payloads, empty input
- [x] `test/providers/my_lists_summary_provider_test.dart` - TDD: reacts to list/climb changes; empty-state sync; deterministic seam
- [x] `test/providers/dashboard_layout_provider_test.dart` - TDD: default order, legacy-id migration, persisted order round trip
- [x] Verify: `flutter analyze && flutter test test/services/peak_list_summary_service_test.dart test/providers/my_lists_summary_provider_test.dart test/providers/dashboard_layout_provider_test.dart`

### Phase 2: Card wiring

- **Goal**: dashboard table UI + slot integration
- [ ] `lib/widgets/dashboard/my_lists_card.dart` - table UI; title; empty state; stable keys; no scroll
- [ ] `lib/screens/dashboard_screen.dart` - render `MyListsCard` in `my-lists`; preserve drag/reorder wiring
- [ ] `test/widget/my_lists_card_test.dart` - TDD: title, 5 columns, row rendering, cap-at-five, empty state, narrow/wide sanity
- [ ] `test/widget/dashboard_screen_test.dart` - TDD: `my-lists` slot visible; card order intact; drag handles intact; legacy id migrated
- [ ] `test/robot/dashboard/dashboard_robot.dart` - add selectors for `my-lists` card/root/table/rows
- [ ] Verify: `flutter analyze && flutter test test/widget/my_lists_card_test.dart test/widget/dashboard_screen_test.dart`

### Phase 3: Journey coverage

- **Goal**: end-to-end dashboard path with deterministic data
- [ ] `test/robot/dashboard/dashboard_journey_test.dart` - open dashboard; locate `My Lists`; verify top rows/columns; verify legacy order migration
- [ ] Update dashboard/widget robot fixtures - inject in-memory peak-list + climb-data providers/repositories; keep selectors stable
- [ ] Verify: `flutter analyze && flutter test test/robot/dashboard/dashboard_journey_test.dart`

## Risks / Out of scope

- **Risks**: legacy layout migration touches persisted order; card refresh seam may need a small provider refactor; row ranking logic must stay aligned with peak-list screen math
- **Out of scope**: editing/navigation controls; new cache/database; peak-list screen UX changes; loading spinner for this card; more than five rows
