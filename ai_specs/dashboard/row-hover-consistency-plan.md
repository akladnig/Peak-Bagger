## Overview
Unify row hover/cursor behavior.
Match `My Lists` to `My Ascents`; extend same affordance to `My Peak Lists` summary + detail rows.

**Spec**: `n/a` (request)

## Context
- **Structure**: feature-first (`lib/widgets/dashboard`, `lib/screens`, `test/...`)
- **State management**: Riverpod + Material
- **Reference implementations**: `lib/widgets/dashboard/my_ascents_card.dart`, `lib/widgets/dashboard/my_lists_card.dart`, `lib/screens/peak_lists_screen.dart`, `lib/theme.dart`
- **Assumptions/Gaps**: keep selection/tap semantics unchanged; only cursor/hover surface consistency

## Plan

### Phase 1: Row primitive parity

- **Goal**: one hover/cursor pattern across row surfaces
- [x] `lib/widgets/dashboard/my_lists_card.dart` - switch to `InkWell`-driven hover/cursor pattern; keep `RowHoverTheme`; preserve tap nav to `My Peak Lists`
- [x] `lib/screens/peak_lists_screen.dart` - add same cursor/hover treatment to peak-list summary rows and peak-detail rows; keep selected-row decoration intact
- [x] `test/widget/my_lists_card_test.dart` - TDD: cursor + hover theme on row; table layout unchanged
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: summary rows and peak rows show hover/click affordance; selection still works
- [ ] Verify: `flutter analyze && flutter test` (analyze passes; full test suite still has unrelated failures)

### Phase 2: Journey regression

- **Goal**: row affordance change does not break dashboard flow
- [x] `test/robot/dashboard/dashboard_journey_test.dart` - regression: row tap still opens selected peak list
- [x] `test/robot/dashboard/dashboard_robot.dart` - add/adjust selectors only if needed for stable row targeting
- [ ] Verify: `flutter analyze && flutter test` (full test suite still has unrelated failures)

## Risks / Out of scope
- **Risks**: peak-lists row hover may need small layout tuning; desktop mouse behavior can differ from touch
- **Out of scope**: selection model changes, navigation changes, theme redesign, data/model work
