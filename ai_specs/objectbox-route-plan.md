## Overview

Add `Route` ObjectBox entity + JSON-backed geometry; wire into admin discovery and schema guard.
Keep changes local to model/service/test layers; reuse existing admin patterns.

**Spec**: `ai_specs/objectbox-route-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`lib/models`, `lib/services`, `lib/screens`, `test/...`)
- **State management**: Riverpod
- **Reference implementations**: `./lib/models/gpx_track.dart`, `./lib/services/objectbox_admin_repository.dart`, `./lib/services/objectbox_schema_guard.dart`, `./test/harness/test_objectbox_admin_repository.dart`
- **Assumptions/Gaps**: none blocking; `colour` is `int`; alias imports where Flutter `Route` type collides

## Plan

### Phase 1: Model + codec slice

- **Goal**: pure entity + round-trip
- [x] `./lib/models/route.dart` - add `Route` entity; `id`, metadata, transient `gpxRoute`, JSON getter/setter; alias `Route` imports where needed
- [x] `./lib/objectbox.g.dart`, `./lib/objectbox-model.json` - regenerate ObjectBox outputs after model add
- [x] TDD: `./test/models/route_test.dart` - round-trip valid points; empty/malformed JSON; partial bad pairs skipped; latitude/longitude order
- [x] Verify: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test`

### Phase 2: Admin discovery + schema slice

- **Goal**: browse `Route` in admin; schema drift aware
- [x] `./lib/services/objectbox_admin_repository.dart` - add `Route` branch, row mapper, search by `name`, sort by `id`
- [x] `./lib/services/objectbox_schema_guard.dart` - include `Route.name`, `Route.gpxRouteJson`, `Route.displayRoutePointsByZoom`, `Route.colour`
- [x] `./test/harness/test_objectbox_admin_repository.dart` - seed `Route` entity + rows
- [x] TDD: `./test/services/objectbox_admin_repository_test.dart` - discover `Route` metadata, row exposure, browse/search/sort
- [x] TDD: `./test/services/objectbox_schema_guard_test.dart` - schema signature includes `Route` markers
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Admin journey coverage

- **Goal**: prove `Route` selectable/browsable end-to-end
- [x] `./test/widget/objectbox_admin_shell_test.dart` - `Route` visible in dropdown; shell opens; rows browseable
- [x] `./test/widget/objectbox_admin_browser_test.dart` - `Route` row selection/details; no mutation UI regression
- [x] `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - open admin, select `Route`, inspect row, close details
- [x] `./lib/screens/objectbox_admin_screen_details.dart` - selectable details values for GpxTrack/Route fields; keep browser assertions stable
- [x] Stable selectors/seams: reuse `nav-objectbox-admin`, `objectbox-admin-entity-dropdown`, `objectbox-admin-table`, `objectbox-admin-details-close`
- [x] Verify: `flutter analyze && flutter test`

## Risks / Out of scope

- **Risks**: generator drift between `objectbox.g.dart` and `objectbox-model.json`; `Route`/Flutter `Route` import collisions; exact entity-order assertions in existing tests
- **Out of scope**: route edit/create UI, import/export behavior, broader map routing features
