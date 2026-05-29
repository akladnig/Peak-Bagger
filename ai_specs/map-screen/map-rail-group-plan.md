## Overview
Grouped map action rail; same behavior, clearer sections, stable selectors.

**Spec**: `ai_specs/map-rail-group.md` (read this file for full requirements)

## Context

- **Structure**: layer-first
- **State management**: Riverpod (`ConsumerWidget`/`Notifier`)
- **Reference implementations**: `lib/widgets/map_action_rail.dart`, `lib/widgets/left_tooltip_fab.dart`, `test/widget/map_screen_rebuild_test.dart`, `test/robot/tasmap/tasmap_robot.dart`, `test/widget/tasmap_display_mode_test.dart`
- **Assumptions/Gaps**: `screenshot.png` is the visual source of truth for section styling; no other product gaps block implementation

## Plan

### Phase 1: Rail shell

- **Goal**: thin end-to-end slice; grouped rail renders, selectors stable, rebuild boundary preserved
- [ ] `lib/widgets/map_action_rail.dart` - split rail into pure section builders; top-right Tools/View/Loc; bottom-right Info; stable group keys; keep existing FAB keys/heroTags; use `assets/route.svg` for create-route placeholder; update tooltip/semantics copy to spec wording; use `UiConstants.groupSpacing` between sections
- [ ] `pubspec.yaml` - add `assets/route.svg` to bundled assets
- [ ] `test/widget/map_screen_rebuild_test.dart` - keep `MapRebuildDebugCounters.actionRailBuilds` unchanged during drag
- [ ] `test/widget/map_action_rail_grouping_test.dart` - group order, `create-route-fab` inert, Info separate, icon-only copy, route SVG rendered
- [ ] `test/robot/tasmap/tasmap_robot.dart` - add group + placeholder finders
- [ ] `test/robot/tasmap/tasmap_journey_test.dart` - critical map-screen journey: open map, assert groups, tap representative actions, verify placeholder inert
- [ ] TDD: rail order + icon-only copy + placeholder + rebuild counter, one red/green at a time
- [ ] Robot journey tests + selectors/seams for grouped rail critical flow
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Accessibility + fit

- **Goal**: focus order, compact-height fit, screenshot styling
- [ ] `lib/widgets/map_action_rail.dart` - explicit traversal/sort keys; safe-area/inset handling for bottom-right Info; scroll if needed on short screens
- [ ] `test/widget/map_screen_keyboard_test.dart` - focus/semantics order, no keyboard regression
- [ ] `test/widget/map_action_rail_grouping_test.dart` - compact-height scroll/no clip, section headers plain text, screenshot-matched styling, `groupSpacing` is preserved
- [ ] TDD: focus order + overflow/scroll + safe-area behavior
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: bottom-right Info vs compact-height overlays; focus order after split; stale tooltip/semantics copy
- **Out of scope**: real route creation; map/provider behavior changes; broader map screen redesign
