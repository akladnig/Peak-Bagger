---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: How should the `AppBarTheme` stop using duplicated hardcoded colors in `lib/theme.dart`?

Answer: Use `colorScheme.surface` for the background and `colorScheme.onSurface` for the foreground.

Decision: `AppBarTheme` now derives its background and foreground from `ColorScheme.surface` and `ColorScheme.onSurface` instead of repeating matching raw color literals.

Constraints:
- Keep the current `elevation`, `surfaceTintColor`, and `shadowColor` behavior unless a later requirement changes them.

### L2

Status: current

Question: Beyond the app bar, how broadly should hardcoded theme colors be replaced inside `CatppuccinColors`?

Answer: Replace any hardcoded colours with `colorScheme` colors where there is a match.

Decision: Inside `CatppuccinColors`, matching hardcoded colors now resolve through `colorScheme` role references only when the literal exactly matches an existing semantic role; non-matching custom colors remain explicit literals.

Constraints:
- Do not replace custom hover, pressed, overlay, or contrast-tuned values unless they match an existing `ColorScheme` role.

### L3

Status: current

Question: What shared color-derivation helpers should `theme.dart` provide for theme-local derived colors?

Answer: Implement top-level `lighten(Color color, [double amount = 0.1])` and `darken(Color color, [double amount = 0.1])` using `HSLColor`, clamping results to `0.0..1.0`.

Decision: `lib/theme.dart` now exposes top-level `lighten` and `darken` helpers that derive colors through `HSLColor` and clamp adjusted values safely.

### L4

Status: current

Question: What exact derived color should replace the dark selected search-button hover background?

Answer: Use `darken` on `primary`. `primary` has a lightness of `60`, and the hover state should have a lightness of `52`.

Decision: The dark selected search-button hover background now derives from `colorScheme.primary` using `darken(colorScheme.primary, 0.08)`.

Constraints:
- Preserve derivation from the current theme primary color rather than restoring a separate hardcoded hover literal.

### L5

Status: current

Question: How should `lighten` and `darken` handle saturation?

Answer: Update `darken` and `lighten` to include saturation, but `lighten` increases saturation and `darken` decreases saturation.

Decision: `lighten` now increases both lightness and saturation by `amount`, while `darken` decreases both lightness and saturation by `amount`, with all adjusted values clamped to `0.0..1.0`.

### L6

Status: current

Question: How should optional `ColorScheme.fromSeed` support be introduced without changing the current Catppuccin look by default?

Recommended Answer:
- Keep the manual scheme as the default path.
- Use seed generation only as an opt-in via a top-level boolean that defaults to `false`.
- Extract dark and light scheme creation behind helper functions so the manual and seeded branches stay localized.
- When seed mode is enabled, use `ColorScheme.fromSeed(...)` with no pinned `copyWith(...)` overrides for now.

Answer: ok

Decision: `CatppuccinColors` should keep the current manual Catppuccin schemes as the default source of truth and add an opt-in top-level boolean, defaulting to `false`, for `ColorScheme.fromSeed(...)` generation through localized light and dark scheme helpers.

Constraints:
- The top-level seed toggle should be a non-`const` `bool` so tests can enable the seeded branch deterministically and reset it afterward.
- Both seeded branches should use the current manual primary `Color(0xFF6347EA)` as `seedColor`.
- Do not pin any generated roles with `copyWith(...)` in the initial seed-mode implementation.
- Leave a clear helper seam so role pinning can be added later without restructuring the rest of `ThemeData`.
- Keep all downstream theme consumers reading from the resolved `colorScheme`.
- The current `theme.dart` implementation still uses manual schemes only; the seeded branch remains future work.
