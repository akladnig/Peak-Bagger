## Overview

Shared summary chart y-axis polish. Add left labels + 4 equal horizontal intervals across all dashboard summary cards.

**Spec**: `./ai_specs/summary-chart-y-axis-labels-horizontal-lines.md`

## Context

- **Structure**: shared widget pipeline; `SummaryCard` -> `SummaryChart` -> metric adapters
- **State management**: local `StatefulWidget` selection/scroll state; no app-wide state change
- **Reference implementations**: `./lib/widgets/dashboard/summary_chart.dart`, `./lib/widgets/dashboard/summary_card.dart`, `./lib/widgets/dashboard/elevation_chart.dart`
- **Assumptions/Gaps**: count-axis labels use plain whole-number formatting with separators; no robot journey update needed

## Plan

### Phase 1: Shared axis plumbing

- **Goal**: expose metric-specific y-axis labels from adapter through chart
- [x] `./lib/widgets/dashboard/summary_card.dart` - add axis label formatter hook on adapter; pass through to `SummaryChart`
- [x] `./lib/widgets/dashboard/distance_card.dart` - supply distance axis label formatter
- [x] `./lib/widgets/dashboard/elevation_card.dart` - supply elevation axis label formatter
- [x] `./lib/widgets/dashboard/elevation_chart.dart` - add/align any shared elevation formatting helper used by axis labels
- [x] `./lib/widgets/dashboard/peaks_bagged_card.dart` - supply count axis label formatter
- [x] `./lib/core/number_formatters.dart` - add shared whole-number/count formatter if needed
- [x] `./lib/widgets/dashboard/summary_chart.dart` - render left-axis label gutter overlay on bar/line charts; keep chart titles hidden
- [x] TDD: left axis overlay visible in both modes; labels rendered from adapter formatter; existing bucket/tooltip behavior unchanged
- [x] Verify: `flutter analyze` && `flutter test test/widget/distance_card_test.dart test/widget/elevation_card_test.dart test/widget/peaks_bagged_card_test.dart`

### Phase 2: Four-interval grid coverage

- **Goal**: lock grid/tick contract and regressions
- [x] `./lib/widgets/dashboard/summary_chart.dart` - derive interval from chartMaxY / 4; keep endpoints aligned
- [x] `./test/widget/distance_card_test.dart` - assert bar/line chart titles and grid config
- [x] `./test/widget/elevation_card_test.dart` - assert bar/line chart titles and grid config
- [x] `./test/widget/peaks_bagged_card_test.dart` - assert bar/line chart titles and grid config
- [x] TDD: 4 equal intervals; zero/near-zero values stay finite; secondary series still shares same axis scale
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: fl_chart title/grid API shape; label width on narrow cards; count formatter choice
- **Out of scope**: tooltip text changes; summary aggregation changes; new chart package; robot journey additions
