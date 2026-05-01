## Overview
Rework `PeakListsScreen` into one pinned, wide-body layout: left summary + mini-map, right details + table.
Keep import/delete/selection behavior; add table-local horizontal scroll and stable selectors.

**Spec**: `ai_specs/011-pl-ui-updates-spec.md` (read this file for full requirements)

## Context

- **Structure**: screen-first; widget-test companion
- **State management**: Riverpod (`ConsumerStatefulWidget`, provider-backed repositories/services)
- **Reference implementations**: `lib/screens/peak_lists_screen.dart`, `lib/widgets/map_action_rail.dart`, `lib/widgets/left_tooltip_fab.dart`, `test/robot/peaks/peak_lists_robot.dart`
- **Assumptions/Gaps**: none material; `588px` minimum supported `PeakListsScreen` body width; add viewport keys if distinct from panes

## Plan

### Phase 1: Pinned shell

- **Goal**: replace divider shell; pin toolbar/import; keep current selection/import flow
- [ ] `lib/screens/peak_lists_screen.dart` - replace outer `Row`/divider with pinned left column + right details/table; keep import wiring, selection state, delete flow; add stable keys for pane regions and mini-map
- [ ] `test/widget/peak_lists_screen_test.dart` - TDD: 588px body render, no divider, pinned toolbar, import button in toolbar, selected title preserved, empty-state shell stable
- [ ] `test/robot/peaks/peak_lists_robot.dart` - update selectors for preserved pane keys and any new viewport keys
- [ ] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: open/select/delete/import journeys against new pinned shell
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Table sizing + scroll

- **Goal**: intrinsic column widths; no wrap; table-local horizontal scroll; short-height overflow owned locally
- [ ] `lib/screens/peak_lists_screen.dart` - extract shared width contract for summary/peak tables; keep action column `max(header, icon)`; add scroll viewports; keep right-column content vertically scrollable when height is tight; preserve fixed `12px` inter-column gaps and right-aligned peak-date/elevation/points columns; keep climbed peak markers above unclimbed markers in the shared marker stack; include the peak points column and points summary text; add the blue selection circle overlay for detail-row peak selection
- [ ] `test/widget/peak_lists_screen_test.dart` - TDD: full-dataset header sizing, summary/peak horizontal scrolling, short-height overflow, unsupported-row and empty-state stability
- [ ] `test/widget/peak_lists_screen_test.dart` - add/adjust assertions for `peak-lists-mini-map`, `peak-lists-selected-title`, and row/action keys after layout changes
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey regressions

- **Goal**: lock critical user journeys and selector stability
- [ ] `test/robot/peaks/peak_lists_journey_test.dart` - verify delete selection, import completion, empty-state, and unsupported-row journeys against the new layout
- [ ] `test/robot/peaks/peak_lists_robot.dart` - keep journey selectors minimal; add only viewport keys needed for critical flows
- [ ] `test/widget/peak_lists_screen_test.dart` - final regression pass for selection persistence and post-delete selection resolution
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: 588px body-width edge, nested scroll coordination, selector churn
- **Out of scope**: import parsing/data-model changes, editing/reordering flows, compact/mobile Peak Lists mode
