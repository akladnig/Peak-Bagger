## Overview
My Lists rows: hover affordance + tap/click into `My Peak Lists`.
Small card seam, then widget proof, then dashboard journey.

**Spec**: `n/a` (request)

## Context
- **Structure**: feature-first (`lib/widgets/dashboard`, `lib/screens`, `test/...`)
- **State management**: Riverpod + GoRouter
- **Reference implementations**: `lib/widgets/dashboard/my_ascents_card.dart`, `lib/widgets/dashboard/my_lists_card.dart`, `test/widget/my_ascents_card_test.dart`, `test/robot/dashboard/dashboard_robot.dart`
- **Assumptions/Gaps**: row tap only needs to open `My Peak Lists`; no peak-list id handoff unless later requested

## Plan

### Phase 1: Row interaction

- **Goal**: hover cue + selectable rows
- [x] `lib/widgets/dashboard/my_lists_card.dart` - add row hover state; click cursor; tap target routes to `/peaks`; keep stable row keys
- [x] `test/widget/my_lists_card_test.dart` - TDD: hover border/background, row tap affordance, empty-state still stable
- [x] `test/widget/dashboard_screen_test.dart` - regression: dashboard shell still renders `My Lists` card unchanged
- [x] Verify: `flutter analyze && flutter test`

### Phase 2: Journey proof

- **Goal**: dashboard row tap reaches peak-lists screen
- [x] `test/robot/dashboard/dashboard_robot.dart` - add row hover/tap helpers for `my-lists`
- [x] `test/robot/dashboard/dashboard_journey_test.dart` - TDD: open dashboard, hover a row, tap it, assert `My Peak Lists` visible
- [x] `lib/router.dart` / `lib/screens/peak_lists_screen.dart` / `test/widget/peak_lists_screen_test.dart` - pass selected list id through `/peaks` and open it on entry
- [x] Verify: `flutter analyze && flutter test`

## Risks / Out of scope
- **Risks**: hover parity across mouse/touch; full `flutter test` still fails in unrelated `gpx_tracks_journey_test.dart`, `distance_card_test.dart`, and `peaks_bagged_card_test.dart`
- **Out of scope**: peak-list screen redesign, persisted selection state, deep-link params, data/model changes
