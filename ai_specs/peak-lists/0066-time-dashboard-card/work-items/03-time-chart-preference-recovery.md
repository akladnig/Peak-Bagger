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

- [ ] Riverpod owns selected Time type, load/save/error state, warning identity/presentation state, and injected preference dependency at app scope, independently of Time's lazy-card lifecycle. Use shared preferences rather than ObjectBox for this value, with stable persisted identifiers unrelated to enum indices or visible labels. Define one authoritative selected type; widgets own only transient menu/focus/inspection presentation.
- [ ] Restore each of `Stacked column view`, `Line view`, and `Clustered column view` in a new app/provider lifecycle and after navigation/reordering. No saved value or an unsupported value safely falls back to stacked without affecting domain data or other cards. Preference loading is visibly pending, not another type presented as completed startup state; existing Track loading must not flash `No time data yet` or stale summaries.
- [ ] Startup preference-read failure uses Stacked column view, keeps the chart usable, and displays exactly `Couldn’t load Time chart preference.` with action `Retry`. Retry repeats the read and applies a valid restored type only if no newer explicit selection supersedes it; late initial/retry reads never overwrite a newer user choice.
- [ ] Selecting a new type immediately updates visible type and saves it. Failed saves retain that visible type and show exactly `Couldn’t save Time chart preference.` with action `Retry`. Both thrown errors and a reported unsuccessful preference write are failures. The prior successfully saved type remains the startup default until a later successful save; do not publish persistence success before completion.
- [ ] Save Retry writes the latest selected type, never a captured obsolete choice. Serialize/coalesce writes so older completions cannot overwrite the latest intended saved preference; deduplicate retries for the same pending operation. Chart browsing stays available. Type selection does not persist/reset period/page, totals, hover/pins, row selection, or other cards' chart preferences.
- [ ] An active Dashboard-level feedback owner presents the exact read/save SnackBar immediately on active Dashboard, even with Time off-screen. If Dashboard is inactive/offstage/unmounted/disposed, retain an unpresented failure and show it once on the next active Dashboard. Presentation does not require Time to be constructed; no feedback is published to inactive/disposed surfaces.
- [ ] Mark warnings presented so rebuilds, Time recreation, Dashboard remount and later navigation do not replay them. Clear a queued warning when a later successful operation resolves that failure before presentation. Superseded saves/late reads/disposal cannot restore stale visible type, discard app-owned pending work, replay obsolete warnings, or create duplicate listeners/effects. Preserve warning/retry identity so Work Item 06 can invoke only the currently displayed Time warning.
- [ ] Integrate actual preference-read outcomes and completion with existing Dashboard readiness/header/frame accounting. A default painted before a pending read resolves is not restored local data, and a failed read with a usable fallback remains a failed dependency outcome, not fabricated persistence success. Retain existing dependency reporting; add no new performance target.
- [ ] Log technical read/write failures with useful operation context and diagnostics separately from the exact user guidance; raw exception text is not user guidance. Keep SnackBar Retry pointer-operable. Keyboard R behavior is completed in Work Item 06 and must use this same retry path, with no extra Dashboard Tab stop.
- [ ] Preserve semantic light/dark pending/feedback presentation, accessible action names, text scaling, existing card/menu geometry and Desktop wide scope. No new routes, runtime network calls, domain records/schema changes, packages without demonstrated necessity, global window policy, iOS/compact layout, or replacement foundations are introduced.
- [ ] Add unit/provider and focused widget coverage using controllable storage fakes/overrides: missing/unsupported/all three saved values, new-lifecycle restore, delayed reads, thrown reads/writes, unsuccessful writes, exact SnackBars/Retry, retained selection, successful retry/restart, overlapping requests, stale read/retry protection, retry deduplication, and disposal. Exercise failures offstage/unmounted or with Time disposed/off-screen, exactly-once next-active delivery, no replay, queued-warning clearing, correct readiness, and diagnostic failure visibility. Use controlled pumps rather than serializing away races; preserve stable card/menu/robot selectors and dispose containers/listeners/resources. No real storage/services/user database/credentials, strict TDD, or new robot mandate.
- [ ] Run `flutter analyze`, affected preference/provider/Time/Dashboard/readiness tests under `TZ=Australia/Hobart`, and the complete `TZ=Australia/Hobart flutter test` suite. Verify affected macOS-wide light/dark pending/feedback, pointer actions, available keyboard/focus and enlarged text without reducing scale. Report actual results; any genuinely dependent Pending layout value is resolved before dependent verification, not guessed.

## Covers

- User Stories: 3.
- Requirements: 3 (loading/failure preservation), 23–26.
- Technical Decisions: 1, 4, 6–9, 13 (app ownership/readiness and scope boundaries).
- Testing Strategy: 1, 4 (preference loading), 5, 7–9.
- Interview Ledger: L5, L9, L12. L18 remains deferred; no shortcut-discovery/Help/editor surface is added.

## Blocked by

- [02 — Add Time's three chart views and chart-type menu](02-time-chart-views-and-menu.md).
