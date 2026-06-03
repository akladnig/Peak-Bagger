<goal>
Add hover synchronization between the elevation profile chart and the map view for selected routes and tracks.
When a user hovers the chart, the map should show a transient dot on the corresponding route or track point and move that dot as the hover position changes.
This matters because it lets users relate elevation changes to exact map position without leaving the info panel.
</goal>

<background>
The chart is rendered from `./lib/widgets/elevation_profile_chart.dart` and reused by the selected route/track info panel path in `./lib/screens/map_screen_panels.dart`.
The route-draft bottom sheet also reuses this chart widget, but hover-to-map sync is out of scope there unless explicitly added later.
`./lib/screens/map_screen.dart` owns the map route layout, and `./lib/screens/map_screen_layers.dart` owns polyline and marker rendering.
Transient map interaction state currently lives in `./lib/providers/map_provider.dart`.
Route elevation series are built from ordered route points in `./lib/services/elevation_profile_series_builder.dart`.
Track elevation profiles are produced by `./lib/services/gpx_track_statistics_calculator.dart`, and those entries already carry `segmentIndex`, `pointIndex`, `distanceMeters`, and `timeLocal`.
That track metadata is the authoritative source for resolving a hovered chart sample back to a map point, so the hover seam must preserve that identity through the chart callback.

Files to examine: `./lib/widgets/elevation_profile_chart.dart`, `./lib/screens/map_screen_panels.dart`, `./lib/screens/map_screen.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/providers/map_provider.dart`, `./lib/services/elevation_profile_series_builder.dart`, `./lib/services/gpx_track_statistics_calculator.dart`, `./test/widget/elevation_profile_chart_test.dart`, `./test/widget/map_route_info_panel_test.dart`, `./test/widget/map_track_info_panel_test.dart`, `./test/widget/map_screen_route_hover_test.dart`
</background>

<discovery>
Examine how the chart currently emits touch/hover data and choose the smallest stable hover seam that can be shared by route and track panels.
Confirm how each chart sample maps back to geometry:
route samples should resolve by sample order against `route.gpxRoute`, and track samples should resolve by the profile entry metadata produced by the statistics pipeline.
Identify the narrowest map-rendering seam that can draw a temporary hover dot without reusing selected-route/selected-track state or interfering with existing map hover logic.
</discovery>

<user_flows>
Primary flow:
1. User opens a route or track info panel on the map screen.
2. User moves a pointer over the elevation chart.
3. The active chart sample is resolved to a corresponding map coordinate.
4. The map shows a transient dot on the route or track at that coordinate.
5. As the pointer moves, the dot follows the hovered sample.
6. When the pointer leaves the chart or the panel closes, the dot disappears.

Alternative flows:
- Route panel: hover resolves against the selected route geometry and updates the dot on that route.
- Track panel: hover resolves against the selected track geometry using the profile entry metadata and updates the dot on that track.
- Track time-axis mode: switching between distance and time axes does not break the hover-to-geometry mapping.
- No usable profile data: the chart remains readable, but no map dot is shown.

Error flows:
- If a hover sample cannot be mapped to a valid geometry point, clear the transient dot rather than showing a guessed position.
- If the selected route/track changes while hovering, ignore stale hover updates from the previous selection.
- If the chart loses pointer hover, clear the dot immediately.
</user_flows>

<requirements>
**Functional:**
1. `ElevationProfileChart` must expose a stable hover seam that reports the active sample to its parent without exposing internal chart state.
2. The route/track info panel must convert the hovered chart sample into a map coordinate and publish that coordinate through a transient, non-persistent hover state.
3. The map route must render the hover dot in a dedicated layer above the route/track polyline layer and below overlay chrome that should remain interactive.
4. Route hover resolution must use the route point order already present in `route.gpxRoute` and `route.gpxRouteElevations`.
5. Track hover resolution must use the profile-entry ordering and metadata from the track statistics pipeline, including `segmentIndex` and `pointIndex` when needed.
6. The hover dot must snap to the raw source geometry for the selected route or track, not to a zoom-simplified display segment.
7. For tracks, the raw source geometry means the original GPX path parsed from `GpxTrack.gpxFileRepaired` when it is non-empty, otherwise `GpxTrack.gpxFile`, not the display-cache geometry from `getSegmentsForZoom()`.
8. Hover state must be scoped separately from selected route/track state and separately from existing map pointer hover state used for peaks, routes, and tracks.
9. Hover state must live in a small dedicated transient hover seam rather than in canonical selection or persistence state.

**Error Handling:**
10. Empty, malformed, or partially populated elevation series must disable hover output for the affected chart instead of showing stale markers.
11. Stale hover updates must be ignored once a different route or track becomes active.

**Edge Cases:**
12. Hovering the first or last sample must snap to the corresponding endpoint.
13. Rapid pointer movement across the chart must not leave a stale dot on the map.
14. Toggling the track chart between distance and time axes must preserve the same sample identity for map sync.

**Validation:**
15. Add deterministic tests for sample-to-geometry mapping, hover callback emission, map marker rendering, and hover clearing.
16. Baseline automated coverage must include logic mapping, widget behavior, and one critical cross-component journey.
17. Use stable app-owned keys for the chart region and the transient map hover marker so tests do not depend on private chart internals.
18. The hover callback payload must preserve route sample index and track identity (`segmentIndex` + `pointIndex`, or an equivalent stable track sample id).
</requirements>

<boundaries>
Edge cases:
- Hover should be pointer-driven only; do not add a new keyboard or touch gesture contract for this feature.
- If the chart has no usable samples, the panel must not synthesize a marker position.
- The route-draft bottom sheet must not publish hover-to-map sync from this feature.
- Do not interpolate a new path that is unrelated to the source series; snap to the mapped source sample or clear the hover.

Error scenarios:
- Pointer exit, panel close, selection change, or chart rebuild with no active hover should clear the transient dot.
- If a late hover callback arrives after the active route or track changed, ignore it.

Limits:
- Do not change elevation profile generation formats, route planning logic, or track import formats.
- Do not persist hover state.
- Do not change existing map hover behavior for peaks, routes, tracks, or route-draft markers.
- Do not broaden the feature into general chart crosshair support beyond the map-sync dot.
- Do not add hover sync to the route-draft bottom sheet in this task.
</boundaries>

<implementation>
Preferred files to create or modify:
- `./lib/widgets/elevation_profile_chart.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/providers/map_provider.dart` only if it is split into a small dedicated transient hover provider; prefer a dedicated provider over canonical map state
- `./lib/services/elevation_profile_series_builder.dart`
- `./lib/services/gpx_track_statistics_calculator.dart` only if the current metadata is insufficient for hover resolution

Implementation expectations:
- Keep the hover seam narrow and deterministic.
- Route hover can resolve by sample index.
- Track hover must resolve from the existing profile metadata rather than inventing a new track mapping scheme.
- Preserve the track sample identity in the chart hover payload so the parent can map the hover back to the correct segment and point.
- The map dot should be transient and should not affect selected route/track state, camera state, or persistence.
- Store the transient hover state in a small dedicated provider or equivalent local seam, not in the canonical map selection state.
- Use the same track XML source for hover resolution that the track processing pipeline uses (`gpxFileRepaired` when present, otherwise `gpxFile`).
- Reuse existing map layer composition patterns instead of introducing a new rendering framework.
- Keep the chart widget testable without requiring private `fl_chart` internals in callers.

Avoid:
- Reusing `selectedRouteId`, `selectedTrackId`, `hoveredRouteId`, or `hoveredTrackId` as the chart hover transport.
- Changing how routes, tracks, or elevation profiles are stored on disk.
- Introducing rebuild-heavy state updates across the full map screen for each hover tick.
</implementation>

<stages>
Phase 1: Define the hover seam
- Add a stable hover callback to `ElevationProfileChart`.
- Preserve sample identity for route and track series.
- Verify the chart can report hover enter, move, and exit deterministically.

Phase 2: Map hover to geometry
- Resolve route chart samples to `route.gpxRoute` points.
- Resolve track chart samples to the corresponding track geometry using existing profile metadata.
- Publish the resulting map coordinate through a transient hover state.

Phase 3: Render the map dot
- Add a dedicated hover-marker layer to the map screen.
- Ensure the dot draws above the route/track polylines and clears on exit.
- Keep the existing map hover interactions unchanged.

Phase 4: Validate behavior
- Add widget coverage for the chart seam, panel wiring, and clearing behavior.
- Add logic coverage for route and track sample resolution.
- Add one end-to-end journey test if the existing harness can drive pointer hover deterministically; otherwise keep the coverage at widget level and document the limitation.
</stages>

<validation>
Use vertical-slice TDD where practical: write one failing test for a single hover behavior, implement the minimum code to pass it, then add the next slice.

Required coverage split:
- `unit` or logic: sample index to geometry resolution for route and track, stale-hover ignore behavior, and clear-on-exit behavior.
- `widget`: `ElevationProfileChart` hover emission, `MapTrackInfoPanel` wiring, map marker visibility, and axis-toggle stability for track charts.
- `robot`: one critical chart-to-map hover journey only if the existing harness can move a pointer over the chart reliably with stable selectors; otherwise document the omission and keep the proof in widget tests.

Required assertions:
- Hovering a chart sample shows a map dot at the expected route/track point.
- Moving the pointer updates the dot to the new sample.
- Leaving the chart clears the dot.
- Switching the track chart axis does not change the sample-to-geometry correspondence.
- Closing the panel clears the dot.
- Hovering with no usable samples does not create a marker.

Selector and seam expectations:
- Keep the chart region keyed with an app-owned key such as `Key('elevation-profile-chart')`.
- Add a stable app-owned key for the transient map hover marker layer or marker widget.
- Prefer fakes or small deterministic seams over mocking private chart internals.
</validation>

<done_when>
Hovering the elevation profile in either the route or track info panel moves a transient dot on the corresponding map geometry, the dot tracks hover motion, the dot clears on exit or panel close, route and track mappings are correct and deterministic, and the automated tests prove the chart-to-map sync without regressing existing map hover behavior.
</done_when>
