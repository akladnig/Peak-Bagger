## Overview
Dashboard wireframe + local reorder state. Custom drag grid, shared-preferences persistence, key-first tests.

**Spec**: `ai_specs/dashboard-wireframe-spec.md`

## Context
- **Structure**: feature-first (`lib/screens`, `lib/providers`, `test/providers`, `test/widget`, `test/robot`)
- **State management**: Riverpod; `Notifier` + async prefs pattern fits existing app style
- **Reference implementations**: `lib/providers/theme_provider.dart`, `lib/providers/gpx_filter_settings_provider.dart`, `test/robot/peaks/peak_lists_robot.dart`
- **Assumptions/Gaps**: no router change; dashboard already reachable via existing `/`, home icon, side menu

## Plan

### Phase 1: State + static board

- **Goal**: default order, prefs seam, six-card render
- [x] `lib/providers/dashboard_layout_provider.dart` - ordered ids, sanitize load, save/restore, injectable prefs loader
- [x] `lib/screens/dashboard_screen.dart` - provider hookup, base card chrome, six placeholder cards, stable keys, 4:3 board scaffold
- [x] `test/providers/dashboard_layout_provider_test.dart` - TDD: empty prefs -> default order; malformed ids -> sanitize; save/load round-trip; save failure keeps in-memory state
- [x] `test/widget/dashboard_screen_test.dart` - TDD: six cards render; board scrolls when short; keys present
- [x] Verify: `flutter analyze && flutter test`

### Phase 2: Drag reorder + responsive grid

- **Goal**: header-only drag/drop, auto reflow, persistence on move
- [x] `lib/screens/dashboard_screen.dart` - custom drag grid, header drag handles, drop targets, order update on drop
- [x] `test/widget/dashboard_screen_test.dart` - TDD: drag header reorders; drop on same slot no-op; 3/2/1 layout at `1200/800` breakpoints; short viewport scrolls
- [x] `test/providers/dashboard_layout_provider_test.dart` - TDD: reorder persists; unknown/missing ids preserve default append order
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Robot journey

- **Goal**: critical dashboard journey, persistence proof
- [x] `test/robot/dashboard/dashboard_robot.dart` - key-first selectors: `app-bar-home`, `dashboard-board`, `dashboard-card-<id>`, `dashboard-card-<id>-drag-handle`
- [x] `test/robot/dashboard/dashboard_journey_test.dart` - TDD: open dashboard from home, drag one card, restart harness, dashboard reopens; provider tests cover saved-order restore
- [x] Use mock prefs / provider override seam; no real device storage
- [x] Verify: `flutter analyze && flutter test`

## Risks / Out of scope
- **Risks**: custom drag grid may need a small amount of gesture tuning; robot drag can be flaky if selectors are weak; short-view scroll behavior must stay stable across window sizes
- **Out of scope**: real dashboard metrics, touch drag support, router changes, sync/server persistence, third-party reorder package
