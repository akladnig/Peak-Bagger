## Overview

Phase 1 app skeleton: vertical navigation, theme switching, placeholder screens. MacOS-only.

**Spec**: `ai_specs/001-prompt-spec.md`

## Context

- **Structure**: Simple flat (single main.dart)
- **State management**: Riverpod (to add)
- **Reference implementations**: None yet (greenfield)
- **Assumptions**: Using Flutter's built-in full-screen mode for macOS

## Plan

### Phase 1: Dependencies & Theme

- **Goal**: Add deps + create theme constants

- [ ] `pubspec.yaml` - add go_router ^17.2.0, shared_preferences ^2.5.0, flutter_riverpod ^3.2.1
- [ ] `lib/theme.dart` - Catppuccin Mocha/Latte color constants + ThemeData

- TDD: ThemeData dark/light modes use correct Catppuccin colors
- Verify: `flutter pub get` && `flutter analyze`

### Phase 2: Theme Provider

- **Goal**: Theme state with persistence

- [ ] `lib/providers/theme_provider.dart` - ThemeNotifier with SharedPreferences load/save
- [ ] `lib/providers/` - create directory if needed

- TDD: Provider loads stored value on init, defaults to system, saves on change
- TDD: Invalid stored values default to system theme
- Verify: `flutter analyze` && `flutter test`

### Phase 3: Router & Menu

- **Goal**: GoRouter with persistent side menu

- [ ] `lib/router.dart` - GoRouter with StatefulShellRoute.indexedStack, 4 routes (/, /map, /peaks, /settings)
- [ ] `lib/widgets/side_menu.dart` - Vertical menu, 64px wide, 4 icon-only items

- TDD: NavigationShell preserves menu state across route changes
- Verify: `flutter analyze`

### Phase 4: Screens

- **Goal**: Placeholder screens with header

- [ ] `lib/screens/dashboard_screen.dart` - placeholder "Dashboard" + header with theme toggle
- [ ] `lib/screens/map_screen.dart` - placeholder "Map" + header with theme toggle
- [ ] `lib/screens/peak_lists_screen.dart` - placeholder "Peak Lists" + header with theme toggle
- [ ] `lib/screens/settings_screen.dart` - placeholder "Settings" + header with theme toggle
- [ ] `lib/widgets/theme_toggle.dart` - moon/sun icon button that toggles theme

- TDD: Each screen shows correct placeholder text
- TDD: Theme toggle shows correct icon for current mode
- Verify: `flutter analyze`

### Phase 5: App Shell

- **Goal**: Wire everything together

- [ ] `lib/app.dart` - MaterialApp with theme from provider, router
- [ ] `lib/main.dart` - ProviderScope wrap, run app

- Verify: `flutter analyze` && `flutter test`

### Phase 6: macOS Configuration

- **Goal**: Full-screen, window title, app icon

- [ ] `macos/Runner/Info.plist` - set CFBundleName to "Peak Bagger"
- [ ] `macos/Runner/Assets.xcassets/AppIcon.appiconset/` - replace with mountain peak icon
- [ ] `lib/app.dart` - set initial route to full-screen (use WindowController for macOS)

- Verify: Run on macOS simulator, check window title and icon

## Risks / Out of Scope

- **Risks**: None identified
- **Out of scope**: iOS support, GPX import, map display, peak matching (future phases)