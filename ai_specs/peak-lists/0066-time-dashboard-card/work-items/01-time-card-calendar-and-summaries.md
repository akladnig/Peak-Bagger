---
type: Work Item
title: Add Time's eligible-duration chart and calendar summaries
parent: ../spec.md
---

## What to build

Deliver the first vertical Time slice through the existing Dashboard, Track metrics, calendar/page state, subset-stacked chart, shared formatters, header reporting, and deterministic tests. Use Distance as the reference, with Spec 0065 taking precedence over 0064 for historical Year to Date browsing and tooltip text. Work Item 02 adds the three-choice menu/other renderers, 03 adds remembered type/loading, and 04–05 add the approved keyboard behavior; these remain required feature work rather than exclusions.

Apply ADS-1.0 and Desktop wide only: macOS-only, wide desktop, maximised-on-launch target, compact keyboard/pointer controls, semantic light/dark styling, accessible labels, visible focus, and respected text scaling. Preserve ObjectBox/Riverpod/GoRouter ownership and the existing grid/card geometry and window policy. Inspect the existing calendar source/test changes before editing; do not overwrite unrelated work.

## Required context

All paths below are relative to the project root.

- `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`.
- `ai_specs/peak-lists/0066-time-dashboard-card/spec.md` and `ai_specs/peak-lists/0066-time-dashboard-card/interview-ledger.md`.
- `ai_specs/peak-lists/0003-dashboard-chart-series-theme/spec.md`, `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md`, `ai_specs/peak-lists/0065-dashboard-weekly-tooltip-and-year-navigation/spec.md` (0065 supersedes fixed-current-year Year to Date and lowercase endpoint names).
- `lib/models/gpx_track.dart`, `lib/services/summary_card_service.dart`, `lib/providers/summary_page_controller.dart`: stored duration meanings, existing Track-date decoding, calendar arithmetic, eligibility, and one authoritative page owner.
- `lib/widgets/dashboard/distance_card.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/dashboard/summary_page_browser.dart`: adapter, tooltip, renderer, input reconciliation, and lifecycle conventions.
- `lib/core/number_formatters.dart`, `lib/core/date_formatters.dart`, `lib/theme.dart`: shared formatting and `ChartSeriesTheme` ownership.
- `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/providers/dashboard_readiness_provider.dart`: card registry/order, header callbacks/frame accounting, lazy grid, and read-outcome reporting.
- `test/core/number_formatters_test.dart`, `test/services/summary_card_service_test.dart`, `test/providers/summary_page_controller_test.dart`, `test/providers/dashboard_layout_provider_test.dart`.
- `test/widget/distance_card_test.dart`, `test/widget/summary_calendar_navigation_test.dart`, `test/widget/summary_card_navigation_test.dart`, `test/widget/summary_chart_tooltip_test.dart`, `test/widget/dashboard_screen_test.dart`, `test/widget/dashboard_readiness_test.dart`.
- `test/robot/dashboard/dashboard_robot.dart`, `test/robot/dashboard/dashboard_journey_test.dart`: retain existing journeys, card-scoped selectors, controlled clocks, and fake tile/provider seams.

## Acceptance criteria

- [x] Dashboard shows exactly one card titled `Time` with stable card ID `time`, normal chrome/drag handle/reordering, and no new route or destination. Default order places it immediately after Distance; a saved order missing Time appends it without rearranging existing cards.
- [x] `Total Time` reads `GpxTrack.totalTimeMillis` and `Moving Time` reads `GpxTrack.movingTime`, both milliseconds. Total includes resting within recording segments and excludes inter-segment `Paused Time`; moving excludes resting. Four hours moving + one hour resting + thirty minutes recording gap contributes five hours total/four moving, without GPX recalculation, end-minus-start substitution, data repair, or schema/model changes.
- [x] Filter the pair once: both values must exist and satisfy `0 ≤ Moving Time ≤ Total Time`. Retain zero/zero and zero-moving Tracks. Both series, endpoints, totals, averages, and activity detection use the same eligible Track set; exclude missing/negative/inconsistent pairs without modifying stored records.
- [x] Reuse established Track-date decoding, excluding unknown dates and dates after Dashboard's Mac-local reference calendar day. Assign each full duration, including multi-day durations, to the Track-date bucket; do not split across dates or apply timezone/DST conversion to durations. Both series share selected-page and bucket boundaries.
- [x] Sum full precision before averages/formatting. With no eligible Tracks after date/duration/cutoff validation, show exactly `No time data yet` and clear headers. Empty buckets/pages inside valid history render zero values and remain navigable; zero/zero eligible history renders a chart rather than the wholly-empty message. Track loading uses the existing loading presentation without flashing empty text or stale headers. Preserve existing Track-load recovery, routes/back behavior, offline/slow-network behavior, and no runtime network calls.
- [x] Presets appear exactly in order `Week`, `Month`, `Last 3 Months`, `Last 6 Months`, `Last 12 Months`, `Year to Date`, `All Time`; initial selection is `Last 12 Months` on its current page. Selecting a different preset opens its current page. No preset/page/totals/inspection persistence is added.
- [x] Reuse calendar pages: Monday–Sunday daily Week; full-calendar daily Month; current-month-anchored complete 3-/6-month pages with clipped Monday-based weekly buckets; 12-month pages with monthly buckets; January–December Year to Date with twelve monthly positions and one-year historical steps; All Time with yearly buckets and up to twelve current-year-anchored years per page. Use calendar steps rather than elapsed-day approximations or rolling/half-window navigation.
- [x] Preserve `First → Previous → Next → Last`. First/Last target earliest/latest eligible Time Track pages as one-off jumps; Previous/Next include empty intervening pages, bounded at earliest eligible page/current period. Each action's enabled state follows its own destination, and horizontal/trackpad browsing agrees. Enabled endpoint names/tooltips are exactly `First` and `Last`; arrow names remain `Previous Week`/`Next Week`, `Previous Month`/`Next Month`, `Previous 3 Months`/`Next 3 Months`, `Previous 6 Months`/`Next 6 Months`, `Previous 12 Months`/`Next 12 Months`, `Previous Year`/`Next Year`, `Previous 12 Years`/`Next 12 Years` as applicable. Disabled buttons have no visual tooltip, retain meaningful disabled semantics/styling, and use the basic cursor.
- [x] Keep the toolbar one row and the overall date-range label's weekday-bearing format. Preserve compact 3-/6-month weekly tooltip titles: `10-16 Aug 2026`, `28 Sep – 4 Oct 2026`, `28 Dec 2026 – 3 Jan 2027`, and single-day `1 Aug 2026`, using actually included edge-week dates and `en_US`; Month retains `Thu 15 Oct` shape. Work Item 02 replaces the initial mode control with the required menu without changing toolbar geometry.
- [x] Header reports Total Time only with `Total:`; averages use Week `Daily Avg:`, Month `Weekly Avg:`, Last 3/6/12 Months and Year to Date `Monthly Avg:`, All Time `Annual Avg:`. Preserve Distance denominators including zero periods, all twelve months for historical years, and elapsed months including current month for current Year to Date. Chart/header/range agree on one selected page; add no Moving Time summary.
- [ ] Time's summary header wraps full labels/values at active text scale, including long day-scale values in light/dark themes. Do not use `FittedBox.scaleDown`, reduce text scale, or truncate essential values. Other headers retain their presentation; the toolbar stays one row. Header growth leaves content/actions reachable within actual supported constraints, subject to the blocking-decision gate below.
- [x] Preserve independent card browsing, allowed historical pages on refresh, clamping when history shortens, zero/empty transitions, and coherent values/control updates. First/Last do not follow later imports. Reconcile activation/refresh/interaction through the existing clock without a midnight timer; preserve 0064/0065 current-page following and historical-page remapping, clear obsolete inspection, and reject superseded page/tooltip callbacks after newer input or disposal.
- [x] Subset stacking draws green from zero to Moving Time, then primary from Moving Time to Total Time: five total/four moving reaches five, never nine. Omit zero-height portions naturally, including no primary remainder for equal totals. Use `ChartSeriesTheme.primarySeriesColor` (currently `colorScheme.primaryContainer`) and `secondarySeriesColor` (`#2E7D32`), preserving selected/lightened tooltip derivations in light/dark and changed-seed themes. Do not globally reverse the existing stacked renderer.
- [x] Pointer hover/pinned inspection reports the reference date and exactly `Total Time: <duration>` then `Moving Time: <duration>`, with their corresponding tooltip colours, not a renamed resting series. Work Item 05 supplies equivalent keyboard inspection/accessibility.
- [x] Shared display helpers format totals/averages/tooltips as all three unpadded components `xd yh zm`, e.g. `0d 0h 0m`, `0d 5h 0m`, `2d 5h 7m`, with a day exactly 24 hours, normal hour/minute carry, and only final-value whole-minute truncation. Do not truncate per Track or before calculating averages. Axis labels are compact decimal days with no space before `d`, including `0d`, `2.5d`, `5d`, no unnecessary trailing zeroes, distinguishable sub-day ticks, and renderable all-zero scaling. Keep units explicit at the millisecond/chart-day boundary; preserve Track-details formatting.
- [x] Wire Time header changes into existing header revision/frame-readiness accounting and preserve dependency failure reporting; preference-read completion joins this path in Work Item 03. Other cards retain controls, defaults, eligibility, palettes, formatting, header presentation, and chart preferences.
- [ ] Extend behavior-focused formatter/service/provider/widget tests for duration/date eligibility, precision/averages, full-calendar boundaries and equal series buckets, all presets/endpoints/empty gaps, future cutoff, refresh/clock rollover, stacking, loading/empty states, placement/order, header wrapping, and readiness. Reuse shared calendar fixtures rather than duplicating calendar algorithms. Use Time equivalents of `distance-card`/`dashboard-card-distance`, `time-...` metric keys, card-scoped shared selectors, synthetic Tracks, provider/repository overrides, controlled clocks, fake tiles if Latest Walk is rendered, and explicit resource disposal; preserve existing robot selectors/journeys. No new strict TDD or robot-journey mandate.
- [ ] Run `flutter analyze`, affected formatter/provider/Time/summary/Dashboard tests under `TZ=Australia/Hobart`, and the complete `TZ=Australia/Hobart flutter test` suite. Check affected macOS wide behavior in light/dark themes, pointer/keyboard controls available at this slice, visible focus, and enlarged text without reducing scale. Record executed results and gate any genuinely dimension-dependent check; regression fixture sizes do not approve window minima.

## Covers

- User Stories: 1, 4; 2 (initial subset-stacked presentation).
- Requirements: 1–13; 16–17; 19 (initial pointer inspection); 20–22.
- Technical Decisions: 1–3, 5–10 (applicable adapter/header/readiness and lifecycle portions).
- Testing Strategy: 1–4 (initial chart), 6–9.
- Interview Ledger: L1–L4, L6–L8, L10. L18 remains deferred: no shortcut hints/footer, accessible-only shortcut explanations, editable shortcuts, or Help screen.

## Blocked by

None - ready to start independent data/calendar/formatting work; dependent layout is subject to the decisions below.

## Blocking decisions

- Conditional gate, not a blanket blocker: the profile's **minimum usable macOS width**, **minimum usable macOS height**, **supported macOS resize range**, **native macOS full-screen choice**, and **feature-specific wide-layout thresholds** remain Pending. Resolve and record only the value(s) actually needed in the profile/Spec before dependent layout implementation or dimension-dependent acceptance, including reachability when the wrapping header grows. Do not invent numeric minima/breakpoints or treat native `1024 × 0`/existing test viewports as approved targets. Unrelated logic and settled layout behavior may proceed.

## Implementation progress — 2026-10-18

**Status: partially implemented; wrapping-header height/reachability remains gated.** The user explicitly selected **`Leave layout gated`** when the conditional decision was raised during implementation. No pending profile value was resolved and no new dimension, breakpoint, window policy, or standard exception was adopted. See Interview Ledger L19.

### Implemented and verified independent work

- Added `TimeSummaryMetrics` and a thin `TimeCard` adapter. The shared card filters duration-pair eligibility once per incoming Track list; both metrics and the existing calendar/page controller consume that same set. Aggregation and summaries retain milliseconds; only the chart renderer converts them to 24-hour days.
- Added opt-in `subsetStacked` rendering without changing the previous stacked policy. Moving Time occupies zero to moving; the primary remainder ends at total. Theme-derived normal/selected/tooltip colours and zero-height omissions are covered.
- Registered Time immediately after Distance by default; existing saved orders append it. Time uses the standard card chrome, ordering and header revision/frame accounting, and reports only Total Time summaries. A Time-only wrapping header path is present, but height/reachability acceptance is **not complete**.
- Reused the existing 0065 calendar changes already present in the worktree. Extended shared calendar/navigation fixtures to Time in both initial binary modes, including all presets, endpoints, empty gaps, future cutoff, refresh/clamping, clock rollover, overlapping input and disposal. Existing robot selectors are retained; My Lists journeys explicitly reveal its card now that the additional card can place it off-screen.
- Added formatter, Time service/widget, independent page-provider, placement/order, and readiness assertions. Unit coverage includes pair validation, precision, the five-total/four-moving example, unchanged records, zero/zero activity, and multi-day values assigned to a single Track day across Hobart DST.

### Unresolved layout finding and verification scope

- At the **existing regression fixture** `1600 × 1000`, `1.5×` text scale, and a synthetic `123456d 23h 59m` total/average, Time's wrapping header leaves the `SummaryChart` only `32` logical pixels high. Its fixed chart insets leave fl_chart a zero-height plot, producing `Rect argument contained a NaN value` during paint. These observations do **not** approve a supported window size or a maximum duration.
- Paused dependent height-policy/layout work as directed. The light/dark long-summary Dashboard tests are retained with explicit `skip: true` and a gate comment in `test/widget/dashboard_screen_test.dart`. Resolve the actual supported window/Time layout contract before implementing height management and enabling those tests. The header-wrapping/reachability criterion and the coverage/verification criteria that include it remain unchecked above.
- macOS-themed deterministic widget checks cover the independent pointer/keyboard controls available in this slice and enlarged text. No separate live native-app visual check was performed; supported-size reachability is not claimed. Work Items 02–05 remain required for the specified menus, preferences and keyboard feature work.

### Executed verification

- `flutter analyze` — **passed, no issues**.
- Focused run: `env TZ=Australia/Hobart flutter test test/core/number_formatters_test.dart test/core/date_formatters_test.dart test/services/time_summary_metrics_test.dart test/services/summary_card_service_test.dart test/providers/summary_page_controller_test.dart test/providers/dashboard_layout_provider_test.dart test/widget/time_card_test.dart test/widget/distance_card_test.dart test/widget/summary_calendar_navigation_test.dart test/widget/summary_card_navigation_test.dart test/widget/summary_chart_tooltip_test.dart test/widget/dashboard_screen_test.dart test/widget/dashboard_readiness_test.dart test/robot/dashboard/dashboard_journey_test.dart --reporter expanded` — **277 passed, 2 gated skips**.
- Full suite: `caffeinate -i env TZ=Australia/Hobart flutter test --reporter expanded` — **2,536 passed, 7 skipped**, approximately **15 minutes 58 seconds**. Two skips are the explicit Time layout gate; the other five pre-existed this work.
- Earlier verification caught and corrected the test theme name, focus traversal assertions, an invalid skip argument, and off-screen My Lists robot assumptions. The long-header paint failure is recorded above and remains unresolved, rather than reported as a passing check.
- Work Item 01 is **not complete** and has not been committed as completed work. Pre-existing calendar/0065, glossary and Podfile changes remain in the worktree with the new Time work.

### Subsequent Work Item 02 integration — 2026-10-18

- Under L20 the user authorised independent chart/menu work against this implemented foundation, preserving the L19 layout gate. Work Item 02's verification subsequently passed analysis, its focused set (244 tests, two gated skips) and the full Hobart suite (2,564 tests, seven skips).
- The user then explicitly selected **`Commit prerequisites and 02`**, authorising a coherent commit of the relevant uncommitted 0065/Time foundations alongside Work Item 02. This publishes the implemented foundation as incomplete work; the unchecked layout/coverage criteria above remain gated. The unrelated Podfile change is excluded.
