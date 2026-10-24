---
type: Work Item
title: Shared field and dropdown presentation
parent: ../spec.md
---

## What to build

Extend the existing shared field foundation with complete wrapping errors and one reusable selection-only dropdown presentation. Support independently caller-configured labelled-field / icon-only triggers and label-only / icon-plus-label rows. Integrate the Admin Entity and Natural Feature Source of truth selectors as production callers, retaining their typed identities, drafts, validation and operation ownership. This is the approved shared enabling slice, not a replacement theme or a reimplementation of Spec 0068.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, revision 2026-10-13, amendment 2026-10-19, dropdown supplement 2026-10-20 and local presentation supplement 2026-10-21; especially §§4/5/9/14.
- `ai_specs/app-profile.md`, `AGENTS.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md` — R1–3, R10, Technical Decisions 1/2/6, Testing Strategy 1/8–12 and refinement decisions 3/5.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/interview-ledger.md` — L1/L2/L9.
- `lib/theme.dart`, `lib/screens/objectbox_admin_screen_controls.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/widgets/objectbox_admin_form_field.dart`, `lib/providers/objectbox_admin_provider.dart`, `lib/providers/objectbox_admin_save_provider.dart`.
- `lib/widgets/dashboard/dashboard_dropdown.dart`, `lib/widgets/dashboard/dashboard_card_keyboard.dart`, `lib/widgets/dashboard/time_chart_type_menu.dart` — existing caller/focus conventions; Dashboard migration belongs to item 06.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md`, its `work-items/` and `implementation-05-verification.md` — completed central theme, form policy, measured read-only viewports and retained-shell Save protection.
- `test/theme_test.dart`, `test/widget/shared_field_grid_theme_test.dart`, `test/widget/objectbox_admin_form_policy_test.dart`, `test/widget/natural_feature_admin_details_test.dart`, existing browser/entity-selector tests and mutable repository harnesses.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] Retain the established `InputDecorationThemeData` foundation in both themes: `searchControlFontSize = 14.0`, `searchControlIconSize = 24.0`, dense layout, 14px `onSurface` labels, central padding and always-floating ordinary labels. Default shape remains `OutlineInputBorder(borderSide: BorderSide(color: colorScheme.onPrimary))` with constructor-default unspecified radius/metrics. Enabled/unfocused idle uses `outline` at 1px, hover effective configured seed at 1px, focus effective seed at 2px; error/focused-error/disabled retain priority. Filled outlines centrally resolve `activeIndicatorBorder`, leaving `enabledBorder` unset.
- [x] Enabled field hover, including focused hover, uses exactly `Color.alphaBlend(primary.withValues(alpha: .08), Color.alphaBlend(primary.withValues(alpha: .12), surface))` once, sharing the mode-control layers. Exit restores the prior fill; disabled hover is suppressed, with no idle selected tint or focus-only fill. Colours follow live effective seed/variant/contrast/brightness and preference rollback; do not substitute DataGrid row hover.
- [x] A central/common error presentation keeps complete beside-field errors soft-wrapped and reachable without ellipsis, arbitrary hidden tails or fixed-height clipping. Labels/errors remain outside editable-content viewport caps. Integrate/regress the shared Admin builder without changing existing validation timing, logical field coverage, read-only selectable values or measured five-line viewports. Verify long errors actually wrap rather than merely exist.
- [x] One reusable presentation exposes independent caller configurations for both trigger variants and both row variants, not new user-facing preferences. Labelled fields inherit central selected-value typography/decoration with 12px content padding, 14px `onSurface` label style and actual text scaling/platform fonts. Always float the meaningful label; maintain beside-field validation, one decorative indicator and a single 48 × 48 minimum target. No associated tooltip, Search icon, indicator focus stop or individual submit action is added.
- [x] Labelled-field width accounts for the longest option/current hint, full floating label, indicator, actual fonts/scaler, padding and framework gaps. Width stays stable across selections while options are unchanged, never stretches merely to fill available space, and is bounded by constraints. Complete labels/values/errors wrap without ellipsis or reduced scale. Real expanded state keeps the effective-seed 2px border while focus belongs to the menu; shared error/disabled priority, hover restoration and live theme changes remain correct.
- [x] Icon-only triggers reuse central circular icon-action styling: transparent idle/focus-only background, `onSurface` .08 hover / .12 press applied once, disabled dim/basic cursor, and a visible 2px primary circular focus/expanded outline even while menu owns focus, with error/disabled priority. Keep one 48 × 48 minimum target and one activation/focus owner, meaningful action/current-value/expanded semantics and desktop tooltip. Do not apply TextField label/measurement/Data-fill/tooltip exclusions to this standalone action.
- [x] Opened menus use a centrally owned 12px rounded semantic surface with subtle outline/shadow, left-aligned 12px labels at scale 1 and 40px minimum macOS rows that grow for wrapped/scaled content. Use zero outer padding, 12px horizontal / 8px vertical option padding, 24px trailing-check space and 12px label/check gap. Hover/focus `.08` and press `.12` `onSurface` backgrounds cover the entire row through clipped rounded edges without gutters or double overlays. No menu-row outline, idle selected fill or automatic initial highlight is present.
- [x] Exactly the committed value has one trailing check and selected semantics; reserve equal check space for every row. Tick colour is effective seed normally, error when applicable and dimmed when disabled, including for icon-only triggers whose primary ring differs from seed. Label-only rows have no leading-icon slot; icon-plus-label rows use centrally sized/spaced decorative icons, aligned complete labels, disabled semantic foregrounds and an independent trailing check. Include the leading slot in width/background measurement with no extra focus stop or duplicate accessible name.
- [x] Prefer below-trigger opening, with trigger-width minimum and content-driven growth within actual safe viewport/keyboard-inset bounds; narrower bounds override the minimum. Long options wrap, constrained height scrolls to every option, and icon triggers do not constrain menus to icon width. Resize/theme changes retain values/drafts. Unavailable/removed anchors close without commit, orphan overlays or forced focus to removed/disabled controls; dispose presentation-owned focus/scroll/listener/overlay resources.
- [x] Opening shows the committed check but no highlighted row. First Down/j targets the next enabled choice relative to committed value; Up/k targets the previous; skip disabled choices and wrap. Unavailable committed values start at first/last enabled respectively. Movement alone never commits. Before directional navigation, Enter closes unchanged with no callback/write for enabled committed values, nullable Any, unavailable values and no enabled choices, including after mere pointer hover. After navigation, Enter commits the target; pointer activation selects an enabled choice directly.
- [x] First outside click/tap is consumed and only dismisses; another gesture is needed to activate underlying content. Escape/Ctrl+C use the same dismissal/focus-return/guard path; back closes only the menu. Prevent same-event cancellation/popup/navigation cascades and background Cmd+F while preserving Cmd+C and unrelated panel shortcut scope. Expose the close/selection ownership needed to preserve Dashboard card traversal/menu-return reasons in item 06.
- [x] Feature owners retain typed IDs/enums, committed values, sole drafts, validation, persistence timing and operation locks. Opening/hover/focus/measurement/dismissal do not persist. Read the current lock at activation/commit before rebuild; reject captured callbacks and never replay after unlock. Choice-less required fields may retain programmatic validation focus without enabling selection; mutation-disabled controls cannot regain focus. Distinguish nullable Any from an absent/unavailable required value.
- [x] Migrate Admin Entity to labelled-field / label-only rows, preserving canonical-name de-duplication/restoration, Schema/Data availability, existing stable selector meaning and selection/reset policy. Migrate Natural Feature Source of truth with exact `OSM` / `Manual` typed choices and existing policy/draft/Save locks. Do not add loaders, editors or writes; Admin Search/Delete changes belong to item 02.
- [x] Focused tests verify actual field/menu rendering and input, not only widget properties: light/dark, non-default seed, default/enlarged scale, wrapping errors, compact numeric fields, live scheme/rollback, all four trigger/row combinations, expanded border/ring while menu owns focus, tick roles, complete constrained content, last-option scrolling, disabled/unavailable/nullable cases, no-op Enter, consumed outside gestures, current-lock rejection, focus return and lifecycle cleanup. Use stable context-scoped selectors where necessary and preserve existing selector meaning rather than depending on Flutter dropdown internals.
- [x] Verify Desktop wide/macOS only at 1280 × 960 and representative larger content sizes with default/enlarged text and actual wrapping/scrolling, including native rendering/input for both trigger and row variants. Keep maximised launch target and window/native-full-screen configuration unchanged; no compact/iOS support, new breakpoint, schema/model/generated-file change or external starter dependency. Preserve ObjectBox/Riverpod/GoRouter and completed Spec 0068 behaviour.
- [x] Use deterministic overrides/fakes, no live network, credentials, production Store, Mapping volumes or other app checkout; close temporary stores before cleanup and dispose owned resources. Run affected tests, existing affected robot regressions, `flutter analyze` and `TZ=Australia/Hobart flutter test --reporter expanded` with README native prerequisites. No new TDD mandate or robot framework is introduced. Record automated versus native evidence, failures/blockers and any human review separately; no template-parity or inherited Dashboard-layout Pass is claimed.

## Covers

- User Stories: 1, 5.
- Requirements: R1; R2.1–3/6 and Admin input integration; R3.1–3; R10.1–10 and reusable R10.11 presentation (Dashboard caller migration in item 06).
- Technical Decisions: 1, 2, 6 and applicable ownership/resource boundaries.
- Testing Strategy: 1, 8–12 and applicable Admin selector regressions.
- Interview Ledger: L1, L2, L9.
- Approved refinement decisions: 3, 5.

## Blocked by

None — completed 2026-10-21.

## Implementation evidence

All 16 acceptance criteria are verified. See [Work Item 01 verification](../implementation-01-verification.md)
for shared presentation/error ownership, Admin integration, deterministic rendering/input,
2,812 passing tests (7 inherited skips), static analysis and native macOS evidence.
The [usage guide](../../../../docs/shared-dropdowns.md) documents the reusable API.
Search/Delete and Dashboard caller migration remain separate items; the inherited Time
layout gate is neither changed nor counted as a Pass.
