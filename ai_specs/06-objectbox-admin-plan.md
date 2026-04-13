## Overview

Read-only ObjectBox browser. Thin shell slice first; schema/data grid, search/sort, details pane, then hardening.

**Spec**: `ai_specs/06-objectbox-admin-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/services`, `lib/providers`, `lib/screens`, `lib/widgets`, `lib/router.dart`, `lib/main.dart`
- **State management**: Riverpod `Provider` + `NotifierProvider`; mirror `map_provider.dart` / `tasmap_provider.dart`
- **Reference implementations**: `lib/router.dart`, `lib/widgets/side_menu.dart`, `lib/screens/settings_screen.dart`, `lib/providers/map_provider.dart`, `lib/providers/tasmap_provider.dart`, `lib/services/peak_repository.dart`, `lib/services/gpx_track_repository.dart`, `lib/objectbox.g.dart`, `test/widget/gpx_tracks_shell_test.dart`, `test/robot/gpx_tracks/*`
- **Assumptions/Gaps**: use generated `getObjectBoxModel()` for schema metadata; chunked eager loading of 50 rows; full-entity search then chunk rendered results; Settings branch shifts 3 -> 4; no platform gate in spec

## Plan

### Phase 1: Shell + discovery slice

- **Goal**: admin route opens; entity list loads; read-only shell visible
- [ ] `lib/services/objectbox_admin_repository.dart` - model/entity discovery API; row/schema source from `getObjectBoxModel()`
- [ ] `lib/providers/objectbox_admin_provider.dart` - state: entity, mode, search, sort, selection, loading, error, no-matches
- [ ] `lib/screens/objectbox_admin_screen.dart` - scaffold; entity dropdown; schema/data toggle; loading/error/empty shells
- [ ] `lib/router.dart` - insert admin branch at index 3; shift Settings/recovery actions to 4; keep shell layout intact
- [ ] `lib/widgets/side_menu.dart` - add database icon above Settings; update branch indexes
- [ ] `lib/main.dart` - override admin repository provider from `objectboxStore`
- [ ] TDD: route/menu opens admin shell; entity dropdown populated from model metadata; initial load shows spinner/error/empty states; no mutation affordances
- [ ] Robot: menu icon -> admin screen -> dropdown/toggle visible; stable keys for menu item, entity dropdown, schema/data toggle, table, empty/error states
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Schema + data browser

- **Goal**: all entities render; rows searchable/sortable; details pane works
- [ ] `lib/services/objectbox_admin_repository.dart` - typed row/schema adapters per entity; unsupported-field fallback values
- [ ] `lib/providers/objectbox_admin_provider.dart` - default primary-key sort; case-insensitive substring search; 50-row chunking; row selection; details pane state
- [ ] `lib/screens/objectbox_admin_screen.dart` - scrollable grid; pinned name column; sticky header; 80-char wrap/auto-expand; right-side details pane; no-matches state
- [ ] TDD: Peak/Tasmap50k/GpxTrack schema fields; default primary-key sort; search matches substring anywhere in name; row chunks load 50 at a time; selecting a row opens details pane; `X` closes; search refresh/loading state shared with initial load
- [ ] Widget tests: pinned-name columns, sticky headers, no-matches state, details-pane close/reset, selection behavior, search refresh spinner
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Hardening + regressions

- **Goal**: failure states and router regressions covered
- [ ] `lib/providers/objectbox_admin_provider.dart` / `lib/services/objectbox_admin_repository.dart` - init failure; query failure; empty/no-selectable-entities handling; fallback display for unsupported field types
- [ ] `test/harness/test_objectbox_admin_repository.dart` - deterministic fake repo/model fixtures
- [ ] `test/widget/objectbox_admin_screen_test.dart` - error-state, empty-state, no-matches, selection, branch regression coverage
- [ ] `test/robot/objectbox_admin/objectbox_admin_robot.dart` + `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - side menu -> browse entity -> switch back to Settings; selectors for menu item, schema/data toggle, entity dropdown, table, empty/error states, details close
- [ ] TDD: store init failure surfaces error; query failure stays inline; unsupported fields fall back; Settings index regression still routes correctly after 3 -> 4 shift
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: eager loading of large entities; ObjectBox metadata API drift; branch-index regression in shell routing
- **Out of scope**: pagination; network/API calls; mutation actions; auth/roles
