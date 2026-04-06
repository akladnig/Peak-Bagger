<goal>
Build Phase 1 of Peak Bagger Flutter app - application skeleton with vertical navigation menu, theme switching, and placeholder screens.

Target users: Mountain enthusiasts who want to track their peak-bagging progress.

MacOS-only for this phase (iOS to follow).
</goal>

<background>
**Tech Stack:**
- Flutter with Dart SDK ^3.8.0
- go_router ^17.2.0 for navigation
- shared_preferences ^2.5.0 for persistent settings
- flutter_riverpod ^3.2.1 for state management
- flutter_lints ^6.0.0 for linting

**Existing Code:**
- @lib/main.dart - Basic Flutter skeleton with MaterialApp

**Theme Colors:**
- Dark mode: Catppuccin Mocha (https://catppuccin.com/palette/)
- Light mode: Catppuccin Latte

**Files to create:**
- @lib/main.dart - Entry point with Riverpod setup
- @lib/app.dart - App configuration with theme and router
- @lib/router.dart - GoRouter configuration
- @lib/theme.dart - Catppuccin theme definitions
- @lib/providers/theme_provider.dart - Theme state management
- @lib/screens/dashboard_screen.dart
- @lib/screens/map_screen.dart
- @lib/screens/peak_lists_screen.dart
- @lib/screens/settings_screen.dart
- @lib/widgets/side_menu.dart - Vertical navigation menu
- @macos/Runner/Assets.xcassets/AppIcon.appiconset/ - Application icon (mountain peak)
</background>

<user_flows>
Primary flow:
1. App launches in full-screen mode
2. Left vertical menu displays with 4 icon-only items
3. User clicks menu icon to navigate to that screen
4. Screen displays placeholder text with screen name
5. User clicks moon/sun icon in top-right to toggle dark/light mode

Navigation flow:
- Dashboard (home) ↔ Map
- Dashboard ↔ Peak Lists
- Dashboard ↔ Settings
- Menu accessible from all screens
</user_flows>

<requirements>
**Functional:**
1. App launches in full-screen mode on MacOS
2. Application icon showing a mountain peak (macOS dock/window icon)
3. macOS window title displays "Peak Bagger"
4. Side menu: 64px wide, left side, icons only, no text labels, no tooltips
5. Four menu items in order (top to bottom): Dashboard, Map, Peak Lists, Settings
6. Each menu item displays icon for navigation
7. Theme toggle at bottom of side menu
8. No headers on screens (clean, full-width content area)
9. Dark mode uses Catppuccin Mocha palette
9. Light mode uses Catppuccin Latte palette
10. Theme defaults to system preference on first launch
11. Theme preference persists via shared_preferences
12. GoRouter handles navigation between screens
13. Each screen displays placeholder text showing screen name

**Theme Configuration:**
- Moon icon (Icons.dark_mode or similar) shown in light mode
- Sun icon (Icons.light_mode or similar) shown in dark mode
- Icon changes to indicate toggling to opposite mode

**Navigation:**
- "/" → Dashboard (initial route)
- "/map" → Map screen
- "/peaks" → Peak Lists screen
- "/settings" → Settings screen

**Icon Mapping:**
| Menu Item | Icon | Tooltip Text |
|-----------|------|--------------|
| Dashboard | `Icons.dashboard` | "Dashboard" |
| Map | `Icons.map` | "Map" |
| Peak Lists | `Icons.landscape` | "Peak Lists" |
| Settings | `Icons.settings` | "Settings" |

**Persistence:**
- Key: "theme_mode" (value: "dark", "light", or "system")
- Load on app startup, save on theme change
</requirements>

<boundaries>
Edge cases:
- First launch with no stored preference: Use system theme
- Invalid stored value (e.g., "darky"): Default to system theme
- shared_preferences fails: Default to system theme
- System theme changes while app running: Do not auto-update (use stored preference)

Error scenarios:
- shared_preferences read failure: Log error, default to system theme
- shared_preferences write failure: Log error, continue with in-memory change
</boundaries>

<implementation>
**Patterns:**
- Use ProviderScope at root for Riverpod
- ThemeNotifier extends StateNotifier<ThemeMode>
- GoRouter with StatefulShellRoute.indexedStack for persistent side menu

**Avoid:**
- Using setState for theme (use Riverpod)
- Hardcoding colors (use theme constants)

**File structure:**
```
lib/
├── main.dart           # Entry point with ProviderScope
├── app.dart            # MaterialApp with theme and router
├── router.dart         # GoRouter configuration
├── theme.dart          # Catppuccin color constants and themes
├── providers/
│   └── theme_provider.dart  # ThemeMode state management
├── screens/
│   ├── dashboard_screen.dart
│   ├── map_screen.dart
│   ├── peak_lists_screen.dart
│   └── settings_screen.dart
└── widgets/
    └── side_menu.dart  # Vertical navigation menu
```
</implementation>

<validation>
**Unit tests:**
- ThemeProvider: Load/save theme preferences, default to system, handle invalid stored values
- Theme constants: Verify Mocha and Latte colors match Catppuccin spec
- System theme detection using MediaQuery.platformBrightnessOf

**Widget tests:**
- SideMenu: Renders 4 icons, navigates on tap, has correct theme background
- Each screen: Displays correct placeholder text
- ThemeToggle: Shows correct icon for current mode, toggles on tap, displays in header

**Integration tests:**
- App launches to Dashboard
- Navigation between all 4 screens works
- Theme toggle persists across app restart
- Invalid stored theme value defaults to system theme

**Baseline automated coverage:**
- Logic: ThemeProvider theme loading/saving, system theme detection
- UI: Side menu rendering, screen placeholders, theme toggle
- Journey: Full navigation flow + theme persistence
</validation>

<done_when>
- App runs on MacOS simulator in full-screen mode
- Window title displays "Peak Bagger"
- macOS dock shows mountain peak application icon
- Left menu shows 4 icon-only items (Dashboard, Map, Peak Lists, Settings) - no text, no tooltips
- Clicking menu item navigates to corresponding screen
- Each screen displays "Dashboard", "Map", "Peak Lists", or "Settings" placeholder
- Top-right icon toggles between moon (light mode) and sun (dark mode) - now at bottom of side menu
- Theme persists across app restarts
- All tests pass
</done_when>