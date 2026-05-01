# Peak Bagger App
## Goal
A flutter app that imports GPX files and then automatically finds any matching peaks and displays the tracks on a map. Displays a Dashboard screen similar to Summit Bag.

- Support for MacOs only. iOs to supported in future.

### Phase 1
#### Features
Application skeleton with vertical menu system on left.
- Left hand menu items from top to bottom, showing icons only, no text:
  - Dashboard
  - Map
  - Peak Lists
  - Settings
- dark/light icon at top right of screen which changes dark/light mode when clicked. Icon to change from Moon to Sun and vice-versa.
- Dark mode to use "Catppuccin Mocha" - refer to https://catppuccin.com/palette/ and https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.mdj
- Light mode to used "Catppuccin Latte"
- Dark Mode defaults to system preferences on first launch.
- Setting persists via shared preferences.
- app to start in full screen mode
- Add a application icon showing a peak to the top left of the application.

Each item navigates to a new screen. Use GoRouter for navigation.

Each screen to display placeholder text showing the screen name.
Details of subsequent screens to be specified, planned and implemented in subsequent phases.

### Dependencies to Add (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^17.2.0
  shared_preferences: ^2.5.0
  flutter_riverpod: ^3.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

