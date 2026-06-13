## Overview
Transient click chooser for overlapping track/route hits.
Reuse existing map selection flow; add popup + robot coverage.

**Spec**: `./track-route-selector-spec.md` (read this file for full requirements)

## Context
- **Structure**: feature-first map screen + shared panels + providers/services
- **State management**: Riverpod `Notifier` + immutable `MapState`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/providers/map_provider.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: none blocking; chooser candidates = all visible hits within current threshold; track subtitle uses `trackDate` + `totalTimeMillis`

## Plan

### Phase 1: Click chooser slice
- **Goal**: thin end-to-end chooser; click overlap -> popup -> select -> shared panel
- [x] `lib/screens/map_screen.dart` - chooser lifecycle; build all hits within threshold; open chooser on click overlap; dismiss on exit/mutation; keep existing selection flow intact
- [x] `lib/screens/map_screen_panels.dart` - chooser card/surface; row shell; placeholder thumbnail path
- [x] `test/widget/map_screen_track_route_selector_test.dart` - `TDD:` overlap opens chooser; row tap opens correct info panel; single-hit path unchanged
- [x] `test/widget/map_screen_track_route_selector_test.dart` - `TDD:` hidden items excluded; track rows sorted by `trackDate` desc; route rows sorted by name asc
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Row layout + thumbnails
- **Goal**: lock chooser presentation; compact, viewport-safe, deterministic
- [ ] `lib/screens/map_screen_panels.dart` - final row subtitle rules; blank thumbnail fallback; popup clamp/reposition
- [ ] `lib/screens/map_screen.dart` - reuse peak popup placement style where practical; keep chooser lifecycle centralized
- [ ] `test/widget/map_screen_track_route_selector_test.dart` - `TDD:` track subtitle uses `trackDate` + `totalTimeMillis`; route subtitle omits timestamp data; missing geometry shows blank thumbnail
- [ ] `test/widget/map_screen_track_route_selector_test.dart` - `TDD:` pointer exit/Escape/mutation dismiss chooser without clearing unrelated selection state
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey + regressions
- **Goal**: critical desktop click journey covered; no regressions in existing selection flows
- [ ] `test/robot/map/track_route_selector_robot.dart` - stable selectors for chooser root, rows, thumbnails, close action
- [ ] `test/robot/map/track_route_selector_journey_test.dart` - click overlap, choose track, choose route, stale dismissal path
- [ ] `test/robot/map/route_info_robot.dart` / `test/robot/gpx_tracks/gpx_tracks_robot.dart` - extend only if shared selectors/helpers are reused
- [ ] `test/widget/map_screen_route_info_test.dart` / `test/widget/map_screen_track_info_test.dart` - regressions for single-item selection unchanged
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: hit aggregation + popup dismissal timing; thumbnail generation from geometry; route/track mixed ordering
- **Out of scope**: persistence, new data models, bulk chooser screen, touch-specific chooser
