## Overview

Replace Tasmap corner storage with `p1..p8`, keep reset-only reimport, draw outline-only polygons from saved point order.

**Spec**: `ai_specs/004-tasmap-refactor-spec.md`

## Context

- **Structure**: feature-local `models` / `services` / `screens` / `providers`
- **State management**: Riverpod `Notifier` + `Provider`
- **Reference implementations**: `lib/services/gpx_importer.dart`, `lib/providers/map_provider.dart`, `lib/screens/settings_screen.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`, `test/widget/objectbox_admin_browser_test.dart`
- **Assumptions/Gaps**: Tasmap reset owns reimport + `import.log`; no startup migration; add stable keys for reset tile, Goto controls, and outline layer

## Plan

### Phase 1: Schema + parser

- **Goal**: make `p1..p8` real, parse valid rows, reject bad counts
- [ ] `lib/models/tasmap50k.dart` - replace `tl/tr/bl/br` with `p1..p8`; add non-empty point helper if needed
- [ ] `lib/services/csv_importer.dart` - parse `p1..p8`; normalize compact/space-separated MGRS; accept only 4/6/8 valid points; emit row warnings
- [ ] `lib/services/tasmap_repository.dart` - persist new model; wire import-log writes via shared path seam
- [ ] `lib/objectbox-model.json`, `lib/objectbox.g.dart` - regen schema
- [ ] `test/csv_importer_test.dart`, `test/tasmap50k_test.dart` - TDD: 4/6/8-point parse, whitespace normalization, invalid-count skip, order preserved
- [ ] `test/services/objectbox_admin_repository_test.dart` - update schema expectations
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Reset + render

- **Goal**: user reset reimports Tasmap; map draws outline-only from saved points
- [ ] `lib/providers/tasmap_provider.dart` - keep reset/reimport user-driven; thread warnings/status
- [ ] `lib/screens/settings_screen.dart` - add stable key to Reset Map Data tile/confirm; surface reset status/warnings
- [ ] `lib/widgets/map_action_rail.dart` - add stable key to Goto control
- [ ] `lib/screens/map_screen.dart` - use `p1..p8`; bounds from all valid points; outline-only polygons; stable key for outline layer + Goto input
- [ ] `lib/services/objectbox_admin_repository.dart` - expose `p1..p8`; drop `tl/tr/bl/br`
- [ ] `test/widget/tasmap_outline_test.dart` - TDD: outline-only render, CSV order, bounds from all points
- [ ] `test/services/objectbox_admin_repository_test.dart`, `test/widget/objectbox_admin_browser_test.dart` - admin/schema fields show new model
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey

- **Goal**: prove Settings reset + return-to-map Tasmap flow end-to-end
- [ ] `test/robot/tasmap/tasmap_robot.dart` - robot helper for reset, Goto, and map assertions
- [ ] `test/robot/tasmap/tasmap_journey_test.dart` - robot: open Settings, reset Tasmap, return to map, confirm selection/refresh still works
- [ ] Add/fix selectors in `lib/screens/settings_screen.dart`, `lib/widgets/map_action_rail.dart`, `lib/screens/map_screen.dart`
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / out of scope

- **Risks**: legacy rows stay until manual reset; `import.log` reuse may couple Tasmap to GPX path helper; polygon validity depends on CSV order
- **Out of scope**: GPX, peaks, routes, automatic startup migration
