---
type: Work Item
title: Make every record-detail value independently scrollable and selectable
parent: ../spec.md
---

## What to build

Introduce reusable labelled read-only value presentation and integrate it across generic and entity-specific ObjectBox Admin record details. Every long detail value gets an independently scrollable viewport capped at five rendered text lines, with full selection/copy and no content loss. Expose this component for subsequent read-only form integration; form conversion and editable multiline inputs belong to Work Item 04.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before affected feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, amendment 2026-10-19, selection/accessibility and five-line requirements.
- `ai_specs/app-profile.md` — Desktop wide, formatting/domain contracts and approved size/range.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md` — R1, R6.2, R7, R8.6–7, Technical Decision 5 and Testing Strategy 6/7.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/interview-ledger.md`.
- `AGENTS.md`, `GLOSSARY.md`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/screens/objectbox_admin_screen.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/theme.dart`.
- `lib/core/number_formatters.dart`, `lib/core/date_formatters.dart` and existing Admin field formatting helpers; preserve display/storage distinctions.
- `test/harness/test_objectbox_admin_repository.dart`, `test/widget/objectbox_admin_shell_test.dart`, `test/widget/objectbox_admin_browser_test.dart`, `test/widget/natural_feature_admin_details_test.dart` and other affected detail tests.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] Audit all generic and entity-specific detail paths and use a shared labelled value/viewport component (or actual local equivalent) for long text rather than a Route/GPX field-name allowlist. Preserve complete values, existing labels/formatting and appropriate scalar/boolean semantics, including existing read-only boolean presentation.
- [x] Each long value's viewport is capped at five rendered text lines measured from the active text style, line metrics, available wrapping width and actual text scale, recalculating for constraint/theme/scale changes. Short values take only their needed height. The cap concerns value content, not labels or the entire panel; do not impose a fixed unscaled pixel height or force every value to five lines.
- [x] Each long value scrolls independently of the outer panel. Users can reach, select and copy content beyond the initial fifth line. Keep the complete stored/displayed text; no ellipsis, substring preview, destructive transformation or outer-panel-only scrolling substitutes for full-value access. `SelectableText(maxLines: 5)` alone is not proof.
- [x] Read-only values have accessible label/value association and selection/pointer affordances without advertising text editing or exposing text-mutation accessibility actions. Create neither `TextField` nor `TextFormField`, even disabled/read-only. Do not require an app-owned `TextEditingController` solely for display; Flutter-managed read-only selection internals such as `SelectableText`'s `EditableText(readOnly: true)` are permitted. Preserve Cmd+C, normal focus/traversal and non-mutation.
- [x] Formatting remains display-only: preserve local number/date conventions and date-only Track semantics, with no read/write side effects from measuring, rebuilding, scrolling or selecting. Do not retarget record selection, save/cancel a draft, bypass mutation locks or close an app-owned Store from a field widget. Schema metadata wrapping and Data-grid preview policy are unchanged.
- [x] App-owned scroll/focus/selection resources have explicit lifecycle owners and are disposed safely. Associate retained state with record/field identity rather than only list index; verify cleanup/identity changes on record, mode and route transitions and no late UI work after disposal. Keep full selection/draft context through legitimate resizing.
- [x] Deterministic widget tests cover long single-paragraph wrapping text, explicit newlines, short/empty values and generic/entity-specific detail surfaces at default and enlarged text scale. Measure actual short/five-line heights, independently scroll to a sentinel beyond line five and select/copy previously offscreen content; property-only `maxLines` assertions are insufficient. Assert non-mutation/no text-mutation semantics, label association and controller/identity cleanup; do not assert blanket `EditableText` absence.
- [x] Verify both application themes and a non-default seed at minimum content 1280 × 960 logical points and representative larger widths/heights, including height 960, changed wrapping widths and unsaved-draft resize scenarios. Supported content is width ≥1280 and height ≥960 with no fixed app-defined maximum; keep one wide layout, wrapping/scrolling, complete values and reachable actions without clipping or reducing text scale. No new breakpoints, compact/iOS obligations, native window change, native full-screen entry or template parity claim. Retain maximised launch; native full-screen Pending is not a blocker.
- [x] Run focused affected detail/browser/shell widget tests, `flutter analyze` and full `flutter test`; perform affected macOS runtime checks and record failures/blockers. Use existing repository/provider fakes and overrides without a user database, mapping volumes, template checkout, network or credentials. Dispose resources; no new robot framework or mandatory red-green process is required, and affected existing robot regressions remain covered. Do not change database schema/model/generated files or add persistence writes/new editable capabilities.

## Covers

- User Stories: 4.
- Requirements: R1; R6.2 selection semantics; R7 detail values; R8.6–7 and applicable accessibility/style integration.
- Technical Decisions: 4–7, especially shared presentation/lifecycle in 5.
- Testing Strategy: 6–9; detail-surface selection aspects of 5.
- Interview Ledger: L7, L9, L10, L13–L16.

## Blocked by

- [01-shared-field-and-data-grid-styling.md](01-shared-field-and-data-grid-styling.md)

## Implementation evidence

Completed 2026-10-20; prerequisite Work Item 01 is complete. All nine acceptance criteria are verified. See [Work Item 03 verification](../implementation-03-verification.md) for the detail-path audit, measured/selectable viewports, lifecycle/resize coverage, complete suite and 192 native macOS configurations. Work Items 04–05 remain separately scoped.
