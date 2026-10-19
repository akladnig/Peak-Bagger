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

- [x] With a Dashboard card focused, Cmd+Shift+Left moves it exactly one stored-order position earlier and Cmd+Shift+Right exactly one later. At either end the unavailable move is a no-op without wrapping or an unnecessary changed-order save. Retain focus on the moved card by stable ID and reveal it after layout/reconstruction.
- [x] The new visible order immediately becomes authoritative for rendering and full-order Tab/Shift+Tab traversal, including initially unbuilt cards and endpoint wrapping. Keep exactly one card stop and no internal/shell/action Tab stops. Repeated keyboard moves and pointer reorders retain the focused card and do not focus an obsolete index or target after stale lazy-build/scroll callbacks.
- [x] Both pointer and keyboard changed orders save through the existing Riverpod layout mechanism and `dashboard_card_order` shared-preferences key; do not add another order store/preference. Preserve existing sanitization/legacy IDs and Time's default-after-Distance versus missing-in-saved-order append policy. Preserve all per-card chart type/preference/page state permitted by the parent Spec.
- [x] On thrown save errors or a reported unsuccessful preference write, keep the latest visible order rather than rolling back. Show a SnackBar identifying card-order save failure with action exactly `Retry`, retain card focus and keep that retained order authoritative for traversal. No exact failure-message sentence beyond identifying the operation is selected by this Spec; do not substitute Time's exact preference error copy.
- [x] Retry saves the latest visible order after any subsequent moves, never an obsolete captured failed order. Serialize/coalesce writes so stale completions cannot overwrite the latest intended saved order; deduplicate retries for the same pending save. Track persistence success only after the write completes. The previous successfully saved order remains the restart result until a later save succeeds; a successful Retry reloads the latest order in a new provider lifecycle.
- [x] Log technical order-save failure context separately from actionable SnackBar guidance, without using raw exception text as the only user guidance. Use replaceable failure/read/write seams and explicit lifecycle ownership; disposal/stale operations must not restore an old visible order or publish from a disposed feedback owner.
- [x] Retry remains pointer-operable and introduces no extra Dashboard Tab stop or keyboard entry path under L16. R must not retry card-order warnings and remains reserved for the visible Time preference warning under requirement 36. Keep Time preference read/save warning identity, exact copy and queued-delivery policy distinct; do not silently transfer that warning policy to order saves.
- [x] Cmd+Shift reorder keys are scoped only to focused cards on active Dashboard. Preserve typing, normal modified editing/copy shortcuts including Cmd+C, dropdown/shell key ownership, pointer reordering and existing route/back outcomes. Menus, temporary shell navigation and inactive Dashboard must not also dispatch card reorder actions.
- [x] Preserve macOS-wide grid/card geometry, Time wrapping header and one-row toolbar, other cards' controls/labels/defaults/eligibility/chart/header presentation/chart preferences, mandatory foundations and existing dependency/readiness reporting. Add no new route, runtime network call, schema change, compact/iOS layout, guessed window minimum or global window policy. L18 shortcut hints/footer, accessible-only explanations, shortcut editing and Help screen remain deferred.
- [x] Extend provider tests with thrown/unsuccessful writes, retained visible order, further-move-then-Retry, overlap/latest-order persistence, retry deduplication, existing sanitization/default/saved-order append behavior, and new-lifecycle success/failure reload outcomes. Extend Dashboard widget tests for pointer and keyboard save failures, single-position/non-wrapping movement, retained/revealed focus, traversal after reorder through lazy targets in both directions/wraps, visible failure/Retry, and R not invoking order recovery. Test real pointer/keyboard dispatch into the shared save boundary, not just direct notifier calls.
- [x] Use deterministic preference failures/provider overrides, synthetic Tracks and controlled clocks/pumps for pending-write/lazy-focus races; stable existing card/drag/row/menu selectors and robot journeys remain intact. Fake tile access if Latest Walk is rendered and dispose test containers/controllers/listeners/resources. No live storage/services/user database/credentials, new strict TDD or robot-journey mandate.
- [x] Run `flutter analyze`, affected layout/provider/Dashboard/Time/summary widget tests under `TZ=Australia/Hobart`, and complete `TZ=Australia/Hobart flutter test`. Verify affected macOS-wide light/dark pointer/keyboard/focus/feedback at enlarged text without scale reduction. Record executed results and any genuinely Pending-value-dependent check; regression fixtures do not approve supported minima or full keyboard accessibility.

## Covers

- User Stories: 6 (keyboard reorder), 7.
- Requirements: 27 (reordering-aware traversal), 37–38; 36 (R exclusion regression).
- Technical Decisions: 1, 6, 9, 11–13.
- Testing Strategy: 1, 7–9, 11–12 (reorder, shared save recovery and narrowed Retry scope).
- Interview Ledger: L13–L14, L16–L17. L18 remains explicitly deferred, with no discovery/editor/Help implementation selected.

## Blocked by

- [04 — Deliver full-order card traversal and timeline/menu keyboard actions](04-dashboard-card-traversal-and-timeline-keys.md).

## Implementation and verification — 2026-10-19

**Work Item 07 completed.** Work Item 04's independent traversal foundation is
complete under L22. This slice preserves the existing geometry and does not
depend on choosing the profile's pending dimensions. Work Items 01–02 retain
L19's wrapping-header height/reachability gate and remain incomplete.

### Delivered behavior

- `DashboardLayoutNotifier.moveCardOnePosition` implements non-wrapping earlier/
  later movement and skips unchanged saves. The visible, immutable order remains
  in the existing layout provider; pointer drops and keyboard moves share its
  save boundary and `dashboard_card_order` storage identity.
- `dashboardOrderSaveProvider` owns observable pending/success/error outcomes and
  serialized physical writes. Intermediate moves coalesce into the latest visible
  order; Retry joins pending work and always reads that latest order. Failure
  retains rendering/traversal state. Diagnostic callbacks record the attempted
  order, error and stack separately from the user-facing message. New layout
  reads reload preferences to avoid SharedPreferences' optimistic failed-write
  cache; late startup reads cannot overwrite user moves, even a return to defaults.
- Dashboard handles only the exact Cmd+Shift+Left/Right chords for a focused card
  (or its pending stable-ID reveal). The order listener reuses full-order reveal
  after reconstruction, preserving focus/inspection instead of restarting card
  entry. New traversal, scope loss, inactive Dashboard and disposal supersede old
  callbacks. Menu, editing and temporary F6 shell ownership remain exclusive.
- Renamed the existing feedback owner to `DashboardPreferenceFeedback`. One
  presenter handles both domains without competing SnackBars: Time keeps its
  exact copy, warning identities, app-owned deferred delivery and Time-only R;
  order failures are delivered on the active surface, with operation-specific
  guidance and pointer `Retry`. Retrying shows pending progress and disables
  duplicate submission. Order Retry is explicitly excluded from focus entry;
  card-only traversal and retained card focus remain intact. Unresolved local
  order feedback can follow a Time warning while that Dashboard remains active;
  no app-owned once-on-next-activation order-warning policy is introduced.
- Technical Decision 11's pointer-only Retry/shell accessibility limitation remains
  an ADS-1.0 alignment gap with confirmed product scope, not an approved exception.
  The provisional L10 governance and deferred L18 discovery work remain unchanged.

### Executed checks

- `flutter analyze` — **passed, no issues**.
- Focused command: `env TZ=Australia/Hobart flutter test` with
  `--concurrency=4 --reporter failures-only` and these 18 files:
  - `test/providers/{dashboard_layout_provider,dashboard_data_load_outcome,dashboard_browsing_provider,time_chart_type_provider,summary_page_controller}_test.dart`
  - `test/widget/{dashboard_keyboard,dashboard_card_actions,dashboard_screen,dashboard_readiness,time_card,time_chart_preference,summary_card_navigation,summary_calendar_navigation,summary_chart_tooltip,distance_card,elevation_card,peaks_bagged_card}_test.dart`
  - `test/robot/dashboard/dashboard_journey_test.dart`
  - Result: **360 passed, 2 existing layout-gated skips**.
- `caffeinate -i env TZ=Australia/Hobart flutter test --concurrency=4 --reporter failures-only`
  — **2,675 passed, 7 skipped**. Two are L19's existing layout gate; five predate
  this feature. Existing map package notices and a map-route journey hit-test
  warning were non-failing output, not new order-save failures.
- New/extended provider and widget coverage exercises thrown and unsuccessful
  writes, retained visible order, previous durable order/new-lifecycle restoration,
  further moves before Retry, coalescing/serialization, retry deduplication,
  superseded failures, stale reads and disposal. Real pointer drags and keyboard
  dispatch verify the common boundary, both movement endpoints, repeated moves
  before paint, retained/revealed identity, full forward/reverse lazy traversal
  with wraps, per-card chart/page preservation, and overlapping focus/scope work.
- Real Time/order failures test exact Time copy and warning lifetime, R exclusion,
  stale Retry callbacks and pointer recovery. Production routed F6 tests also
  verify Cmd+Shift chords cannot reorder while shell destinations own focus.
- macOS-themed light/dark widget checks use **1.5× text scale** without reduction
  for reorder focus, lazy reveal and pointer failure/pending/Retry. These are
  deterministic desktop widget checks, not live native-app visual inspection or
  approval of regression fixture sizes as supported minima. The inherited Time
  long-header height/reachability checks remain gated under L19.
- Test data uses controlled preference writes, mock preferences, synthetic Tracks
  without preview geometry, and existing fake tile/provider seams where applicable.
  Containers, focus/scroll controllers, listeners and resources are disposed.
- `git diff --check` — passed. The pre-existing `macos/Podfile.lock` modification
  is unrelated to this implementation.
