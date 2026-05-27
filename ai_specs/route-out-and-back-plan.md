## Overview

Add route waypoint persistence + one-shot `Out and Back`.
Keep Riverpod draft flow; persist metadata on save, serialize later in GPX.

**Spec**: `ai_specs/route-out-and-back-spec.md`

## Context

- **Structure**: feature-first by screen/provider/service
- **State management**: Riverpod `Notifier` + repository providers
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/services/gpx_export_service.dart`, `test/providers/route_draft_state_test.dart`, `test/robot/map/map_route_robot.dart`
- **Assumptions/Gaps**: metadata computed at save time only; exports serialize persisted route metadata; no export ordering requirement

## Plan

### Phase 1: Waypoint persistence

- **Goal**: route waypoint round-trip through ObjectBox
 - [x] `lib/models/route_waypoint.dart` - add persisted waypoint model
 - [x] `lib/models/route.dart` - add JSON-backed waypoint field, legacy empty decode
 - [x] `lib/services/objectbox_schema_guard.dart` - include new route field in schema signature
 - [x] regenerate `lib/objectbox.g.dart`
 - [x] TDD: legacy route decodes empty waypoint list; saved route round-trips waypoints intact
 - [x] Verify: `flutter analyze && flutter test test/services/route_repository_test.dart test/services/objectbox_schema_guard_test.dart`

### Phase 2: Draft save + action

- **Goal**: compute metadata on save; mirror outbound geometry once
- [x] `lib/providers/map_provider.dart` - add `applyRouteDraftOutAndBack()`, draft validation, geometry mirror, save-time waypoint mapping
- [x] `lib/services/route_repository.dart` - no behavior change unless route save wiring needs a seam
- [x] TDD: valid draft mirrors committed geometry, bumps geometry/elevation version once, leaves mode unchanged
- [x] TDD: invalid/inconsistent draft leaves geometry untouched and surfaces route-draft error
- [x] TDD: save failure keeps draft open; retry recomputes metadata from current committed draft state
- [x] Verify: `flutter analyze && flutter test test/providers/route_draft_state_test.dart`

### Phase 3: Route sheet control

- **Goal**: add one-shot button in existing strip
- [x] `lib/widgets/map_route_bottom_sheet.dart` - add `Out and Back` button, key, tooltip, icon, enable/disable rules
- [x] `test/robot/map/map_route_robot.dart` - add stable selector helper for the new control
- [x] TDD: button placement, tooltip, icon, enabled state, disabled state, filled-button family
- [x] Verify: `flutter analyze && flutter test test/widget/map_screen_route_sheet_test.dart`

### Phase 4: GPX export + journey

- **Goal**: export stored waypoints; preserve correlated peak precedence
- [x] `lib/core/constants.dart` - add `GpxConstants.precision = 6`
- [x] `lib/services/gpx_export_service.dart` - serialize stored waypoints, keep correlated peaks, normalize coords with precision constant
- [x] `test/services/gpx_export_service_test.dart` - explicit waypoint XML, peak-name vs generic-label, collision precedence
- [x] `test/robot/map/map_route_journey_test.dart` - build route, tap `Out and Back`, save, confirm persisted route
- [x] TDD: exported GPX includes stored `<wpt>` entries; correlated peak wins same-coordinate collision
- [x] TDD: robot journey completes with stable selectors and no private-helper reach-in
- [x] Verify: `flutter analyze && flutter test test/services/gpx_export_service_test.dart test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope

- **Risks**: ObjectBox regen + schema guard drift; robot flake around horizontal strip; export collision edge cases
- **Out of scope**: manual waypoint editing UI; route-planning algorithm changes; export ordering requirements
