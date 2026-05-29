## Overview
Add prev/next paging to Latest Walk card.
Default to latest track; next disabled at latest track.

**Spec**: ad hoc request

## Context
- **Structure**: feature-first dashboard/widgets/services
- **State management**: Riverpod `Notifier` + card-local widget state
- **Reference implementations**: `lib/widgets/dashboard/latest_walk_card.dart`, `lib/services/latest_walk_summary.dart`, `lib/screens/map_screen_layers.dart`, `test/widget/latest_walk_card_test.dart`, `test/robot/dashboard/dashboard_journey_test.dart`
- **Assumptions/Gaps**: card-local paging only; order by `startDateTime` desc; prev disabled at oldest, next disabled at latest; no route or global track selection changes

## Plan

### Phase 1: Track paging model
- **Goal**: ordered walk list + current index seam
- [x] `lib/services/latest_walk_summary.dart` - expose ordered tracks / current index / boundaries for paging
- [x] `test/services/latest_walk_summary_test.dart` - TDD: sort order, null filter, tie-break, empty list, first/last bounds, next-disabled-at-latest state
- [x] TDD: keep summary selection deterministic; latest remains default view
- [x] Verify: `flutter analyze` && `flutter test test/services/latest_walk_summary_test.dart`

### Phase 2: Card controls
- **Goal**: arrow buttons + tooltip nav in card header
- [x] `lib/widgets/dashboard/latest_walk_card.dart` - add prev/next arrows right of track name, tooltips, disabled states, paging updates, preserve mini-map/markers/cache path
- [x] `test/widget/latest_walk_card_test.dart` - TDD: arrows render, tooltips present, next disabled on latest, previous disabled on oldest, content updates on tap
- [x] `test/widget/dashboard_screen_test.dart` - ensure dashboard slot still renders with new header layout
- [x] TDD: stable selectors `latest-walk-prev-track`, `latest-walk-next-track`, `latest-walk-track-title`
- [x] Verify: `flutter analyze` && `flutter test test/widget/latest_walk_card_test.dart test/widget/dashboard_screen_test.dart`

### Phase 3: Dashboard journey
- **Goal**: prove card paging in app shell
- [x] `test/robot/dashboard/dashboard_robot.dart` - add helpers for track nav buttons and title assertions
- [x] `test/robot/dashboard/dashboard_journey_test.dart` - critical path: open dashboard, page older/newer, next disabled at latest, previous works
- [x] TDD: one journey slice for page-back/page-forward; one for disabled-next-at-latest
- [x] Verify: `flutter analyze` && `flutter test test/robot/dashboard/dashboard_journey_test.dart`

## Risks / Out of scope
- **Risks**: local card state can drift from track list updates; reset selection when tracks refresh
- **Risks**: selectors in a compact header; keep keys stable and tooltips explicit
- **Out of scope**: route changes, global map selection, persistence of paging between launches
