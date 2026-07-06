---
type: Work Item
title: Settings Seed Swatch Picker UI
parent: ../spec.md
---

## What to build
Replace the `Theme Colours` dropdown in `SettingsScreen` with a single horizontal seed-colour swatch row that uses the selected seed-colour preference from Work Item 01, renders the exact swatches from the Spec in the required order, updates the selected seed colour immediately on tap, and keeps the existing seeded scheme variant and contrast controls in place.

## Required context
- `lib/screens/settings_screen.dart` currently renders the `Theme Colours` dropdown between the theme mode toggle and the seeded scheme controls. Keep the picker local to `SettingsScreen` and preserve the surrounding theme control structure.
- `lib/providers/theme_provider.dart` supplies the selected seed colour and persistence hook used by the settings control.
- `test/widget/settings_screen_theme_test.dart` already uses stable `Key` selectors for the settings theme controls; extend that convention for the swatch row and each swatch so direct tapping and selected-state checks stay deterministic.
- No dependency change is expected. Preserve the existing widget-test split from the Spec; no robot journey coverage is needed unless implementation scope changes.

## Acceptance criteria
- [ ] `SettingsScreen` removes the user-facing Catppuccin/Seeded palette choice so the existing `Theme Colours` dropdown and `Catppuccin` option are absent from the final UI.
- [ ] The theme settings area shows a single horizontal linear swatch row of rounded-square swatches in this exact order, with these exact labels and values: `baseColor('My Seed Colour', Color(0xff7e47eb))`, `indigo('Indigo', Colors.indigo)`, `blue('Blue', Colors.blue)`, `teal('Teal', Colors.teal)`, `green('Green', Colors.green)`, `yellow('Yellow', Colors.yellow)`, `orange('Orange', Colors.orange)`, `deepOrange('Deep Orange', Colors.deepOrange)`, `pink('Pink', Colors.pink)`, `brightBlue('Bright Blue', Color(0xFF0000FF))`, `brightGreen('Bright Green', Color(0xFF00FF00))`, and `brightRed('Bright Red', Color(0xFFFF0000))`.
- [ ] Tapping a swatch updates the active seed colour immediately for the current session and delegates persistence through the shared theme preference flow without adding a new route, dialog, loading state, empty state, error copy, offline behavior, or retry flow.
- [ ] The active swatch exposes a visible selected state that does not rely on color alone, each swatch keeps a mobile-usable tap target, each swatch exposes its exact Requirement 3 label through widget semantics, and the active swatch exposes a selected semantic state.
- [ ] The picker remains usable on narrow screens and with large text settings by horizontally scrolling when needed instead of wrapping or clipping.
- [ ] Focused TDD drives the settings UI changes in this item, and `test/widget/settings_screen_theme_test.dart` verifies that the palette dropdown is gone, the swatch row renders, the exact swatch labels exist, a restored stored swatch is shown as selected after preferences load, the selected swatch state updates, tapping a swatch changes the persisted seed colour, and the swatches expose stable selectors and semantics for deterministic widget assertions.

## Covers
- User Stories: 1-3
- Requirements: 1-4, 7-9
- Technical Decisions: 2, 4-5
- Testing Strategy: 1, 3, 5-6
- Interview Ledger: L1-L2

## Blocked by
- `01-seed-theme-preference-and-theme-path-cleanup.md`
