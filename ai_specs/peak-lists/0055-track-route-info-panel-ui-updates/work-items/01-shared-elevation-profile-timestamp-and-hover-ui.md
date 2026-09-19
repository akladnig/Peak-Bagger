---
type: Work Item
title: Shared Elevation-Profile Timestamp and Hover UI
parent: ../spec.md
---

## What to build

Complete the shared persisted-profile timestamp contract and use it consistently in `ElevationProfileChart` for Track, saved Route, and Route Draft graph hosts. Deliver the rounded chart-range-minimum base label, timestamp-aware tooltip behavior, map-consistent hover styling, Time-selector availability, and shared-chart pointing cursor without changing touch interaction, callbacks, semantics, or loading/empty/error states.

## Required context

- `lib/services/elevation_profile_series_builder.dart` owns `ElevationProfileSeries.supportsTimeAxis`; it must represent the complete persisted-entry contract, not merely the decoded sample list.
- `lib/widgets/elevation_profile_chart.dart` owns the existing chart range calculation, `elevation-profile-chart-touch-area` key, hover callbacks, axis selectors, tooltip, and `MapChartHoverDotTheme` integration.
- `lib/widgets/map_route_bottom_sheet.dart` hosts the same chart in `RouteDraftGraphOverlay`; do not create a parallel chart implementation.
- Follow fixture and widget-test patterns in `test/services/elevation_profile_series_builder_test.dart`, `test/widget/elevation_profile_chart_test.dart`, and `test/widget/map_screen_route_sheet_test.dart`. The Spec requires no robot coverage, new test seams, fakes beyond in-memory model fixtures, API keys, or live network calls.

## Acceptance criteria

- [x] `ElevationProfileSeries.supportsTimeAxis` is true only when every persisted profile entry is a map with numeric `distanceMeters` and parseable `timeLocal`, timestamps strictly increase in persisted profile order, and at least the required profile samples are available; any malformed or skipped persisted entry makes it false. Null `elevationMeters` and absent `segmentIndex` or `pointIndex` alone do not make timestamps unusable.
- [x] Every rendered `ElevationProfileChart`, including `RouteDraftGraphOverlay`, renders its lower y-axis base label from the existing rounded chart-range minimum, rounded to a whole metre with no unit suffix, while retaining the existing rounded range and grid lines.
- [x] With usable timestamps, the hover tooltip retains its existing x-axis value and elevation, then renders local recorded time as `HH:MM` and total time from the first profile sample as `HH:MM elapsed`; hours are zero-padded to at least two digits and do not wrap at 24. These time lines work in both Distance and Time modes.
- [x] With unusable timestamps, Time is disabled and both hover time lines are omitted while existing applicable hover content remains. This includes missing or non-chronological Track timestamps and saved Routes with elevation data but no timestamps.
- [x] Tooltip background and text use `ColorScheme.primaryContainer` and `ColorScheme.onPrimaryContainer`. The hover vertical line and selected dot use `MapChartHoverDotTheme.color`, and the vertical line is 2 logical pixels wide.
- [x] The `MouseRegion` keyed `elevation-profile-chart-touch-area` remains on the cursor-bearing shared chart interaction area and uses `SystemMouseCursors.click`; enabled Distance and Time selectors use the pointing cursor, disabled Time keeps the default cursor, and touch interaction, keyboard accessibility, semantic labels, loading, empty, and error states remain unchanged.
- [x] Extend `test/services/elevation_profile_series_builder_test.dart` for complete valid and invalid persisted-entry cases: missing timestamps, non-map entries, missing or nonnumeric `distanceMeters`, equal or descending timestamps, and other skipped malformed entries, while proving null elevation and absent indexes remain usable.
- [x] Extend `test/widget/elevation_profile_chart_test.dart` for the rounded base label, hover time lines in both axis modes, unavailable-time fallback, tooltip colors, map-marker hover color, 2-pixel line, cursor values, touch behavior, and existing semantics. Extend `test/widget/map_screen_route_sheet_test.dart` to prove the shared changes render in `RouteDraftGraphOverlay`.
- [x] Run `flutter analyze` and `flutter test test/services/elevation_profile_series_builder_test.dart test/widget/elevation_profile_chart_test.dart test/widget/map_screen_route_sheet_test.dart`.

## Covers

- User Stories: 2-3
- Requirements: 5-8; 9-10 (shared elevation-profile portions)
- Technical Decisions: 1, 3-4
- Testing Strategy: 2-4
- Interview Ledger: L1, L3, L5

## Blocked by

None - ready to start
