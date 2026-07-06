---
type: Spec
title: Seed Colour Swatch Picker
---

## Problem

The current theme settings still expose a Catppuccin/Seeded palette choice and the app theme still treats Catppuccin as a user-facing option. That leaves the settings flow one step removed from the actual control the user wants: choosing the seed colour directly from a fixed set of swatches. [L1] [L2]

## Proposed Outcome

The settings screen replaces the palette selector with a horizontal seed-colour swatch picker. The app uses the selected seed colour as the only theme-colour source, seeded theme generation is always enabled, and the chosen swatch persists across rebuilds and restarts. The Catppuccin option and hardcoded Catppuccin theme colours are removed from the flow. [L1] [L2]

## User Stories

1. As a user, I can choose the app seed colour from Settings using swatches instead of a Catppuccin/Seeded palette dropdown. [L1] [L2]
2. As a user, I can select one of the exact listed swatches and see which one is active. [L2]
3. As a user, my selected seed colour is remembered after rebuilds and app restarts. [L2]
4. As a user, the app continues to use the selected seed colour for seeded theme generation without reintroducing a Catppuccin option. [L1] [L2]

## Requirements

1. Remove the user-facing Catppuccin/Seeded palette choice from Settings. The existing Theme Colours dropdown and Catppuccin option do not remain in the final UI. [L1]
2. Add a seed colour picker in the Settings theme area as a single horizontal linear swatch row. The swatches are shown as rounded squares, the row scrolls horizontally when needed, and the selected swatch has a visible selected state that does not rely on color alone. [L2]
3. The swatch list must appear in this exact order and with these exact labels and color values:
   1. `baseColor('My Seed Colour', Color(0xff7e47eb))`
   2. `indigo('Indigo', Colors.indigo)`
   3. `blue('Blue', Colors.blue)`
   4. `teal('Teal', Colors.teal)`
   5. `green('Green', Colors.green)`
   6. `yellow('Yellow', Colors.yellow)`
   7. `orange('Orange', Colors.orange)`
   8. `deepOrange('Deep Orange', Colors.deepOrange)`
   9. `pink('Pink', Colors.pink)`
   10. `brightBlue('Bright Blue', Color(0xFF0000FF))`
   11. `brightGreen('Bright Green', Color(0xFF00FF00))`
   12. `brightRed('Bright Red', Color(0xFFFF0000))` [L2]
4. Tapping a swatch sets the app seed colour to that swatch immediately and persists the choice for future rebuilds and app launches. On app startup, the last stored seed swatch must be applied before the first visible frame. The app must not briefly render `My Seed Colour` and then switch to the restored swatch. [L2]
5. Persist the selected seed colour under a dedicated theme seed-colour preference key using the swatch id from Requirement 3. The app no longer reads or writes the existing `theme_color_palette` preference. If that legacy preference exists, remove it during theme preference bootstrap/load so upgraded installs clear the obsolete key even before the user changes swatches. When no seed-colour value is stored or the stored value cannot be used, the default seed colour is `My Seed Colour` `Color(0xff7e47eb)`, matching `_seedColor` in `lib/theme.dart`.
6. The app theme must use the selected seed colour as the only theme-colour source. Seeded theme generation is always enabled. No Catppuccin-specific palette, hardcoded Catppuccin theme colour constant, or manual non-seeded theme branch remains in the implementation path. [L1]
7. Theme mode, seeded scheme variant, and seeded contrast level controls remain available and unchanged apart from sharing the same seeded theme source. [L1]
8. The picker must remain usable on narrow screens and with large text settings. If the swatches do not fit, horizontal scrolling is required rather than wrapping or clipping. Each swatch must keep a mobile-usable tap target size, expose its exact Requirement 3 label through widget semantics, and expose a selected semantic state for the active swatch. [L2]
9. The change must not add new routes, dialogs, loading states, empty states, error copy, offline behavior, or retry flows. If persistence fails, the current in-memory choice still applies for the session. [L1] [L2]

## Technical Decisions

1. Treat the selected seed colour as the source of truth for theme generation, make seeded theme generation unconditional, and remove the user-facing palette mode from the settings flow. [L1]
2. Reuse the existing theme preferences persistence pattern for storing the selected seed colour so the picker survives rebuilds and restarts, but store the selected swatch as its stable id rather than reusing the old palette enum preference. [L2]
3. Remove redundant theme-selection code that only supported Catppuccin versus seeded branching, including `config.useSeedGeneratedColorScheme` checks and manual non-seeded colour branches that are no longer reachable after this change. [L1]
4. Keep the new picker local to `SettingsScreen`; do not introduce a new route or modal picker. [L1] [L2]
5. Preserve the existing seeded theme controls and their current structure so the picker only replaces the palette selector. [L1]

## Testing Strategy

1. Use focused TDD for the settings UI and theme-state changes.
2. Extend provider/theme tests to cover the default `My Seed Colour` seed colour, each supported swatch value, startup restore from a valid stored swatch id before first frame, persistence across rebuilds, removal of the legacy `theme_color_palette` preference during theme preference bootstrap/load, and fallback to `My Seed Colour` when the stored seed-colour value is missing or invalid. [L2]
3. Extend `test/widget/settings_screen_theme_test.dart` to verify the palette dropdown is gone, the swatch row renders, the exact swatch labels exist, a restored stored swatch is shown as selected after preferences load, the selected swatch state updates, and tapping a swatch changes the persisted seed colour. [L1] [L2]
4. Update `test/theme_test.dart` to verify that both light and dark app themes derive their seeded color schemes from the selected seed colour swatch rather than a fixed color constant, and that no manual non-seeded theme branch remains responsible for the active theme path. [L1] [L2]
5. No robot journey coverage is required unless the final implementation introduces a new cross-screen flow; widget and provider tests are the expected split. [L1] [L2]
6. Use deterministic shared-preferences fakes and stable widget selectors plus semantics for the swatches so widget tests can verify labels, selection state, and direct tapping reliably. [L2]

## Out of Scope

1. Custom freeform color entry.
2. Changing theme mode, seeded scheme variant, or seeded contrast level behavior.
3. Introducing additional theme palettes beyond the listed swatches.

## Notes

1. Relevant starting files are `lib/app.dart`, `lib/screens/settings_screen.dart`, `lib/providers/theme_provider.dart`, `lib/theme.dart`, `test/widget/settings_screen_theme_test.dart`, and `test/theme_test.dart`. [L1] [L2]
2. The current code still exposes a Catppuccin/Seeded palette selector, a fixed seed color in app bootstrap, and conditional theme branching; this spec replaces that user-facing choice with direct seed swatch selection and a seeded-only theme path. [L1] [L2]
