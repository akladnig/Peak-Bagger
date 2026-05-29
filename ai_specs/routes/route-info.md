<goal>
Extend the existing map track info drawer/panel so it can present both tracks and routes through one shared UI shell.
This matters because tracks and routes are both path objects on the map, but routes should not show track-only metadata such as time.
</goal>

<background>
The app is a Flutter/Riverpod map application.
The current track info panel lives in `./lib/screens/map_screen_panels.dart` as `MapTrackInfoPanel`, and it is opened from `./lib/screens/map_screen.dart` for selected tracks only.
Route data lives in `./lib/models/route.dart`; it includes name, distance, ascent/descent, and elevation values, but no time fields.
Track selection already uses `selectedTrackId` plus `selectTrack` / `clearSelectedTrack` in `./lib/providers/map_provider.dart`; route selection should mirror that pattern with the smallest equivalent route-specific seam.

Relevant files to examine and update:
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/providers/map_provider.dart`
- `./lib/models/gpx_track.dart`
- `./lib/models/route.dart`
- `./test/widget/map_screen_track_info_test.dart`
- `./test/robot/map/map_route_robot.dart`
- `./test/robot/map/map_route_journey_test.dart`
- any new route info widget test file under `./test/widget/`

Reuse the existing panel layout and formatting helpers where possible.
</background>

<discovery>
Inspect how track selection works and mirror that pattern for routes with a narrow route-specific seam.
Confirm whether the current track panel can be converted to a shared panel with section gating instead of duplicating the whole UI.
Identify the smallest stable keys needed for track and route panel assertions.
</discovery>

<user_flows>
Primary flow:
1. The user selects a track on the map.
2. The shared info panel opens and shows track metadata.
3. The user selects a route using the same map-selection style as tracks, through the new route selection seam.
4. The same panel shell opens and shows route metadata.
5. Route content omits time-related sections entirely.

Alternative flows:
- If a selected item has missing optional metadata, the panel still renders using the existing fallback formatting.
- If the user switches from a track to a route, the panel updates in place instead of leaving stale track-only content visible.

Error flows:
- If the selected track or route is no longer available, clear the selection and close the panel.
- If route info cannot be resolved cleanly, fail safe by not showing a broken detail panel.
</user_flows>

<requirements>
**Functional:**
1. Replace the track-only panel with a shared path info panel that can render either a `GpxTrack` or a `Route`, or a small shared view model derived from both.
2. Preserve the current card shell, close affordance, width, and left-side placement.
3. For tracks, keep the existing content: date, time range, distance, ascent, elevation metrics, total time, moving time, resting time, paused time, and peak-correlation content.
4. For routes, render a name-only header and show the available route fields: distance, ascent, descent, and elevation metrics.
5. For routes, omit the entire Time section.
6. Use the same section order as tracks for shared sections, with Time omitted and all track-only content absent.
7. Hide all track-only content that does not apply to routes, including peak-correlation details and track date/time rows.
8. Keep formatting consistent with the existing date, distance, ascent, elevation, and duration helpers.
9. Add the smallest route-selection seam needed so the shared panel can be opened for a selected route.
10. Make the route seam mirror track selection ergonomics by using the same provider-driven select/clear lifecycle shape.

**Error Handling:**
11. Missing optional values must use the same fallback behavior already used by the track panel.
12. A deleted or unavailable selected route must clear selection and close the panel instead of leaving stale UI behind, via the route selection seam.

**Edge Cases:**
13. A route with zero distance, zero ascent, or zero elevation values must still render valid numeric output.
14. Track and route detail state must not be active at the same time.

**Validation:**
15. Add widget tests proving that tracks still show the Time section and routes do not.
16. Add widget tests proving that shared rendering shows route metrics and track metrics from their respective models.
17. Add robot-driven coverage for the route-selection journey if a stable route-selection flow is implemented in this work; otherwise defer robot coverage.
</requirements>

<boundaries>
Edge cases:
- Track time data may remain null; keep the existing formatter fallback behavior.
- Routes have no time source; do not synthesize, backfill, or infer time values.
- Route and track sections must stay mutually exclusive where fields do not apply.

Error scenarios:
- Deleted selected item: clear the selection and close the panel.
- Model mismatch: render only fields supported by the selected object type.

Limits:
- Do not add persisted state for route info unless a separate route-selection feature needs it.
- Do not create a second route-specific drawer; reuse the existing shared panel shell.
- Do not invent route time fields or route duration placeholders.
</boundaries>

<implementation>
Modify:
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart` only if route hit-testing or selection needs a seam
- `./lib/providers/map_provider.dart` only if a selected-route seam is required
- `./lib/providers/route_repository_provider.dart` if the route list needs a selection-facing helper or invalidation signal
- `./test/widget/map_screen_track_info_test.dart`
- `./test/widget/` for any new shared route-info widget tests
- `./test/robot/map/map_route_robot.dart` and `./test/robot/map/map_route_journey_test.dart` for the route-selection journey

Preferred approach:
- Introduce a shared info widget or presenter around the existing panel instead of duplicating the layout.
- Gate sections by model capability, not by string checks or ad hoc conditionals.
- Keep stable app-owned keys for the root panel, close button, and section assertions.
- Add route selection with the same provider-driven lifecycle shape as tracks (`select` / `clear` / selection id), rather than a second bespoke state model.

Avoid:
- Splitting the UI into separate track and route panels with duplicate markup.
- Adding route-specific time placeholders.
- Changing unrelated route rendering, track rendering, or map shell behavior.
</implementation>

<stages>
Phase 1: Model the shared panel.
Verify that track data still renders unchanged and route data renders with time omitted.

Phase 2: Wire route selection into the shared panel.
Verify that selecting a route opens the same panel shell and clears stale track-only content.

Phase 3: Add tests.
Verify track-only and route-only sections, fallback strings, and panel close behavior.
</stages>

<validation>
Use TDD-style slices where practical:
1. Start with a failing widget test for route-specific omission of the Time section.
2. Add a failing widget test for route metric rendering.
3. Add any selection-state seam needed for route opening before broadening coverage.
4. Keep implementation minimal until each slice is green.

Automated coverage outcomes:
- Logic/business rules: shared field selection and section gating are covered.
- UI behavior: the panel renders the correct sections for tracks and routes.
- Critical journeys: the route entry path is covered if a stable route-selection flow exists; otherwise the missing journey is explicitly documented.

Testing split:
- Widget tests: panel content, section visibility, close behavior, and fallback formatting.
- Robot tests: only the end-to-end route-selection flow if the app already has a stable, key-driven journey for it.
- Unit tests: any shared presenter/helper that maps track vs route data into visible sections.

Stable selectors:
- Use a shared root key for the panel and explicit keys for section headers or metrics.
- Keep selectors app-owned and key-first.
</validation>

<done_when>
The work is complete when the existing track info panel can also present routes, routes do not show time-related fields, track behavior remains unchanged, the route selection seam opens the shared panel, and the automated tests prove the section gating.
</done_when>
