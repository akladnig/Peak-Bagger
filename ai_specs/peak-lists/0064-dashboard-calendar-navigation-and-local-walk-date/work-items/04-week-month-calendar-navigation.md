---
type: Work Item
title: Browse complete Week and Month pages across all three timeline cards
parent: ../spec.md
---

## What to build

Deliver full-history Week/Month browsing vertically through shared page calculations, authoritative per-card Riverpod state, the routed injectable reference clock, four-button UI, synchronized summaries/tooltips, and service/widget tests. Use the common SummaryCard path for Peaks Bagged, Elevation, and Distance rather than separate navigation implementations. Multi-month/yearly contracts extend this flow in item 5; direct-input/refresh/rollover reconciliation is completed in item 6.

## Required context

Paths in this section are relative to the project root.

- `ai_specs/coding-rules.md` (ADS-1.0) and `ai_specs/app-profile.md` (Desktop wide/macOS-only/maximised, mandatory Riverpod/GoRouter, semantic themes, accessible focus/cursors/text scaling, named Pending values).
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`: Requirements 3–5, 9–16, and 18–21 (Week/Month portions); Technical Decisions 1–7; Testing Strategy 1 and 3–8. Read sibling `interview-ledger.md`, especially L1/L3/L6/L9, and `GLOSSARY.md`.
- `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/work-items/02-location-derived-import-dates.md` and its implemented calendar/status decoder. Do not reinterpret canonical carriers with `toLocal()` or silently treat skipped legacy values as corrected.
- `lib/services/summary_card_service.dart`, `lib/services/elevation_summary_service.dart`, `lib/services/peaks_bagged_summary_service.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, and the `elevation_card.dart`, `distance_card.dart`, and `peaks_bagged_card.dart` adapters in that widget directory.
- `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_readiness_provider.dart`, `lib/providers/map_provider.dart`, `lib/router.dart`, `lib/core/date_formatters.dart`, `lib/core/constants.dart`, and `lib/theme.dart` for clock/state/header callbacks, routed activation, shared formatting, and toolbar styles.
- `test/services/summary_card_service_test.dart`, `test/services/elevation_summary_service_test.dart`, the three card tests and `summary_chart_tooltip_test.dart` under `test/widget/`, and `test/widget/dashboard_screen_test.dart` / `dashboard_readiness_test.dart`.
- `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/elevation_journey_test.dart`, and `test/harness/test_map_notifier.dart` for routed provider seams. Item 6 owns the expanded interaction journey, but the injected clock must already reach the real routed Dashboard in this slice.
- Historical `ai_specs/dashboard/elevation-card-spec.md` trailing windows/half-window movement/offset preservation are superseded by the parent Spec. Inspect the existing user edits to `summary_chart.dart` and its tooltip test before modifying affected behavior; preserve unrelated work.

## Acceptance criteria

- [x] Apply the shared behavior to Peaks Bagged, Elevation, and Distance in both line and column modes. Retain preset labels/order exactly: `Week`, `Month`, `Last 3 Months`, `Last 6 Months`, `Last 12 Months`, `Year to Date`, `All Time`; retain default `Last 12 Months` (its full current-page contract is completed in item 5).
- [x] Selecting a different `Week` or `Month` preset opens the current period even when latest activity is older. Week is exactly seven daily buckets Monday–Sunday; Month has one daily bucket per day of the complete calendar month, including 28/29/30/31-day months. Navigate by whole calendar weeks/months, never half windows or trailing partial periods.
- [x] Reach all qualifying recorded history, including records several years old and consecutive empty periods, without truncation to recent 14 days or previous/current month. Use calendar arithmetic and end-exclusive boundaries across leap/year/DST transitions; elapsed 24-hour subtraction is not a calendar-week definition.
- [x] Maintain one authoritative selected calendar page per card in the Riverpod/application-state boundary; derive range, endpoint destinations, button availability, buckets, summaries, and scroll destination from it. Pixel offsets are presentation state, not page identity, and no second persisted/widget-owned copy of domain data is introduced. Cards browse independently.
- [x] Inject a Dashboard reference clock through Riverpod while retaining explicit `SummaryCardService.buildTimeline(... now:)`, card `now`, and `DashboardScreen.now` test inputs. Production uses the Mac-local calendar reference; the actual routed `/` Dashboard must consume the injectable clock so an advanceable override controls it. Provide the reference/state seams needed by item 6 without a midnight background timer.
- [x] Toolbar sequence is exactly first → prev → next → last, with `Icons.first_page`, existing chevrons, and `Icons.last_page`. First/last tooltips and accessible action names are lowercase `first` and `last`; Week arrows are `Previous Week` / `Next Week`, Month arrows are `Previous Month` / `Next Month`. Enabled controls must not use `Previous window` / `Next window`.
- [x] first/last locate the established pages containing the earliest/latest qualifying primary-metric record. Preserve each card's own primary-metric eligibility and peaks/new-peaks meanings; secondary-series inactivity must not remove a primary page or determine its endpoints. Do not require a new-peak secondary value.
- [x] Prev/Next visit every consecutive page, including zero-chart/zero-summary gaps, stopping at the earliest-record page backwards and current period forwards. No wrapping/skipping. With latest activity in August and reference month October, last opens August, then `Next Month` visits September and October.
- [x] Disable each control when its destination is already displayed or absent. last can be disabled on an older latest-record page while Next is enabled toward today; last can be enabled on today's page when latest activity is older. All four are disabled only when the entire permitted range is one page; one historical activity page does not by itself disable forward navigation toward today.
- [x] Chart values, date range through the last included day, total, and average agree on the selected complete page. Preserve metric definitions, units, rounding, palettes, and exact average labels Week `Daily Avg:` / Month `Weekly Avg:`. Include zero-valued periods consistently and align primary/secondary daily boundaries.
- [x] Month hover titles use shared formatting with exact `EEE d MMM` shape, for example `Thu 15 Oct`, without comma/year, in both modes. Preserve tooltip metric rows/values and existing inspection behavior except where page changes make selection obsolete.
- [x] Exclude calendar days after the Mac-local reference day from values and endpoints for both series in Week/Month, using item 2's intended-day decoder. Retain complete-page future dates as zero buckets. Future-only datasets use the existing no-qualifying-data state; this defensive display cutoff neither repairs data nor changes Latest Walk selection.
- [x] Preserve loading and wholly empty-dataset copy: `No walks yet`, `No elevation data yet`, `No distance data yet`, and `No peaks bagged yet` where applicable. An empty page inside qualifying history is navigable zero data, not the empty-dataset state; loading never flashes no-data.
- [x] Keep the selector, ordered navigation group, and line/column toggle on one row. Preserve Dashboard geometry/reordering and text scale; do not wrap to a second row, suppress text scaling, invent minimum dimensions, add compact/iOS/touch obligations, or choose native full-screen behavior.
- [x] Verify semantic light/dark styling, visible keyboard focus/activation and logical traversal, accessible descriptions/tooltips, selection distinct from hover, disabled styling/default cursor, and enabled pointing/click cursor. Existing toolbar controls remain icon buttons rather than being changed to popup-footer FilledButtons.
- [x] Preserve Dashboard entry/exit, Latest Walk map navigation, dependency-failure reporting, and unrelated network behavior; add no runtime request/credentials, domain writes, persisted summaries, or navigation preferences. Shared timeline/header caches must not report a different selected page; item 6 completes adversarial refresh/movement reconciliation.
- [x] Extend service/widget tests for all three adapters/modes, current-period entry, all four icons/order/destinations/cursors, exact tooltips, full history/gaps, daily/weekly summary roles, Month hover, and initial reference-clock injection through the routed screen. Use independent Hobart DST offset expectations for both transitions plus no dropped/duplicated calendar days. Update superseded bounded-history/half-window assertions using behavior-first regressions, without an additional strict TDD mandate.

### Verification

Add `test/providers/summary_page_controller_test.dart` for the page-state/clock behavior and extend the existing tests below. Use fixed data, Riverpod overrides, mapping/repository/preference fakes and `latestWalkTileProviderFactoryProvider` when Latest Walk renders; no live tiles, services, credentials, or user database. Dispose all resources.

```sh
TZ=Australia/Hobart flutter test \
  test/services/summary_card_service_test.dart \
  test/services/elevation_summary_service_test.dart \
  test/providers/summary_page_controller_test.dart \
  test/widget/elevation_card_test.dart \
  test/widget/distance_card_test.dart \
  test/widget/peaks_bagged_card_test.dart \
  test/widget/summary_chart_tooltip_test.dart \
  test/widget/dashboard_screen_test.dart \
  test/widget/dashboard_readiness_test.dart
flutter analyze
TZ=Australia/Hobart flutter test
```

Also complete the parent Spec's exact Testing Strategy 8 focused block. Check the single-row toolbar on actual macOS wide layouts in light/dark themes, with keyboard input and enlarged text. Existing card constraints are regression fixtures, not approved minimum window dimensions. Record any actually dimension-dependent check as gated under Blocking decisions rather than claiming it passed.

### Completion evidence — 2026-10-16

- `SummaryCardService` now defines full end-exclusive Week/Month pages, whole-calendar adjacency, primary-metric first/last destinations, and the separate current-period forward limit. It aggregates the selected page only; primary and secondary series use the same explicit page even when the secondary series has no qualifying values. Track dates use `TrackDateCalendarCodec`, with a reference-day cutoff and complete future zero buckets.
- `summaryPageControllerProvider` owns each mounted card's independent preset/page selection. Daily page identity is never derived from scroll pixels. The shared `SummaryCard` renders Week/Month range, chart, total and average from that selection; existing non-daily rendering remains the extension point for item 5. Navigation is immediate for these daily pages; direct panning/scroll settling and adversarial refresh/rollover handling remain item 6.
- `dashboardReferenceClockProvider` reaches the actual routed Dashboard while explicit `now` inputs remain supported. The elevation journey uses an advanceable fixed clock and checks October Month entry, a February 2020 first jump, last, mode/hover behavior, and November Week entry after a data refresh. No midnight timer or persisted navigation state was added.
- Shared toolbar controls have exact icons/order/tooltips and semantic names, compact centrally defined semantic light/dark styling, differentiated focus/hover overlays, keyboard activation, and enabled/disabled cursors. Preset labels retain their text scale and may wrap inside the selector; the selector, navigation group and mode toggle remain in one toolbar row. The prior chart selection-invalidation change and its existing hover/pinned regression tests were retained and incorporated because page changes rely on that behavior.
- Added `test/providers/summary_page_controller_test.dart` and `test/widget/summary_calendar_navigation_test.dart`. The latter covers all three actual adapters, both modes, both daily presets, current-period entry, multi-year first/last, consecutive gaps, endpoints/cursors/order, summary roles, repeated peaks without new peaks, missing secondary data, Month hover `Thu 15 Oct`, future values in both series, future-only empty states, keyboard focus/traversal/Enter, semantics, and light/dark 1.5× text. Service tests cover 28/29/30/31 days, leap/year boundaries and both Hobart DST transitions with independent `+11 → +10` / `+10 → +11` offset assertions and complete daily assignments. Distance's existing non-null zero value remains qualifying primary activity.
- The Work Item focused block plus the new shared widget test passed (**106 tests** before the final additional year-boundary/future-only cases); the final full suite includes all of them. Parent Testing Strategy 8's exact nine-file block passed (**83 tests**). The affected shared-widget and existing Dashboard-journey rerun passed (**31 tests**) after correcting a fixture's zero-distance eligibility assumption and making `DashboardRobot.pumpApp` unmount/settle the prior scope before replacing its container.
- Final `flutter analyze`: **no issues**. Final `TZ=Australia/Hobart flutter test --reporter expanded`: **2,376 passed, 5 skipped**. This includes the existing date-derivation/import/migration tests, Dashboard entry/exit/map/readiness paths, and existing journeys. `flutter build macos --debug`: **passed** after restoring the normal entry point following the native preview. ObjectBox's existing Swift Package Manager warning remains non-fatal.
- Actual macOS verification used a temporary fake-data entry point rendering the real `DashboardScreen`, fixed/advanceable clock/provider seams, mock preferences and in-memory repositories, without opening the user database or rendering live Latest Walk tiles. At the observed maximised **1710 × 1073** native window (an observation, not an approved minimum), inspected light/dark and 1×/1.5× text; Tab focus was visibly distinct, Enter on first opened February 2020, and Tab/Enter on Next opened the zero-valued March page with matching range/total/average. All three toolbars retained their single row. Temporary preview was terminated; normal app build restored. Window-only screenshots are in the session temporary directory as `spec0064-calendar-light.png`, `spec0064-calendar-light-focus.png`, `spec0064-calendar-dark-enlarged.png`, and `spec0064-calendar-light-enlarged-gap.png`.
- Scope/authority review: the historical trailing/half-window Week/Month contract is superseded as the parent Spec states. No foundation replacement or intentional shared-rule exception is proposed. Existing Dashboard title ellipsis at 1.5× text was observed outside the toolbar; this remains an alignment gap, not approved compliance. Supported-range/minimum-size verification remains gated by the named Pending values below; the observed native window and regression fixtures resolve none of them.

### Journey Verification

- Journey: Routed Dashboard full-history calendar navigation, inspection, mode switching and injected reference clock.
- Verification command(s): `TZ=Australia/Hobart flutter test test/robot/dashboard/elevation_journey_test.dart`; exercised in the exact parent focused block and final full suite.
- Required seams/selectors: advanceable `dashboardReferenceClockProvider`, existing mapping/repository/preference overrides and `TestMapNotifier`; card-scoped `summary-period-dropdown`, `summary-first-window`, `summary-prev-window`, `summary-next-window`, `summary-last-window`, `summary-mode-fab`, range/header and bucket keys.
- Result: `pass`.
- Remaining risk: item 5 owns anchored multi-month/yearly page semantics; item 6 owns snapped horizontal input and adversarial refresh/movement/rollover reconciliation. Supported-window-range checks are gated below. The existing journey file keeps its established inline setup; no multi-journey harness restructuring was introduced.

Summary: the affected elevation journey and eight existing Dashboard journeys passed; no declared journey was skipped. Remaining risks are the explicitly later slices and pending supported dimensions.

## Covers

- User Stories: 2; 4–5 (Week/Month button/summary/hover behavior).
- Requirements: 3–5; 9–16; 18–21 (applicable Week/Month/shared-toolbar portions).
- Technical Decisions: 1–4; 6–7; preserve 5's lifecycle ownership while item 6 completes interruption handling.
- Testing Strategy: 1; 3–6; 7 (routed clock/selector seams); 8.
- Interview Ledger: L1; L3; L6; L9.
- Approved refinement decisions: future-date cutoff/current-period entry and injectable clock in Spec Notes; R4; respect R1/R5 canonical decoding from item 2.

## Blocked by

- [02-location-derived-import-dates.md](02-location-derived-import-dates.md)

## Blocking decisions

- The profile's **Pending — minimum usable macOS width**, **Pending — minimum usable macOS height**, **Pending — supported macOS resize range**, and **Pending — feature-specific wide-layout thresholds** must be resolved in the profile/Spec before any implementation or verification that actually depends on them. Existing-card regression fixtures and independent date/page logic may proceed. Native observed `1024 × 0` is not an approved usable range. If the one-row toolbar cannot satisfy accessibility/usability, report the conflict rather than silently wrapping it or reducing text scale.
- Completion gate retained: toolbar checks passed at the observed wide native window and existing regression constraints. No check across an approved minimum/resize range is claimed; those dimensions remain unresolved. Existing Dashboard card-title ellipsis at enlarged text is recorded above for later profile/layout alignment.
