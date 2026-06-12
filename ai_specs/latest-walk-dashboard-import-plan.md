## Overview

Latest walk should snap to the newest imported track after track refresh + dashboard revisit.
Keep newest-first date ordering as the single source of truth.

**Spec**: `task description` (quick plan; no spec file)

## Context

- **Structure**: feature-first dashboard UI under `lib/screens` + `lib/widgets`; data/order logic in `lib/services`
- **State management**: Riverpod `Notifier` + shell route preserves dashboard state
- **Reference implementations**: `lib/screens/dashboard_screen.dart`, `lib/widgets/dashboard/latest_walk_card.dart`, `lib/services/latest_walk_summary.dart`, `test/widget/dashboard_screen_test.dart`, `test/robot/dashboard/dashboard_journey_test.dart`, `test/services/latest_walk_summary_test.dart`
- **Assumptions/Gaps**: dashboard branch stays mounted in `StatefulShellRoute`; fix should reselect newest track on import-driven track list changes, not on manual paging alone

## Plan

### Phase 1: Rebind latest walk

- **Goal**: stale latest-walk selection drops when a newer import arrives
- [x] `lib/screens/dashboard_screen.dart` - key `LatestWalkCard` by newest track id (`LatestWalkSummary.selectLatestTrack(tracks)?.gpxTrackId`) so a new import recreates the card with newest track selected
- [x] `test/widget/dashboard_screen_test.dart` - TDD: page latest-walk to an older track, update `tracks` with a newer import, expect title and map to jump to newest; prev/next bounds reset correctly
- [x] `test/robot/dashboard/dashboard_robot.dart` - add shell-nav helper for map/dashboard round-trip if needed for the regression
- [x] `test/robot/dashboard/dashboard_journey_test.dart` - TDD: open dashboard, page latest-walk away from newest, navigate to map, inject imported tracks, return; newest imported track visible on dashboard
- [x] Verify: `flutter analyze` && `flutter test test/widget/dashboard_screen_test.dart test/robot/dashboard/dashboard_journey_test.dart`

### Phase 2: Lock sort contract

- **Goal**: latest-walk track order stays newest-first by date
- [x] `test/services/latest_walk_summary_test.dart` - TDD: unordered tracks still sort by `startDateTime` desc; tie-break by `gpxTrackId`; null-date tracks excluded
- [x] `lib/services/latest_walk_summary.dart` - unchanged; contract test passed, no edge case exposed
- [x] Verify: `flutter analyze` && `flutter test test/services/latest_walk_summary_test.dart`

## Risks / Out of scope

- **Risks**: key-based reselect resets latest-walk paging whenever newest track changes; tracks without `startDateTime` remain excluded; shell-state persistence can hide stale-state bugs if only single-route tests are run
- **Out of scope**: import parsing, GPX date extraction, dashboard layout/order, map UI changes
