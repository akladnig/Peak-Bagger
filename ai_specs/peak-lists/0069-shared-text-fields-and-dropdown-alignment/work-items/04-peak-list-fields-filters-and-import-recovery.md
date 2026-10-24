---
type: Work Item
title: Peak List fields, filters and recoverable import
parent: ../spec.md
---

## What to build

Complete Peak List details Search, Add/Edit Peak fields and Points controls, metadata-filter presentation and pre-acceptance Import Peak List recovery. Align the shared List Name and GPX Track Name/Route Name consumers without activating the unused Create flow. Keep feature-owned criteria, typed identities, sole drafts, validation and accepted background-job execution intact.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, revision 2026-10-13, amendment 2026-10-19 and supplements 2026-10-20/21; `ai_specs/app-profile.md`, `AGENTS.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md` — Peak List/GPX scope of R1–3/5–7/10–11, Technical Decisions 1/2/4–6, Testing Strategy 1/4–6/8–12 and background-job exclusions; matching `interview-ledger.md` L1/L2/L4/L6/L7/L9/L10 and sibling item 01.
- `lib/screens/peak_lists_screen.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/widgets/peak_selected_peaks_list.dart`, `lib/widgets/map_metadata_filter_popup.dart`, `lib/providers/peak_list_details_metadata_filter_provider.dart`, `lib/services/peak_metadata_rules.dart`, current mutation/provider/service owners and `lib/theme.dart`.
- `lib/widgets/peak_list_name_field.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/widgets/gpx_import_dialog.dart`, `lib/widgets/dialog_helpers.dart`, current file-picker/duplicate-check/import-starter seams and background runner.
- `ai_specs/peak-lists/0056-peak-list-details-search-and-filter/spec.md`, `ai_specs/peak-lists/0020-peak-rating-difficulty-duration-sorting-and-filters/spec.md`, `ai_specs/peak-lists/0023-map-metadata-filter-refresh-and-hover-affordances/spec.md`, `ai_specs/peak-lists/0011-background-jobs-import-export-progress/spec.md` and relevant ledgers/amendments. Current tooltip/shared-presentation contracts supersede historical conflicting styling only.
- `test/widget/peak_lists_screen_test.dart`, `test/widget/peak_list_peak_dialog_test.dart`, `test/widget/gpx_import_dialog_test.dart`, `test/providers/peak_list_details_metadata_filter_provider_test.dart`, `test/providers/peak_list_import_background_runner_test.dart`, existing import/filter/Points tests and affected Peak List/background-job robot journeys.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] Align all covered fields: shared `List Name` in live Import and uncalled Create, repeated per-file `Track Name` / `Route Name`, Add-mode Search, edit `Difficulty` / `Duration`, Points selector and repeated numeric `Points`, and details name Search. Inherit central dense 14px labels/padding/outline/hover/error roles in both themes instead of local generic border/text/padding copies. Preserve platform fonts, actual scaling, accepted input/units, existing validation timing and complete common wrapping errors. Do not activate/remove the unused Create flow.
- [x] Repeated Points inputs have visible **Points** labels and per-peak accessible context; integer entry, limits, decrement/increment behaviour and peak duration parsing/ranges/normalisation remain unchanged. No `FittedBox.scaleDown` or clipped labels/values/units/actions is used to force compact fields. Add/Edit fields, Points and associated controls reject current mutation locks and captured callbacks before rebuild/awaits, preserving a single draft and retained input on failure/theme/resize rather than resynchronising committed values over edits.
- [x] Remove details Search tooltip/local borders and all text-field-associated tooltips, including Points adjustment/selection controls, while keeping semantic names and unrelated title/Close/Edit tooltips. Only Search has decorative leading `Icons.search` at central 24px, with no action/button semantics/focus stop/action cursor. No individual submit button is added; feature Save/Cancel/Import boundaries remain.
- [x] Details and Add New Peak local Search show exactly **Search ⌘F**, keep descriptive hints (including `Search Peaks` where present) and context-specific accessible names. Labels remain persistent; if inline/floating is chosen, dim only the empty/unfocused inline shortcut cue, not entered text/floating labels/ordinary fields. Cmd+F selects all current text without changing query/filter/identity/draft; details requires an active selected list, and Add dialog owns its local shortcut instead of background Search.
- [x] Cmd+F does nothing when no list is selected, the intended surface is inactive, its field is unavailable/disabled/mutation-locked or a dialog/dropdown/drawer/focus-owning picker owns interaction. Check live eligibility before focus/scroll, including stale callbacks; do not switch modes/routes/tabs, focus background Search or queue/replay actions. Preserve normal editing/Cmd+C and existing effective-list name-query resets.
- [x] Migrate Points and metadata Rating/Difficulty/Duration selectors to shared labelled-field / label-only menus, retaining current option order/typed identity, meaningful labels, Any/null versus absent-required distinctions, grouping and persistence/validation/draft owners. Use stable content-driven closed widths, 48 × 48 targets, expanded effective-seed 2px borders, complete scaled/wrapped values/errors, 12px menus/40px growing macOS rows, trailing checks and full-width state backgrounds with no field tooltip/Search icon/extra focus stop or local palette.
- [x] When a retained Difficulty is absent from the new list's valid options, keep its typed value and active filtering, showing one checked **disabled** entry exactly **<difficulty> (<region>) — unavailable for this list** with existing region display name. Any and current valid choices remain selectable; never clear/substitute/newly enable the unavailable value. Once valid again, use its normal option without a duplicate retained row.
- [x] Rating closed/menu labels are exactly **Any, 3.0+, 3.5+, 4.0+, 4.5+**, in that order, with accessible names such as **Any rating** and **Rating at least 4.5 out of 5**. Preserve enum/stable option identity, thresholds 3.0/3.5/4.0/4.5 and existing matches. Replace stars only in this dropdown presentation, retaining domain stars elsewhere. Preserve Difficulty grouping/disambiguation, Duration options, AND-combined name/metadata filtering, session-scoped criteria and `Clear filters`; no new saved criteria/restart persistence.
- [x] Shared menu input works through real callers: no initial highlight, next/previous enabled skip/wrap relative to committed value (first/last enabled if unavailable), no commit on movement, immediate Enter closes unchanged with no callback/write even after hover, Enter after navigation commits and pointer activation selects directly. Test nullable Any, disabled retained Difficulty and no-enabled-choice cases. Consume first outside gesture; Escape/Ctrl+C/back dismiss only dropdown with eligible focus return/no editor/popup/navigation cascade. Exclude background Cmd+F, reject stale commit/current-lock changes and clean up removed/disabled anchors without orphan overlays/forced focus.
- [x] Import acquires parent lock before async duplicate checking/preparation/starter hand-off, rejecting duplicate/stale callbacks. Disable inputs/repeated Import and guard parent Cancel/header Close if present/outside/supported keyboard/back/programmatic dismissal through one current policy with visible pending feedback. Keep the existing duplicate-name confirmation's controls/cancellation/dismissal usable while protecting the parent; rejected confirmation returns to retained form without starting work and releases attempt lock.
- [x] Recoverable pre-acceptance Import failure keeps the mounted dialog, selected CSV and list name; shows actionable feedback rather than raw exception-only guidance; releases lock and re-enables **Import / Cancel**. Close once only after app-owned Background Jobs starter accepts work. After acceptance, work outlives the dialog and later failures retain existing Jobs/SnackBar reporting under Spec 0011; add no post-acceptance cancellation, replayable-input retention or Jobs-panel Retry.
- [x] Idle Cancel and permitted idle dismissal discard the Import draft with no write/new unsaved-change confirmation. Blocked dismissal is never replayed after completion/failure. GPX Track Name/Route Name fields preserve existing validation and failed-start retention. Dispose owned controllers/focus/listeners and handle async completion after disposal; diagnostics omit credentials/private payloads.
- [x] Unit/provider tests retain exact metadata matches/thresholds/session ownership and current guards. Widget tests verify labels/scaled complete errors/Points behaviour, active versus local-dialog Cmd+F eligibility, stable selected identities, unavailable Difficulty revalidation without duplicates, Rating semantic wording and shared actual menu input. File-picker/duplicate-check/starter fakes with controlled futures/exceptions verify early locks, usable child confirmation, all parent dismissal paths, retained CSV/name, retry, idle discard, one accepted hand-off and later background-owned failure; regress GPX failed-start retention and affected existing robot journeys.
- [x] Verify native macOS rendering/input at 1280 × 960 and representative larger content sizes, default/enlarged text and My Seed Colour in dark mode only, resizing with drafts/open menus. Labels/values/errors/actions remain reachable by wrapping/scrolling, never reduced scale/new breakpoints. Preserve Desktop wide/macOS-only/maximised-launch target, native window/full-screen configuration, ObjectBox/Riverpod/GoRouter and domain persistence; no schema/model/generated changes or external starter dependency.
- [x] Ordinary automated tests use Riverpod overrides and controlled repositories/preferences/file-picker/import seams, not network/keys/production ObjectBox/Mapping volumes. Follow README native prerequisites if temporary Stores are needed and close before cleanup; dispose resources. Run affected focused tests/robot regressions, `flutter analyze` and full `TZ=Australia/Hobart flutter test --reporter expanded`; record automated/native evidence and failures/blockers distinctly. No new TDD/journey framework or template-parity requirement is introduced; preserve earlier explicit test-first requirements if covered parser/domain logic changes.

## Covers

- User Stories: 1, 3, 4, 5, 6 (Peak List/import scope; API key in item 05).
- Requirements: R1; Peak List/GPX scope of R2–3, R5–6; Import scope of R7; Points/metadata scope of R10; R11.
- Technical Decisions: 1, 2, 4–6 as applicable to these owners.
- Testing Strategy: 1, 4–6, 8–12 as applicable to these callers.
- Interview Ledger: L1, L2, L4, L6, L7, L9, L10.
- Approved refinement decision: 3 (including Any/unavailable/empty immediate-Enter cases).

## Blocked by

- [01-shared-field-and-dropdown-presentation.md](01-shared-field-and-dropdown-presentation.md)

## Implementation status — 2026-10-22

**Completed — all 15 criteria verified**, following the user-reported Cmd+F bug
and [routed-shell correction/strict native rerun](../cmd-f-follow-up.md). Item 01
is already complete.

See [item 04 verification](../implementation-04-verification.md) for initial changes
and dated evidence. The follow-up records failing-then-passing real-shell sidebar
regressions, modal guards, **273 passing focused tests**, the additional Admin
sidebar/draft regression, clean analysis and full-suite **2,833 passed / 6 skipped**.
The final strict native matrix passed at 1280 × 960 / 1600 × 1000 and 1×/2× text,
including Command/F key delivery, Add Search focus/select-all and repeated Cmd+F,
actual resizing, menu input and Import recovery. The probe now supplies the device
modifier flag and verifies foreground activation immediately before injection.
No native application keyboard workaround, window/menu change, human visual Pass
or whole-app compliance claim is included.
