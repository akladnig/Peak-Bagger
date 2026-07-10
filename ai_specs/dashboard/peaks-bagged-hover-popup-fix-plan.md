## Overview
Fix Peaks Bagged hover popup text and edge clipping.
Keep chart hover/pin behavior unchanged.

**Spec**: `n/a` (bug report)

## Context
- **Structure**: feature-first dashboard widgets
- **State management**: local `StatefulWidget` chart state + shared summary chart
- **Reference implementations**: `lib/widgets/dashboard/peaks_bagged_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/elevation_profile_chart.dart`, `test/widget/peaks_bagged_card_test.dart`
- **Assumptions/Gaps**: copy change only in Peaks Bagged tooltip; clamp to visible plot area, not page chrome; pinned hover behavior stays the same

## Plan

### Phase 1: Tooltip copy + bounds

- **Goal**: correct label text; keep popup fully inside graph viewport
- [x] `lib/widgets/dashboard/peaks_bagged_card.dart` - change tooltip value text from `Total climbs` to `Total Peaks`
- [x] `lib/widgets/dashboard/summary_chart.dart` - clamp tooltip X placement within the visible plot area; preserve hover vs pinned selection behavior
- [x] `test/widget/peaks_bagged_card_test.dart` - TDD: tooltip text reads `Total Peaks`; first and last buckets keep the popup fully visible
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: unrelated failures in `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` and `test/widget/distance_card_test.dart`)

## Risks / Out of scope

- **Risks**: tooltip width may vary by period/locale; edge clamping must not fight horizontal scroll positioning
- **Out of scope**: chart redesign, metric changes, non-Peaks Bagged summary cards
