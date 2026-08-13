---
type: Spec
title: Peak Track Elevation Correlation
---

## Problem

Peak correlation currently uses only horizontal distance from a stored `Peak` to GPX track geometry. A track passing near a peak at a substantially different elevation can therefore be recorded as an ascent. Users also cannot rebuild one selected track to test revised correlation rules; the existing Settings action rebuilds every track.

## Proposed Outcome

Require both horizontal and vertical proximity for Peak Correlation, with independently persisted distance and elevation thresholds. Give users a confirmed, single-track `Recalculate Track Statistics` action in the track information panel to rebuild that track's statistics, peak correlation, and derived bagged history using the current settings.

## User Stories

1. As a peak bagger, I want a nearby track to count a peak only when it was recorded at approximately the peak's elevation, so tracks on another contour do not produce false ascents.
2. As a peak bagger, I want to tune the allowed elevation difference independently of horizontal distance, so I can accommodate the accuracy of my GPX recording.
3. As a peak bagger, I want to recalculate one selected track from its information panel, so I can test changed correlation settings without rebuilding every track.

## Requirements

1. A peak is correlated when any finite track position is within the configured horizontal `Distance threshold` and the absolute difference between `Peak.elevation` and track elevation at that position is within the configured `Elevation threshold`. Equality at either threshold is a match. [L1]
2. For every finite GPX segment, consider every position within the distance threshold. For a point within a multi-point segment, linearly interpolate elevation from the two segment endpoint elevations at that position. A one-point segment uses that point's elevation. Correlate the peak when any position meets both thresholds. [L1] [L6]
3. Do not correlate a peak when `Peak.elevation` is missing, or when no track point/segment within the distance threshold can supply valid elevation within the elevation threshold. A valid elevation is a finite numeric `<ele>` value in metres; absent, blank, non-numeric, `NaN`, and infinite values are unavailable. Do not retain the previous horizontal-only fallback. [L3] [L6]
4. Preserve existing segment semantics: do not match a line extension beyond a segment, support track points and route points as currently supported, and include each matching peak at most once per track. For route-export correlation, use stored `Route.gpxRouteElevations` or its existing route-elevation resolver and include those values in the correlation geometry. [L1]
5. Continue to process the repaired stored GPX XML when it exists, otherwise the original stored GPX XML, for both all-track and individual recalculation. The chosen XML is the source for statistics and correlation. [L7]
6. The Peak Correlation Settings section must retain `Distance threshold` and add an `Elevation threshold` integer dropdown. The two settings are independent and persistent. [L2] [L4]
7. `Elevation threshold` defaults to 10 m and supports exactly 10, 20, 30, ..., 100 m. Invalid or unavailable stored values resolve to the 10 m default. [L1] [L4]
8. The Peak Correlation section summary must show both configured thresholds in metres. [L2] [L4]
9. Saving either threshold must not rebuild existing tracks. New imports and explicit rebuilds use both current thresholds. [L5]
10. In `MapTrackInfoPanel`, place a filled `Recalculate Track Statistics` button immediately above the existing `Hide this track on the map` / `Show this track on the map` switch. The control is available only for a selected track, never a route. [L7]
11. Tapping the button must show a confirmation dialog with title `Recalculate Track Statistics?`, message `This will rebuild statistics and peak correlation for this track from stored GPX XML. Do you wish to proceed?`, and `Cancel` and `Recalculate` actions. Cancel must make no changes. [L8]
12. Confirming an individual recalculation must rebuild only the selected track's statistics, filtered/display data, repaired XML when needed, and peak correlation. It must update derived bagged history from persisted tracks so downstream ascent views remain accurate. Commit the selected track and derived bagged history atomically: if any processing, persistence, or bagged-history synchronization step fails, restore their exact prior persisted state, including every prior bagged-history row and its identifier. It must not recalculate or rewrite unrelated tracks. [L7]
13. While either global or individual track recalculation is active, prevent another global or individual recalculation. For the selected track, disable the filled button and show inline progress with `Recalculating...`; leave the panel open. [L9]
14. After successful individual recalculation, refresh the open track panel's statistics and correlated peaks, then use the existing single-action dialog helper to show `Track Statistics Recalculated` with `Track statistics and peak correlation were refreshed.` The panel remains open behind the dialog. [L9]
15. If individual recalculation fails, restore its prior persisted track and bagged history, re-enable the button, and use the existing single-action dialog helper to show `Track Statistics Recalculation Failed` with the actionable error text. The panel remains open behind the dialog. [L9]

## Technical Decisions

1. Extend the GPX geometry used by `TrackPeakCorrelationService` to retain optional `<ele>` values alongside latitude and longitude, rather than deriving an elevation from aggregate track statistics. Correlation must operate on the actual stored processing XML. [L1] [L3] [L6]
2. Keep horizontal and vertical threshold preferences in the existing SharedPreferences-backed Peak Correlation settings boundary, using a distinct elevation key and independently normalized value. Expose both current thresholds to every `TrackPeakCorrelationService` caller, including route export. [L4]
3. Reuse the existing `MapNotifier` processing flow (`GpxImporter`, `GpxTrackRepairService`, current processing XML selection, correlation application, repository replacement, and bagged-history synchronization) for the selected-track operation. Add a focused notifier entry point rather than duplicating this flow in the map screen. Introduce an injectable derived-track persistence boundary that commits the selected-track replacement and its resulting bagged-history synchronization plan in one ObjectBox write transaction; on failure it must preserve both prior records, including bagged-history identifiers. The test implementation of this boundary must support deterministic failure injection before each write stage. [L7]
4. Use the existing global track-operation busy state as the source of truth for mutual exclusion, while exposing a selected-track busy state to the panel button. Do not permit concurrent mutations of track-derived data. [L9]
5. Preserve the existing all-track Settings action and its result behavior. The individual action has a separate, single-track confirmation and result contract: use the existing danger-confirmation dialog helper for confirmation and the existing single-action dialog helper for success and failure. [L7] [L8] [L9]

## Testing Strategy

1. Use test-driven development for the correlation service changes: add one focused failing unit test before each behavior change, then implement the smallest passing change. [L1] [L3] [L6]
2. Add unit coverage for: a vertical match within 10 m; rejection outside the vertical threshold despite horizontal proximity; inclusive threshold boundaries; missing peak elevation; missing, blank, non-numeric, `NaN`, or infinite one-point elevation; missing endpoint elevation; linear interpolation at an interior closest point; a nearby vertical match despite a closer vertical rejection; and preservation of finite-segment behavior and duplicate suppression. [L1] [L3] [L6]
3. Add provider/service coverage for persisted elevation-threshold defaults, supported values, invalid-value normalization, current-setting use during new and explicit recalculation, and individual recalculation updating exactly one track while resynchronizing bagged history. Cover deterministic failure before the selected-track write and before the bagged-history write by asserting the exact prior selected track and bagged-history rows, including their identifiers, are restored. Extend route-export service coverage to prove correlated peak waypoints use stored or resolved route elevations. Use the existing repository/provider test fakes; do not use real GPX files, ObjectBox databases, network services, or SharedPreferences outside their established test mocks. [L4] [L5] [L7]
4. Extend Peak Correlation Settings widget coverage to verify the `Elevation threshold` field, the two-threshold summary, and persistence through the existing settings provider test seam. [L2] [L4]
5. Extend `MapTrackInfoPanel` widget coverage to verify the filled individual-recalculation button appears above the visibility row for tracks only, confirmation/cancel behavior, busy state, success refresh/message, and failure recovery. Verify the existing confirmation and single-action dialogs are used while the panel remains open. Use stable keys for the button, confirm action, busy indicator, and result/error surfaces. [L7] [L8] [L9]
6. Extend the existing GPX-track robot helpers and a journey test to select a track, recalculate it, and verify the panel remains open with refreshed correlation output. Use deterministic fixtures and provider/repository fakes. [L7] [L9]

## Out of Scope

1. Automatically rebuilding existing tracks after either threshold changes.
2. Changing the existing horizontal-distance options or default.
3. Inferring a missing peak or GPX elevation from a DEM, nearby sample, or aggregate track statistic.
4. Applying the individual recalculation action to planned routes.
5. Adding a batch-selective track recalculation workflow.
