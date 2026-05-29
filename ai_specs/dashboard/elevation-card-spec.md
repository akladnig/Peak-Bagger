<goal>
Build the Elevation dashboard card as a derived summary of the current GPX track set, not as a persisted analytics entity. The card should help users review ascent trends over rolling time windows, compare totals and averages, and inspect bucket-level detail through an interactive chart.
</goal>

<background>
The app is a Flutter + Riverpod dashboard with existing draggable cards, provider-backed state, and established widget/robot test patterns.

Relevant files to examine:
- `./lib/screens/dashboard_screen.dart`
- `./lib/providers/dashboard_layout_provider.dart`
- `./lib/providers/map_provider.dart`
- `./lib/models/gpx_track.dart`
- `./lib/services/gpx_track_statistics_calculator.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./test/widget/dashboard_screen_test.dart`
- `./test/providers/dashboard_layout_provider_test.dart`
- `./test/robot/dashboard/dashboard_robot.dart`
- `./test/robot/dashboard/dashboard_journey_test.dart`

Use the current `mapProvider` track list as the source of truth. Derive summary data from `GpxTrack.trackDate` and `GpxTrack.ascent`. Exclude tracks with no usable date or no ascent.
</background>

<user_flows>
Primary flow:
1. User opens the dashboard and sees the Elevation card in the existing grid.
2. The newest bucket is anchored on the right edge of the chart, with older buckets extending to the left.
3. User reviews the current rolling window total and average ascent.
4. User changes the time period with the period dropdown.
5. The chart recomputes buckets, the title-row total and average update, and the chart re-renders.
6. User hovers a bucket or point to inspect its label and ascent total.
7. User toggles between column and smoothed-line display with the top-right FAB.

Alternative flows:
- Returning user: previously selected period, chart mode, and scroll position remain stable for the current session unless the implementation intentionally resets them.
- Navigation flow: previous/next arrows move the visible window by half of the current visible range with a smooth one-second transition.
- Boundary flow: next clamps at today’s date and previous clamps at the earliest available `GpxTrack.trackDate`.
- Scroll flow: horizontal scrolling updates the visible window, total, and average without changing the selected period preset.
- Period change flow: changing the dropdown preserves the current horizontal scroll position.

Error flows:
- Loading state: while `mapProvider.isLoadingTracks` is true, show a loading placeholder or skeleton instead of the empty state.
- No usable tracks: show an empty state or zero-state summary instead of chart data.
- Tracks missing date or ascent: ignore them and keep the remaining buckets valid.
- Window at data boundary: disable or no-op the relevant arrow when the next move would not change the visible window.
</user_flows>

<requirements>
**Functional:**
1. Add an Elevation card widget and wire it into the dashboard card grid under the existing `elevation` card id.
2. Derive all chart data from the current `mapProvider.tracks` list; do not add a persisted summary entity.
3. Support the following period presets as one control that also determines bucket granularity:
   - `Week` uses daily buckets across the trailing 7 local days.
   - `Month` uses daily buckets across the trailing local month window.
   - `Last 3 Months` uses weekly buckets grouped by month.
   - `Last 6 Months` uses weekly buckets grouped by month.
   - `Last 12 Months` uses monthly buckets.
   - `All Time` uses yearly buckets.
4. Support internal bucket widths for day, week, month, 3-month, 6-month, and annual summaries so the card can render the required windows and motion model.
5. Show a title row that includes the period dropdown, whole-metre total ascent for the visible window, and whole-metre average ascent per visible bucket.
   - Compute the average across all visible buckets, including zero-valued buckets, and round the displayed result with Dart `round()`.
   - Keep previous/next arrows in the title row.
6. Render the chart in either column mode or smoothed-line mode, with a FAB in the top-right of the graph area to toggle modes.
7. Keep all chart windows horizontally scrollable.
8. Use `fl_chart` for the chart rendering layer.

**Error Handling:**
9. While `mapProvider.isLoadingTracks` is true, render a loading placeholder or skeleton and do not show the empty state yet.
10. Ignore tracks with missing `trackDate` or missing `ascent`.
11. When no valid data exists for the selected window after loading completes, render a clear empty/zero state rather than failing or showing stale values.
12. Keep the visible summary values synchronized when the user scrolls, changes period, or uses the arrows.
13. Preserve the current scroll position when the user changes the period preset.

**Edge Cases:**
14. Use local date boundaries for bucket assignment and label generation so totals are stable for the user’s timezone.
15. If multiple tracks land in the same bucket, sum their ascent values into that bucket.
16. If a bucket has no contributing tracks, render it with zero ascent so the visible window remains contiguous.
17. Smooth transitions should not drop or duplicate buckets when moving half a window.

**Validation:**
18. Bucket labels must match the active granularity: weekdays for daily week views, day numbers for daily month views, repeated month labels for weekly buckets in the 3-month and 6-month views, and year labels for annual views.
19. Hover popup text must show the bucket label on the first row and elevation in whole metres on the second row.
20. The same hover inspection behavior must work in both column and smoothed-line modes.
</requirements>

<boundaries>
Edge cases:
- The current date falls near a month or year boundary: the visible window still uses trailing time windows, not hard calendar-page navigation.
- The available track set is shorter than the requested window: render only the data that exists and keep the chart interactive.
- The visible range has only one non-empty bucket: the average equals the total for that window after Dart `round()`.

Error scenarios:
- No tracks loaded: show an empty state with no chart interaction errors.
- Persistence failures in unrelated dashboard state must not block elevation rendering.
- Pointer hover unavailable on touch devices: the chart should remain usable without hover-only affordances.

Limits:
- Do not persist bucket summaries or chart state to ObjectBox or SharedPreferences unless needed for unrelated dashboard behavior.
- Do not introduce a second bucket-selection control; the period dropdown is the only user-facing time control.
- Avoid coupling to private widget internals; keep test seams at public widget, provider, or service boundaries.
- Do not reset the chart viewport when the period changes; preserve the current horizontal scroll offset.
</boundaries>

<implementation>
Add `fl_chart` to `./pubspec.yaml` and use it for the elevation chart rendering.

Create a dedicated elevation summary service/model in `./lib/services/elevation_summary_service.dart` that:
- computes buckets from the current track list,
- exposes the visible window total and average,
- supports horizontal window shifting by half the visible range,
- and produces stable labels for chart rendering and hover popups.

Create a dedicated Elevation card widget in `./lib/widgets/dashboard/elevation_card.dart` and wire it into `./lib/screens/dashboard_screen.dart` using the existing `dashboardCards` definition.

Create a reusable chart subwidget in `./lib/widgets/dashboard/elevation_chart.dart` for the bar and line renderers.

Use the existing Riverpod/data flow patterns already used by `LatestWalkCard` and the dashboard layout provider.

Add stable `Key`s for:
- the Elevation card root,
- the period dropdown,
- the mode-toggle FAB,
- the previous/next arrows,
- the chart viewport,
- and each bucket hit target used for hover and robot tests.

Add test files at:
- `./test/services/elevation_summary_service_test.dart`
- `./test/widget/dashboard/elevation_card_test.dart`
- update `./test/robot/dashboard/dashboard_journey_test.dart` or add a focused elevation journey test alongside it.

Avoid:
- adding a new persisted aggregate table,
- using ad hoc time math inside the widget tree,
- and building the chart state from private mutable widget-only logic that cannot be unit tested.
</implementation>

<validation>
Automated coverage must include unit tests, widget tests, and robot-driven journey tests.

**TDD expectations:**
1. Build the summary logic in small vertical slices.
2. Start with a failing unit test for one window type and one bucket type, then implement the minimum code to pass.
3. Add follow-up tests for edge windows, missing data, average calculation, and arrow stepping.
4. Keep dependencies deterministic by injecting the clock/date source and any scroll/animation control needed for the window movement.
5. Prefer fakes or simple test doubles for data sources; do not mock internal widget state.

**Unit tests:**
6. Verify bucket grouping and label generation for day, week, month, 3-month, 6-month, and annual summaries.
7. Verify total and average calculations for a visible window.
8. Verify missing-date and missing-ascent tracks are excluded.
9. Verify half-window arrow stepping and boundary clamping.
10. Verify period changes preserve scroll position.

**Widget tests:**
11. Verify the Elevation card renders in the dashboard grid.
12. Verify dropdown changes update chart mode, totals, averages, and bucket labels.
13. Verify the FAB toggles between column and smoothed-line rendering.
14. Verify hover popup content and highlighted bucket state.
15. Verify empty/zero states and disabled/no-op controls when there is no usable data.
16. Verify the chart viewport stays anchored on the right edge at the newest date on initial load.

**Robot journey tests:**
17. Cover the primary dashboard journey: open dashboard, select a period, scroll the chart, and confirm the total and average update together.
18. Cover the chart-mode toggle journey.
19. Cover the hover inspection journey on desktop pointer input.
20. Cover period changes preserving scroll position and arrow clamping at the newest and earliest bounds.
21. Use stable selectors, not brittle text-only or index-based selection, for the card root, dropdown, arrows, FAB, and chart buckets.

**Baseline coverage outcomes:**
22. Logic/business rules: bucket math, totals, averages, and window stepping.
23. UI behavior: dropdown, toggle FAB, arrows, hover state, and empty state.
24. Critical journey: dashboard card interaction from selection through scroll/toggle/inspection.
</validation>

<done_when>
The dashboard shows an Elevation card that computes ascent summaries from current tracks, supports the required period presets and chart modes, updates total and average as the visible window changes, exposes hover details, and is covered by deterministic unit, widget, and robot tests.
</done_when>
