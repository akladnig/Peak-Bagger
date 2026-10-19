---
type: Work Item
title: Remember Time's chart type with lifecycle-safe failure recovery
parent: ../spec.md
---

## What to build

Deliver remembered Time chart type end to end: app-owned Riverpod state, replaceable shared-preferences read/write boundaries, pending presentation, latest-choice-wins recovery, Dashboard-scoped warning delivery, and correct readiness accounting. Persist only the chart type; reuse the integrated card/menu and preserve its browsing. Work Item 06 adds R as a keyboard invocation of the same visible warning Retry action.

Apply ADS-1.0 and the Desktop wide/macOS-only profile with ObjectBox for existing domain records, Riverpod for state/DI, GoRouter for existing navigation, and shared preferences for this small preference. Do not copy silently swallowed failures from existing preference code. Widgets render/dispatch; app-owned preference work and unpresented failures survive card disposal.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md`, `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`, `ai_specs/peak-lists/0066-time-dashboard-card/work-items/02-time-chart-views-and-menu.md` and its Time/menu implementation.
- `lib/providers/dashboard_layout_provider.dart`: `dashboardPreferencesLoaderProvider`, existing loader/override/read-outcome patterns, and order identity that remains separate from chart type.
- `lib/providers/theme_provider.dart`, `lib/providers/peak_marker_info_settings_provider.dart`: preference/bootstrap ownership examples; their existing error policies are not approval to swallow Time failures.
- `lib/main.dart`, `lib/app.dart`, `lib/router.dart`, `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_readiness_provider.dart`: startup/provider lifecycle, offstage routed Dashboard activation, active feedback ownership, header revision/frame accounting and dependency failure reporting.
- `lib/widgets/dashboard/summary_card.dart`, `lib/providers/summary_page_controller.dart`, Time chart state/adapter/tests from Work Items 01–02: keep preset/page independent of restored type.
- `test/providers/dashboard_layout_provider_test.dart`, `test/providers/dashboard_data_load_outcome_test.dart`, `test/widget/dashboard_screen_test.dart`, `test/widget/dashboard_readiness_test.dart`, `test/robot/dashboard/dashboard_robot.dart`: deterministic preference/provider and lifecycle/readiness harness conventions.

## Acceptance criteria

- [x] Riverpod owns selected Time type, load/save/error state, warning identity/presentation state, and injected preference dependency at app scope, independently of Time's lazy-card lifecycle. Use shared preferences rather than ObjectBox for this value, with stable persisted identifiers unrelated to enum indices or visible labels. Define one authoritative selected type; widgets own only transient menu/focus/inspection presentation.
- [x] Restore each of `Stacked column view`, `Line view`, and `Clustered column view` in a new app/provider lifecycle and after navigation/reordering. No saved value or an unsupported value safely falls back to stacked without affecting domain data or other cards. Preference loading is visibly pending, not another type presented as completed startup state; existing Track loading must not flash `No time data yet` or stale summaries.
- [x] Startup preference-read failure uses Stacked column view, keeps the chart usable, and displays exactly `Couldn’t load Time chart preference.` with action `Retry`. Retry repeats the read and applies a valid restored type only if no newer explicit selection supersedes it; late initial/retry reads never overwrite a newer user choice.
- [x] Selecting a new type immediately updates visible type and saves it. Failed saves retain that visible type and show exactly `Couldn’t save Time chart preference.` with action `Retry`. Both thrown errors and a reported unsuccessful preference write are failures. The prior successfully saved type remains the startup default until a later successful save; do not publish persistence success before completion.
- [x] Save Retry writes the latest selected type, never a captured obsolete choice. Serialize/coalesce writes so older completions cannot overwrite the latest intended saved preference; deduplicate retries for the same pending operation. Chart browsing stays available. Type selection does not persist period/page, totals, hover/pins, row selection, or other cards' chart preferences, and does not reset calendar browsing or unrelated state. Preserve the existing clearing of incompatible inspection on type changes under parent requirement 19 and Work Item 02.
- [x] An active Dashboard-level feedback owner presents the exact read/save SnackBar immediately on active Dashboard, even with Time off-screen. If Dashboard is inactive/offstage/unmounted/disposed, retain an unpresented failure and show it once on the next active Dashboard. Presentation does not require Time to be constructed; no feedback is published to inactive/disposed surfaces.
- [x] Mark warnings presented so rebuilds, Time recreation, Dashboard remount and later navigation do not replay them. Clear a queued warning when a later successful operation resolves that failure before presentation. Superseded saves/late reads/disposal cannot restore stale visible type, discard app-owned pending work, replay obsolete warnings, or create duplicate listeners/effects. Preserve warning/retry identity so Work Item 06 can invoke only the currently displayed Time warning.
- [x] Integrate actual preference-read outcomes and completion with existing Dashboard readiness/header/frame accounting. A default painted before a pending read resolves is not restored local data, and a failed read with a usable fallback remains a failed dependency outcome, not fabricated persistence success. Retain existing dependency reporting; add no new performance target.
- [x] Log technical read/write failures with useful operation context and diagnostics separately from the exact user guidance; raw exception text is not user guidance. Keep SnackBar Retry pointer-operable. Keyboard R behavior is completed in Work Item 06 and must use this same retry path, with no extra Dashboard Tab stop.
- [x] Preserve semantic light/dark pending/feedback presentation, accessible action names, text scaling, existing card/menu geometry and Desktop wide scope. No new routes, runtime network calls, domain records/schema changes, packages without demonstrated necessity, global window policy, iOS/compact layout, or replacement foundations are introduced.
- [x] Add unit/provider and focused widget coverage using controllable storage fakes/overrides: missing/unsupported/all three saved values, new-lifecycle restore, delayed reads, thrown reads/writes, unsuccessful writes, exact SnackBars/Retry, retained selection, successful retry/restart, overlapping requests, stale read/retry protection, retry deduplication, and disposal. Exercise failures offstage/unmounted or with Time disposed/off-screen, exactly-once next-active delivery, no replay, queued-warning clearing, correct readiness, and diagnostic failure visibility. Use controlled pumps rather than serializing away races; preserve stable card/menu/robot selectors and dispose containers/listeners/resources. No real storage/services/user database/credentials, strict TDD, or new robot mandate.
- [x] Run `flutter analyze`, affected preference/provider/Time/Dashboard/readiness tests under `TZ=Australia/Hobart`, and the complete `TZ=Australia/Hobart flutter test` suite. Verify affected macOS-wide light/dark pending/feedback, pointer actions, available keyboard/focus and enlarged text without reducing scale. Report actual results; any genuinely dependent Pending layout value is resolved before dependent verification, not guessed.

## Covers

- User Stories: 3.
- Requirements: 3 (loading/failure preservation), 23–26.
- Technical Decisions: 1, 4, 6–9, 13 (app ownership/readiness and scope boundaries).
- Testing Strategy: 1, 4 (preference loading), 5, 7–9.
- Interview Ledger: L5, L9, L12. L18 remains deferred; no shortcut-discovery/Help/editor surface is added.

## Blocked by

- Uses the verified independent chart/menu foundation from [02 — Add Time's three chart views and chart-type menu](02-time-chart-views-and-menu.md). The user authorised independent Work Item 03 preference/recovery work on 2026-10-18 (Interview Ledger L21).
- Retain L19's wrapping-header height/reachability gate and incomplete dependent verification; this authorisation does not resolve Pending profile/window values or mark Work Items 01–02 complete.

## Implementation progress — 2026-10-18

**Work Item 03's independent preference/recovery scope is implemented and verified under L21.** The inherited wrapping-header height/reachability gate remains open under L19; the two dependent Dashboard tests remain skipped, and Work Items 01–02 remain incomplete. No minimum window size, resize range, native window mode or feature-layout threshold was selected.

### Implemented

- Extended the existing app-owned `timeChartTypeProvider` with one selected type, actual read/save outcomes, hydration, warning identity/presentation and currently visible warning identity. App bootstrap initializes the notifier without subscribing the root App/router to preference-state changes. Card disposal does not dispose preference work.
- **Source conflict clarified:** this item's original blanket “does not persist/reset … hover/pins” wording conflicted with parent requirement 19 and completed Work Item 02 inspection behavior. The criterion now distinguishes forbidden persistence/unrelated resets from the parent's required clearing of incompatible inspection. This slice preserves that parent contract and existing behavior; it introduces no inspection-policy change or standard exception.
- Added replaceable `TimeChartPreferenceStorage` and diagnostics providers. Production storage reuses `dashboardPreferencesLoaderProvider` and persists only `dashboard_time_chart_type`, using `stacked-column`, `line`, and `clustered-column`. Missing/unsupported identifiers fall back to stacked. No domain data, calendar/page or other chart preferences are written.
- Guarded initial/retry reads against explicit user choices; serialized/coalesced physical writes; retained optimistic selection on thrown/false saves; suppressed superseded operation warnings; and exposed identity-checked `retryWarning` / `retryVisibleWarning` for the pointer action and Work Item 06. Diagnostics include operation, storage key, selected identifier/revision where applicable, error and stack.
- Time uses its existing loading state until initial hydration completes, with header summaries withheld. Save/read-retry progress overlays the card without changing its geometry or disabling browsing. Failed read fallback remains usable while retaining an actual failed dependency outcome.
- Added `TimeChartPreferenceFeedback` at Dashboard scope with a Dashboard-local messenger. It observes routed activation/TickerMode and app lifecycle, presents even without Time constructed, marks warning delivery after a visible frame, removes presentation on exit, and retains unpresented failures across unmount/remount. Retry is pointer-operable and its focus node skips Tab traversal. Full card keyboard behavior remains later work.
- Added 20 provider tests and 11 focused widget tests with controllable durable-storage fakes, real shared-preferences mock integration, diagnostic capture, delayed completions, synchronous/asynchronous throws, unsuccessful writes, stale-read protection, latest-choice save serialization/retry, disposal, off-screen/offstage/unmounted delivery, routed navigation, no replay, pending/readiness/header behavior and App/router identity. Existing Time/calendar/navigation fixtures now provide deterministic preferences. Full-suite checks also identified two older routed Admin/Tasmap harnesses needing the same mock dependency; their product assertions are retained.

### Executed verification

- `flutter analyze` — **passed, no issues**.
- `env TZ=Australia/Hobart flutter test test/providers/time_chart_type_provider_test.dart test/providers/dashboard_layout_provider_test.dart test/providers/dashboard_data_load_outcome_test.dart test/services/time_summary_metrics_test.dart test/providers/summary_page_controller_test.dart test/widget/time_chart_preference_test.dart test/widget/time_card_test.dart test/widget/summary_chart_tooltip_test.dart test/widget/summary_calendar_navigation_test.dart test/widget/summary_card_navigation_test.dart test/widget/distance_card_test.dart test/widget/elevation_card_test.dart test/widget/peaks_bagged_card_test.dart test/widget/dashboard_screen_test.dart test/widget/dashboard_readiness_test.dart test/robot/dashboard/dashboard_journey_test.dart --reporter expanded` — **285 passed, 2 inherited gated skips**.
- `env TZ=Australia/Hobart flutter test test/widget/objectbox_admin_shell_test.dart test/widget/tasmap_map_screen_test.dart --reporter expanded` — **46 passed** after adding deterministic shared-preferences setup.
- `caffeinate -i env TZ=Australia/Hobart flutter test --reporter expanded` — final run **2,595 passed, 7 skipped**, approximately **18 minutes 2 seconds**. Two skips retain L19's layout gate; five pre-existed this work. The first full run had 2,593 passes and the two missing-preferences harness timeouts, both corrected before the final passing run.
- macOS-targeted widget fixtures passed light/dark pending, exact read/save feedback and pointer Retry checks at **1.5× text scale**, with accessible labels and no extra Retry Tab stop. Existing menu keyboard/focus, chart/calendar and Dashboard robot regressions passed. These fixtures are regression evidence, not approved window minima. No separate live native-app visual inspection was performed; L19-dependent long-header layout verification remains gated.
- Initial focused checks exposed an unsafe widget `ref` read during teardown, pending cleanup in one test, and a disposal fixture completing a read before dispatch. Lifecycle ownership and the controlled test timing were corrected before the final passing runs.

### Remaining feature work

- Work Item 06 must bind R only to the currently visible Time warning using the shared retry path. Work Items 04–05 retain the card/menu/inspection keyboard requirements; this slice adds no shortcut discovery or Help/editor surface.
- Resolve L19's actual supported window/Time layout contract before completing the inherited wrapping-header height/reachability checks. This slice claims no full-feature or whole-app ADS-1.0 compliance.
