---
type: Work Item
title: Align shared field and Data grid styling
parent: ../spec.md
---

## What to build

Complete Spec 0068's bounded central-theme prerequisite before dependent Schema/form integration. Extend the existing theme owners, remove conflicting affected Admin decoration overrides, and verify the rendering and existing consumers of the changed definitions. This is not an app-wide component/layout compliance sweep, Search behaviour redesign or theme Settings redesign.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before affected feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, amendment 2026-10-19, especially §§4–5, 8–9.
- `ai_specs/app-profile.md` — Desktop wide and approved content-size range.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md` — R1, R8.3–6, Technical Decision 7, Testing Strategy 7/11 and source conflicts.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/interview-ledger.md`.
- `AGENTS.md`, `GLOSSARY.md`, `lib/theme.dart`, `lib/core/constants.dart`, `lib/core/app_sizes.dart`.
- `lib/screens/objectbox_admin_screen_controls.dart`, `lib/screens/objectbox_admin_screen_table.dart`, `lib/screens/objectbox_admin_screen_details.dart`.
- `test/theme_test.dart`, affected Admin widget tests and existing consumer regressions discovered during the theme audit.
- `ai_specs/peak-lists/0060-shared-data-grid-style/spec.md` — preserved consumer semantics only; its older colours and 1280 × 800 target do not override the amended standard/profile/0068.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] Central definitions in `lib/theme.dart` own the field decoration for both application themes. Define `searchControlFontSize = 14.0` and `searchControlIconSize = 24.0`; labels use the former with `colorScheme.onSurface`, dense layout and actual text scaling. Ordinary field labels remain visible independently of placeholders.
- [x] The default shape is `OutlineInputBorder(borderSide: BorderSide(color: colorScheme.onPrimary))` with supplied constructor defaults, not the card/popup radius. Enabled/unfocused idle uses `colorScheme.outline`, width 1; enabled/unfocused hover uses the currently effective configured seed, width 1; focused outline uses that seed, width 2. Keep error/disabled border priority. For filled outlined fields, centrally resolve `activeIndicatorBorder` and leave `enabledBorder` unset so hover is resolved by Flutter.
- [x] Enabled pointer hover, including focused hover, uses exactly `Color.alphaBlend(primary.withValues(alpha: .08), Color.alphaBlend(primary.withValues(alpha: .12), surface))` from the current scheme. Share the selected-Data/hover layer definitions centrally, avoid double overlays, restore prior fill on exit and suppress disabled hover. Add no idle selected tint or focus-only fill. Live seed/scheme changes and rollback update the rendered roles without hard-coded seed colours.
- [x] Affected editable fields inherit central decoration instead of repeating conflicting borders/text styles. Preserve inline error wrapping, retained input, disabled/error styling and actual text scale. Do not add field-associated tooltips, per-field submit buttons or magnifying-glass prefixes to ordinary fields. Existing Search consumers retain accessible names and their applicable shared presentation without changing filtering/submission/shortcut behaviour in this item.
- [x] Applicable `DataGridTheme` metrics are `labelLarge` headers, `bodyMedium`/`onSurface` rows, header vertical padding 4, row horizontal/vertical padding 12/6, column gaps 12, and local `onPrimary` dividers of thickness 1. Primary/value/action widths 144/160/72 remain component bases, not fixed pane dimensions; no artificial action column is required for the later read-only Schema table. Do not change the global scheme to fake local divider roles.
- [x] Selected fill subtracts 0.30 from HSL saturation and lightness, each clamped to 0…1; selected horizontal borders subtract 0.08. Use effective seed as the dark base and `primaryContainer` as the light base. Hover is `Color.lerp(selectedRowColor, Colors.white, 0.10)`; unselected press is primary at 0.12 over surface. Selection takes precedence over hover/press, disabled rows suppress interaction feedback, and independent keyboard focus remains a visible 2-pixel primary outline even when selected. Integrate and test the consumers needed to render these states, not just token values.
- [x] Where affected icon actions are touched, retain the shared circular transparent-idle/focus-only background, onSurface 0.08 hover/0.12 press overlays, 2-pixel primary circular focus outline and dimmed/locked disabled state. Admin row trash retains exact `Colors.red` / `#F44336` with transparent idle backing; confirmation Delete and other destructive actions retain semantic error colours. Labelled footer buttons retain their shared `primaryContainer`/`onPrimaryContainer` pairing.
- [x] Audit existing consumers of changed central definitions and record their affected regression coverage. Preserve data, validation, sorting, selection, navigation, domain colours and action semantics; do not turn read-only schema rows into interactive controls or broaden unrelated styling work.
- [x] Focused unit/rendered widget tests cover both themes and a non-default effective seed, exact metrics/formulas and 14/24 tokens, visible/scaled labels and errors, pointer entry/exit, focused hover, disabled/error priority, selected precedence, independent focus and live theme changes. Merely asserting theme inheritance is insufficient.
- [x] Verify affected layout at 1280 × 960 logical-point content and representative larger widths/heights, including height 960 and enlarged text scale: width ≥1280, height ≥960, no fixed app-defined maximum, one wide layout with wrapping/scrolling and reachable labels/controls. Do not reduce text scale, introduce breakpoints/compact/iOS obligations, change native window configuration or enter native full-screen. Retain the maximised-launch target; native full-screen remains Pending and non-blocking.
- [x] Run `flutter test test/theme_test.dart`, affected consumer/Admin regressions, `flutter analyze` and full `flutter test`; perform affected macOS runtime checks and record failures/blockers honestly. Ordinary tests require no production database, mapping volume, network, credentials or template checkout. Reuse existing deterministic seams and robot regressions where affected; no new robot framework or mandatory red-green process is required. No database migration, generated/model edits, new preference or persistence boundary is introduced.

## Covers

- Requirements: R1; R8.3–6.
- Technical Decisions: 7, with architecture/persistence safeguards from 4/6.
- Testing Strategy: 7, 8–9, 11.
- Interview Ledger: L1, L6, L7, L9, L14–L16.

## Blocked by

None — completed 2026-10-20.

## Implementation evidence

See [Work Item 01 verification](../implementation-01-verification.md) for the central-theme/consumer audit, rendered-state tests, supported-size and native macOS checks, retained Search scope boundary, and command outcomes. No database/model or native window source is changed.
