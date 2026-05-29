## Overview
Route admin in ObjectBox Admin: inline edit, delete, and jump-to-map for Route rows.
Reuse existing admin shell patterns; keep Route geometry intact.

**Spec**: `./ai_specs/route-admin-spec.md`

## Context

- **Structure**: feature-first admin screens + provider/repository seams
- **State management**: Riverpod
- **Reference implementations**: `./lib/screens/objectbox_admin_screen.dart`, `./lib/screens/objectbox_admin_screen_details.dart`, `./lib/screens/objectbox_admin_screen_table.dart`, `./lib/providers/map_provider.dart`, `./lib/providers/route_repository_provider.dart`
- **Assumptions/Gaps**: route save loads existing Route by id; preserve geometry/waypoints/cache fields; map jump uses route id + selected route state, clears selected track

## Plan

### Phase 1: Route persistence seam

- **Goal**: save/delete Route rows without dropping geometry
- [x] `./lib/screens/objectbox_admin_screen.dart` - wire Route save/delete handlers to `RouteRepository` + `routeRevisionProvider`
- [x] `./lib/providers/route_repository_provider.dart` - keep Route list refresh path tied to revision bumps
- [x] `./lib/services/route_repository.dart` - ensure existing Route record is loaded/mutated by id on save
- [x] TDD: Route save preserves geometry/payload/cache fields; non-empty name blocks save; delete refresh keeps selection stable
- [x] Verify: `flutter analyze && flutter test test/services/route_admin_editor_test.dart test/providers/map_provider_selected_route_test.dart`

### Phase 2: Route admin UI

- **Goal**: inline edit + delete affordances in admin shell
- [x] `./lib/screens/objectbox_admin_screen_details.dart` - Route view-on-map/edit/close action row; inline edit form; read-only JSON text fields; save-success/error dialogs
- [x] `./lib/screens/objectbox_admin_screen_table.dart` - Route-only delete icon column and stable delete keys
- [x] `./lib/widgets/dialog_helpers.dart` - reuse existing dialog helper patterns only if Route keys need a small seam
- [x] TDD: action ordering; inline edit render; read-only long-field display; validation; save-error/success dialogs; delete confirm/cancel flow
- [x] Verify: `flutter analyze && flutter test test/widget/objectbox_admin_shell_test.dart test/widget/objectbox_admin_browser_test.dart`

### Phase 3: Map jump + journey coverage

- **Goal**: route view-on-map selects Route by id and fits bounds on MapScreen
- [x] `./lib/providers/map_provider.dart` - add route-focus request by id, clear selectedTrackId, set showRoutes true
- [x] `./lib/screens/map_screen.dart` - consume route-focus request; fit selected Route bounds via existing `CameraFit.bounds` path; fallback for 0/1 points
- [x] `./test/robot/objectbox_admin/objectbox_admin_robot.dart` - add selectors for route actions, dialog buttons, edit inputs
- [x] `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - browse Route -> view on map -> edit -> save -> delete journey
- [x] TDD: route-focus request updates map selection; route bounds fit request; critical journey remains deterministic with fake repos
- [x] Verify: `flutter analyze && flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart test/widget/map_screen_route_info_test.dart`

## Risks / Out of scope

- **Risks**: preserving geometry during save; route-focus/select state interaction; keeping admin selection stable after delete/refresh
- **Out of scope**: schema migration; route-draft editing; export-format changes; new admin entity types
