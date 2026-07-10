---
type: Spec
title: Dashboard Chart Series Theme
---

## Problem

Dashboard chart series colors are split between `lib/widgets/dashboard/dashboard_series_colors.dart`, `lib/theme.dart`, and `lib/widgets/dashboard/summary_chart.dart`. That leaves the dashboard chart palette partly owned by a widget-local file instead of the app theme, and `summary_chart.dart` still reads its first series colors from `ThemeData.colorScheme.primary` and `ThemeData.colorScheme.tertiary` rather than a dedicated chart-series theme. [L1]

## Proposed Outcome

`lib/theme.dart` becomes the single source of truth for the dashboard chart series palette by absorbing the current contents of `lib/widgets/dashboard/dashboard_series_colors.dart` and exposing them through a `ChartSeriesTheme` theme extension. `lib/widgets/dashboard/summary_chart.dart` uses that chart-series theme for the first series' default and selected colors instead of `colorScheme.primary` and `colorScheme.tertiary`, while the existing chart appearance, selection behavior, and tooltip behavior remain unchanged. [L1]

## User Stories

1. As a developer maintaining the app theme, I want the dashboard chart palette centralized in `lib/theme.dart` so chart colors live with the rest of the theme definitions.
2. As a developer working on summary charts, I want `summary_chart.dart` to read chart-series colors from a dedicated theme extension so it no longer depends on `ColorScheme.primary` and `ColorScheme.tertiary` for series coloring.
3. As a user viewing dashboard charts, I want the charts to look the same after the refactor so the change does not alter the dashboard experience.

## Requirements

1. Move the current contents of `lib/widgets/dashboard/dashboard_series_colors.dart` into `lib/theme.dart`. The moved content must preserve the current `dashboardSecondarySeriesColor` value and the current `lighterSeriesColor(Color color, [double delta = 0.15])` implementation contract. [L1]
2. Introduce a `ChartSeriesTheme` theme extension in `lib/theme.dart`. It must be the theme-owned source of truth for the dashboard chart series colors that were previously provided by `dashboard_series_colors.dart`. [L1]
3. Register `ChartSeriesTheme` in the app theme configuration so it is available from both light and dark themes through `Theme.of(context).extension<ChartSeriesTheme>()`. [L1]
4. Update `lib/widgets/dashboard/summary_chart.dart` so the first series colors no longer come from `theme.colorScheme.primary` and `theme.colorScheme.tertiary`; those colors must come from `ChartSeriesTheme` instead. [L1]
5. Preserve the current chart palette values and derived-color behavior. The chart series should continue to resolve to the same visible colors as before this refactor, including the current secondary series green and the lighter tooltip color derivation. [L1]
6. Delete `lib/widgets/dashboard/dashboard_series_colors.dart` after the migrated consumers no longer need it so chart consumers depend on `lib/theme.dart` for the shared palette. [L1]
7. Keep the existing dashboard chart flow unchanged. This work must not add new routes, dialogs, loading states, empty states, error copy, retry behavior, persistence, or data-shape changes. [L1]

## Technical Decisions

1. Use the existing `ThemeExtension` pattern already established in `lib/theme.dart` for `ChartSeriesTheme` rather than introducing a separate provider or service. [L1]
2. Keep the moved chart-series helper in `lib/theme.dart` so downstream widgets can continue to derive lighter chart colors without reimplementing the HSL adjustment logic. [L1]
3. Treat `ChartSeriesTheme` as the access point for summary-chart series colors, while keeping the rest of the dashboard chart implementation in place. [L1]

## Testing Strategy

1. Use focused TDD for the theme refactor and chart-color wiring. Add or update one assertion at a time for the moved helper, the new `ChartSeriesTheme`, and the summary-chart color source change. [L1]
2. Extend `test/theme_test.dart` as the primary seam for verifying that `ChartSeriesTheme` is registered on both light and dark themes and that the moved helper still behaves the same. [L1]
3. Update the existing widget tests that currently import `dashboard_series_colors.dart`, especially `test/widget/distance_card_test.dart` and `test/widget/peaks_bagged_card_test.dart`, so they import `package:peak_bagger/theme.dart` and continue to assert the same tooltip colors. [L1]
4. Keep `test/widget/summary_chart_tooltip_test.dart` as the widget seam for summary-chart behavior. If the color-source change needs direct coverage, add the smallest assertion necessary there rather than creating a new broad harness. [L1]
5. No robot or multi-screen journey coverage is required. This refactor stays within theme wiring and existing dashboard widgets, so unit and widget coverage are the right split. [L1]

## Out of Scope

1. Changing dashboard chart layout, axes, bucket selection behavior, tooltip placement, or chart math.
2. Redesigning the dashboard chart palette beyond moving it into `lib/theme.dart`.
3. Adding new theme settings, runtime toggles, or persistence for chart-series colors.

## Notes

1. Relevant files are `lib/widgets/dashboard/dashboard_series_colors.dart`, `lib/theme.dart`, and `lib/widgets/dashboard/summary_chart.dart`. [L1]
2. Existing downstream consumers of the shared chart palette include `lib/widgets/dashboard/distance_card.dart` and `lib/widgets/dashboard/peaks_bagged_card.dart`, which currently rely on the moved helper and secondary-series color. [L1]
