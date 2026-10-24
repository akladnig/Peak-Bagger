---
type: Work Item
title: Dashboard dropdown migration
parent: ../spec.md
---

## What to build

Migrate existing Dashboard Period and Time Chart type menus to the shared dropdown presentation while preserving card-owned keyboard traversal, focus/inspection and preferences. Period uses labelled-field / label-only presentation; Time retains its current-type icon-only Chart type trigger with icon-plus-label rows. Independent presentation/state/input work may proceed, but inherited Time header/chart-height reachability work and dependent checks remain gated.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, revision 2026-10-13, amendment 2026-10-19, dropdown supplement 2026-10-20 and local supplement 2026-10-21, especially §§5/9/14; `ai_specs/app-profile.md`, `AGENTS.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md` — R1/R10, Technical Decisions 1/2/6, Testing Strategy 8–12, Follow-Up 3 and refinement decisions 3/5; matching `interview-ledger.md` L2/L9 and sibling item 01.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, its `interview-ledger.md` L19–L22, gated Work Items 01–02 and later implemented preference/keyboard items. Retain incomplete header-height reachability checks; current global minimum is not a Time layout resolution.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`, `ai_specs/peak-lists/0065-dashboard-weekly-tooltip-and-year-navigation/spec.md`, affected Spec 0067 contracts and relevant existing Dashboard ledgers; preserve period/calendar/card action ownership.
- `lib/widgets/dashboard/dashboard_dropdown.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/time_chart_type_menu.dart`, `lib/widgets/dashboard/dashboard_card_keyboard.dart`, `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/providers/time_chart_type_provider.dart`, `lib/theme.dart` and established card/preference owners.
- `test/widget/dashboard_screen_test.dart`, existing Dashboard keyboard/card-actions/summary-navigation/calendar/tooltip/Time/preference tests, `test/harness/summary_chart_controls.dart` and `test/robot/dashboard/dashboard_journey_test.dart`.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks
and the inherited Time layout gate. Runtime support and dated evidence are
unchanged. See `ai_specs/app-profile.md`.

- [x] Migrate all existing summary Period menus to shared **labelled-field triggers / label-only rows**, with floating label exactly **Period**, preserving option sets/order, typed period identity, calendar actions and card-owned state. Other covered Dashboard selectors retain their approved labelled presentation; do not invent chart-type selectors for other cards' binary controls or migrate their chart preferences.
- [x] Time uses a shared **icon-only** trigger showing the existing current type icon. Action name/desktop tooltip remains exactly **Chart type**; expose selected value and expanded state accessibly. Keep one 48 × 48 minimum target/activation/focus owner without extra indicator stop. Reuse central circular transparent idle/focus-only styling, `onSurface` .08 hover / .12 press once, disabled dim/basic cursor and visible 2px primary circular focus/expanded outline even while focus belongs to menu, with error/disabled priority/live theme rollback. Do not apply TextField label/measurement/Data-fill/tooltip prohibition to this standalone action.
- [x] Time menu uses **icon-plus-label rows** with these exact choices/icons in order: **Stacked column view** / `Icons.stacked_bar_chart`; **Line view** / `Icons.show_chart`; **Clustered column view** / `Icons.bar_chart`. Keep complete labels, centrally styled decorative/aligned leading icons, no duplicate accessible name/focus stop and an independent trailing committed check. Preserve typed enum identity and existing Time-only preference/operation timing; opening/focus/hover/dismissal never persists and presentation variants are caller configuration, not a user preference.
- [x] Period labelled boxes retain central dense 14px `onSurface` floating labels/selected-value typography, 12px padding/default field radius, content-driven stable width and complete scaled/wrapped values bounded by actual constraints. Keep one 48 × 48 target, no indicator focus stop/field-associated tooltip/Search icon/submit action, neutral idle outline 1px/effective-seed hover 1px/focused-or-expanded 2px, correct error/disabled priority and once-composited shared Data hover with pointer-exit restoration and live theme/rollback.
- [x] Both caller variants share 12px rounded semantic menu surface, 12px text at scale 1, 40px minimum macOS rows growing for full wrapped/scaled labels, zero outer padding, 12px horizontal / 8px vertical option padding, 24px trailing-check reserve and 12px label/check gap. Label-only menus have no leading-icon slot; icon menus include decorative slot in width/background measurement. Full-width `onSurface` .08 hover/focus / .12 press reaches clipped rounded edges without gutter/double overlay; no row outlines, idle selected fill or opening highlight. Exactly committed value has selected semantics/check in effective seed/error/disabled role, not generated primary even if icon ring differs.
- [x] Shared menus prefer below-trigger opening, grow from trigger-width minimum within safe viewport/keyboard-inset bounds and wrap/scroll to every option; icon trigger does not restrict menu to icon width. Preserve typed values/drafts through resize/theme changes. Close removed/unavailable anchors without commit, orphan overlay or forced disabled/removed focus, dispose owned resources and reject captured selection callbacks immediately after a current lock or owner change without replay.
- [x] Preserve P/C shortcuts at existing card owners. On opening, committed check has no row highlight; first Down/j targets next enabled choice relative to committed value, Up/k previous, skipping disabled and wrapping. Unavailable values start first/last enabled respectively. Movement alone does not commit. Enter before directional navigation closes unchanged with no callback/write, even after hover; after navigation it commits target, pointer activation selects directly. Preserve unchanged-close versus changed-selection menu-return/inspection reasons, including keyboard-opened menus.
- [x] Preserve full-order **Tab/Shift+Tab card-only traversal**, no new internal normal Tab stops, eligible menu-return focus and inspection context. First outside gesture is consumed/dismiss-only; Escape/Ctrl+C share close/guard/focus-return path and back closes only dropdown with no card/popup/navigation cascade. Exclude background Cmd+F, preserve ordinary editing/Cmd+C, existing shell/card shortcut ownership and no double dispatch. Immediate unchanged Enter must not reset inspection or trigger persistence.
- [x] Preserve the **one-row toolbar**, current card/grid geometry and grid breakpoints, without label-to-icon substitutions or text downscaling. The inherited Time height decision is resolved by Spec 0066 L23; its reserved chart and scrollable content now pass the dependent long-header/enlarged-text checks. No invented window threshold or unrelated Dashboard redesign is introduced; independent checks alone are not substituted for this verification.
- [x] Extend deterministic Dashboard/Time/summary caller tests and existing robot regressions for option identity/order/icons, persistent current-type icon/value/semantics, labelled Period sizing, actual pointer/keyboard input, unchanged Enter, P/C, full-card traversal/menu-return/inspection, preference boundaries, stale locks, consumed outside dismissal, Ctrl+C/Escape/back equivalence and owner/resize cleanup. Exercise rendering/input through both trigger and row variants; generic component tests alone do not establish caller compatibility.
- [x] Run native macOS rendering/input checks at 1280 × 960 and representative larger content sizes, default/enlarged text, My Seed Colour in dark mode only, draft retention and open-menu resize. The inherited Time height/reachability checks now pass under L23, with essential content reachable through wrapping/scrolling rather than geometry/scaling exceptions. Desktop wide/macOS-only/maximised-launch target and native window/full-screen configuration remain unchanged; no compact/iOS support or external starter dependency is added.
- [x] Preserve ObjectBox/Riverpod/GoRouter and existing domain/preferences boundaries, with no schema/model/generated-file changes, new chart capability or user-facing presentation preference. Use deterministic provider/repository/preference/clock overrides, not live network/credentials/production DB/Mapping volumes; dispose owned controllers/listeners/overlays and follow README prerequisites/cleanup for any genuine temporary Store use.
- [x] Run affected Dashboard/provider/Time/summary tests and existing robot regressions, `flutter analyze` and full `TZ=Australia/Hobart flutter test --reporter expanded`. Record automated versus native rendering/input versus any attributed human review separately, reporting failures and skips honestly. No new TDD/journey framework, template-parity metric or upstream/starter human-acceptance claim is introduced. Completion follows L23's resolved decision and passing dependent verification, not a waiver of the former gate.

## Covers

- User Story: 5.
- Requirements: R1; Dashboard scope of R10, especially R10.8–9/11.
- Technical Decisions: 1, 2, 6 and applicable ownership/resource boundaries.
- Testing Strategy: 8–12, including inherited Time layout gating.
- Interview Ledger: L2, L9; inherited Spec 0066 L19–L22 retained as history and resolved for Time overflow by L23.
- Approved refinement decisions: 3, 5.

## Blocked by

- [01-shared-field-and-dropdown-presentation.md](01-shared-field-and-dropdown-presentation.md)

## Blocking decisions

- **Resolved 2026-10-24, Spec 0066 L23:** the user approved retaining existing
  card/grid geometry, reserving usable chart space and scrolling overflowing Time
  content. No toolbar wrapping, text downscaling or new grid/window threshold is
  authorised. The dependent criteria below can now be verified against that contract;
  the 2026-10-23 delivery record remains accurate historical partial-delivery evidence.

## Implementation progress — 2026-10-23

**Current status — completed 2026-10-24.** All criteria are checked following the
L23 Time overflow delivery. Analysis and native rendering/input pass; final full
suite **2,887 passed, five existing skips**. See
[Time height/reachability evidence](../../0066-time-dashboard-card/implementation-layout-verification.md).
The dated partial-delivery notes below and item 06's original verification record
remain historical evidence; their "incomplete" gate status is superseded here.

The independent shared Period / Time Chart type migration is implemented. Shared
presentation owns field/icon/menu styling and input; the thin Dashboard adapter
retains P/C, full-card traversal and unchanged/changed inspection return. Card/grid
geometry, calendar state, other cards' binary controls and Time-only preference
ownership remain unchanged.

**This Work Item is not complete.** The inherited Time header/chart-height contract
and dependent layout checks remain unresolved; no previous gated item is completed
or waived here. See [the verification record](../implementation-06-verification.md)
for executed checks, discoveries and the automated/native/human evidence split.

Verification: analysis clean; native macOS input/rendering passed at 1280 × 960 and
1600 × 1000 with 1× / 1.5× text in My Seed Colour/dark; full Hobart-timezone suite
**2,877 passed, six existing skips**. The three unchecked combined criteria retain
their dependent layout/full-completion gate; their independent verification portions
passed. No attributed human visual acceptance is claimed.
