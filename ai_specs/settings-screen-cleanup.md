<goal>
Refactor `./lib/screens/map_screen.dart` into smaller, cohesive screen-scoped files without changing route behavior, widget keys, or user-visible interactions.

Findings fromn a prior query:
lib/screens/settings_screen.dart:42-765 mixes screen state, action tiles, dialogs, and settings sections. The natural splits are top action tiles (:48-166), result/failure dialogs (:376-556), track filter section (:558-667), and peak correlation section (:670-713). That would leave SettingsScreen as a coordinator instead of a 700+ line file.
