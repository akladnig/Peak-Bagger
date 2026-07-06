---
type: Work Item
title: Seed Theme Preference And Theme Path Cleanup
parent: ../spec.md
---

## What to build
Replace the palette-mode persistence flow with a dedicated seed-colour preference that stores the selected swatch id from the Spec's exact swatch list, remove the legacy `theme_color_palette` preference during theme bootstrap/load, restore a valid stored swatch before the first visible frame, and make the selected seed colour the only theme-colour source for both light and dark themes.

## Required context
- `lib/providers/theme_provider.dart` contains the existing shared-preferences loading pattern, theme bootstrap behavior, and the legacy `theme_color_palette` key that must stop being read and written.
- `lib/app.dart` currently builds `ThemeConfig` from the palette provider and hardcodes `Color(0xFF7E47EB)`; this item should move app bootstrap to the selected swatch source of truth.
- `lib/theme.dart` contains `ThemeConfig`, `CatppuccinColors.darkWith`, `CatppuccinColors.lightWith`, and the current Catppuccin/manual non-seeded branch that this item removes from the active path.
- `test/theme_test.dart` is the right place for seeded-theme path coverage. Follow the repository's existing deterministic shared-preferences fake pattern for provider-side persistence coverage.

## Acceptance criteria
- [ ] Theme preferences store the selected seed colour under a dedicated seed-colour preference key using the exact swatch id from Requirement 3, default to `My Seed Colour` `Color(0xff7e47eb)` when no usable value is stored, and no longer read or write `theme_color_palette`.
- [ ] Theme preference bootstrap/load removes the legacy `theme_color_palette` key on upgraded installs even before the user changes swatches, while preserving the current in-memory choice for the session if persistence fails.
- [ ] A valid stored seed swatch is restored before the first visible frame so the app does not briefly render `My Seed Colour` and then switch to the restored swatch.
- [ ] The app theme uses the selected seed colour as the only theme-colour source, seeded theme generation is unconditional, and no Catppuccin-specific palette, hardcoded Catppuccin theme colour constant, `config.useSeedGeneratedColorScheme` branch, or other manual non-seeded theme path remains responsible for the active light or dark theme.
- [ ] Theme mode, seeded scheme variant, and seeded contrast level behavior remain available and unchanged apart from sharing the same seeded theme source.
- [ ] Focused TDD drives the provider/theme-state changes in this item, including tests that cover the default `My Seed Colour` swatch, each supported swatch value, startup restore from a valid stored swatch id before first frame, persistence across rebuilds, removal of the legacy `theme_color_palette` preference during bootstrap/load, fallback to `My Seed Colour` when the stored seed-colour value is missing or invalid, and seeded color-scheme derivation in `test/theme_test.dart` for both light and dark themes.

## Covers
- User Stories: 3-4
- Requirements: 3-7, 9
- Technical Decisions: 1-3
- Testing Strategy: 1-2, 4
- Interview Ledger: L1-L2

## Blocked by
None - ready to start
