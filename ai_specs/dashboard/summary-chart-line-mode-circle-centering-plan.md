## Overview

Dashboard summary chart line mode. Shift dots to bucket centres; keep column mode unchanged.

**Spec**: user bug note (no spec file)

## Context

- **Structure**: dashboard card shell -> `SummaryCard` -> shared `SummaryChart`
- **State management**: local `StatefulWidget` selection/scroll state; no global state change
- **Reference implementations**: `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/dashboard/summary_card.dart`, `test/widget/distance_card_test.dart`
- **Assumptions/Gaps**: line mode needs a half-step x offset per bucket; secondary series must stay aligned; no robot journey needed

## Plan

### Phase 1: Center line dots

- **Goal**: dot circle lands in the middle of each bucket column
- [x] `lib/widgets/dashboard/summary_chart.dart` - offset `FlSpot` x values to bucket centres; share helper for both series; adjust `minX`/`maxX` to keep end buckets centred
- [x] `test/widget/distance_card_test.dart` - TDD: line-mode x values are half-step centred; primary/secondary series stay aligned; column mode unchanged
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: fl_chart range math; edge buckets after x offset; hover/tap assumptions
- **Out of scope**: bar mode layout; tooltip/content changes; robot coverage
