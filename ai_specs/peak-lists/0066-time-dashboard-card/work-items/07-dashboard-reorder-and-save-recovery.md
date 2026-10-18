---
type: Work Item
title: Add keyboard reordering and latest-order save recovery
parent: ../spec.md
---

## What to build

Deliver keyboard reordering and shared pointer/keyboard order-save recovery through the existing Dashboard layout notifier/preferences boundary, visible authoritative order, focus/reveal coordination and failure SnackBar. Retry saves the latest visible order, with deterministic provider/widget tests for unsuccessful writes, exceptions, overlap and restart. Reuse the existing `dashboard_card_order` identity/storage and Work Item 04's stable-ID full-order traversal rather than creating another order or chart preference.

Apply ADS-1.0 and Desktop wide/macOS-only semantic light/dark focus/error/pending feedback, keyboard/pointer controls and text scaling, keeping ObjectBox/Riverpod/GoRouter foundations. Technical Decision 11's deliberate limitation remains recorded: L16/L17 confirm pointer-operable card-order Retry without a keyboard entry path/Tab stop; R is Time-preference-only. This is confirmed product scope with an unresolved ADS-1.0 accessibility gap, not an approved standard exception or settled provisional L10 process.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`, `ai_specs/peak-lists/0066-time-dashboard-card/work-items/04-dashboard-card-traversal-and-timeline-keys.md` and its stored-order focus/reveal implementation.
- `lib/providers/dashboard_layout_provider.dart`: `DashboardLayoutNotifier.setOrder`/`moveCard`, `dashboardPreferencesLoaderProvider`, order sanitization/read outcomes and `dashboardCardOrderStorageKey = 'dashboard_card_order'`. Current swallowed exceptions/ignored unsuccessful writes are implementation gaps to change.
- `lib/screens/dashboard_screen.dart`, `lib/router.dart`, `lib/providers/dashboard_readiness_provider.dart`: pointer drag/drop callbacks, stable card identity, lazy grid/order/readiness, active feedback/focus and shell-scope boundaries.
- Time preference/feedback implementation from Work Item 03 and R integration from 06 when available: keep warning/retry domains distinct; these are integration context, not additional prerequisites for independent order-save recovery.
- `test/providers/dashboard_layout_provider_test.dart`, `test/providers/dashboard_data_load_outcome_test.dart`, `test/widget/dashboard_screen_test.dart`, `test/widget/dashboard_readiness_test.dart`, `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`: injected preferences, reload, pointer reorder, routed focus and selector conventions.

## Acceptance criteria

- [ ] With a Dashboard card focused, Cmd+Shift+Left moves it exactly one stored-order position earlier and Cmd+Shift+Right exactly one later. At either end the unavailable move is a no-op without wrapping or an unnecessary changed-order save. Retain focus on the moved card by stable ID and reveal it after layout/reconstruction.
- [ ] The new visible order immediately becomes authoritative for rendering and full-order Tab/Shift+Tab traversal, including initially unbuilt cards and endpoint wrapping. Keep exactly one card stop and no internal/shell/action Tab stops. Repeated keyboard moves and pointer reorders retain the focused card and do not focus an obsolete index or target after stale lazy-build/scroll callbacks.
- [ ] Both pointer and keyboard changed orders save through the existing Riverpod layout mechanism and `dashboard_card_order` shared-preferences key; do not add another order store/preference. Preserve existing sanitization/legacy IDs and Time's default-after-Distance versus missing-in-saved-order append policy. Preserve all per-card chart type/preference/page state permitted by the parent Spec.
- [ ] On thrown save errors or a reported unsuccessful preference write, keep the latest visible order rather than rolling back. Show a SnackBar identifying card-order save failure with action exactly `Retry`, retain card focus and keep that retained order authoritative for traversal. No exact failure-message sentence beyond identifying the operation is selected by this Spec; do not substitute Time's exact preference error copy.
- [ ] Retry saves the latest visible order after any subsequent moves, never an obsolete captured failed order. Serialize/coalesce writes so stale completions cannot overwrite the latest intended saved order; deduplicate retries for the same pending save. Track persistence success only after the write completes. The previous successfully saved order remains the restart result until a later save succeeds; a successful Retry reloads the latest order in a new provider lifecycle.
- [ ] Log technical order-save failure context separately from actionable SnackBar guidance, without using raw exception text as the only user guidance. Use replaceable failure/read/write seams and explicit lifecycle ownership; disposal/stale operations must not restore an old visible order or publish from a disposed feedback owner.
- [ ] Retry remains pointer-operable and introduces no extra Dashboard Tab stop or keyboard entry path under L16. R must not retry card-order warnings and remains reserved for the visible Time preference warning under requirement 36. Keep Time preference read/save warning identity, exact copy and queued-delivery policy distinct; do not silently transfer that warning policy to order saves.
- [ ] Cmd+Shift reorder keys are scoped only to focused cards on active Dashboard. Preserve typing, normal modified editing/copy shortcuts including Cmd+C, dropdown/shell key ownership, pointer reordering and existing route/back outcomes. Menus, temporary shell navigation and inactive Dashboard must not also dispatch card reorder actions.
- [ ] Preserve macOS-wide grid/card geometry, Time wrapping header and one-row toolbar, other cards' controls/labels/defaults/eligibility/chart/header presentation/chart preferences, mandatory foundations and existing dependency/readiness reporting. Add no new route, runtime network call, schema change, compact/iOS layout, guessed window minimum or global window policy. L18 shortcut hints/footer, accessible-only explanations, shortcut editing and Help screen remain deferred.
- [ ] Extend provider tests with thrown/unsuccessful writes, retained visible order, further-move-then-Retry, overlap/latest-order persistence, retry deduplication, existing sanitization/default/saved-order append behavior, and new-lifecycle success/failure reload outcomes. Extend Dashboard widget tests for pointer and keyboard save failures, single-position/non-wrapping movement, retained/revealed focus, traversal after reorder through lazy targets in both directions/wraps, visible failure/Retry, and R not invoking order recovery. Test real pointer/keyboard dispatch into the shared save boundary, not just direct notifier calls.
- [ ] Use deterministic preference failures/provider overrides, synthetic Tracks and controlled clocks/pumps for pending-write/lazy-focus races; stable existing card/drag/row/menu selectors and robot journeys remain intact. Fake tile access if Latest Walk is rendered and dispose test containers/controllers/listeners/resources. No live storage/services/user database/credentials, new strict TDD or robot-journey mandate.
- [ ] Run `flutter analyze`, affected layout/provider/Dashboard/Time/summary widget tests under `TZ=Australia/Hobart`, and complete `TZ=Australia/Hobart flutter test`. Verify affected macOS-wide light/dark pointer/keyboard/focus/feedback at enlarged text without scale reduction. Record executed results and any genuinely Pending-value-dependent check; regression fixtures do not approve supported minima or full keyboard accessibility.

## Covers

- User Stories: 6 (keyboard reorder), 7.
- Requirements: 27 (reordering-aware traversal), 37–38; 36 (R exclusion regression).
- Technical Decisions: 1, 6, 9, 11–13.
- Testing Strategy: 1, 7–9, 11–12 (reorder, shared save recovery and narrowed Retry scope).
- Interview Ledger: L13–L14, L16–L17. L18 remains explicitly deferred, with no discovery/editor/Help implementation selected.

## Blocked by

- [04 — Deliver full-order card traversal and timeline/menu keyboard actions](04-dashboard-card-traversal-and-timeline-keys.md).
