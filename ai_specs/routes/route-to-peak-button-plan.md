## Overview

Add `Route to Peak` beside the route mode buttons.
Use the current `peakInfoPeak` anchor; keep snap/straight-line routing unchanged.

**Spec**: `this request`

## Context

- **Structure**: layer-first Flutter app; `providers/` + `screens/` + `widgets/`
- **State management**: Riverpod `MapNotifier` / `MapState`
- **Reference implementations**: `lib/widgets/map_route_bottom_sheet.dart`, `lib/providers/map_provider.dart`, `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/robot/map/map_route_journey_test.dart`
- **Assumptions/Gaps**: `peakInfoPeak` is the peak marker anchor; button uses the current draft start + captured peak target; disable/inert until a peak marker exists

## Plan

### Phase 1: Route-to-peak slice

- **Goal**: peak-aware route button, draft routing, end-to-end coverage
- [x] `lib/widgets/map_route_bottom_sheet.dart` - add `Route to Peak` button left of `Snap to Trail`; stable key; disable when no peak marker
- [x] `lib/providers/map_provider.dart` - add route-to-peak draft plumbing; capture current peak target; route first tap to peak; clear target on cancel/save
- [x] `test/providers/route_draft_state_test.dart` - TDD: peak target routes first tap to peak; no peak target stays disabled / no-op
- [x] `test/widget/map_screen_route_sheet_test.dart` - TDD: button order/rendering; enabled/disabled state; draft state reflects peak target
- [x] `test/robot/map/map_route_robot.dart` - add stable selector for `Route to Peak`
- [x] `test/robot/map/map_route_journey_test.dart` - TDD: peak popup -> route-to-peak -> save journey
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: one-shot vs persistent mode ambiguity; peak popup changing mid-draft; eligibility vs first-tap availability
- **Out of scope**: peak search UI; route storage/schema changes; unrelated map rendering changes
