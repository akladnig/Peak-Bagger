## Overview

Persistent waypoint slice for map screen. Start with marker persistence through an existing entry point, then add rail/chooser/favourites/ETA/admin incrementally.

**Spec**: `ai_specs/map-screen/drop-marker.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `lib/widgets`
- **State management**: Riverpod; `Provider`, notifier-driven `mapProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/widgets/map_action_rail.dart`, `lib/services/objectbox_admin_repository.dart`
- **Assumptions/Gaps**: `home` reserved only; `Goto Favourite` camera-only; marker singleton persisted row mirrored into `selectedLocation`

## Plan

### Phase 1: Marker Persistence Slice

- **Goal**: prove persisted marker end-to-end via existing peak popup path
- [x] `lib/models/waypoints.dart` - add ObjectBox `Waypoints` entity; fields for id, name, type, latitude, longitude, mgrs
- [x] `lib/services/waypoints_repository.dart` - add ObjectBox + in-memory storage; marker singleton helpers; favourite list/save helpers scaffolded
- [x] `lib/core/constants.dart` - add Home MGRS constant; minimal waypoint constants if needed
- [x] `lib/objectbox-model.json` - regenerate schema with `Waypoints`
- [x] `lib/objectbox.g.dart` - regenerate schema code
- [x] `lib/providers/map_provider.dart` - add restore/save seams for current marker; restore persisted marker into `selectedLocation` without camera move
- [x] `lib/screens/map_screen.dart` - route peak-popup `Drop a Marker on the Peak` through waypoint persistence contract
- [x] `test/services/waypoints_repository_test.dart` - repository seam coverage
- [x] `test/widget/map_screen_peak_info_test.dart` - extend marker-drop assertions to cover persistence/restore contract
- [x] TDD: marker save replaces prior marker row; favourites can remain unimplemented beyond no-regression seams
- [x] TDD: persisted marker restore sets `selectedLocation` without camera movement
- [x] TDD: peak-popup drop persists marker and leaves camera unchanged
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Rail + Armed Drop Marker

- **Goal**: add new location-rail controls; arm-next-tap marker flow
- [x] `lib/widgets/map_action_rail.dart` - add `Drop Marker` above `Center on marker`; add `Favourites` below it; stable keys/tooltips; preserve grouping/spacing
- [x] `lib/providers/map_provider.dart` - add narrow armed-mode state seam only if notifier-owned state is cleaner than screen-local state (kept screen-local in `MapScreen`)
- [x] `lib/screens/map_screen.dart` - implement armed marker mode; cancel paths; next empty-map tap drops marker; preserve higher-priority hit targets
- [x] `test/widget/map_action_rail_grouping_test.dart` - assert new button order/messages/keys
- [x] `test/widget/map_screen_camera_request_test.dart` or new `test/widget/map_screen_waypoint_test.dart` - armed drop behavior; no recentering; cancel paths
- [x] TDD: rail renders `drop-marker-fab` and `goto-favourite-fab` in requested order
- [x] TDD: armed mode consumes next empty-map tap only; peak/track/route hits still win
- [x] TDD: pressing armed FAB again or dismiss paths clear armed mode
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Empty-Map Chooser + Favourites

- **Goal**: replace implicit empty-map marker placement with chooser + favourite save/goto
- [x] `lib/screens/map_screen.dart` - bypass legacy empty-map immediate selection flow; capture tap context; open/dismiss chooser; wire chooser actions
- [x] `lib/screens/map_screen_panels.dart` - add tap-action popup, favourites popup, favourite naming dialog, empty state, viewport-safe placement, stable selectors
- [x] `lib/services/waypoints_repository.dart` - finish favourite save/list/duplicate-name helpers; marker-row normalization on save
- [x] `lib/providers/waypoints_provider.dart` - add repository access / refresh seam only if needed for popup list updates (not needed; notifier/repository access stayed sufficient)
- [x] `test/widget/map_screen_waypoint_test.dart` - chooser contents; favourite naming validation; camera-only goto-favourite; empty state
- [x] `test/widget/map_action_rail_grouping_test.dart` - update location-group tooltip expectations
- [x] `test/robot/map/drop_marker_robot.dart` - new robot helper for chooser/favourite flows, or extend existing map robot lane minimally
- [x] TDD: unarmed empty-map tap opens chooser instead of immediately setting marker
- [x] TDD: chooser always shows marker/favourite; favourite save trims, rejects blank/duplicate, saves success path
- [x] TDD: goto-favourite moves camera to default zoom but does not change `selectedLocation` or persisted marker row
- [x] Robot journey tests + selectors/seams for critical flows: `drop-marker-fab`, `goto-favourite-fab`, `map-tap-action-popup`, `map-tap-action-drop-marker`, `map-tap-action-drop-favourite`, `favourite-name-dialog`, `favourite-name-input`, `favourite-name-save`, `favourites-popup`, `favourites-popup-row-<id>`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Conditional ETA + Admin Support

- **Goal**: chooser-driven ETA rows; admin list/delete for `Waypoints`
- [x] `lib/screens/map_screen.dart` - capture precomputed or replayable tap-time ETA context; show Home ETA only on routable taps; show Marker ETA only when current marker exists; reuse existing ETA popup contract
- [x] `lib/screens/map_screen_panels.dart` - render conditional ETA rows in chooser
- [x] `lib/services/objectbox_admin_repository.dart` - load/map `Waypoints` rows; primary-name handling; preview values
- [x] `lib/screens/objectbox_admin_screen.dart` - add `Waypoints` delete action wiring
- [x] `lib/screens/objectbox_admin_screen_table.dart` - add `objectbox-admin-waypoints-delete-<id>` key path
- [x] `test/widget/map_screen_drive_eta_test.dart` - chooser-driven ETA routing; routable/non-routable variants; marker-present vs marker-absent variants
- [x] `test/widget/objectbox_admin_waypoints_test.dart` or existing admin test file - entity list/delete coverage for `Waypoints`
- [x] TDD: chooser captures tap-time ETA context; later button press does not depend on popup-button tap position
- [x] TDD: non-routable tap omits ETA rows; routable tap shows Home ETA; Marker ETA appears only with current marker
- [x] TDD: chooser-triggered ETA still uses existing loading/success/error popup surface
- [x] Robot journey tests + selectors/seams for critical flows: reuse `map-interaction-region`, existing `drive-eta-popup-*` keys, plus chooser ETA row keys; fake route-graph hit service and fake ORS/live-location seams
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: map tap precedence regressions in `MapScreen`; chooser anchoring/edge clamping; ObjectBox schema churn and generated-file sync
- **Out of scope**: editable Home waypoint; waypoint rename/edit UI; marker history; mini-map adoption; broader action-rail redesign
