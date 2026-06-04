## Overview

Move theme control out of the shared app bar and into Settings.
Keep provider/persistence unchanged; just relocate UI + coverage.

**Spec**: quick plan from task description; no standalone spec file

## Context

- **Structure**: screen-driven Flutter app; shell routes + settings list in `lib/screens`
- **State management**: Riverpod `themeModeProvider` (`ThemeModeNotifier` + SharedPreferences)
- **Reference implementations**: `lib/router.dart`, `lib/screens/settings_screen.dart`, `lib/providers/theme_provider.dart`, `test/widget/gpx_tracks_shell_test.dart`, `test/widget/open_route_service_settings_test.dart`
- **Assumptions/Gaps**: binary dark/light toggle only; place after track filter section to preserve above-the-fold layout; no system-mode UI change

## Plan

### Phase 1: Settings control

- **Goal**: expose theme toggle inside settings
- [x] `lib/screens/settings_screen.dart` - add theme row after track filter section; read `themeModeProvider`; switch/tap toggles `toggleTheme()`; add stable key
- [x] `test/widget/settings_screen_theme_test.dart` - TDD: row visible; tap flips mode; persisted mode reflected after pump/rebuild
- [x] Verify: `flutter analyze` && `flutter test test/widget/settings_screen_theme_test.dart`

### Phase 2: Shell cleanup

- **Goal**: remove app-bar theme action; preserve shell layout
- [x] `lib/router.dart` - drop `themeModeProvider`/`isDark` app-bar action and related padding; keep summary strip intact
- [x] `test/widget/gpx_tracks_shell_test.dart` - TDD: shared app bar no longer exposes `app-bar-theme-action`; existing shell assertions stay green
- [x] `test/widget/map_peak_list_selection_test.dart` - remove stale theme-action expectation from app-bar summary coverage
- [x] Verify: `flutter analyze` && `flutter test test/widget/gpx_tracks_shell_test.dart test/widget/map_peak_list_selection_test.dart`

## Risks / Out of scope

- **Risks**: SharedPreferences async load flake; settings row may need scroll selector if placed too low; app-bar spacing regressions
- **Out of scope**: full theme-mode picker, system-mode UX, broader settings redesign
