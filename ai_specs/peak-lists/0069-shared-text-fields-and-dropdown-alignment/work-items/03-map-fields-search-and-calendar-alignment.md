---
type: Work Item
title: Map fields, Search and calendar alignment
parent: ../spec.md
---

## What to build

Align the remaining Map editing, Peak Info, overlay, Search and date-picker fields with the shared foundation. Migrate Map Search/calendar selection-only controls, add contextual Cmd+F and explicit Year navigation feedback, preserving existing search, route, overlay and date-domain behaviour. Do not redesign Map navigation or introduce new validation restrictions.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, revision 2026-10-13, amendment 2026-10-19 and supplements 2026-10-20/21; `ai_specs/app-profile.md`, `AGENTS.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md` — Map scope of R1–3/5–6/9–10, Technical Decisions 1/2/5/6, Testing Strategy 1/4/6–12; matching `interview-ledger.md` L1/L2/L3/L6/L8/L9 and sibling item 01.
- `lib/widgets/map_search_popup.dart`, `lib/screens/map_screen_panels.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/widgets/map_basemaps_drawer.dart`, `lib/theme.dart`, current Map keyboard/search/route/overlay providers and services.
- `ai_specs/peak-lists/0050-search-popup-track-date-range/spec.md`, `ai_specs/peak-lists/0059-search-popup-multi-filter-natural-search/spec.md`, `ai_specs/peak-lists/0049-tasmania-dem-overlays/spec.md` and relevant ledgers/amendments — retain date/apply/overlay contracts and Map-specific Search semantics.
- `test/widget/map_screen_peak_search_test.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/map_basemaps_drawer_test.dart`, existing Map route/keyboard/search/provider tests, picker seams and affected Map robot regressions.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] Audit/align every covered Map constructor and repeated runtime field: Search, `Start date`, `End date`, both `Year` inputs, `Walking Speed`, `Go to location`, route-name/waypoint-name prompts, `Favourite name`, Peak Info `Name` / `Elevation`, bottom-sheet `Route name`, and each Terrain relief shading / Contour lines `Opacity`. Remove redundant local generic decoration/padding/density rather than copy the central theme. Preserve existing other labels and accepted input/units.
- [x] Missing labels use exactly `Route name`, `Waypoint name`, `Favourite name`, `Go to location`, `Walking Speed`, `Opacity`; labels remain visible independently of placeholders. Overlay/other repeated inputs expose contextual accessible names. Peak Info uses exactly **Elevation** in editing and **Elevation:** in read-only display, retaining metres, validation, calculations and stored data; unrelated height concepts/glossary are unchanged.
- [x] Inherit central dense 14px `onSurface` labels, default outline shape/radius, neutral idle/effective-seed hover/focus borders, error/disabled priority and once-composited Data hover fill through both themes/live seed changes/rollback. Ordinary labels always float; no ordinary input has a Search icon or individual submit action. Complete errors use the common soft-wrapping policy without ellipsis/fixed-height clipping, including compact numeric inputs and adjacent units/actions; never defeat scaling with `FittedBox.scaleDown`.
- [x] Keep appropriate input types and existing accepted ranges/normalisation/storage precision. Preserve Opacity integer entry and approved invalid-entry reversion on focus loss, Walking Speed/route calculations and existing numeric parsing. Route-name input/controls honour current pending Save; callbacks reject current locks before rebuild/awaits without duplicate operations. Retain sole drafts through failures/theme/resize without overwriting focused input from committed values and dispose owned controllers/focus nodes.
- [x] No text-field-associated tooltips remain, including Walking Speed adjustment controls, Search controls, calendar navigation/choice controls or labelled dropdown indicators. Retain meaningful accessible names, ordinary editing/Cmd+C and unrelated surface-level Close/Edit tooltips/actions. Only Search gets decorative leading `Icons.search` at the central 24px token, without tap/button semantics, independent focus stop or action cursor.
- [x] Main Map Search shows exactly **Search ⌘F**, retaining descriptive hints where present (including `Search Peaks`) and a context-specific accessible name. Keep a persistent label; ordinary fields always float. If Search is inline/floating, only its empty/unfocused inline cue is dimmed with disabled foreground; floating label remains `onSurface` and entered text is not dimmed. No Search submit button/tooltip is added.
- [x] Cmd+F on active Main Map opens Search if closed, otherwise focuses/selects all the existing query without changing raw input, criteria, selection or drafts. Do nothing when unavailable/disabled/mutation-locked or behind another dialog/dropdown/drawer/focus-owning picker; check current eligibility before focus/scroll, including stale callbacks. Do not change routes/tabs or queue/replay unavailable actions. Preserve Map's debounce, minimum-query/date parsing, category, region, sort/group, pagination and result-selection contracts; Admin's no-debounce behaviour is not imported.
- [x] Migrate Region, Sort, Group and both Month selectors to shared labelled-field / label-only menus, using exact meaningful labels **Region**, **Sort**, **Group**, **Month** where missing. Preserve current options/order/typed identities and caller commit/draft ownership; Year remains text input. Enforce shared content-driven stable widths, complete wrapping labels/values, 48 × 48 closed target, expanded 2px effective-seed border, 12px menus/40px growing macOS rows, effective-seed checks and full-width state backgrounds without local styles or new selectors.
- [x] Independently validate each calendar **Year** only on Enter or focus loss, not partial keystrokes. Accept **1 through 9999**. Blank/non-numeric/0/10000 and other invalid input remain visible with exactly **Enter a year from 1 to 9999** beside the corresponding field. Invalid submission changes neither displayed calendar month/year nor selected start/end dates; valid submission navigates only that calendar and clears its error without selecting a date.
- [x] Picker dismissal clears transient Year errors; reopen derives normal picker state instead of restoring abandoned invalid navigation. Apply eligibility depends on selected start/end draft dates, not invalid navigation text alone. Preserve Spec 0050 parser/formats/date-only semantics/endpoint copying and Apply/Cancel/Clear/outside-close/trigger-focus boundaries. Remove duplicate endpoint error display, not information. Touched labelled picker footer/cancellation actions follow shared FilledButton order/colour/scrolling without changing commit semantics.
- [x] Shared menus show committed checks but no initial highlight; Down/j and Up/k navigate enabled choices relative to committed value with skip/wrap and no commit until activation. Immediate Enter before directional navigation closes unchanged with no callback/write, even after hover. Pointer activation still selects directly. Outside gesture only dismisses and is consumed; Escape/Ctrl+C/back close only the dropdown with eligible focus return and no picker/popup/navigation cascade. Exclude background Cmd+F, preserve Cmd+C, and reject stale callbacks when current locks or owner removal invalidate selection; resize/close leaves no orphan overlay/forced disabled focus.
- [x] Extend field/Peak Info/overlay/route widgets and Search/keyboard/picker seams with deterministic tests for complete scaled labels/errors, exact Elevation wording, Opacity reversion, current/stale pending guards, contextual Cmd+F eligibility and unchanged Map query semantics. Year cases include 1/9999, blank/non-numeric/0/10000, partial typing, Enter/focus-loss timing, independent errors, valid recovery, dismissal/reopen, unchanged dates/navigation on invalid input and Apply with valid dates despite invalid Year text. Exercise actual shared-selector input/locks/cleanup through callers and existing robot regressions.
- [x] Verify native macOS rendering/input at 1280 × 960 and representative larger content sizes, default/enlarged text, light/dark/custom themes and resize with unsaved drafts/open menus. Keep labels/values/errors/actions reachable by constraints/wrapping/scrolling without downscaling/new breakpoints; no compact/iOS support or window/full-screen changes, maximised launch target preserved. Keep ObjectBox/Riverpod/GoRouter, no entity/model/generated-file changes or external starter requirement.
- [x] Use controlled provider/repository/preference/clock/platform seams, not live network/keys/user ObjectBox/Mapping volumes. Dispose controllers/containers/listeners/overlays; temporary Stores follow README prerequisites and close before cleanup. Run focused tests and affected existing robot regressions, `flutter analyze` and full `TZ=Australia/Hobart flutter test --reporter expanded`; record actual automated versus native results/failures/blockers. No new TDD/robot framework is mandated; retain earlier explicit test-first requirements if their parser/domain logic changes, and make no template-parity claim.

## Covers

- User Stories: 1, 3, 5.
- Requirements: R1; Map scope of R2–3, R5–6; R9; Map Search/calendar scope of R10.
- Technical Decisions: 1, 2, 5, 6 as applicable to Map/input/overlay ownership.
- Testing Strategy: 1, 4, 6–12 as applicable to these callers.
- Interview Ledger: L1, L2, L3, L6, L8, L9.
- Approved refinement decision: 3 (shared immediate-Enter behaviour through callers).

## Blocked by

- [01-shared-field-and-dropdown-presentation.md](01-shared-field-and-dropdown-presentation.md)

Dependency complete. Item 03 completed 2026-10-21.

## Implementation evidence

See [Work Item 03 verification](../implementation-03-verification.md): all 14 criteria,
284 focused tests, full suite **2,863 passed / 7 inherited skips**, clean analysis,
16 native macOS rendering/input configurations and actual native resize/open-menu
checks passed. Failed/interrupted attempts and native-versus-automated limits are
recorded separately; no template-parity or inherited Dashboard-layout Pass is claimed.
