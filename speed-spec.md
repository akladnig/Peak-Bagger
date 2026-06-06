<goal>
Add speed metrics to the track info panel so selected tracks show Average Speed, Moving Speed, and Max Speed alongside the existing time summary.

This matters because users already inspect distance and time for a track; speed is the missing summary metric, and it should be calculated consistently from the imported GPX data instead of ad hoc in the widget tree.
</goal>

<background>
The track info panel is rendered from `./lib/screens/map_screen_panels.dart`.
Shared number formatting helpers live in `./lib/core/number_formatters.dart`.
Track summary values are calculated in `./lib/services/gpx_track_statistics_calculator.dart`, imported in `./lib/services/gpx_importer.dart`, refreshed by `./lib/providers/map_provider.dart` via the existing recalculate flow, and stored on `./lib/models/gpx_track.dart`.

There is an unrelated `calculateMaxSpeed` helper in `./lib/services/geo.dart`; do not confuse that percentile-based helper with the new rolling time-window track speed metric.

Files to examine:
- `./lib/screens/map_screen_panels.dart`
- `./lib/core/number_formatters.dart`
- `./lib/services/gpx_track_statistics_calculator.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/models/gpx_track.dart`
- `./test/core/number_formatters_test.dart`
- `./test/gpx_track_test.dart`
- `./test/widget/map_screen_track_info_test.dart`
- `./test/widget/map_screen_route_info_test.dart`
- `./test/robot/gpx_tracks/single_track_import_journey_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/widget/objectbox_admin_browser_test.dart`
</background>

<discovery>
Before coding, verify the current GPX statistics pipeline and confirm which track fields are already available at import time.

Specifically confirm:
- where `totalTimeMillis`, `movingTime`, and `distance2d` are sourced today
- whether the speed values should be persisted on `GpxTrack` or derived in the panel
- which parsed trackpoint timestamps are available for a rolling max-speed window calculation
</discovery>

<user_flows>
Primary flow:
1. User selects a track and opens its info panel on the map.
2. The panel shows the existing Time section.
3. A new Speed section appears directly under Time.
4. The Speed section shows Average Speed, Moving Speed, and Max Speed in km/h.
5. The user can switch tracks and the panel updates immediately with the new track’s values.

Alternative flows:
- Route selection: the route info panel remains unchanged and does not show Speed.
- Old track records: if speed fields are still at their default values, the panel still opens and shows those values instead of crashing.
- No timing data: if the track has no usable time data, the speed rows render Unknown.

Error flows:
- Zero or missing duration: do not divide by zero; render Unknown.
- Short or sparse track data: if the max-speed window cannot be formed, render Unknown.
- Segment gaps or repeated timestamps: ignore them rather than inflating the reported speed.
</user_flows>

<requirements>
**Functional:**
1. Add a km/h speed formatter in `./lib/core/number_formatters.dart`.
   - Accept nullable input.
   - Render `Unknown` for null.
   - Default to one decimal place and append `km/h`.
2. Extend the GPX statistics pipeline so track summary data includes:
    - Average Speed = `distance2d / totalTime`
    - Moving Speed = `distance2d / movingTime`
    - Max Speed = rolling maximum average speed over a 1 minute window
    - Use the same 2D parsed trackpoint stream used by the other summary metrics; do not switch to 3D distance or a separate filtered geometry path.
3. Make the max-speed calculation windowed and reusable.
   - Support at least `30s`, `1m`, `3m`, and `5m` windows.
   - Use contiguous samples within a segment.
   - Do not bridge across segment gaps.
   - Ignore zero or negative elapsed-time spans.
4. Update `./lib/screens/map_screen_panels.dart` so the track branch renders a `Speed` section directly under `Time`.
   - Show `Average Speed`, `Moving Speed`, and `Max Speed` in that order.
   - Leave the route branch unchanged.
5. Persist three non-nullable `double` speed summary fields on `./lib/models/gpx_track.dart`: `averageSpeedKmh`, `movingSpeedKmh`, and `maxSpeedKmh`.
    - Default each field to `0.0`.
    - Populate them in `./lib/services/gpx_importer.dart`.
    - Persist only the derived summary values, not raw GPX-derived scratch state.
    - The existing `Recalculate Track Statistics` flow in `./lib/screens/settings_screen.dart` and `./lib/providers/map_provider.dart` must also refresh these fields for stored tracks.

**Error Handling:**
6. If total time or moving time is unavailable or zero, return null from the speed calculation and render Unknown.
7. If the rolling max-speed helper cannot form a valid window, return null and render Unknown.
8. Preserve existing route-panel behavior and do not introduce speed-only logic there.

**Edge Cases:**
9. Tracks shorter than the requested max-speed interval should not crash and should not invent a value.
10. Tracks with repeated timestamps, stationary points, or segment gaps must not overstate max speed.
11. Existing stored tracks without populated speed fields should default to `0.0` until the existing `Recalculate Track Statistics` flow refreshes them; do not add a separate migration.

**Validation:**
12. Add focused unit tests for `formatSpeedKmh` and the windowed max-speed calculator.
13. Add widget coverage for the track info panel Speed section and a route-panel regression proving Speed stays absent there.
14. Update model round-trip tests and any ObjectBox admin/schema expectations affected by new persisted `GpxTrack` fields.
15. Keep one critical journey covered in an existing robot or journey test: selecting/opening a track still shows the panel, and the panel content includes the new Speed section.
</requirements>

<boundaries>
Edge cases:
- Do not change distance, elevation, time, or visibility behavior.
- Do not add the Speed section to the route panel.
- Do not move formatting logic into the widget tree.

Storage boundaries:
- Keep the speed values as derived track-summary fields.
- Do not change the raw GPX payload shape.
- Do not add a new dependency.
</boundaries>

<implementation>
Create or modify these files:
- `./lib/core/number_formatters.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/services/gpx_track_statistics_calculator.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/models/gpx_track.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`
- `./test/core/number_formatters_test.dart`
- `./test/gpx_track_test.dart`
- `./test/widget/map_screen_track_info_test.dart`
- `./test/widget/map_screen_route_info_test.dart`
- `./test/robot/gpx_tracks/single_track_import_journey_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/widget/objectbox_admin_browser_test.dart`

Patterns to use:
- Keep the panel presentational; the statistics layer owns the speed math.
- Reuse the existing GPX statistics/import pipeline so speed values are available with the rest of the track summary.
- Prefer deterministic synthetic GPX fixtures and explicit `GpxTrack` test objects.
- Keep `GpxTrack.fromMap()` / `toMap()` and ObjectBox serialization in sync with the new fields.

What to avoid:
- Do not parse GPX inside `MapTrackInfoPanel`.
- Do not hard-code formatter strings in the widget layer.
- Do not reuse the unrelated percentile-based helper in `./lib/services/geo.dart` for the new rolling-window metric.
</implementation>

<stages>
Phase 1: formatter and calculator.
- Add the km/h formatter and the windowed speed calculation helper.
- Verify with unit tests on direct formatting and fixed GPX fixtures.

Phase 2: persistence.
- Add derived speed fields to `GpxTrack` and populate them in the importer.
- Update the existing track-statistics recalculation path so stored tracks also refresh the new speed fields.
- Regenerate ObjectBox artifacts and verify model round-trip and schema/admin tests.

Phase 3: panel rendering.
- Add the Speed section under Time in the track branch.
- Verify route behavior is unchanged.

Phase 4: journey coverage.
- Update the existing track-info robot or journey test to assert the panel still opens and includes the new Speed section.
- Run the targeted suite, then the full relevant test pass.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for `formatSpeedKmh`, average speed math, moving speed math, and max-speed windows at 30s/1m/3m/5m.
- UI behavior: widget tests for the track info panel showing `Average Speed`, `Moving Speed`, and `Max Speed`, plus a regression test proving the route panel still omits `Speed`.
- Critical journey: robot or existing journey coverage for opening a selected track and verifying the info panel still appears with the new Speed section.
- Persistence: model round-trip tests for `averageSpeedKmh`, `movingSpeedKmh`, and `maxSpeedKmh`, plus any ObjectBox admin/schema assertions that enumerate track fields.
- Recalculation coverage: verify the existing `Recalculate Track Statistics` flow repopulates the new speed fields on stored tracks.

TDD expectations:
- Write one failing slice at a time: formatter, calculator, persistence, panel rendering, route regression.
- Keep the max-speed calculator deterministic by using fixed GPX fixtures with known timestamps and distances.
- Use nullable seams or explicit null behavior to cover missing-time and short-track cases without relying on live file I/O.
- Keep the windowed speed helper in the statistics layer so the widget tests stay pure.

Selectors and seams:
- Reuse `Key('track-info-panel')` as the primary anchor.
- Add stable keys for the speed section and rows if needed for deterministic tests, such as `track-info-panel-speed-section`, `track-info-panel-average-speed`, `track-info-panel-moving-speed`, and `track-info-panel-max-speed`.

Verification:
- `flutter test test/core/number_formatters_test.dart test/gpx_track_test.dart test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_info_test.dart`
- `flutter test`
</validation>

<done_when>
- Selected tracks show a `Speed` section under `Time` with Average Speed, Moving Speed, and Max Speed in km/h.
- The speed formatter is covered by tests and renders Unknown for null values.
- The statistics layer can calculate max speed for 30s, 1m, 3m, and 5m windows.
- Track import persists the new speed summary data.
- Route info behavior is unchanged.
- Widget, unit, robot/journey, and schema-related coverage pass.
</done_when>
