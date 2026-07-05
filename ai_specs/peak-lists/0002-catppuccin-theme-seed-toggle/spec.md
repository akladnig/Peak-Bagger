---
type: Spec
title: Catppuccin Theme Seed Toggle
---

## Problem

`lib/theme.dart` already replaced many matching hardcoded literals inside `CatppuccinColors` with semantic `colorScheme` reads and already exposes shared `lighten` and `darken` helpers for derived theme colors. The remaining gap is that theme creation still has no controlled opt-in `ColorScheme.fromSeed(...)` path, and the spec should treat the current role-based Catppuccin implementation as the baseline that seed-mode work must preserve by default. [L1] [L2] [L3] [L4] [L5] [L6]

## Proposed Outcome

`CatppuccinColors.dark` and `CatppuccinColors.light` continue to use the current manual Catppuccin palette as the default visual contract, including the existing `colorScheme`-driven app bar and matching role reads plus the current `lighten` and `darken` helper behavior. The only new capability added from this point is an opt-in top-level seed-generation switch through localized color-scheme helpers, while existing user entry, exit, back, cancel, retry, persistence, and theme-toggle flows remain unchanged because this work stays inside `lib/theme.dart`. [L1] [L2] [L3] [L4] [L5] [L6]

## User Stories

1. As a developer maintaining the theme, I want the current semantic `colorScheme`-driven Catppuccin implementation preserved as the baseline so future theme changes do not drift back to duplicated matching literals.
2. As a developer tuning derived control states, I want the existing shared `lighten` and `darken` helpers preserved and covered so hover and emphasis colors continue to derive from semantic theme roles instead of copied literals.
3. As a developer experimenting with Material seeded color generation, I want a top-level opt-in switch that can route theme creation through `ColorScheme.fromSeed(...)` without changing the existing manual Catppuccin look by default.
4. As a user switching between the app's existing light and dark modes, I want the current settings-driven theme flow to keep working without new routes, dialogs, loading states, or behavior changes while theme internals are refactored.

## Requirements

1. Keep the current manual Catppuccin light and dark color schemes as the default source of truth. Theme output must stay on the manual branch unless an opt-in top-level seed-generation boolean is explicitly enabled. The default value of that boolean must be `false`. [L6]
2. Preserve the current `CatppuccinColors` baseline behavior where matching hardcoded color literals are read from a local `colorScheme` instance whenever the literal exactly matches an existing semantic role. This preserved baseline includes app-bar colors and other theme-local color assignments such as icon, text, border, and control colors when they match an existing role. [L1] [L2]
3. Preserve the current rule that custom hover, pressed, overlay, or other contrast-tuned values are not replaced with semantic reads unless the custom literal exactly matches an existing `ColorScheme` role. Non-matching values remain explicit literals. [L2]
4. Preserve the current `AppBarTheme` contract where `backgroundColor` resolves from `colorScheme.surface` and `foregroundColor` resolves from `colorScheme.onSurface`, while keeping the existing `elevation`, `surfaceTintColor`, and `shadowColor` behavior unchanged. [L1]
5. Preserve the current downstream contract where theme consumers continue reading from the resolved `colorScheme` rather than from alternate duplicated color constants for the same semantic roles. [L2] [L6]
6. Preserve the existing top-level `lighten(Color color, [double amount = 0.1])` and `darken(Color color, [double amount = 0.1])` helpers in `lib/theme.dart`. Each helper must keep using `HSLColor`, adjusting values relative to the input color, clamping every adjusted channel to `0.0..1.0`, and returning a `Color`. [L3] [L5]
7. Preserve the current helper behavior where `lighten` increases both lightness and saturation by `amount`, while `darken` decreases both lightness and saturation by `amount`. [L5]
8. Preserve the current dark selected search-button hover contract where the hover background derives from `colorScheme.primary` using `darken(colorScheme.primary, 0.08)` so a primary lightness of `0.60` resolves to `0.52` in that hover state. [L4]
9. Add seed-generated color-scheme support as an opt-in top-level non-`const` boolean branch inside theme creation, with the current manual branch preserved as the default behavior and the toggle defaulting to `false`. [L6]
10. Localize manual-versus-seeded scheme selection behind dedicated light and dark scheme helpers so the rest of each `ThemeData` factory can continue reading one resolved `colorScheme` value without disturbing the current manual implementation shape. [L6]
11. When the seed-generation boolean is enabled, build dark and light schemes with `ColorScheme.fromSeed(...)` using the current manual primary `Color(0xFF6347EA)` as `seedColor` for both branches. [L6]
12. Do not pin any generated roles with `copyWith(...)` in this initial seed-mode scope. [L6]
13. The top-level non-`const` seed-generation boolean must act as the deterministic test seam for seeded-mode coverage, and tests that enable the seeded branch must reset it afterward so global state does not leak across cases. [L6]
14. The initial seed-mode implementation must leave a clear seam inside the localized scheme helpers so role pinning can be added later without refactoring the rest of `ThemeData`. [L6]
15. This feature must not add new routes, dialogs, loading indicators, empty states, error copy, retry UX, offline handling, slow-network behavior, or external-service dependencies. Theme generation remains synchronous and local to app startup and rebuilds. [L6]
16. Preserve the existing theme toggle entry point, source-of-truth ownership, and persistence behavior outside `lib/theme.dart`; this spec does not authorize provider, settings, or routing changes. [L6]

## Technical Decisions

1. Keep the current pattern of one resolved `colorScheme` local per theme factory and have `ThemeData`, `AppBarTheme`, text styles, icon styles, and theme extensions read from that object wherever a matching semantic role already exists. [L1] [L2]
2. Keep `lighten` and `darken` as the existing minimal top-level helpers in `lib/theme.dart` rather than introducing a larger theme utility layer. The helpers are a presentation-only seam for local derived-state colors such as hover backgrounds and borders. [L3] [L5]
3. Represent seed-mode experimentation as a top-level non-`const` boolean branch, defaulting to the manual path, rather than introducing runtime UI, persisted user settings, or environment-driven configuration in this scope. This same branch is the intended seeded-mode test seam. [L6]
4. Use the current manual primary `Color(0xFF6347EA)` as `seedColor` for both dark and light `ColorScheme.fromSeed(...)` branches in the initial implementation. [L6]
5. Localize manual and seeded `ColorScheme` selection inside dedicated light and dark scheme helpers so future `copyWith(...)` pinning can be added in one place if design direction changes later. [L6]
6. Treat the existing manual Catppuccin scheme as the source of truth for current user-facing output. Seed mode is an internal alternate generator, not a redesign of the current production theme contract. [L6]

## Testing Strategy

1. Use focused TDD for the remaining theme work and any missing regression coverage: add or extend tests one failing assertion at a time for the existing semantic role reuse, existing helper behavior, existing derived-state colors, and the new seed-branch selection. [L2] [L3] [L4] [L5] [L6]
2. Extend `test/theme_test.dart` as the primary seam for validating the current `CatppuccinColors.dark`, `CatppuccinColors.light`, `AppBarTheme`, existing top-level theme helper behavior, and the new seed branch instead of creating a new broad harness. [L1] [L2] [L6]
3. Add or preserve unit-style assertions that `lighten` increases both HSL lightness and saturation, `darken` decreases both HSL lightness and saturation, and both helpers clamp safely at the `0.0..1.0` boundaries. [L3] [L5]
4. Add or preserve theme-level assertions that the dark selected search-button hover background resolves from `darken(colorScheme.primary, 0.08)` rather than a hardcoded duplicate literal. [L4]
5. Add or preserve theme-level assertions that the manual branch remains the default path and preserves the current Catppuccin outputs when the top-level seed-generation boolean is left at its default `false` value. [L6]
6. Add deterministic coverage for the new opt-in seeded branch by toggling the top-level non-`const` seed boolean inside `test/theme_test.dart`, asserting the seeded branch uses `Color(0xFF6347EA)` as `seedColor`, and resetting the boolean after each seeded-path assertion so global state does not leak across cases. [L6]
7. Prefer unit and theme tests over widget or robot journey tests for this work. No new cross-screen journey is introduced, so robot coverage and stable selectors are not required unless implementation unexpectedly changes an existing user journey. [L6]
8. Run `flutter analyze` and the focused theme test target after implementation; run broader widget coverage only if the final refactor changes existing theme-consumer expectations. [L1] [L2] [L6]

## Out of Scope

1. Adding a runtime UI control for toggling seed mode.
2. Persisting seed-mode choice in settings, providers, or local storage.
3. Pinning seeded roles with `copyWith(...)` in the initial implementation.
4. Redesigning the Catppuccin palette or changing the current manual theme output by default.
5. Refactoring unrelated widgets, routes, or providers outside the minimum theme-consumer assertions needed for validation.

## Follow-Ups

1. If seeded output becomes desirable later, add targeted `copyWith(...)` pinning inside the localized scheme helpers rather than reintroducing scattered hardcoded literals throughout `ThemeData`.

## Notes

1. Relevant files and seams for this work are `lib/theme.dart` and `test/theme_test.dart`.
2. Existing light and dark theme usage already flows through `CatppuccinColors.light` and `CatppuccinColors.dark`, so this work should stay concentrated at that boundary.
3. The current `theme.dart` implementation already includes top-level `lighten` and `darken` helpers, `colorScheme`-derived app-bar colors, and additional matching `colorScheme` substitutions inside `CatppuccinColors`.
4. The current `theme.dart` implementation does not yet expose the opt-in seeded `ColorScheme.fromSeed(...)` branch described in this spec.
5. The remaining delta for this spec is the seeded-branch seam and its focused regression coverage; the baseline role-based Catppuccin behavior is already implemented and should not be re-scoped as fresh feature work.
