<goal>
Add readable y-axis labels and four equal horizontal intervals to the shared summary chart so the dashboard charts are easier to read without relying only on the bottom bucket labels. This should improve readability across elevation, distance, and peaks-bagged cards in both column and line display modes.
</goal>

<background>
The app is a Flutter project using `fl_chart` for dashboard summary charts.
The summary chart is shared by multiple cards and currently hides left-axis titles and grid lines in both chart modes.

Files to examine:
- `./lib/widgets/dashboard/summary_chart.dart`
- `./lib/widgets/dashboard/summary_card.dart`
- `./lib/widgets/dashboard/distance_card.dart`
- `./lib/widgets/dashboard/elevation_card.dart`
- `./lib/widgets/dashboard/elevation_chart.dart`
- `./lib/widgets/dashboard/peaks_bagged_card.dart`
- `./test/widget/distance_card_test.dart`
- `./test/widget/elevation_card_test.dart`
- `./test/widget/peaks_bagged_card_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens a dashboard summary card.
2. The chart shows y-axis labels and evenly spaced horizontal grid intervals.
3. User reads chart values against the left axis while viewing either columns or line mode.

Alternative flows:
- Distance card: y-axis labels should use the distance formatter and remain consistent with the 2D/3D series values.
- Elevation card: y-axis labels should use the same whole-meter formatting style already used by the elevation summary.
- Peaks bagged card: y-axis labels should use whole-number count formatting with thousands separators and no unit suffix.

Error flows:
- Zero or near-zero values: axis labels and grid lines still render without divide-by-zero or NaN behavior.
- Tall values: labels remain legible and do not overlap the chart content.
</user_flows>

<requirements>
**Functional:**
1. Show y-axis labels on the left side of the summary chart in both `SummaryDisplayMode.columns` and `SummaryDisplayMode.line`.
2. Render four equal horizontal intervals across the plot area, which yields five labeled y-axis positions including the baseline and top tick.
3. Keep the existing bucket labels, scroll behavior, tooltip behavior, and chart data calculations unchanged.
4. Use the same interval value for grid lines and y-axis titles: `chartMaxY / 4`, with both endpoints included so labels and grid lines stay aligned.

**Error Handling:**
5. If chart values are all zero, preserve the current minimum chart height behavior so the interval remains finite and the chart still renders.
6. If the interval values are not visually clean, format labels through a metric-specific formatter instead of exposing raw floating-point noise.

**Edge Cases:**
7. Support both single-series and secondary-series charts without misaligned axes or grid lines.
8. Reserve enough horizontal space for the left-axis labels so the chart remains readable on narrow widths.
9. Do not render labels or grid lines outside the chart bounds.

**Validation:**
10. Add automated widget coverage for the chart configuration, not only screenshot-based checks.
11. Verify that both bar and line charts expose left titles and enabled grid rendering with four equal intervals.
12. Verify that existing card widget tests still pass for loading, empty state, period switching, mode switching, and tooltip display.
</requirements>

<boundaries>
Edge cases:
- Zero or near-zero values: avoid divide-by-zero and keep labels finite.
- Mixed primary and secondary values: the axis scale should still be driven by the larger series value.
- Narrow layouts: labels must not collide with the chart area or bottom labels.

Error scenarios:
- No usable tracks: existing loading and empty states remain unchanged.
- Formatting fallback: if a metric-specific formatter is unavailable, use a safe whole-number fallback rather than hiding the axis.

Limits:
- Do not add a new charting package.
- Do not change summary aggregation logic or tooltip content as part of this work.
</boundaries>

<implementation>
- Update `./lib/widgets/dashboard/summary_chart.dart` to enable left-axis titles and horizontal grid rendering for both bar and line charts.
- Thread a metric-specific y-axis label formatter through the summary card stack instead of hardcoding label text in the chart widget.
- Extend `./lib/widgets/dashboard/summary_card.dart` and the metric adapters in `./lib/widgets/dashboard/distance_card.dart`, `./lib/widgets/dashboard/elevation_card.dart`, and `./lib/widgets/dashboard/peaks_bagged_card.dart` to supply that formatter.
- If needed, add a small shared whole-number helper in `./lib/core/number_formatters.dart` so peaks-bagged axis labels can be formatted explicitly without reusing an elevation-specific name.
- Keep the change localized to the shared summary chart pipeline.
- Add or update widget tests under `./test/widget/` to assert the chart configs expose y-axis labels and four-interval grid behavior.
- Prefer inspecting `BarChartData` and `LineChartData` directly in tests over relying on rendered pixels.
- Avoid adding robot coverage for this change unless a broader dashboard journey is being updated in the same work, because this is a localized chart-rendering behavior.
- Update `./lib/widgets/dashboard/elevation_chart.dart` and `./test/widget/elevation_card_test.dart` alongside the other chart/card files so the elevation card is covered explicitly.
</implementation>

<validation>
- Use vertical-slice TDD for the chart behavior: add one failing widget assertion for the axis labels, make it pass, then add the grid assertion, then refactor.
- Keep tests at the public-widget level; do not test private helpers directly.
- Add or update a focused widget test file if needed, otherwise extend `./test/widget/distance_card_test.dart`, `./test/widget/elevation_card_test.dart`, and `./test/widget/peaks_bagged_card_test.dart`.
- Assert that the summary chart in both bar and line modes has non-hidden left titles, an enabled grid, and four equal horizontal intervals.
- Assert that the metric-specific axis labels render without breaking existing tooltip and selection behavior.
- Run the existing summary card widget tests to confirm the new axis rendering does not regress loading, empty state, period switching, mode switching, or tooltip display.
- No new robot journey test is required for this change; existing dashboard journey coverage should continue to pass unchanged.
</validation>

<done_when>
- The shared summary chart displays readable y-axis labels and four equal horizontal intervals in both display modes.
- All summary card variants keep their existing behavior and tests pass.
- The implementation is confined to the shared summary chart path and its adapter plumbing.
</done_when>
