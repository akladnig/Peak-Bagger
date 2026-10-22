---
type: Work Item
title: Settings fields, selectors and persistence recovery
parent: ../spec.md
---

## What to build

Complete Settings field/selector alignment, contextual Tile Cache Search, persistence-confirmed API-key dialog completion and Local tile server base URL recovery across non-transactional preference phases. Keep current options, small-preference storage, URL save-before-validation and capability/fallback semantics. Do not broaden Settings, add online credential verification or migrate credential/preference storage.

## Required context

All paths below are relative to the project root; read the standard, then the profile, before feature context.

- `ai_specs/coding-rules.md` — ADS-1.0, revision 2026-10-13, amendment 2026-10-19 and supplements 2026-10-20/21; `ai_specs/app-profile.md`, `AGENTS.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0069-shared-text-fields-and-dropdown-alignment/spec.md` — Settings scope of R1–3/5–8/10, Technical Decisions 1/2/5/6, Testing Strategy 1/4–6/8–12, Follow-Up 2 and refinement decision 2; matching `interview-ledger.md` L1/L2/L4/L6/L9 and sibling item 01.
- `lib/screens/settings_screen.dart`, `lib/providers/open_route_service_api_key_provider.dart`, `lib/providers/local_topo_settings_provider.dart`, `lib/theme.dart`, current Local Topo runtime/client/snapshot/preference seams, theme/preferences providers and Tile Cache owners.
- `ai_specs/peak-lists/0026-local-topo-tile-server/spec.md` and its later feature amendments; README Local Topo fallback/retry and native-library guidance. Preserve existing capability evolution and save-before-network-validation, not API-key rollback for successfully saved URLs.
- `test/widget/open_route_service_settings_test.dart`, `test/providers/open_route_service_api_key_provider_test.dart`, `test/widget/local_topo_settings_screen_test.dart`, `test/providers/local_topo_settings_provider_test.dart`, `test/services/local_topo_runtime_test.dart`, `test/widget/settings_screen_theme_test.dart` and existing Tile Cache/filter/correlation/preference/robot seams.

## Acceptance criteria

**2026-10-21 verification override:** test My Seed Colour (`#7E47EB`) in dark mode
only (`MyTheme.dark`), with no alternate seeds/light/custom-theme matrices. This
supersedes broader verification clauses below; keep behaviour/scale/resize checks.
Runtime support and dated evidence are unchanged. See `ai_specs/app-profile.md`.

- [x] Align `API key`, `Local tile server base URL` and Tile Cache map-sheet Search with central dense 14px field labels/padding, fallback shape/default radius, neutral idle/effective-seed hover/focus/error/disabled roles and exact once-composited Data hover. Use appropriate URL input type, existing accepted values/trimming/blank semantics and complete common wrapping errors; no copied generic decoration, clipped scaled text, field-associated tooltip or individual submit action. Feature **Save / Retry / Clear / Cancel** boundaries remain distinct from field submission.
- [x] API-key submission acquires a parent operation lock before awaited preparation/persistence, disabling input/duplicate Save and guarding Cancel/header Close if present/outside/supported keyboard/back/programmatic dismissal with the same live policy. Reject stale callbacks before rebuild, show pending feedback and never queue/replay blocked dismissal. Keep the dialog mounted until local persistence succeeds and close once at that boundary, not before starting Save.
- [x] On API-key failure retain typed input in the dialog and the previously saved/effective key active, show actionable retry guidance and re-enable **Save / Cancel**. Treat false preference writes like exceptions; no silent effective unpersisted key or premature success. Preserve trimming, blank-key semantics and storage location. Idle Cancel/permitted dismissal discards without write/new confirmation. Dispose the controller and guard async lifecycle; never log key contents/credentials/private payloads or issue real key verification requests. The pre-existing default credential remains a separately scoped review/rotation follow-up; do not disclose/rotate it automatically. Report/stop affected work if a server-only-secret boundary is discovered.
- [x] Local URL syntax errors appear beside the retained draft with exact guidance **Enter a valid http or https base URL.** Saved URL and validation status remain visible. Acquire authoritative attempt protection before awaited preference preparation for Save/Retry/Clear/conflicting changes, not merely network validation. Keep pending progress, prevent duplicate/stale completions and release protection on every terminal outcome.
- [x] Preserve URL/capability/stored-snapshot contracts and exact existing states **Empty**, **Invalid URL syntax**, **Validating**, **Live validated**, **Restored snapshot**, **Validation failed**. Preserve **Save / Retry / Clear**, network-failure retry/fallback and save-before-network-validation; a syntactically valid URL successfully saved before later network failure is not rolled back like an API key. No automatic background probe, Local Topo authentication or unrelated service redesign is introduced.
- [x] Handle URL/snapshot/status preference operations as non-transactional, with these phase-specific results and recovery targets:

  | Failure point | Required result and recovery |
  | --- | --- |
  | Before URL is saved | Keep previous confirmed saved/effective configuration and typed draft for **Save** retry. |
  | After URL is saved, including snapshot cleanup/status persistence | Keep newly saved URL, never use previous-URL snapshot, report incomplete work and retain confirmed saved URL as validation **Retry** target. |
  | Network capability validation fails | Retain saved URL, remove active capability availability and use existing basemap fallback/retry; do not roll back saved URL. |
  | Persisting successful validation snapshot/status fails | Retain saved URL, do not claim **Live validated** or activate an unpersisted new snapshot; show persistence failure and offer validation **Retry** against confirmed saved URL. |
  | Clear partially fails | Do not claim successful Clear; reconcile remaining stored configuration, deactivate inconsistent snapshots and allow **Clear** retry. |

- [x] Every phase retains the typed draft, releases the attempt lock and offers actionable recovery. Treat false write/removal results like exceptions; distinguish persistence versus network errors/success. Saved/effective UI/runtime reflect confirmed storage, reading back when necessary. If consistency cannot be confirmed, disable Local Topo availability and use existing safe basemap fallback rather than uncertain configuration. Reject stale async responses and do not leave indefinite pending state, activate incompatible/unpersisted snapshots or introduce a storage migration.
- [x] Migrate all covered Settings selectors to shared labelled-field / label-only menus: Seeded Scheme Variant; Outlier Filter; Hampel window; Elevation smoother/window; Position smoother/window; correlation Distance/Elevation threshold; Tile Cache Min Zoom / Max Zoom. Preserve existing labels, complete option sets/order, typed identities, draft/committed owners, persistence timing and dependencies/availability. No binary/multi-select controls become dropdowns, no starter swatches/options/preferences are imported and no theme Settings redesign is added.
- [x] Each selector retains content-sized stable closed width bounded by constraints, complete floating labels/values/errors and one 48 × 48 target with decorative indicator/no extra stop/tooltip/Search icon/individual submit. Expanded effective-seed 2px border persists while menu owns focus; 12px menu text/40px growing macOS rows, trailing effective-seed/error/disabled checks, full-width .08/.12 state backgrounds and no initial highlight/row outline match the shared presentation through live themes/rollback. Opening/hover/focus/dismissal do not persist.
- [x] Tile Cache Search shows exactly **Search ⌘F**, retaining **Search Tasmap sheets** hint and context-specific accessible name, decorative leading 24px Search icon and persistent label. If inline/floating, dim only empty/unfocused inline shortcut cue, not entered text/floating labels. Active Tile Cache Cmd+F focuses/selects all existing query without criteria/selection/draft changes. Do nothing on inactive tab/route, unavailable/disabled/mutation-locked field or behind dialog/dropdown/drawer/focus-owning picker; check live eligibility before focus/scroll, including stale callbacks. Do not change tabs/routes or queue/replay and preserve normal editing/Cmd+C.
- [x] Exercise actual selector input: Down/j, Up/k skip disabled/wrap relative to committed selection without committing; immediate Enter before navigation closes unchanged/no callback/write even after hover, while navigated Enter/pointer activation commits per existing owner. Consume first outside gesture and keep Escape/Ctrl+C/back dropdown-only, with eligible focus return/no dialog/navigation cascade. Exclude background Search, reject stale commit after current mutation locks and clean up resized/removed anchors without orphan overlays/disabled forced focus.
- [x] Preference-controlled API-key widget/provider tests cover pending/early guards, false results/exceptions, all dismissal paths, retained draft/prior effective key, retry via Save, one successful write/close, idle discard, stale hydration/completion and safe diagnostics. URL provider/widget/runtime tests inject false/exception outcomes at every URL/snapshot/status write/removal phase, including later failure after prior success and partial Clear; assert exact recovery target, confirmed-storage/runtime/display consistency, uncertainty fallback, no unpersisted active snapshot/false Live validated/Clear success, released locks and saved-URL retention after network failure.
- [x] Settings/Tile Cache tests retain option identities/order/persistence boundaries and verify exact Search label/hint/semantics/select-all/eligibility, actual shared-menu input/cleanup and unchanged filter/correlation behaviour. Keep stable selector meaning across widget replacement and use deterministic preference/HTTP/client/clock/Riverpod seams, no live network/keys/user Store/Mapping volumes/other app checkout. Dispose containers/controllers/listeners/overlays; temporary ObjectBox, if genuinely needed, follows README prerequisites and closes before cleanup.
- [x] Verify native macOS rendering/input at 1280 × 960 and representative larger content sizes, default/enlarged text and My Seed Colour in dark mode only, draft-preserving resize/open menus and reachable labels/errors/actions by wrapping/scrolling. Preserve Desktop wide/macOS-only/maximised-launch target, ObjectBox/Riverpod/GoRouter and native window/full-screen configuration; no compact/iOS support, new breakpoint, schema/model/generated changes or template parity.
- [x] Run focused preference/provider/runtime/widget tests and affected existing robot regressions, `flutter analyze` and full `TZ=Australia/Hobart flutter test --reporter expanded` with documented native prerequisites. Distinguish automated, native rendering/input and any human review, reporting actual failures/blockers. No new TDD/journey framework is mandated; preserve any earlier explicit parser/domain test-first requirement if that logic changes.

## Covers

- User Stories: 1, 3, 4, 5 (Settings/API-key scope; Import in item 04).
- Requirements: R1; Settings scope of R2–3, R5–6; API-key scope of R7; R8; Settings scope of R10.
- Technical Decisions: 1, 2, 5, 6 and applicable completion/ownership guards.
- Testing Strategy: 1, 4–6, 8–12 as applicable to Settings.
- Interview Ledger: L1, L2, L4, L6, L9.
- Approved refinement decisions: 2; 3 (shared immediate-Enter caller regression).

## Blocked by

None — prerequisite [01-shared-field-and-dropdown-presentation.md](01-shared-field-and-dropdown-presentation.md) completed 2026-10-21.

## Implementation evidence

Completed 2026-10-22. All 15 acceptance criteria are verified; see
[Work Item 05 verification](../implementation-05-verification.md) for ownership,
phase-specific persistence recovery, automated/native evidence and journey risks.

- Final full suite: **2,873 passed, 6 inherited skips, no failures**.
- Static analysis: **no issues found**; focused regressions: **109 passed**, with
  final persistence/runtime **50 passed** and GPX/filter robot rerun **19 passed**.
- Native macOS pointer/keyboard and rendering checks: 1280 × 960 and 1600 × 1000,
  each at 1×/2× text, using My Seed Colour/dark only.
- No human visual/template-parity Pass or unrelated Time-layout acceptance is
  claimed. The existing default-credential review/rotation follow-up remains.
