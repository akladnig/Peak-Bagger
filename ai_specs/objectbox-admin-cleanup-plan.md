## Overview

Mechanical split of `ObjectBoxAdminScreen`; preserve route, keys, copy, tests.
Root screen keeps orchestration; sibling files take presentational widgets.

**Spec**: `ai_specs/objectbox-admin-cleanup-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; screens/providers/services/widgets
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `lib/screens/objectbox_admin_screen.dart`, `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`
- **Assumptions/Gaps**: `objectbox_admin_screen_helpers.dart` optional only if pure helper extraction clearly pays off

## Plan

### Phase 1: Prove split pattern

- **Goal**: first sibling files; shell intact
- [x] `lib/screens/objectbox_admin_screen_controls.dart` - add exported controls widget; move presentational controls only
- [x] `lib/screens/objectbox_admin_screen_details.dart` - add exported details widget; move details rendering only
- [x] `lib/screens/objectbox_admin_screen.dart` - wire new widgets; keep router/ref/controllers/snackbars in root
- [x] TDD: shell still opens from menu; dropdown/toggle/table selectors unchanged; then extract controls
- [x] TDD: selecting row still shows details pane; close still clears selection; then extract details pane
- [x] Robot journey tests + selectors/seams for critical flows: keep `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` green; preserve `side-menu-objectbox-admin`, `objectbox-admin-entity-dropdown`, `objectbox-admin-schema-data-toggle`, `objectbox-admin-table`
- [x] Verify: `flutter analyze` && `flutter test test/widget/objectbox_admin_shell_test.dart` && `flutter test test/widget/objectbox_admin_browser_test.dart` && `flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

### Phase 2: Move states and table

- **Goal**: extract body presentation surface
- [x] `lib/screens/objectbox_admin_screen_states.dart` - move schema view + shared loading/error/empty presentation widgets
- [x] `lib/screens/objectbox_admin_screen_table.dart` - move data grid, header row, row tiles, cells
- [x] `lib/screens/objectbox_admin_screen.dart` - keep `_buildBody`, refresh orchestration, load-more trigger, horizontal scroll ownership; swap in exported widgets
- [x] TDD: no-entity, no-selection, loading, error, no-match states render same copy/keys; then extract states widgets
- [x] TDD: row chunking, fixed first column, header/row scroll sync, selection rendering stay unchanged; then extract table widgets
- [x] TDD: schema mode still shows current field rows for selected entity; then extract schema view
- [x] Robot journey tests + selectors/seams for critical flows: keep stable keys unchanged; avoid async/controller indirection that makes shell journey flaky
- [x] Verify: `flutter analyze` && `flutter test test/widget/objectbox_admin_shell_test.dart` && `flutter test test/widget/objectbox_admin_browser_test.dart` && `flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

### Phase 3: Optional pure helpers, then harden

- **Goal**: trim root file; finish safely
- [ ] `lib/screens/objectbox_admin_screen_helpers.dart` - add only if pure helper extraction removes real noise; no ref/router/controller/snackbar side effects
- [ ] `lib/screens/objectbox_admin_screen.dart` - keep visible-entry refresh orchestration, load-more triggering, horizontal-scroll coordination, export/snackbar side effects in root; remove dead inline widget code/imports
- [ ] `test/services/objectbox_admin_repository_test.dart` - keep green; no service contract drift
- [ ] TDD: visible-entry refresh still fires on path re-entry, not unchanged visibility/rebuild churn; add focused test only if current coverage misses regression after refactor
- [ ] TDD: export visibility + `No gpxFile selected` behavior + repository export call remain unchanged; add focused widget assertion only if touched path loses coverage
- [ ] Verify: `flutter analyze` && `flutter test test/services/objectbox_admin_repository_test.dart` && `flutter test`

## Risks / Out of scope

- **Risks**: scroll-controller sync regressions; accidental refresh duplication; selector/copy drift breaking widget tests
- **Out of scope**: provider redesign; repository/model changes; copy/UX redesign; promoting admin-only UI into `lib/widgets/`
