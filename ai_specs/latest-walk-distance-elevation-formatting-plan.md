## Overview

Fix Latest Walk distance to 1 decimal; make elevation-card values use comma-separated metres.
Thin slice: shared formatters in the two card paths, then lock with widget/service tests.

**Spec**: ad hoc bug fix request

## Context

- **Structure**: feature-first widgets/services
- **State management**: local widget state only here; Riverpod elsewhere
- **Reference implementations**: `lib/services/latest_walk_summary.dart`, `lib/core/number_formatters.dart`, `lib/widgets/dashboard/elevation_chart.dart`, `test/services/latest_walk_summary_test.dart`, `test/widget/elevation_card_test.dart`
- **Assumptions/Gaps**: add/extend shared elevation formatter in `lib/core/number_formatters.dart`; keep distance change isolated to Latest Walk

## Plan

### Phase 1: Card formatting fix

- **Goal**: correct displayed units without widening scope
- [x] `lib/services/latest_walk_summary.dart` - format `distanceText` with 1 decimal place
- [x] `lib/core/number_formatters.dart` - add/extend shared elevation formatter with thousands separators
- [x] `lib/widgets/dashboard/elevation_chart.dart` - use shared formatter for axis labels and tooltip values
- [x] `lib/widgets/dashboard/elevation_card.dart` - use shared formatter for header value
- [x] `test/services/latest_walk_summary_test.dart` - TDD: selected track distance text renders `12.4 km`
- [x] `test/widget/latest_walk_card_test.dart` - TDD: Latest Walk card shows 1-decimal distance
- [x] `test/widget/elevation_card_test.dart` - TDD: elevation header/tooltips render `1,234 m`
- [x] Verify: `flutter analyze` && `flutter test test/services/latest_walk_summary_test.dart test/widget/latest_walk_card_test.dart test/widget/elevation_card_test.dart`

## Risks / Out of scope

- **Risks**: shared formatter change may affect other elevation displays; confirm only intended surfaces use it
- **Out of scope**: global elevation formatter changes; map screen / my ascents text updates
