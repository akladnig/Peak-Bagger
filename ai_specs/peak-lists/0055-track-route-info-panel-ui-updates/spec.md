---
type: Spec
title: Track and Route Information Panel UI Updates
---

## Problem

Track and saved Route information panels show redundant distance units, and Track labels incorrectly imply that the to/from metrics identify a correlated peak. The reusable elevation-profile chart does not expose elapsed time, uses a generic unit marker for its lower y-axis label, and has hover styling that does not match the map hover marker. Mouse users also lack a consistent pointer affordance for enabled interactive controls in these surfaces. [L1] [L6]

## Proposed Outcome

Make Track and saved Route information easier to scan and interact with by presenting compact distance values, accurately labelled maximum-elevation timing, a clearer and map-consistent elevation hover, and a pointing cursor for all enabled controls within the defined panels. Apply the shared elevation-profile chart changes to the Route Draft overlay as well. Preserve existing statistics, elevation-profile data, loading/error states, and behavior outside the defined panels and shared chart. [L1] [L2] [L3]

## User Stories

1. As a walker reviewing a completed Track, I can see concise 2D/3D distance values and accurately named to/from highest-elevation metrics, including elapsed recorded time when available.
2. As a walker inspecting a Track, saved Route, or Route Draft profile, I can identify the actual minimum elevation and see the selected sample's clock time and elapsed time in a readable, map-consistent hover.
3. As a mouse user, I receive a pointing cursor over every enabled selectable control in the Track/Route information panels and every shared elevation profile.

## Requirements

1. In the Track and saved Route information-panel summary, replace the `Distance (2d/3d)` value format `xx.x km / yy.y km` with unitless one-decimal kilometre values in the form `xx.x / yy.y`. The existing label continues to identify the values as 2D/3D distance. [L1]
2. For every Track whose peak-correlation statistics are processed and whose profile has a valid highest-elevation position, show `To highest elevation` and `From highest elevation`, regardless of correlated `Peak` count. These metrics continue to target the first maximum recorded elevation point in the profile, not a correlated `Peak`. Derive both distance values at display time from that profile: `To highest elevation` uses the first maximum-elevation sample's `distanceMeters`; `From highest elevation` uses the final profile sample's `distanceMeters` minus that value. Do not use persisted `distanceToPeak` or `distanceFromPeak` fields. [L6]
3. Show each highest-elevation metric as `XX.X km / HH:MM` only when every persisted profile entry is a map with numeric `distanceMeters` and a parseable `timeLocal`, all timestamps are strictly chronological in profile order, and the first profile sample, first maximum-elevation profile sample, and final profile sample are present. `elevationMeters` may be null; `segmentIndex` and `pointIndex` are not required for timestamp usability. Any other malformed or skipped persisted profile entry makes timestamps unusable. `To highest elevation` is the elapsed time from the first profile sample to the first maximum-elevation sample; `From highest elevation` is from that sample to the final profile sample. Calculate from profile timestamps only, include pauses, round to the nearest minute, and render total elapsed hours without day wrapping, zero-padded to at least two digits, as `HH:MM` (for example, `25:15`). Render these two rows as single unclipped lines at `UiConstants.preferredLeftWidth`, using the existing label/value row with a 3:2 label-to-value width allocation. [L2] [L6]
4. If a Track has unusable profile timestamps, retain the applicable distance value without a duration. Profile timestamps are unusable when any persisted profile entry is malformed or skipped, any decoded profile sample lacks a timestamp, or timestamps are not strictly chronological. Do not show an unknown, zero, estimated, or moving-time substitute. [L2]
5. In every rendered `ElevationProfileChart`, including the Route Draft overlay, replace the lower y-axis `m` marker with the existing rounded chart-range minimum, rounded to the nearest whole metre. Keep the existing rounded y-axis range and grid lines so the chart remains legible. The base label is numeric and has no unit suffix. This supersedes the earlier raw-profile-minimum guidance in [L4].
6. For an elevation profile with usable timestamps, retain the existing x-axis value and elevation in the hover tooltip and add two lines below them: local recorded clock time as `HH:MM`, followed by total elapsed time as `HH:MM elapsed`, measured from the first profile sample. Total elapsed hours do not wrap at 24 and are zero-padded to at least two digits. Timestamp usability uses the complete persisted-entry contract in requirement 3. The two time lines must be available in both Distance and Time axis modes. [L5]
7. For a profile without usable timestamps, disable the Time selector and omit both hover time lines while retaining the applicable existing hover content. This includes profiles with a missing or non-chronological timestamp and saved Routes with elevation data but no timestamps. [L5]
8. Style the elevation hover tooltip with `ColorScheme.primaryContainer` as its background and `ColorScheme.onPrimaryContainer` as its text color. Use the map hover marker color for the profile's hover vertical line and selected dot, and reduce the vertical hover line from its current 4 logical pixels to 2 logical pixels. Apply this shared-chart styling in the Route Draft overlay too. [L1]
9. Give every enabled pointer-selectable control in the Track and saved Route information panels, and the interactive area of every shared elevation profile including Route Draft, a pointing cursor. This includes profile hover/tap interaction; Distance and Time selectors; Export; Recalculate Track Statistics; route edit and close controls; peak-correlation removal; the visibility switch; route timing info and recalculation buttons; and walking-speed decrement, text-input, and increment controls. Keep the existing `elevation-profile-chart-touch-area` key on the cursor-bearing `MouseRegion` that defines the profile interaction area. Disabled controls retain the default cursor. Do not change pointer behavior elsewhere in the app. [L3]
10. Preserve touch interaction, keyboard accessibility, existing semantic labels, existing loading/empty/error elevation-profile states, and the recalculation button's disabled-in-progress behavior. [L1] [L3]

## Technical Decisions

1. Use the existing `ElevationProfileChart` range calculation as the source of the chart-range minimum label, and use `ElevationProfileSeries` for timestamps, hover content, colors, and interaction behavior across Track, saved Route, and Route Draft. `ElevationProfileSeries.supportsTimeAxis` means every persisted profile entry satisfies the complete timestamp-usability contract in requirement 3 and timestamps strictly increase in profile order; malformed or skipped entries make it false. Its existing callbacks remain the test seam for Track/Route map-hover coordination. [L1] [L5]
2. Derive highest-elevation elapsed durations at display time from the existing Track elevation profile timestamps only. Do not add ObjectBox fields, migrations, recalculation output fields, background work, APIs, or network dependencies for this presentation change. [L2] [L6]
3. Reuse `MapChartHoverDotTheme.color` for the chart hover indicator so the chart and map marker cannot diverge. [L1]
4. Keep the new cursor behavior scoped to enabled controls in the Track/Route panel widgets and shared elevation profile chart; do not establish an application-wide cursor policy. [L3]

## Testing Strategy

1. Update the existing widget tests for `MapTrackInfoPanel` and saved Route information panels to verify compact 2D/3D values, corrected highest-elevation labels for processed Tracks without correlated Peaks, and distance-plus-`HH:MM` / distance-only fallback cases. Cover profile-derived to/from distance values, profile-only timestamp calculation, nearest-minute rounding, total elapsed times over 24 hours, a missing timestamp, and a non-chronological timestamp with deterministic inline `GpxTrack.elevationProfile` fixtures; do not call external services. At `UiConstants.preferredLeftWidth`, assert the complete highest-elevation labels and values share one non-overlapping line. [L1] [L2] [L6]
2. Update `test/services/elevation_profile_series_builder_test.dart` to verify `ElevationProfileSeries.supportsTimeAxis` is true only when every persisted entry meets requirement 3's complete timestamp-usability contract and timestamps strictly increase, and false for missing timestamps, non-map entries, missing or nonnumeric `distanceMeters`, equal or descending timestamps, and other skipped malformed entries. Verify that null `elevationMeters` and absent `segmentIndex` or `pointIndex` do not by themselves make timestamps unusable. Extend `ElevationProfileChart` widget tests to verify the whole-metre rounded chart-range-minimum base label, timestamp hover lines in both axis modes, disabled Time mode and omitted hover time lines for missing or non-chronological timestamps, tooltip colors, map-marker-matched hover color, and the 2-pixel hover line. Extend `map_screen_route_sheet_test.dart` to verify the shared chart changes render in `RouteDraftGraphOverlay`. [L1] [L5]
3. Add widget-level assertions for `SystemMouseCursors.click` on enabled covered controls and default cursors for disabled controls, without changing touch interactions or semantic behavior. Cover the `MouseRegion` identified by `elevation-profile-chart-touch-area` and selectors in every shared-chart host; Export; Track recalculation; Route edit, close, timing info, and timing recalculation actions; peak-correlation removal; visibility; and each walking-speed control. Verify touch chart interaction, existing semantic labels and enabled states, and keyboard operation of affected controls. Existing keys and semantic labels remain stable selectors. [L3]
4. Use the repository's existing widget-test style; no robot coverage, new Test Seams, fakes beyond in-memory model fixtures, API keys, or live network calls are required for this UI-only work.

## Verification

1. Run `flutter analyze`.
2. Run `flutter test test/services/elevation_profile_series_builder_test.dart test/widget/elevation_profile_chart_test.dart test/widget/map_track_info_panel_test.dart test/widget/map_route_info_panel_test.dart test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_sheet_test.dart`.
3. Run `flutter test`.

## Out of Scope

1. Changing the calculation from maximum recorded elevation to a correlated `Peak` position.
2. Changing Track statistics, peak-correlation algorithms, persistence schemas, recalculation workflow, or GPX import behavior.
3. Adding timestamps to saved Routes or estimating unavailable Track timestamps.
4. Changing cursors for controls outside the Track/Route information panels and the shared elevation-profile chart interaction area, including its Route Draft host.
