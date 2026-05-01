## Overview

Shared shell `AppBar`; replace split shell chrome.
Drive header + nav from one destination model; ship wide first, then compact, then cleanup/polish.

**Spec**: `ai_specs/001-app-bar-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-by-type; `screens/`, `widgets/`, `providers/`, `services/`, `models/`
- **State management**: Riverpod + GoRouter `StatefulShellRoute.indexedStack`
- **Reference implementations**: `lib/router.dart`, `lib/widgets/side_menu.dart`, `test/widget/objectbox_admin_shell_test.dart`
- **Assumptions/Gaps**: none; spec committed in `2168df8`

## Plan

### Phase 1: Shell Vertical Slice

- **Goal**: shared header + destination model on wide layout
- [ ] `lib/router.dart` - add shared destination model; branch index primary; shared titles/labels/keys; shared AppBar shell; move theme action; move home icon; reuse pre-nav cleanup
- [ ] `lib/widgets/side_menu.dart` - consume shared destinations; render labeled wide nav; keep temporary `side-menu-objectbox-admin` alias alongside `nav-objectbox-admin`
- [ ] `lib/theme.dart` - add AppBar elevation/shadow tuning only as needed for shared header
- [ ] `test/widget/objectbox_admin_shell_test.dart` - migrate shell navigation assertions toward shared destination keys
- [ ] `test/widget/gpx_tracks_shell_test.dart` - preserve route-shell snackbar/settings behavior under shared header
- [ ] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - add shared-key selectors; keep deterministic pump path
- [ ] TDD: destination model exposes ordered branch/path/label/title/key contract; no route-name-derived text
- [ ] TDD: wide shell shows shared AppBar, correct title, theme action, home action, ordered labeled nav
- [ ] TDD: home icon from non-dashboard route returns to Dashboard; on Dashboard it is no-op
- [ ] Robot journey tests + selectors/seams for critical flows: open app on wide layout, go admin via `nav-objectbox-admin`, assert title changes, go home via AppBar, deterministic ProviderScope/test repositories
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Compact Nav + Interaction Rules

- **Goal**: compact drawer path; same model/keys/order
- [ ] `lib/router.dart` - add `LayoutBuilder` shell split at `720`; compact AppBar leading menu; compact drawer; active-destination drawer no-op closes drawer only
- [ ] `lib/widgets/side_menu.dart` - extract/reuse destination rendering inputs if needed; avoid duplicate nav definitions
- [ ] `test/widget/objectbox_admin_shell_test.dart` - add compact-width coverage for destination order, selected state, drawer close/no-op behavior
- [ ] `test/widget/gpx_tracks_shell_test.dart` - confirm shell messages remain usable with compact chrome
- [ ] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - add/extend compact journey only if harness stays deterministic; otherwise report gap per spec
- [ ] TDD: compact shell uses drawer, shared destination keys, shared order, selected state, no-op on active destination tap
- [ ] TDD: compact title truncates before menu/theme actions overflow; wide labels wrap to two lines
- [ ] Robot journey tests + selectors/seams for critical flows: open compact nav via trigger, navigate with `nav-*` keys, assert drawer closes, assert title/order/selection; fixed test width seam
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Screen Cleanup + Focus + Migration Finish

- **Goal**: remove redundant headers; preserve map behavior; finish selector migration
- [ ] `lib/screens/settings_screen.dart` - remove local top-level AppBar
- [ ] `lib/screens/objectbox_admin_screen.dart` - remove local top-level AppBar
- [ ] `lib/screens/dashboard_screen.dart` - remove in-body title; keep intentional empty body
- [ ] `lib/screens/peak_lists_screen.dart` - remove in-body title; keep FAB-only body
- [ ] `test/widget/map_screen_keyboard_test.dart` - add shell-interaction focus-return coverage where needed
- [ ] `test/widget/objectbox_admin_shell_test.dart` - stop relying on icon-based shell taps; use shared keys only
- [ ] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - finalize long-term `nav-*` selectors; drop temporary reliance on old key where safe
- [ ] TDD: settings/admin no longer render local AppBars; dashboard/peak-lists title text removed; existing body/FAB behavior preserved
- [ ] TDD: after compact nav or AppBar interactions on Map, keyboard shortcuts still work once focus should return
- [ ] Robot journey tests + selectors/seams for critical flows: shared-key-only navigation contract on wide path; report any compact robot gap explicitly
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: map focus regressions from new shell controls; selector migration churn across existing tests; compact drawer journey may stay widget-only if robot harness is brittle
- **Out of scope**: new page content for Dashboard/Peak Lists; localisation-backed titles; route-specific actions in shared AppBar
