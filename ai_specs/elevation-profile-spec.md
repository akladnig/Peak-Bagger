<goal>
Add a reusable elevation profile chart that appears under the Elevation section in track info, saved route info, and the live route-creation bottom sheet.

The chart should follow the dashboard chart language, default to distance, allow switching to time when the source data supports it, and stay reusable for the future Latest Walk popup without implementing that popup now.
</goal>

<background>
Tech stack: Flutter, Riverpod, `fl_chart`, ObjectBox, GPX XML parsing, and the existing route elevation sampler.

Relevant context:
- `GpxTrack.elevationProfile` already stores JSON samples produced by `lib/services/gpx_track_statistics_calculator.dart`.
- `Route` already stores `gpxRoute` and `gpxRouteElevations`, so a saved route profile can be derived from geometry plus sampled elevations.
- `MapState` already tracks live route-draft elevation summary/loading/error state, but it does not yet store a live point-series cache for plotting.
- `lib/screens/map_screen_panels.dart` and `lib/widgets/map_route_bottom_sheet.dart` currently show summary metrics only.
- `lib/widgets/dashboard/summary_chart.dart` and `lib/widgets/dashboard/elevation_chart.dart` define the dashboard chart style and axis formatting to follow.
- `lib/services/route_elevation_sampler.dart` already exposes `sampleRoute()` and `samplePointElevations()` for route drafting.

Files to examine:
- @lib/models/gpx_track.dart
- @lib/models/route.dart
- @lib/providers/map_provider.dart
- @lib/screens/map_screen_panels.dart
- @lib/widgets/map_route_bottom_sheet.dart
- @lib/widgets/dashboard/summary_chart.dart
- @lib/widgets/dashboard/elevation_chart.dart
- @lib/services/gpx_track_statistics_calculator.dart
- @lib/services/route_elevation_sampler.dart
- @test/gpx_track_test.dart
- @test/services/route_elevation_sampler_test.dart
- @test/widget/map_screen_route_sheet_test.dart
- @test/widget/map_track_info_formatting_test.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart
</background>

<discovery>
Before implementation, confirm these points in code:
1. Which reusable data model should represent chart samples from tracks, saved routes, and live route drafts.
2. Which route-draft state fields are needed so the live bottom-sheet chart can update when sampled point elevations arrive.
3. Which existing dashboard chart formatting helpers can be reused directly without duplicating axis-label logic.
</discovery>

<user_flows>
Primary flow:
1. User opens a track info popup or saved route info popup.
2. The Elevation section renders a profile chart directly below the section title.
3. The chart defaults to distance and offers a time toggle when the source data contains timestamps.
4. The user switches x-axis mode and the chart updates labels/tooltips without changing the underlying elevation series.
5. User opens the route creation bottom sheet and sees the same chart live as the route draft grows.

Alternative flows:
- Track with full `elevationProfile` data: show both distance and time modes.
- Saved route with no timestamps: keep the chart in distance mode and disable or hide the time mode control.
- Route draft while elevation sampling is still running: show the loading state and update the chart once point elevations arrive.
- Returning user: x-axis selection is local to the current popup or sheet and resets to distance when reopened.

Error flows:
- Profile JSON cannot be parsed: fail closed to an empty chart state and keep the rest of the popup usable.
- Route elevation sampling fails: keep the route draft usable, preserve the existing summary/error UI, and do not block the chart container.
- The chart receives fewer than 2 usable points: render the empty state instead of a malformed plot.
</user_flows>

<requirements>
**Functional:**
1. Introduce a reusable elevation profile chart widget and a pure data-shaping layer so the same chart code can render track profiles, saved route profiles, and live route-draft profiles.
2. The default x-axis mode is distance.
3. Users can switch the x-axis mode to time from within the chart card.
4. Time mode is enabled only when the supplied samples include timestamps; otherwise the control is disabled or hidden and distance remains active.
5. Track info popups must read from `GpxTrack.elevationProfile`.
6. Saved route info popups must derive the chart series from `Route.gpxRoute` plus `Route.gpxRouteElevations`.
7. The route creation bottom sheet must render the chart from the current draft geometry and live sampled point elevations, not from summary stats alone.
8. The live route-draft chart must refresh when the committed route geometry changes and when sampled point elevations arrive later.
9. The chart must use the same visual language as the dashboard elevation charts: axis label formatting, theme colors, spacing, and tooltip behavior.
10. Add stable app-owned keys for the chart container, x-axis toggle, loading state, empty state, and error state.
11. Keep the chart widget reusable for the future Latest Walk popup, but do not implement that popup now.
12. Do not use horizontal scrolling in the profile chart.
13. The x-axis must always scale to the full extent of the current series, with `x-max` equal to the furthest sample distance in distance mode.
14. In the live route-draft flow, the x-axis extent must update as new committed points are added, so the visible scale grows from the current furthest sample rather than scrolling.
15. Route and live route-draft profiles must use control points only, with straight line segments between samples and no densified intermediate series.
16. For route and live route-draft charts, each sample’s x-value must be the cumulative 2D geodesic distance along the stored point sequence, matching the route-distance accumulation rule already used in `map_provider.dart`.

**Error Handling:**
17. If profile data is missing or partially missing, render what is available and leave missing elevations as gaps rather than fabricating values.
18. If the route draft elevation sampler fails, keep the bottom sheet usable and preserve the existing summary/error messaging.
19. If profile JSON is invalid or empty, show the empty state instead of crashing the popup or sheet.
20. Time mode must preserve source order, ignore samples with missing timestamps, and disable itself when fewer than 2 valid timestamps remain.

**Edge Cases:**
21. Distance mode must accumulate across track or route segments without bridging gaps that are explicit in the source data.
22. Time mode must not re-sort samples with duplicate or non-monotonic timestamps; plot them in source order.
23. Single-point or single-sample inputs must not render as a broken chart.
24. X-axis selection is local to the open chart instance and does not need to persist between openings.
25. Do not add persistent storage for route-draft profile state unless it is already required for the live draft flow.

**Validation:**
20. Add unit tests for the profile parsing and point-series derivation logic first, then widget tests for rendering states and x-axis switching, then robot tests for the critical popup and sheet journeys.
21. Baseline automated coverage must include logic/business rules, UI behavior, and critical user journeys.
22. For the route-draft live profile, add deterministic seams so tests can inject fake elevation samples and avoid real GDAL sampling.
23. Use stable keys and deterministic selectors so robot tests can open the popup or sheet and verify the chart and toggle controls reliably.
</requirements>

<boundaries>
Edge cases:
- Track profiles may contain segment boundaries and null elevations; the chart must preserve those gaps.
- Saved routes and live route drafts currently have point elevations but no timestamps, so time mode is only meaningful for track profiles unless new time data is introduced later.
- The future Latest Walk popup is out of scope for this slice.

Error scenarios:
- Invalid or empty elevation profile data: show empty state and keep the surrounding popup/sheet operational.
- Route sampling failure: keep summary metrics visible and avoid replacing the whole bottom sheet with an error screen.
- Partial live draft updates: show loading or partial data rather than stale chart data from an old request.
- No horizontal scroll state should be introduced; the chart must reflow and rescale instead of panning.

Limits:
- Do not add new packages unless the existing `fl_chart` stack cannot support the required chart.
- Do not rewrite raw GPX or route geometry just to render the chart.
- Keep chart rendering pure and data-in only; repositories and samplers belong outside the widget.
- The chart should fit the current popup or sheet width and let the x-axis extent define the visible scale.
</boundaries>

<implementation>
Create:
- `./lib/services/elevation_profile_series_builder.dart`
- `./lib/widgets/elevation_profile_chart.dart`

Modify:
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`
- `./lib/services/gpx_track_statistics_calculator.dart` only if the chart needs a new sample shape or parser helper shared with track data

Implementation shape:
- Keep the data-shaping layer pure and deterministic so it can be unit tested with fixtures.
- Parse `GpxTrack.elevationProfile` into chart-ready samples for distance mode and, when timestamps exist, time mode.
- Derive saved-route samples from `Route.gpxRoute` plus `Route.gpxRouteElevations`.
- Add a live route-draft sampled-elevations field in `MapState` and keep it in sync with the existing route-draft request and geometry version gates.
- Render the chart inside the existing Elevation sections rather than creating a second summary layout.
- Reuse the dashboard axis formatting helpers and match the dashboard spacing/tooltip tone.
- Make the x-axis max equal the current furthest sample distance in distance mode, and update that extent as draft points are committed.
- Use only the stored control points for route and draft charts; do not densify or interpolate extra samples.
- Keep the chart widget free of direct repository access and free of route-planning logic.
</implementation>

<stages>
1. Data model and parser.
   - Add the reusable sample model and pure builders, then verify them with unit tests for track JSON parsing, route series derivation, segment gaps, and missing-value handling.
2. Shared chart widget.
   - Build the reusable elevation profile chart with distance/time mode switching, empty/loading/error states, and dashboard-matched styling.
3. Track and route wiring.
   - Embed the chart into the track and saved-route elevation sections using existing data sources.
4. Live route-draft wiring.
   - Add the transient sampled-elevation cache to route drafting and wire the bottom sheet to update as samples resolve.
5. Verification.
   - Run widget, robot, and existing GPX/route journey coverage to confirm no regressions.
</stages>

<illustrations>
Desired:
- A track popup opens and shows a distance profile immediately, then the user toggles to time and sees the x-axis relabel without losing the series.
- A saved route popup shows a distance-only profile because no timestamps are available.
- The route creation bottom sheet updates its profile as the draft grows and sampled elevations arrive, while the x-axis resizes to the current furthest draft point.

Counter-examples:
- Rendering a blank chart when only one sample is available.
- Fabricating timestamps for routes or drafts.
- Blocking the route draft UI while the elevation chart is loading.
- Allowing horizontal panning instead of rescaling the x-axis.
- Densifying route points before plotting.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for track-profile parsing, route-series derivation, segment-gap handling, missing-value handling, and time-mode gating.
- UI behavior: widget tests for distance mode, time mode, disabled/hidden time control, loading state, empty state, and error state.
- Critical journeys: robot tests for opening a track or route info popup and for creating a route with a live-updating elevation chart in the bottom sheet.
- Live-route scaling: add a test assertion that the chart x-axis max increases when a later committed point extends the route draft.

TDD expectations:
- Write one failing slice at a time: parser/series derivation, widget rendering, track/route wiring, then live route-draft wiring.
- Keep the data layer pure and injectable so tests do not depend on the filesystem, ObjectBox, or GDAL.
- Prefer fakes for route-elevation sampling and route-draft state seams; avoid mocking private parsing internals.

Robot-testing expectations:
- Use stable keys for the chart container, toggle control, and state messages.
- Cover one happy-path popup journey and one live route-draft journey.
- Report any residual risk if time mode is unavailable for route/draft data by design.

Recommended test split:
- Unit tests: parsing, sample derivation, timestamp gating, and gap preservation.
- Widget tests: empty/loading/error states and x-axis switching.
- Robot tests: popup/sheet journeys and the live route-draft update path.
</validation>

<done_when>
- Track and route elevation sections render a reusable profile chart instead of summary text only.
- The chart supports distance mode and time mode where timestamps exist.
- The route-creation bottom sheet updates the chart live as the draft changes.
- Automated tests cover the parser, widget states, and the critical popup and route-draft journeys.
</done_when>
