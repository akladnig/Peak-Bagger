## Overview

Shared path-info panel for tracks + routes.
Route selection mirrors track hover/click path; one provider seam, one shared panel, no route time.

Status: phases 1 through 3 are complete.

**Spec**: `ai_specs/route-info.md` (read this file for full requirements)

## Context

- **Structure**: layered Flutter app (`screens/`, `widgets/`, `providers/`, `services/`, `models/`)
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/providers/map_provider.dart`, `lib/services/track_hover_detector.dart`, `test/providers/map_provider_selected_track_test.dart`, `test/providers/map_provider_selected_route_test.dart`, `test/widget/map_screen_route_info_test.dart`
- **Assumptions/Gaps**: route selection seam is implemented; robot journey remains deferred in this pass.

## Plan

### Phase 1: Route seam

- **Goal**: route hover/click selects route; stale route clears
- [x] `lib/providers/map_provider.dart` - add route selection state + `selectRoute` / `clearSelectedRoute` / `reconcileSelectedRouteState`
- [x] `lib/screens/map_screen.dart` - mirror track pointer flow for routes; wire route hover/click; clear hovered route on exit/cancel; listen for route list changes; choose selected track/route panel branch
- [x] `lib/services/route_hover_detector.dart` - new route hover hit-test helper, track-detector clone
- [x] `TDD:` route select/clear contract; stale selected route clears; invalid route no-op; track selection unchanged
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Shared panel

- **Goal**: one panel shell for both path types; route omits Time
- [x] `lib/screens/map_screen_panels.dart` - refactor `MapTrackInfoPanel` into shared path info panel; route name-only header; same section order as tracks; omit Time; keep track sections intact
- [x] `test/widget/map_screen_track_info_test.dart` - keep track regression coverage
- [x] `test/widget/map_screen_route_info_test.dart` - new route panel cases; route metrics; no Time; close clears route; stale route selection closes
- [x] `TDD:` route panel renders name-only header + track section order; no Time section; track behavior unchanged
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey coverage

- **Goal**: key-first route selection journey
- [x] `test/robot/map/route_info_robot.dart` - new robot helper; stable selectors: `map-interaction-region`, `track-info-panel`, `track-info-panel-close`
- [x] `test/robot/map/route_info_journey_test.dart` - hover/click route -> panel visible -> close clears -> stale route removal clears
- [x] `TDD:` one journey assertion at a time; deterministic fake route storage/revision where needed
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: pointer hit-testing for route polylines may need tuning; route hover/select behavior is now covered by widget, provider, and robot tests
- **Out of scope**: route drafting/saving/export, route persistence/schema changes, unrelated map gesture work
