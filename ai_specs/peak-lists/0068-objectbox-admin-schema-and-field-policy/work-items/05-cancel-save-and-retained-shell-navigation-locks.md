---
type: Work Item
title: Complete Cancel / Save behaviour and retained-shell navigation locks
parent: ../spec.md
---

## What to build

Complete the affected-editor cancellation baseline for Peak, Natural Feature, Contact, Route and PeakList, including the authoritative pending-Save lock across local dismissal and retained-shell departure. Verify actual routed-shell behaviour rather than relying on disabled buttons or editor unmounting. Keep existing save/validation/persistence outcomes and permitted idle re-entry behaviour; add no dismissal binding, confirmation or cross-destination draft retention.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before affected feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, amendment 2026-10-19, footer, async and dismissal rules.
- `ai_specs/app-profile.md` — Desktop wide, keyboard and approved size/range contracts.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/spec.md` — R1, R8.1/7, refinement decisions and Testing Strategy 5/7/10.
- `ai_specs/peak-lists/0068-objectbox-admin-schema-and-field-policy/interview-ledger.md` — especially L11.
- `AGENTS.md`, `GLOSSARY.md`, `lib/screens/objectbox_admin_screen_details.dart`, `lib/screens/objectbox_admin_screen.dart`, `lib/providers/objectbox_admin_provider.dart`, `lib/router.dart`.
- `lib/widgets/side_menu.dart`, `lib/widgets/shell_destination_keyboard.dart`, `lib/core/widgets/popup_keyboard_dismiss.dart` as existing interaction evidence; inspect actual supported bindings rather than adding new ones.
- The five existing `lib/services/*_admin_editor.dart` services, current save callbacks/repositories, `lib/theme.dart` and Work Item 04's integrated forms.
- `test/widget/objectbox_admin_shell_test.dart`, `test/widget/objectbox_admin_browser_test.dart`, `test/widget/natural_feature_admin_details_test.dart`, `test/providers/objectbox_admin_provider_test.dart`, `test/harness/test_objectbox_admin_repository.dart` and existing shell/robot regression seams.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] All five existing editors show labelled footer **Cancel / Save**, in that order, both using `FilledButton` with shared `primaryContainer` background/`onPrimaryContainer` foreground in both themes. Align right where space permits and wrap/reflow so actions remain reachable. Pending Save has visible progress/disabled semantics; affected header actions retain accessible names, permitted tooltips and central circular interaction/focus styling.
- [x] For an existing record in each editor, Cancel discards the single unsaved draft, restores committed values and returns to read-only details for that same record without any write. Peak and Contact existing create-flow cancellation abandons creation without saving and leaves create mode; add no other create flow. Verify policy/read-only/multiline integration from Work Item 04 does not change these outcomes.
- [x] Failed Save retains the draft and field input for retry or cancellation, with the existing validation, errors and persistence boundary. Existing successful Save, refresh, selected-record lifecycle and domain actions remain intact. Do not fabricate success before completion, duplicate writes, add confirmations or introduce another draft owner.
- [x] Acquire pending/duplicate protection before awaited preparation/validation/Save work. Enforce the current save lock at authoritative action/navigation boundaries, including callbacks captured before rebuild; disabling a visible button alone is insufficient. Prevent cancellation and dismissal during Save, and retain existing mutation/input/draft locks rather than allowing new view-only interactions to bypass them.
- [x] While Save is pending, header Close, Cancel, supported keyboard dismissal/back and every supported route-departure path honour the lock. Cover side-menu/shell destination changes, supported keyboard navigation away and programmatic departure, even when `StatefulShellRoute.indexedStack` retains the mounted Admin editor. Do not rely on disposal or a local-only pop guard as proof of branch-departure protection. Do not queue a blocked departure/cancellation for automatic execution after Save.
- [x] When idle, permitted dismissal or departure discards unsaved edits without a write and preserves existing re-entry/refresh behaviour. Explicit Cancel on an existing record instead retains that record's read-only details. No cross-destination draft retention, new dismissal gesture, new shortcut or confirmation is added. Preserve ordinary text editing/Cmd+C and scope existing cancellation/navigation bindings correctly.
- [x] Keep `/objectbox-admin`, **ObjectBox Admin**, **Entity**, **Schema / Data**, existing entity/record selection, validation, deletion/confirmation, map/export flows and external navigation entry semantics except for the expressly approved locks/cancellation. Preserve other features' navigation and operation guards; no Search/filter/sort redesign or new persistence boundary belongs here.
- [x] Tests exercise all five editors' exact FilledButton order/colours, existing-record Cancel restoring committed values/same details with zero writes, Peak/Contact create Cancel leaving create mode with zero writes, failed Save retention/retry/Cancel and duplicate prevention. Controlled pending futures exercise local dismissal/back paths and stale callbacks before and after rebuild without live services.
- [x] Extend `test/widget/objectbox_admin_shell_test.dart` through the real routed shell: hold Save pending, attempt side-menu/shell destination changes, supported keyboard navigation and programmatic departure, assert Admin remains active and its editor/draft is retained even when the branch would stay mounted. After completion/failure, verify permitted actions work without replaying blocked attempts. Separately prove idle departure discards without writes and existing re-entry/refresh is preserved. Local Cancel/Close-only tests do not satisfy this criterion.
- [x] Verify light/dark themes, a non-default seed, focus/accessibility/Cmd+C and default/enlarged text scale at 1280 × 960 and representative larger content widths/heights, including the shortest supported height 960. During an unsaved draft, resizing preserves selection/draft and recalculates value viewports; footer, errors and dismissal controls remain reachable via wrapping/scrolling. Supported width ≥1280 and height ≥960 has no fixed app-defined maximum and one wide layout, not new breakpoints/compact/iOS support. Keep maximised launch and native window configuration unchanged; native full-screen remains Pending and non-blocking. No reduced text scale or template parity claim.
- [x] Run affected editor/provider/browser tests and `flutter test test/widget/objectbox_admin_shell_test.dart`, affected existing shell/robot regressions, `flutter analyze` and full `flutter test`; perform affected macOS runtime checks and record failures/blockers. Ordinary tests use controlled futures, existing mutable in-memory repositories and Riverpod overrides, not production Stores, mapping volumes, network, credentials or template checkout. Dispose controllers/containers/listeners; no mandatory red-green process or new robot framework is introduced.
- [x] Preserve mandatory ObjectBox/Riverpod/GoRouter foundations and data/service ownership. No entity annotation/model UID/history/generated-file changes or schema migration. Report inseparable mandatory-baseline conflicts instead of silently treating current source as approval; broader separable Admin alignment is not expanded into this item.

## Covers

- Requirements: R1; R8.1, R8.7 and applicable footer/accessibility/style integration.
- Technical Decisions: 4–7, including explicit operation/resource ownership.
- Testing Strategy: 5, 7–10.
- Interview Ledger: L6, L7, L9, L11, L14–L16.

## Blocked by

- [04-policy-driven-admin-forms-and-value-viewports.md](04-policy-driven-admin-forms-and-value-viewports.md)

## Implementation evidence

Completed 2026-10-20; Work Item 04 is complete. All 12 acceptance criteria are verified. See [Work Item 05 verification](../implementation-05-verification.md) for the five-editor cancellation audit, authoritative Save/navigation gates, real retained-shell and same-turn departure tests, full suite (**2781 passed, 7 skipped**), static analysis and **160 native macOS configurations**. Existing user-authored standard/profile/parent Spec/ledger changes remain outside the implementation commit.
