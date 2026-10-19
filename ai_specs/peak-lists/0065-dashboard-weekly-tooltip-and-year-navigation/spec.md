---
type: Spec
title: Dashboard Weekly Tooltip and Year Navigation
---

## Problem

The weekly chart tooltip titles in Dashboard's `Last 3 Months` and `Last 6 Months` presets repeat weekdays and dates, making them unnecessarily long. The user wants concise titles without changing the overall date-range label underneath the dropdown. [L1] [L3]

`Year to Date` is currently fixed to the current year with all four navigation buttons disabled, preventing inspection of complete historical calendar years. Timeline buttons also expose tooltips while disabled, and endpoint tooltips use lowercase `first` and `last`. [L1] [L2]

## Proposed Outcome

Across Peaks Bagged, Elevation, and Distance, show compact weekly chart tooltip ranges and allow `Year to Date` to browse historical January–December years while retaining current-year year-to-date calculations. Dashboard navigation buttons expose tooltips only when enabled, with endpoint text exactly `First` and `Last`. [L1] [L2] [L3]

## User Stories

1. As a Dashboard user, I can quickly read the included dates of a weekly bucket without repeated weekdays or month names.
2. As a Dashboard user, I can browse complete historical years and compare their monthly totals and averages with the current year to date.
3. As a Dashboard user, I see meaningful navigation tooltips for available actions, without tooltip popups on unavailable actions.

## Requirements

### Compact weekly chart tooltip titles

1. Apply the shorter weekly date-range titles to `Last 3 Months` and `Last 6 Months` in the **Peaks Bagged**, **Elevation**, and **Distance** timeline cards, in both line and column modes. Use the same titles for hover and pinned chart tooltips. Preserve tooltip metric rows, units, values, colours, and inspection behavior. [L1] [L3]
2. Format a range within one calendar month/year as **`10-16 Aug 2026`**: unpadded day numbers, an unspaced ASCII hyphen, one abbreviated month, and one year. Format a range spanning months within one year as **`28 Sep – 4 Oct 2026`**: both abbreviated months, a spaced en dash, and the year once at the end. Omit weekdays in both cases. [L1] [L3]
3. Complete the compact formatting rules with these supporting defaults from the interview recommendation: a cross-year range is `28 Dec 2026 – 3 Jan 2027`, retaining both years; a single included day is `1 Aug 2026`, without a repeated endpoint. Keep the existing English abbreviated month vocabulary/`en_US` display convention. [L3]
4. Use the bucket's **actually included** first and last calendar days, including clipped Monday-based edge weeks. A bucket containing only 1–2 August displays `1-2 Aug 2026`, rather than including the preceding July dates. Derive the final included date from the end-exclusive boundary using calendar arithmetic. Do not alter bucket boundaries, page lengths, or aggregation. [L1] [L3]
5. Preserve the overall date-range label directly underneath the period dropdown/navigation row in its existing weekday-bearing format, including for the two affected presets. Preserve other presets' chart tooltip formats and unrelated date displays. In particular, Month retains titles such as `Thu 15 Oct`. [L3]

### Year to Date historical-year browsing

6. Keep the preset label exactly **`Year to Date`**, its current position between `Last 12 Months` and `All Time`, and the default preset `Last 12 Months`. Selecting a different preset and entering Year to Date opens the current year. Apply the yearly behavior to all three timeline cards and both chart modes. This concerns the timeline preset, distinct from the separate `My Year to Date` statistics card. [L2]
7. Each Year to Date page covers **1 January through 31 December of its selected year**, with twelve monthly buckets. Previous/Next move exactly one calendar year, without rolling twelve-month windows or skipping empty years. The current-year page keeps its full January–December bucket positions, but excludes records after the Dashboard's Mac-local reference calendar day, retaining zero-valued future positions. [L2]
8. Historical-year totals include qualifying activity throughout the selected year. Their `Monthly Avg:` divides the total by all **12 months**, including zero-valued months. The current-year total remains year to date and its average divides by the elapsed calendar months, including the current month. For example, at 15 October 2026 a historical 2025 total of 120 has an average of 10; a current 2026 total of 120 has an average of 12. Retain existing metric definitions, display units, rounding, primary/secondary series meanings, and palettes. [L2]
9. Retain the ordered four-button toolbar **First → Previous → Next → Last**, existing first/last and chevron icons, and one-row arrangement. For Year to Date, First jumps to the year containing the earliest qualifying activity; Last jumps to the year containing the latest qualifying activity. Use each card's existing primary-metric eligibility rules and reference-day cutoff; a missing secondary value must not remove a primary-qualifying year. Endpoint jumps remain one-off actions rather than automatically following subsequent imports. [L1] [L2]
10. Bound yearly navigation backwards at the earliest qualifying year and forwards at the current year. Visit intervening empty years with twelve zero-valued buckets and zero summaries. Disable each button according to its own destination: First/Last when already at their endpoint, Previous at the earliest year, Next at the current year. If the latest recorded year is 2024 and the reference year is 2026, Last may be disabled on 2024 while Next remains enabled to reach empty 2025 and 2026. If the whole permitted range is one year, disable all four. [L2]
11. Horizontal scrolling/trackpad page browsing must use the same complete yearly steps and bounds as buttons. Switching line/column mode preserves the selected year. Each card's selected page remains independent. Chart, overall date-range label, totals, averages, and controls must agree on the selected year after navigation settles. The label keeps its existing format while reflecting the selected January–December range. [L2] [L3]
12. Apply established refresh and reference-date reconciliation to Year to Date: preserve a still-permitted historical year on refresh, clamp a year before newly shortened history to the earliest permitted year, and show the existing no-qualifying-data state if no eligible records remain. On year rollover, a card displaying the current year follows the new current year; a historical selection stays on its calendar year when still permitted. Reconcile on Dashboard activation, refresh, or timeline interaction through the existing reference clock, without a new midnight timer. Superseding input, preset changes, refresh, and disposal must not restore stale page or tooltip state. [L2]

### Navigation tooltips and accessibility

13. Suppress tooltip popups for **disabled Dashboard navigation buttons**, across all timeline presets; keep the existing equivalent suppression on Latest Walk and the separate My Year to Date card. Preserve their enabled tooltip text except for the explicit timeline changes below. Disabled buttons retain visible disabled styling, the default/basic cursor, disabled semantics, and meaningful accessible action names independently of visual tooltips. [L1]
14. Timeline endpoint tooltip text and accessible action names are exactly **`First`** and **`Last`**. Year to Date uses **`Previous Year`** and **`Next Year`** for its enabled arrow tooltips and action names, replacing the fixed-period descriptions. Other presets retain their exact period-specific arrow names. An enabled control has a click cursor, visible keyboard focus and keyboard activation. A control that becomes disabled must not leave a stale tooltip visible. [L1] [L2]

### Existing states and feature boundaries

15. Preserve Dashboard entry/exit, routes, loading behavior, existing dependency-failure feedback and recovery, and wholly empty-dataset copy (`No walks yet`, `No elevation data yet`, `No distance data yet`, or `No peaks bagged yet` as applicable). An empty historical year within otherwise qualifying history is a navigable zero page, not a wholly empty dataset. Loading must not briefly render no-data copy. [L2]
16. This is derived display/browsing state: add no stored navigation preference, domain-data migration, background job, runtime network call, credential, or external-service dependency. Keep existing offline/slow-network behavior. Preserve Track-date calendar decoding and the defensive future-date cutoff. [L1] [L2] [L3]

## Technical Decisions

1. Adopt **ADS-1.0** from project-root-relative `ai_specs/coding-rules.md` and the **Desktop wide only** profile in `ai_specs/app-profile.md`: macOS-only, wide layout, maximised on launch, compact keyboard/pointer controls, semantic light/dark themes, accessible action labels, visible focus and disabled feedback, and respected text scaling. ObjectBox, Riverpod, and GoRouter remain mandatory foundations. No standard exception is proposed.
2. Reuse `lib/core/date_formatters.dart` for a distinct compact weekly-range display helper and the shared `defaultTooltipTitleText` function in `lib/widgets/dashboard/summary_chart.dart`. Do not globally change `formatSummaryDateRange`, which also owns the unaffected header label. Format calendar components without timestamp conversion. The single-day and cross-year forms in requirement 3 are explicit supporting defaults, not separately answered interview questions. [L1] [L3]
3. Extend the established `SummaryCardService`, `SummaryPageNavigation`, and Riverpod `summaryPageControllerProvider` flow. Remove the Year to Date fixed-page restrictions; calculate selected-year January/next-January boundaries with calendar constructors rather than elapsed-day durations. Reuse existing monthly aggregation and primary/secondary adapter boundaries. Do not introduce a second mutable page owner in widgets or infer page identity solely from pixel offsets. [L2]
4. Reuse the shared SummaryCard/toolbar/page-browser path for all three adapters. Preserve keys and existing callback seams. Distinguish visual tooltip suppression from accessible labels, avoiding duplicated spoken names. Keep scroll/hover/pinned-selection controllers and superseded callbacks under their existing lifecycle owners; clear obsolete inspection state when the selected year or data changes. [L1] [L2] [L3]
5. Existing deterministic seams are `SummaryCardService` explicit date/page/metric inputs, `SummaryCard.now`, `DashboardScreen.now`, `dashboardReferenceClockProvider`, provider overrides, and `onVisibleSummaryChanged`. Fixtures can construct tracks and monthly buckets without opening production ObjectBox or using live services. [L2]
6. The profile's minimum usable macOS width/height, supported resize range, native full-screen choice, and feature-specific wide-layout thresholds remain **Pending**. This change reuses existing toolbar geometry and introduces no dimension-dependent acceptance criterion. Resolve a pending value before any subsequently necessary layout work that depends on it; observed native dimensions are not approved targets.

## Testing Strategy

1. **Approach:** behavior-focused regression tests with public formatter/service/provider/widget inputs are required. No additional strict TDD or new robot-journey mandate was agreed for this focused change. Extend existing tests rather than mirroring private implementation. Documentation publication itself needs document validation only. [L1] [L2] [L3]
2. **Formatting:** extend `test/core/date_formatters_test.dart` for exact punctuation, same-month, cross-month, cross-year, clipped edge-week, single-day, leap-day and component-preserving inputs. Assert the existing header formatter remains unchanged. Verify real hover and pinned titles in both modes via `test/widget/summary_chart_tooltip_test.dart` or the existing shared calendar-navigation fixtures, including unchanged metric rows and Month titles. [L1] [L3]
3. **Service/provider:** extend `test/services/summary_card_service_test.dart` and `test/providers/summary_page_controller_test.dart` for current-year entry, complete historical monthly pages, one-year moves, earliest/latest endpoints, empty gaps, per-destination enablement, primary-only eligibility, future exclusion, current versus historical averages, refresh preservation/clamping, and year rollover with a fixed/advanceable clock. Include history with activity only in an older year and a history confined to the current year. [L2]
4. **Widget behavior:** extend `test/widget/summary_calendar_navigation_test.dart` and affected navigation tests across all three adapters and both modes. Verify buttons and horizontal browsing produce matching selected-year ranges/buckets/summaries; mode switching preserves the year; the header retains its old formatting; historical empty pages remain navigable; and current/empty/loading states remain correct. Replace assertions that require Year to Date to remain fixed. [L2] [L3]
5. **Tooltip availability:** verify exact enabled `First`, `Last`, `Previous Year`, and `Next Year` strings, unchanged other-period arrow names, and no hover popup for disabled controls across presets. Retain accessible names/disabled state independently of tooltip text, enabled keyboard activation/focus, and click/basic cursors. Cover an enabled hovered button becoming disabled and check that stale tooltip content disappears. Existing Latest Walk/My Year to Date suppression should remain covered without adding different navigation semantics. [L1] [L2]
6. **Lifecycle and regressions:** retain rapid-input, superseded movement, refresh, mode-change, rollover, and disposal coverage through the shared page-browser tests. Preserve current robot selectors and deterministic clock overrides; existing Dashboard robot tests run in the full suite, but a new full-route journey is not required to prove these local behaviors. Use synthetic fixtures/fakes rather than credentials, real network calls, production data or a production database.
7. **Implementation verification:** run `flutter analyze`, the focused formatter/service/provider/widget tests above under `TZ=Australia/Hobart`, and the full suite with `TZ=Australia/Hobart flutter test`. Check the affected macOS Desktop wide controls in light/dark themes and supported text scaling, keeping the one-row toolbar and visible focus without shrinking text. Report actual checks and any failures; this Spec does not claim runtime verification has already occurred.

## Out of Scope

- Shortening the date-range label underneath the dropdown, other presets' chart titles, or unrelated date displays. [L3]
- Renaming the `Year to Date` preset or changing the separate `My Year to Date` card's statistics/year-navigation contract. [L2]
- Changing Monday-based grouping, 3-/6-/12-month anchored page sequences, All Time's twelve-year pages, counting models, units or rounding.
- Changes to import-time Track-date derivation/recalculation, ObjectBox schema, persisted settings, app navigation, external services, packages, window policy, iOS support, or compact navigation.

## Notes

### Source conflicts and precedence

- This Spec deliberately supersedes the fixed-current-year Year to Date restrictions in `ai_specs/peak-lists/0064-dashboard-calendar-navigation-and-local-walk-date/spec.md` requirements 5, 7, 13, 15, 16 and related tests/out-of-scope text. It also supersedes that Spec's lowercase first/last names in requirement 12. Preserve its remaining calendar-page, Track-date, cutoff, refresh, and lifecycle contracts. These are approved feature-behavior changes from L1/L2, not exceptions to ADS-1.0.
- Pre-implementation source mirrored the old restrictions: `SummaryPageNavigation._fixed` disabled yearly browsing, `calendarPage` used the reference year for Year to Date, the header always supplied lowercase endpoint tooltips, and the weekly tooltip branch shared the header's long formatter. Those behaviors and their regression expectations are replaced by this implementation.
- The app profile's existing long summary-range convention remains valid for the header. A separate weekly chart tooltip format avoids a global conflict with that convention. [L3]
- No glossary change is required: these are feature-specific display/navigation decisions, and the canonical Track/Track date distinctions are retained.

## Implementation and verification

### Completed acceptance criteria

- [x] Requirements 1–5: compact weekly tooltip ranges use a separate component-preserving formatter; hover and pinned titles share it across all three adapters and both chart modes. Metric rows/colours, clipped week boundaries, Month titles, and weekday-bearing header ranges are retained.
- [x] Requirements 6–8: Year to Date enters the current year and browses complete January–December years with twelve monthly buckets. Historical averages include all twelve months; current-year averages include elapsed months. Future records remain excluded.
- [x] Requirements 9–11: First/Previous/Next/Last use per-destination eligibility, yearly steps and bounds, zero-valued empty years, horizontal/trackpad browsing, independent card selection, and selection-preserving mode changes.
- [x] Requirement 12: existing Riverpod reconciliation preserves historical selections and one-off endpoint jumps, commits refresh clamps, follows a new current year on rollover, and rejects superseded input/inspection state.
- [x] Requirements 13–14: disabled timeline controls have no tooltip, including after an enabled hovered control disables. Exact endpoint/year action names, independent accessible labels without repeated tooltip semantics, cursors, styling, focus, and keyboard activation are covered.
- [x] Requirements 15–16: loading/no-data/empty-year distinctions, Track-date decoding, reference-day cutoff, and existing shared lifecycle behavior are retained. The implementation adds only derived display/navigation behavior.

### Verification results

- `flutter analyze`: passed, no issues.
- Focused formatter/service/provider/calendar-navigation/page-browser/chart-tooltip regression tests were exercised under `TZ=Australia/Hobart`; initial accessibility-test cleanup errors were corrected. The corrected tooltip/focus subset passed (9 tests), and all focused files subsequently passed within the full suite.
- An existing DistanceCard regression expectation for disabled-button tooltips was updated after the first full run exposed it.
- Full suite: **2,486 passed, 5 skipped**, using `caffeinate -i env TZ=Australia/Hobart flutter test`. Earlier attempts exceeded command time limits; the successful run completed in approximately 10 minutes 32 seconds.
- macOS-themed widget checks passed in light/dark themes at 1.5× text scaling, including the one-row toolbar, visible focus styling, keyboard activation/traversal, semantics, and click/basic cursors. These deterministic widget checks do not claim a separate live native-app visual inspection or approval of the profile's pending window dimensions.
- No ADS-1.0 exception or new dimension-dependent layout decision was required.
