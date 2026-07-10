---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: What should change in the dashboard chart theming refactor?

Answer: Move the contents of `lib/widgets/dashboard/dashboard_series_colors.dart` into `lib/theme.dart`, create a `ChartSeriesTheme` theme in `lib/theme.dart`, and make `lib/widgets/dashboard/summary_chart.dart` use colors from the new chart-series theme instead of `theme.colorScheme.primary` and `theme.colorScheme.tertiary` for the chart series colors.

Decision: Dashboard chart series colors are centralized in `lib/theme.dart` behind a new `ChartSeriesTheme`, and `summary_chart.dart` reads its series colors from that theme instead of from `ColorScheme.primary` and `ColorScheme.tertiary`.

Constraints:
- Preserve the current `dashboardSecondarySeriesColor` value and the current `lighterSeriesColor(Color color, [double delta = 0.15])` behavior when moving them.
- Update downstream imports so consumers read from `package:peak_bagger/theme.dart` instead of `dashboard_series_colors.dart`.
