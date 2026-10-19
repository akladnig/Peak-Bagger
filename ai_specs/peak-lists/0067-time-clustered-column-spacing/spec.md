---
type: Spec
title: Time Clustered Column Spacing
---

## Problem

Time's `Clustered column view` draws Total Time and Moving Time side by side, but its fixed internal gap competes with the width-dependent gap between buckets. The two columns can appear less closely related to each other than to neighbouring columns. The requested spacing swap was clarified as a visual grouping correction, rather than a literal numerical exchange of the existing gaps. [L1]

## Proposed Outcome

Make each bucket's two columns read as one cluster: a smaller gap within the Total Time/Moving Time pair and a larger gap between neighbouring clusters, consistently across calendar periods and chart resizing. Preserve the established Time card behaviour and series meanings. [L1]

## User Stories

1. As a Dashboard user, I can clearly distinguish each calendar bucket's Total Time/Moving Time pair from neighbouring pairs in Time's Clustered column view. [L1]
2. As a Dashboard user, I retain that visual grouping when changing calendar periods, browsing historical pages, or resizing the chart. [L1]

## Requirements

1. Apply the fix to the Dashboard's `Time` card when `Clustered column view` is selected through its existing `Chart type` menu. Preserve that exact label, menu order, icon, selection state, and remembered chart-type preference. [L1]
2. For each bucket, keep Total Time first/left and Moving Time second/right. Each column retains its independent full value on the common zero-based duration axis, with the existing primary/secondary chart colours and selected-colour derivations. [L1]
3. Make the horizontal edge-to-edge gap between the two columns within a cluster smaller than the edge-to-edge gap between neighbouring clusters. Both gaps must remain non-negative, columns must have positive width, and adjacent clusters must not overlap. Apply the geometry to the reserved column positions even when a duration is zero and its column has no visible height. [L1]
4. Maintain this grouping in every existing preset: `Week`, `Month`, `Last 3 Months`, `Last 6 Months`, `Last 12 Months`, `Year to Date`, and `All Time`, on current and historical pages. Recalculate spacing from the actual chart constraints and bucket count when either changes. Do not rely on a single fixed gap that reverses the relationship in denser views. [L1]
5. Exact gap values, ratios, and column widths are implementation defaults, not interview-selected dimensions. They may be adjusted together to achieve the grouping rule. A literal exchange of the old internal/external gap values is not required. [L1]
6. Preserve bucket centres and their alignment with date labels, label guides, pointer hit regions, hover/pinned tooltips, and keyboard inspection. Preserve selected-page state, calendar navigation, Track eligibility, aggregation, duration formatting, header summaries, and accessible inspected values. Spacing changes introduce no additional interaction or focus stop.
7. Preserve Time's `Stacked column view` and `Line view`, and Distance, Elevation, and Peaks Bagged presentation and controls. Keep existing loading and `No time data yet` states, Track/preference error and Retry behaviour, chart-type transitions, routes, and entry/exit behaviour. This is a rendering-only correction with no new persistence, network, asynchronous operation, or failure state.
8. Retain existing card/grid geometry and toolbar layout. Use actual available plot constraints without defining a new supported window range or breakpoint. Carry forward Spec 0066's L19 wrapping-header height/reachability gate; this fix neither resolves that gate nor requires the gated header redesign.

## Technical Decisions

1. Adopt **ADS-1.0** from project-root-relative `ai_specs/coding-rules.md` and the **Desktop wide only** profile in `ai_specs/app-profile.md`: macOS-only, wide desktop, maximised launch target, keyboard/pointer interaction, semantic light/dark styling, and respected text scaling. ObjectBox, Riverpod, and GoRouter remain mandatory foundations. No foundation change or standard exception is proposed.
2. Existing implementation evidence: `TimeCard` maps `TimeChartType.clusteredColumn` to `SummaryBarSeriesStyle.grouped` in `lib/widgets/dashboard/time_card.dart`. `_SummaryBarChart` in `lib/widgets/dashboard/summary_chart.dart` uses `BarChartAlignment.spaceAround`, `barsSpace: 6`, and individual rod widths of `DashboardUI.rodWidthFor(bucketExtent) / 2`; `rodWidthFor` currently returns 80% of the bucket extent. `SummaryCard` supplies bucket extent from plot width divided by bucket count. These are observed values to correct, not approved spacing targets. [L1]
3. Keep the rendering correction scoped to Time's opted-in clustered presentation. Shared rendering may be adjusted where that remains opt-in, but stacked/line and other-card geometry must retain their established behaviour. Place any reusable chart geometry metric with the existing chart/domain metric owner rather than scattering new arbitrary gaps through widgets. Chart column geometry is a justified domain metric under ADS-1.0 section 4, distinct from shared surface-padding tokens. [L1]
4. Preserve the existing authoritative state boundaries: Riverpod owns chart-type preference and calendar state; the renderer derives geometry from constraints and existing buckets. No additional mutable spacing state, preference key, database field, dependency, or lifecycle resource is needed.
5. Existing Test Seams are sufficient: deterministic Track fixtures and `TimeCard.now`, mocked shared preferences/provider overrides, chart-type selection keys, `SummaryChart.bucketExtent`, exposed `BarChart` data, and the existing bucket hit-region keys. Reuse them to verify geometry against available plot space and retained bucket alignment.
6. Supporting verification defaults below follow project conventions; the interview selected the visible grouping rule, not a strict TDD process, robot journey, exact spacing ratio, or new window contract. [L1]

## Testing Strategy

1. Add focused widget/rendering regression coverage for the resolved grouping behaviour using deterministic Time data. Assert the actual inter-cluster gap exceeds the internal gap and that rods do not overlap; checking only that a `barsSpace` constant changed is insufficient. Account for the chart alignment, plot width, rod widths, and bucket count when measuring or deriving the rendered gaps. [L1]
2. Exercise all seven presets, including dense daily buckets, sparse yearly buckets, a historical page, valid zero-duration data, and an all-zero renderable chart. Resize the same mounted chart between representative wide-desktop fixture constraints and check the grouping relationship updates correctly without changing the selected period/page/type. Fixture dimensions are regression inputs, not approved usable window minima. [L1]
3. Retain checks for primary-left/secondary-right ordering, full duration heights, light/dark theme colours, and bucket/date-label alignment. Exercise pointer inspection and existing keyboard inspection after the geometry change to ensure the date and both durations still refer to the intended bucket. Reuse existing assertions where they already cover these behaviours.
4. Run existing Time and shared-chart/card tests for stacked/line presentation, loading/empty states, menu selection, calendar/page preservation, tooltip behaviour, and other-card regressions. No new preference-failure tests or robot journey are required for this rendering-only change; retain existing coverage and stable selectors. No strict TDD mandate is selected.
5. Use synthetic Tracks, controlled dates, and mocked preferences/provider dependencies. Automated checks require no production database, live tiles, network calls, credentials, or API keys. Dispose test resources through established harness conventions.
6. Implementation verification: run `flutter analyze`; focused `env TZ=Australia/Hobart flutter test test/widget/time_card_test.dart test/widget/summary_chart_tooltip_test.dart test/widget/summary_calendar_navigation_test.dart test/widget/summary_card_navigation_test.dart test/widget/distance_card_test.dart test/widget/elevation_card_test.dart test/widget/peaks_bagged_card_test.dart`; affected existing keyboard-inspection tests; and the complete `env TZ=Australia/Hobart flutter test` suite. Check the affected macOS wide chart in light/dark modes across sparse/dense periods and resizing, with text scaling preserved. Report actual executed results and any inherited gated checks without declaring the 0066 layout gate resolved.
7. Spec publication requires documentation structure, relative-link, decision-coverage, and scope checks only. Runtime tests and visual verification belong to implementation; executed results are recorded separately in the delivery section below.

## Out of Scope

- A literal numerical swap of the current gaps or an interview-mandated fixed gap/ratio. [L1]
- New chart controls, preferences, chart types, routes, data transformations, duration semantics, or changes to other cards.
- Time header-height remediation, Dashboard grid redesign, new window dimensions/resize policy, native full-screen policy, or feature breakpoints.
- Compact/narrow navigation, iOS/touch layouts, package upgrades, schema changes, or new services.

## Open Questions

- The profile's minimum usable macOS width/height, supported resize range, native full-screen choice, and feature-specific wide-layout thresholds remain Pending. Spec 0066's L19 height/reachability gate remains in force. Resolve any genuinely dependent value before expanding this fix into dimension-dependent layout work; do not infer approved minima from test fixtures.

## Implementation delivery — 2026-10-19

**Spacing fix implemented and automated verification complete.** The inherited 0066 header-height gate remains separate.

### Acceptance coverage

- [x] Requirements 1–2: retain the exact chart controls/preference, series order, independent heights, and theme colours.
- [x] Requirements 3–5: derive internal spacing from bucket extent; keep a smaller non-negative internal gap, positive rod widths, and separated clusters across all presets, current/historical pages, resizing, and zero-duration data. [L1]
- [x] Requirement 6: retain bucket centres/hit-region alignment, calendar state, pointer inspection, keyboard inspection, and accessible metric values.
- [x] Requirement 7: existing Time stacked/line, loading/empty, menu, preference and other-card regression coverage passes.
- [x] Requirement 8: retain existing card/grid/toolbar and window contracts; no header-height gate or Pending profile value is resolved by this fix.
- [x] Testing Strategy 1–6: focused regressions, static analysis, format checks and the complete suite pass; macOS-targeted widget evidence and verification limits are recorded below.

### Delivered geometry and regression evidence

- `DashboardUI.groupedBarsSpaceFor` defines the selected implementation default: the internal gap is **4% of bucket extent**. Existing rods remain **40% each**, leaving approximately **16% between clusters** under `spaceAround` (plus existing fractional plot-width rounding). Inter-cluster separation is therefore approximately four times the internal gap. Only the grouped renderer uses this metric; no mutable state or lifecycle resource was added.
- Four new tests cover light/dark themes and mixed/all-zero data. Each visits all seven presets on current and historical pages and resizes the same mounted card through `700`, `1000`, and `560` logical-pixel chart-card widths within a `1200 × 650` macOS-targeted widget surface at **1.5× text scale**. These are regression fixtures, not approved minimum usable dimensions.
- Assertions derive the inter-cluster gap from the rendered plot width and actual group widths/alignment, verify the gap relationship and positive widths, check each cluster stays within its bucket hit region with matching centre, and verify resize preserves period/page/type. Existing tests retain values, colours, tooltips, pointer/keyboard equivalence, navigation and other-card coverage.
- Before the production change, all four new tests failed on the fixed-gap dense Month geometry: derived inter-cluster spacing was approximately **−2.10 logical pixels**, reproducing overlap. They pass with proportional spacing.

### Executed verification

- `flutter analyze` — **passed, no issues**.
- `dart format --output=none --set-exit-if-changed lib/core/constants.dart lib/widgets/dashboard/summary_chart.dart test/widget/time_card_test.dart` — **passed, no changes required**.
- `env TZ=Australia/Hobart flutter test test/widget/time_card_test.dart test/widget/summary_chart_tooltip_test.dart test/widget/summary_calendar_navigation_test.dart test/widget/summary_card_navigation_test.dart test/widget/distance_card_test.dart test/widget/elevation_card_test.dart test/widget/peaks_bagged_card_test.dart test/widget/dashboard_keyboard_test.dart --reporter expanded` — **238 passed**.
- `caffeinate -i env TZ=Australia/Hobart flutter test --reporter expanded` — **2,679 passed, 7 existing skips**, approximately **5 minutes 50 seconds**. No skip was introduced or removed; the inherited gated header checks remain skipped.
- `git diff --check` — **passed**.
- macOS/light/dark/enlarged-text geometry is verified through rendered widget fixtures, with pointer and keyboard inspection covered by existing focused tests. No separate live native-app visual inspection was performed.

## Notes

- **Required context, project-root-relative:** `ai_specs/coding-rules.md`, `ai_specs/app-profile.md`, `GLOSSARY.md`, this Spec and its sibling [Interview Ledger](interview-ledger.md).
- **Existing feature contract:** [0066 Time Dashboard Card](../0066-time-dashboard-card/spec.md), its [Interview Ledger](../0066-time-dashboard-card/interview-ledger.md), and [Work Item 02](../0066-time-dashboard-card/work-items/02-time-chart-views-and-menu.md). This is a focused follow-up to clustered rendering, not completion of the still-gated original feature.
- **Source and verification evidence:** `lib/widgets/dashboard/time_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/core/constants.dart`, `test/widget/time_card_test.dart`, and `test/harness/summary_chart_controls.dart`.
- **Conflict review:** 0066 specifies side-by-side series and their order but no exact gap contract. The new grouping requirement adds that contract without changing series meanings. Existing fixed-gap geometry is implementation evidence to replace, not an approved exception. The previously documented broader Dashboard accessibility alignment gap is not addressed by this spacing fix.
