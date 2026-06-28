## Overview

Add dual route timing rows, per-route walking speed, persisted timing provenance.
Keep timing math in services; keep panel callback-driven; follow existing Riverpod/ObjectBox seams.

**Spec**: `ai_specs/routes/route-timing-ui-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first-ish; `lib/services`, `lib/providers`, `lib/screens`, `test/*`
- **State management**: Riverpod + ObjectBox
- **Reference implementations**: `./lib/services/route_timing_service.dart`, `./lib/providers/map_provider.dart`, `./lib/screens/map_screen_panels.dart`, `./lib/services/gpx_importer.dart`, `./test/robot/map/route_info_robot.dart`
- **Assumptions/Gaps**: segment-aligned provenance JSON; route panel stays standalone; `routeRevisionProvider` handles refresh; legacy mixed fallback stays read-only

## Plan

### Phase 1: Vertical slice

- **Goal**: persisted speed + provenance + happy-path panel slice
- [x] `./lib/models/route.dart` - add `walkingSpeedKmh` + segment-provenance field; constructor/default wiring
- [x] `./lib/objectbox.g.dart` - regenerate schema for new persisted fields
- [x] `./lib/services/route_timing_service.dart` - add pure display-timing API: preserved/manual totals, speed-aware Naismith/Scarf, fallback result model
- [x] `./lib/providers/map_provider.dart` - add route timing settings update seam; save route; increment `routeRevisionProvider`
- [x] `./lib/screens/map_screen.dart` - inject timing-setting callbacks into `MapTrackInfoPanel`
- [x] `./lib/screens/map_screen_panels.dart` - replace single row with minimal Naismith/Scarf rows + speed control happy path for fully manual routes
- [x] TDD: route model persists `walkingSpeedKmh` + provenance JSON; then implement
- [x] TDD: fully manual route returns speed-aware Naismith/Scarf totals; then implement
- [x] TDD: stepper/shortcut change persists immediately and rerenders selected route; then implement
- [x] TDD: panel renders two rows, no inline explanation, happy-path speed update; then implement
- [x] Verify: `flutter test test/services/route_repository_test.dart test/services/route_timing_service_test.dart test/widget/map_route_info_panel_test.dart test/widget/map_screen_route_info_test.dart && flutter analyze`

### Phase 2: Import/edit/admin/schema wiring

- **Goal**: provenance populated at creation/update boundaries
- [x] `./lib/services/gpx_importer.dart` - mark timestamp imports preserved; untimed imports manual-estimated; default speed fallback semantics
- [x] `./lib/providers/map_provider.dart` - populate provenance on geometry fallback + route-draft save; preserve unchanged segments where possible
- [x] `./lib/services/route_admin_editor.dart` - preserve new timing fields or recompute/provenance per spec
- [x] `./lib/services/objectbox_admin_repository.dart` - expose new route fields in admin rows
- [x] `./lib/services/objectbox_schema_guard.dart` - include new route fields in schema signature
- [x] `./test/services/objectbox_admin_repository_test.dart` - cover new route timing fields in admin rows
- [x] `./test/services/objectbox_schema_guard_test.dart` - cover new route timing fields in schema signature
- [x] TDD: timestamp import gets preserved provenance; untimed import gets manual provenance; then implement
- [x] TDD: route edit/save preserves unchanged verified spans and marks inserted spans manual; then implement
- [x] TDD: admin/schema surfaces include new fields; then implement
- [x] Verify: `flutter test test/services/objectbox_admin_repository_test.dart test/services/objectbox_schema_guard_test.dart test/services/route_admin_editor_test.dart test/providers/map_provider_import_test.dart test/services/gpx_importer_filter_test.dart && flutter analyze`

### Phase 3: Fallbacks + popup UX

- **Goal**: full panel behavior; legacy fallback; typed-entry semantics
- [x] `./lib/screens/map_screen_panels.dart` - add info popups, inline limitation copy, direct-entry field, submit/blur persistence, focus-scoped shortcuts, disabled legacy mixed state
- [x] `./lib/services/route_timing_service.dart` - add legacy verified/manual/mixed fallback copy + stored-mixed-total result states
- [x] `./test/widget/map_route_info_panel_test.dart` - popup copy, typed-entry local state, submit/blur persist, disabled fallback assertions
- [x] `./test/widget/map_screen_route_info_test.dart` - selected-route refresh, reopen persistence, legacy safety
- [x] TDD: typed edits stay local until submit/blur, invalid text keeps last valid totals; then implement
- [x] TDD: fully preserved route stays fixed across speed changes; then implement
- [x] TDD: legacy mixed route shows stored mixed total, Scarf dash, disabled speed, inline + popup limitation copy; then implement
- [x] Verify: `flutter test test/widget/map_route_info_panel_test.dart test/widget/map_screen_route_info_test.dart test/services/route_timing_service_test.dart && flutter analyze`

### Phase 4: Robot + blast-radius cleanup

- **Goal**: critical journeys; selector migration; residual regressions
- [ ] `./test/robot/map/route_info_robot.dart` - add selectors/actions/assertions for dual rows, speed control, info popups, reopen persistence
- [ ] `./test/robot/map/route_info_journey_test.dart` - critical journey: open route -> adjust speed -> totals update -> close/reopen -> persisted speed restored
- [ ] `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - replace old single-row route timing assertions with dual-row contract
- [ ] `./lib/screens/map_screen_panels.dart` - add any remaining stable keys/seams required by robot tests
- [ ] TDD: robot happy path for route timing controls; then implement
- [ ] Robot journey tests + selectors/seams for critical flows: dual timing row keys, info-popup keys, speed field/stepper keys, deterministic repository-backed route fixture
- [ ] Verify: `flutter test test/robot/map/route_info_journey_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart test/widget/map_route_info_panel_test.dart test/widget/map_screen_route_info_test.dart && flutter analyze`

## Risks / Out of scope

- **Risks**: segment-provenance mapping for edited routes; legacy mixed fallback copy clarity; callback-save/rerender race in selected route panel
- **Out of scope**: GPX export timing rewrite, track timing UI changes, global walking-speed preference
