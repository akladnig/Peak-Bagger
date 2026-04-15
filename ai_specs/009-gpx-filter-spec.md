<goal>
Add persisted GPX filtering for hiking tracks so imported and rebuilt tracks can use cleaner elevation data for statistics while preserving the raw source GPX unchanged.

This keeps ascent/descent and elevation profiles more stable without changing existing import, route, or map-rendering behavior.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, SharedPreferences, XML parsing.
Platform context: the existing GPX flow is macOS-focused and reads/writes the user's Documents folder directly.

Relevant files to examine:
- @lib/models/gpx_track.dart
- @lib/services/gpx_importer.dart
- @lib/services/gpx_track_statistics_calculator.dart
- @lib/providers/map_provider.dart
- @lib/screens/settings_screen.dart
- @lib/services/objectbox_admin_repository.dart
- @lib/objectbox-model.json
- @lib/objectbox.g.dart
- @ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md

Current behavior to preserve:
- Raw GPX XML remains the canonical source of truth in `gpxFile`.
- Raw GPX remains authoritative for contentHash, trackDate, first-point classification, file organization, and duplicate detection.
- Route-only GPX files already follow a separate path and are not track-statistics input.
- Track display caching and map rendering should use the filtered track geometry once a track has been imported, rebuilt, or recalculated.

Import note:
- `rescanTracks` must re-filter all existing tracks instead of skipping tracks whose raw `contentHash` already exists.
</background>

<discovery>
Before implementing, confirm these points in code:
1. How ObjectBox handles a newly added non-nullable `String` field on legacy rows, and what default should be emitted for `filteredTrack`.
2. Which code path currently computes track statistics during import and reset/reimport.
3. How the project's existing SharedPreferences-backed settings pattern is structured in Riverpod.
4. Which admin/debug or serialization views enumerate `GpxTrack` fields without affecting map rendering.
</discovery>

<user_flows>
Primary flow:
1. User opens Settings and adjusts track filter controls.
2. User imports tracks or runs a rebuild/reset path.
3. The app filters each eligible track, stores the filtered GPX XML in `filteredTrack`, and calculates statistics from the filtered data.
4. The user sees updated track statistics, updated display geometry, and the existing success messaging from the track operation flow.

Alternative flows:
- Returning user with saved preferences: filter choices are restored and used automatically for the next import/rebuild.
- Legacy rows already in ObjectBox: tracks continue to load even if `filteredTrack` is empty until the user resets/reimports.
- Route-only GPX files: they bypass the track filter pipeline and keep the existing route handling flow.

Error flows:
- Invalid GPX XML: skip the file as today and keep the existing import error behavior.
- Filtering cannot be applied safely: leave `filteredTrack` empty for that track and fall back to raw `gpxFile` for statistics.
- Invalid saved settings: clamp to supported defaults and continue.
</user_flows>

<requirements>
**Functional:**
1. Add a new non-nullable `filteredTrack` `String` field to `GpxTrack` and persist it in ObjectBox with an empty-string default for legacy rows.
2. `filteredTrack` must store a valid minimal GPX document with the same `<gpx>` wrapper as `gpxFile`, and `gpxFile` must remain unchanged.
3. The filtered XML must represent the same logical track, preserve segment boundaries, and keep only the subset of metadata the app reads intact (`trkseg`, `trkpt`, `ele`, `time`, `name`); all other unrecognized GPX content and extensions are intentionally discarded.
4. Use a concrete hiking-friendly filter pipeline:
    - reject impossible points first using conservative point-jump/speed checks
    - drop any track point missing `<time>` before speed-based filtering
    - remove elevation spikes with a Hampel filter
    - smooth remaining elevation with the selected smoother
    - optionally apply a conservative lat/lon smoother
5. Use fixed conservative thresholds for outlier rejection and expose these user-configurable controls in Settings:
    - Hampel window size: odd integer, clamped to 5..11
    - elevation smoother type: `median` or `savitzkyGolay`
    - elevation smoother window size: odd integer, clamped to 5..9
    - position smoother type: `movingAverage` or `kalman`
    - position smoother window size: odd integer, clamped to 3..7
6. Persist filter settings globally using the same app-settings persistence style already used in the project.
7. Default values must be conservative for hiking: Hampel window 7, elevation smoother `median`, elevation smoother window 5, position smoother `movingAverage`, position smoother window 5.
8. Generate and persist `filteredTrack` and rebuild display cache during import, reset/reimport, and track-statistics recalculation paths.
9. Track-statistics recalculation must use the same loading gate and atomic replacement behavior as import/reset.
10. Existing rows are not auto-backfilled on app startup; they only gain or refresh `filteredTrack` when the user resets/reimports or runs recalculation.
11. Track statistics, elevation profile calculations, and display geometry must prefer `filteredTrack` when it is populated, and fall back to raw `gpxFile` when it is not.
12. Update the settings screen with an expandable track-filter section so users can view and change the filter controls before the next import/rebuild.
13. The expandable filter section and each filter control must expose stable app-owned `Key` values for widget and robot tests.
14. Update ObjectBox admin/debug views and any model-serialization paths that enumerate `GpxTrack` fields.

**Error Handling:**
14. Invalid GPX continues to be skipped and logged with the existing import behavior.
15. Missing or empty `filteredTrack` must never break load, display, or stats recalculation.
16. Invalid stored filter values must be sanitized on read and never crash the settings screen.
17. If filtering cannot safely transform a valid track, the app should keep processing by using the raw XML as the stats input for that track only and surface a warning through the existing track-operation status/warning UI.
18. If fewer than 2 points remain after time pruning and outlier rejection, the app must fall back to raw XML for that track’s stats/display and surface the same warning path.

**Edge Cases:**
19. Tracks shorter than the current window size must not be over-smoothed; preserve the raw segment or apply only the safe outlier pass.
20. Missing elevation samples must remain missing; do not invent altitude values.
21. Segment boundaries must not be bridged or merged by the filter.
22. Route-only GPX files remain outside this feature.
23. The filter must be deterministic and idempotent for the same raw input and settings.

**Validation:**
24. Add focused unit tests for the pure filter service first, then importer/rebuild integration, then settings persistence, then UI journeys.
25. Baseline automated coverage must include logic/business rules, settings UI behavior, and the critical import/rebuild journey.
</requirements>

<boundaries>
Edge cases:
- Short track: keep the track importable and avoid aggressive smoothing.
- No elevation data: preserve geometry and calculate stats without fabricating elevation.
- Legacy row with empty `filteredTrack`: treat it as a supported transitional state, not corruption.

Error scenarios:
- Corrupted GPX: existing skip/log behavior stays in place.
- Bad saved settings: coerce to defaults and continue.
- Filter implementation failure on a valid track: fail closed to raw XML for that track only, not the whole batch.

Limits:
- This task covers hiking tracks only, not route filtering.
- Global filter settings are app-wide, not per-track.
- Raw GPX remains the canonical stored source and should not be rewritten by filtering.
- Map rendering and display caching should switch to filtered geometry for imported/rebuilt/recalculated tracks.
</boundaries>

<implementation>
Modify these files:
- `./lib/models/gpx_track.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/gpx_track_statistics_calculator.dart`
- `./lib/services/track_display_cache_builder.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`

Add these files:
- `./lib/services/gpx_track_filter.dart`
- `./lib/providers/gpx_filter_settings_provider.dart`

Implementation shape:
- Keep the filter service pure and deterministic so it can be unit tested with XML fixtures.
- Parse raw GPX once for filtering, emit filtered GPX XML, and store that XML in `filteredTrack`.
- Use the filtered XML for statistics only; keep raw GPX untouched for provenance and fallback.
- Rebuild display geometry from filtered track XML so the map and stats stay aligned.
- Build a provider-fed `GpxFilterConfig` from SharedPreferences and pass it into import/recalc instead of reading settings inside the services.
- Persist settings through a Riverpod-backed settings provider with SharedPreferences as the backing store.
- Keep the settings UI small and explicit: one expandable section for filter type and window sizes, no separate save button, and changes take effect on the next import/rebuild.
- Do not add a third-party filtering package unless the in-repo implementation cannot satisfy the required behavior.
</implementation>

<stages>
1. Schema update.
   - Add `filteredTrack`, regenerate ObjectBox artifacts, and confirm legacy rows still load.
2. Filter engine.
   - Implement the hiking pipeline and prove it with focused unit tests.
3. Import and stats wiring.
   - Persist filtered XML during import/reset/recalculate and compute stats/display from filtered XML when available.
4. Settings controls.
   - Add the filter controls, persist them, and feed them into the import/rebuild pipeline.
   - Recalculate Track Statistics should also refresh filtered data and use the same loading gate and atomic replacement behavior as import/reset.
5. Verification.
   - Run unit, widget, and robot coverage for the new behavior and the existing GPX journeys.
</stages>

<illustrations>
Desired:
- A track with one altitude spike keeps the route shape, but the spike disappears from `filteredTrack` and from ascent/descent totals.
- A normal multi-segment hiking track imports unchanged in shape except for cleaned elevation noise.
- A short track with too few points still imports safely.

Counter-examples:
- Rewriting raw `gpxFile` as part of filtering.
- Bridging across segment gaps.
- Removing route-only GPX support.
- Treating settings changes as per-track state.
</illustrations>

<validation>
Use vertical-slice TDD:
1. Write one failing test for the pure filter service.
2. Implement the smallest change to make it pass.
3. Repeat for import/rebuild integration, then settings persistence, then UI behavior.

Test split:
- Unit tests: filter algorithm, settings persistence/clamping, stats selection logic.
- Widget tests: settings controls render, persist, and disable correctly during loading.
- Robot tests: critical journey from Settings changes to import/reset/rebuild and visible completion state.

Deterministic seams:
- Inject the filter service into import/rebuild code.
- Inject or fake SharedPreferences for settings tests.
- Keep the filter logic free of time, file-system, or network dependencies.

Required coverage outcomes:
- Logic/business rules: outlier rejection, Hampel cleanup, smoother selection, small-track fallback, legacy-row fallback.
- UI behavior: settings controls, selected values, disabled/loading states, and error-free persistence.
- Critical journeys: change settings -> import/rebuild -> filteredTrack persisted -> updated statistics available.

Robot-testing expectations:
- Use stable app-owned keys for the new settings controls and any result dialogs.
- Cover the end-to-end happy path once and the rebuild/reset path once.
- Report any residual risk if filtered-track behavior remains raw-fallback-dependent for legacy rows.
</validation>

<done_when>
- `GpxTrack` persists a `filteredTrack` GPX XML string and the ObjectBox schema is regenerated.
- Imported and rebuilt tracks populate `filteredTrack` and use it for statistics.
- Settings expose persisted filter controls with safe defaults and clamping.
- Legacy rows still load, and only reset/reimport backfills them.
- Automated tests cover the filter logic, settings persistence, UI state, and the critical import/rebuild journey.
</done_when>
