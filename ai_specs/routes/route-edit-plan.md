## Overview
Add in-place route editing from the saved route info panel.
Seed existing route into draft, save back to same id, reopen panel.

**Spec**: `ai_specs/routes/route-edit-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first; UI in `./lib/screens`, state in `./lib/providers`, shared route draft UI in `./lib/widgets`
- **State management**: Riverpod
- **Reference implementations**: `./lib/screens/map_screen_panels.dart`, `./lib/widgets/map_route_bottom_sheet.dart`, `./test/providers/route_draft_state_test.dart`, `./test/robot/map/route_info_journey_test.dart`
- **Assumptions/Gaps**: full-geometry edit; `routeWaypoints` regenerated on save; `selectedRouteId` restored from `sourceRouteId`

## Plan

### Phase 1: Edit entry + seed

- **Goal**: route panel edit button -> draft seeded from saved route
- [x] `./lib/screens/map_screen_panels.dart` - add `Edit Route` header action + callback
- [x] `./lib/screens/map_screen.dart` - wire selected route edit callback into provider
- [x] `./lib/providers/map_provider.dart` - add `sourceRouteId`; new begin-edit path; seed draft state from `Route`
- [x] `./lib/widgets/map_route_bottom_sheet.dart` - scroll draft summary panel so seeded edit state fits
- [x] `./test/widget/map_route_info_panel_test.dart` - header button, tooltip, placement
- [x] `./test/widget/map_screen_route_sheet_test.dart` - edit opens draft overlay; name/route seed visible
- [x] `./test/providers/route_draft_state_test.dart` - seed state, clear panel selection, no-op while already drafting
- [x] TDD: header button visible; edit entry seeds route name/points/elevation; `sourceRouteId` retained while `selectedRouteId` clears
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_route_info_panel_test.dart test/widget/map_screen_route_sheet_test.dart test/providers/route_draft_state_test.dart`

### Phase 2: Save/cancel + journeys

- **Goal**: update same route id; restore/reopen on exit; recover errors
- [ ] `./lib/providers/map_provider.dart` - branch `saveRouteDraft()` on `sourceRouteId`; regenerate waypoints; restore selection on save/cancel; clear edit session
- [ ] `./lib/services/route_repository.dart` - only if helper needed for update semantics
- [ ] `./test/widget/map_screen_route_sheet_test.dart` - save/cancel reopen panel; same id updated; original route unchanged on cancel; save failure message
- [ ] `./test/robot/map/route_info_robot.dart` - edit/save/cancel actions + stable selectors
- [ ] `./test/robot/map/route_info_journey_test.dart` - open route -> edit -> save -> reopen; cancel path; deleted-route recovery
- [ ] TDD: save updates same id and refreshes panel; cancel restores original route; deleted route exits edit mode; save failure keeps draft/error
- [ ] Robot selectors: `track-info-panel-edit`, `track-info-panel-close`, `route-name-field`, `route-save-button`, `route-controls-overlay-root`
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: route->draft endpoint seeding; reopen timing after save/cancel; robot flake around panel close/open
- **Out of scope**: metadata-only edit, new editor surface, schema migration
