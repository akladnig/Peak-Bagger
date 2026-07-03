## Overview

Light theme semantic parity with dark theme shape; light values stay Latte.
Thin slice first: explicit theme contract, then direct panel consumer, then other live consumers.

**Spec**: `ai_specs/light-theme-semantic-parity-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/providers`, `lib/screens`, `lib/widgets`, `lib/services`
- **State management**: Riverpod; `NotifierProvider` + `Provider` + `ConsumerWidget`
- **Reference implementations**: `lib/theme.dart`, `lib/screens/map_screen_panels.dart`, `lib/widgets/side_menu.dart`
- **Assumptions/Gaps**: `SelectedButtonThemeData` has no real consumer; remove, not mirror. `objectbox_admin_shell_test.dart` likely enough for `SideMenu`; add `test/widget/side_menu_test.dart` only if shell seam is too indirect.

## Plan

### Phase 1: Theme Contract Slice

- **Goal**: explicit light semantic shape; parity at theme boundary
- [x] `lib/theme.dart` - mirror dark explicit role shape in `_createLightTheme()` for in-scope roles; set agreed light values for `secondary`, `onSecondary`, `tertiary`, `onTertiary`, `primaryContainer`, `onPrimaryContainer`, `surfaceContainer`, `outline`, `outlineVariant`
- [x] `lib/theme.dart` - align light `AppBarTheme` structure with dark: scaffold background pairing, foreground, elevation, transparent tint, shadow
- [x] `lib/theme.dart` - keep `iconTheme.color` intentionally equal to `colorScheme.onPrimaryContainer` in both themes
- [x] `lib/theme.dart` - remove `SelectedButtonThemeData` if still unreferenced; keep `RowHoverTheme` + `SearchButtonThemeData` parity intact
- [x] `test/theme_test.dart` - replace smoke checks with semantic parity assertions: explicit light values, app bar structure, extension presence parity, `iconTheme.color == onPrimaryContainer`, dark unchanged for guarded roles
- [x] TDD: light theme exposes panel-surface `secondary` / `onSecondary` pair with agreed values -> then implement
- [x] TDD: light app bar mirrors dark structural contract with light values -> then implement
- [x] TDD: both themes expose only live extensions; `SearchButtonThemeData` + `RowHoverTheme` present, `SelectedButtonThemeData` absent if unused -> then implement
- [x] TDD: both themes keep `iconTheme.color == colorScheme.onPrimaryContainer` -> then implement
- [x] Verify: `flutter analyze` && `flutter test test/theme_test.dart` && `flutter test`

### Phase 2: Panel Foreground Slice

- **Goal**: `secondary` panel surface + local `onSecondary` foreground contract
- [x] `lib/screens/map_screen_panels.dart` - add panel-scoped foreground override for `MapTrackInfoPanel`; direct descendants on the `secondary` card resolve text/icon semantics from `colorScheme.onSecondary`
- [x] `lib/screens/map_screen_panels.dart` - remove panel-local `onSurface` icon coloring for close, edit, timing info, recalc, walking-speed controls where they are direct panel foreground descendants
- [x] `lib/screens/map_screen_panels.dart` - keep visibility `Switch` default Material semantics; no local thumb/track/overlay overrides
- [x] `lib/screens/map_screen_panels.dart` - keep export control as separate button surface via `FilledButton.icon`; no manual icon color or local foreground override
- [x] `test/widget/map_track_info_panel_test.dart` - pump `CatppuccinColors.light`; assert panel card uses `secondary`, direct descendants use `onSecondary`, switch stays default, export button does not inherit panel override
- [x] `test/widget/map_route_info_panel_test.dart` - pump `CatppuccinColors.light`; assert route branch timing labels/icons/edit-close controls follow panel contract; export button and switch remain explicit exceptions
- [x] TDD: track branch panel title, section titles, row labels/values, close icon, visibility label resolve to `onSecondary` -> then implement
- [x] TDD: route branch edit/close, timing info/recalculate icons, timing labels, walking-speed controls resolve to `onSecondary` -> then implement
- [x] TDD: switch keeps default semantics; export button stays separate surface and avoids inherited `onSecondary` foreground -> then implement
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_track_info_panel_test.dart` && `flutter test test/widget/map_route_info_panel_test.dart` && `flutter test`

### Phase 3: Consumer Regression Slice

- **Goal**: real `primaryContainer` and `surfaceContainer` consumers guarded
- [ ] `test/widget/objectbox_admin_shell_test.dart` - add concrete `SideMenu` selected/unselected inversion assertions against `primaryContainer` and theme icon color; add `test/widget/side_menu_test.dart` only if shell assertions are too indirect
- [ ] `test/widget/elevation_profile_chart_test.dart` - pump `CatppuccinColors.light`; assert disabled time toggle background resolves from `theme.colorScheme.surfaceContainer`
- [ ] `lib/widgets/side_menu.dart` - touch only if tests expose a mismatch between selected/unselected inversion and centralized theme contract
- [ ] `lib/widgets/elevation_profile_chart.dart` - touch only if test exposes a missing seam or non-theme fallback
- [ ] TDD: real `primaryContainer` consumer preserves selected/unselected inversion under light theme -> then implement only if failing
- [ ] TDD: disabled time toggle resolves disabled background from `surfaceContainer` under light theme -> then implement only if failing
- [ ] Verify: `flutter analyze` && `flutter test test/widget/objectbox_admin_shell_test.dart` && `flutter test test/widget/elevation_profile_chart_test.dart` && `flutter test`

## Risks / Out of scope

- **Risks**: panel-scoped override accidentally bleeds onto export button; light `secondary` reads accent-like instead of neutral surface; test seams may need descendant-style inspection rather than simple widget field checks
- **Out of scope**: settings flow, routing, providers, package changes, broad screen restyling, extra theme-role expansion beyond audited live consumers, robot journey tests
