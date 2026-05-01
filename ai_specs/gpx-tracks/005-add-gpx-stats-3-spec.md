<goal>
Extend the existing GPX track stats pipeline with time analytics that are derived from the filtered GPX XML already stored in `GpxTrack.filteredTrack`, with raw-GPX fallback when filtered XML is missing or invalid. Timestamp fields are normalized to UTC; duration fields remain millisecond counts.

This slice adds persisted time summary fields so imported tracks, reset tracks, and manually recalculated tracks all share one source of truth without reopening the source files.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `xml`, `latlong2`, and the existing GPX stats/import/reset flow.

Relevant context:
- `GpxTrack` already stores raw GPX XML in `gpxFile`, filtered GPX XML in `filteredTrack`, segmented geometry in `displayTrackPointsByZoom`, and the distance/peak/elevation stats added by `005-add-gpx-stats-1-spec.md` and `005-add-gpx-stats-2-spec.md`.
- `lib/services/gpx_track_statistics_calculator.dart` is the shared pure stats entry point used by import/reset/recalc and should consume filtered GPX XML for time math, falling back to raw GPX XML when `filteredTrack` is unavailable.
- `lib/services/gpx_importer.dart` parses raw GPX XML, builds filtered XML, and persists `GpxTrack` rows.
- `lib/providers/map_provider.dart` owns import, reset, and manual statistics recalculation.
- `lib/screens/settings_screen.dart` is the maintenance entry point for track repair actions.
- ObjectBox schema changes require regenerating both `lib/objectbox-model.json` and `lib/objectbox.g.dart`.
- The existing ObjectBox admin browser/repository should be kept in sync when entity fields change.
- Time stats are filter-setting dependent because they are derived from the filtered GPX output produced by the current filter configuration.
- Rerunning import, reset, or manual recalculation is expected to rewrite `filteredTrack` and recompute time stats from the current filter configuration.

Files to examine:
- @lib/models/gpx_track.dart
- @lib/services/gpx_track_statistics_calculator.dart
- @lib/services/gpx_importer.dart
- @lib/services/gpx_track_repository.dart
- @lib/services/geo.dart
- @lib/services/objectbox_admin_repository.dart
- @lib/providers/map_provider.dart
- @lib/screens/settings_screen.dart
- @lib/objectbox-model.json
- @lib/objectbox.g.dart
- @test/gpx_track_test.dart
- @test/services/objectbox_admin_repository_test.dart
- @test/widget/objectbox_admin_browser_test.dart
- @test/widget/gpx_tracks_shell_test.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart
- @ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md
- @ai_specs/005-gpx-tracks-spec.md
- @ai_specs/005-add-gpx-stats-1-spec.md
- @ai_specs/005-add-gpx-stats-2-spec.md
</background>

<user_flows>
Primary flow:
1. User imports GPX tracks, rescans tracks, or runs Reset Track Data.
2. The app filters the raw GPX XML once, then calculates time analytics from the stored filtered XML for each persisted track.
3. The track row is saved with `startDateTime`, `endDateTime`, `totalTimeMillis`, `movingTime`, `restingTime`, and `pausedTime`.
4. The user can later run manual statistics recalculation from Settings and receive the same values from `filteredTrack` without reading the source files again.

Alternative flows:
- Track has valid geometry but some missing time samples: keep the track import/recalc successful and persist usable defaults.
- Track has no parseable time samples: persist zero/default time stats.
- Track has no usable `filteredTrack`: fall back to raw GPX time stats and warn.

Error flows:
- Stored `filteredTrack` cannot be parsed: fall back to raw GPX time stats, continue the batch, and keep the existing warning behavior from `005-add-gpx-stats-1-spec.md`.
- A track operation is already running: ignore repeat requests and keep the operation single-flight.
</user_flows>

<requirements>
**Functional:**
1. Retrofit `GpxTrack` with `movingTime` (`int`), `restingTime` (`int`), and `pausedTime` (`int`) while keeping the existing fields intact.
2. Keep `startDateTime`, `endDateTime`, and `totalTimeMillis` as persisted fields; do not rename or remove them in this slice.
3. Populate all time analytics from `filteredTrack` during import, reset, and manual recalculation. Manual recalculation must not read the filesystem or move files.
4. Use a clustered stop-detection heuristic: sort parseable trackpoints by time within each `<trkseg>` from the chosen source XML; for each consecutive pair, compute `dt`, distance, and speed; classify the interval as rest when it is both very slow and short enough to avoid GPS jitter; merge adjacent rest intervals into a cluster; sum qualifying cluster durations as `restingTime`.
5. Use these defaults for rest detection: `restSpeedThreshold` 0.3 m/s to enter rest, 0.5 m/s to exit rest, `restDistanceThreshold` 10 m, and `minimumRestDuration` 60 s. Compute `dt` and cluster durations at whole-second resolution. Normalize parsed timestamps to UTC before comparison and storage. `totalTimeMillis` is `endDateTime - startDateTime - pausedTime`.
6. Treat `pausedTime` as the duration between adjacent `<trkseg>` elements in the chosen source XML. If the track has zero or one segment, persist `pausedTime = 0`.
7. Manual recalculation must continue to reapply peak correlation, refresh `MapState.tracks`, preserve `showTracks`, and use the existing status/warning/result-dialog flow.
8. Update ObjectBox schema artifacts and admin tooling so the new fields persist and remain inspectable.

**Error Handling:**
9. If `filteredTrack` is empty, invalid, or unparsable for a persisted row, fall back to raw GPX time stats. If raw GPX is also unusable, skip the row, continue the batch, and surface a warning.
10. If a GPX track has no parseable time samples, persist zero/default values for `totalTimeMillis`, `movingTime`, `restingTime`, and `pausedTime`.

**Edge Cases:**
11. Time parsing must ignore unparseable timestamps and non-positive `dt` intervals. When some trackpoints in a segment lack parseable timestamps, skip only those points and continue with the remaining parseable points.
12. Existing rows with legacy or stale stats should be repaired by recalculation without requiring a full data wipe.
13. The feature does not change route-vs-track classification, Tasmania organization, or track rendering behavior.
14. Do not infer pauses from movement gaps or distance clusters.
15. Normalize parsed timestamps to UTC for comparison and storage.
16. Time stats are derived from the currently configured filter settings, so changing those settings and rerunning import/recalc can change stored values.

**Validation:**
17. Add explicit numeric assertions for synthetic GPX samples covering `totalTimeMillis`, `movingTime`, `pausedTime`, and `restingTime`.
18. Add importer tests proving newly imported rows populate the new time fields from stored filtered XML, fall back to raw GPX when filtered XML is unavailable, and persist UTC-normalized timestamps.
19. Add recalc tests proving existing rows are updated from `filteredTrack` without filesystem reads, that invalid or empty `filteredTrack` falls back to raw GPX with a warning, and that segment-gap `pausedTime` is computed from adjacent `<trkseg>` elements.
20. Add a regression test showing filter-setting changes can change the computed time stats.
21. Add a regression test for partial timestamp gaps that confirms missing points are skipped but the remaining parseable points still contribute to time stats.
22. Update admin-browser/repository tests so the new fields appear in ObjectBox inspection output.
</requirements>

<boundaries>
Edge cases:
- Existing rows with legacy or stale stats should be repaired by recalculation without requiring a full data wipe.
- The feature does not change route-vs-track classification, Tasmania organization, or track rendering behavior.

Error scenarios:
- Invalid or empty `filteredTrack`: fall back to raw GPX time stats, record a warning, and keep the batch moving.
- Missing or partial time data: zero the time-summary fields rather than inventing heuristics.
- Concurrent import/rescan/recalc requests: only one track operation may run at a time.
- Time stats may change when filter settings change and the import/recalc path is rerun.

Limits:
- Use the existing macOS track-storage assumptions and current ObjectBox schema flow.
- Do not add new packages; the current XML, geodesic, and JSON dependencies are sufficient.
- Keep time stats logic shared between import/rescan/reset and manual recalculation so there is one source of truth.
</boundaries>

<implementation>
Update `./lib/services/gpx_track_statistics_calculator.dart` to compute time summary fields from filtered GPX XML using the clustered stop-detection heuristic, with raw-GPX fallback when filtered XML is unavailable.
Update `./lib/models/gpx_track.dart`, `./lib/objectbox-model.json`, and `./lib/objectbox.g.dart` for the new schema.
Update `./lib/services/gpx_importer.dart` and `./lib/providers/map_provider.dart` so import/reset/manual recalc all use the same stats calculator output from `filteredTrack`, with raw-GPX fallback when needed.
Update `./lib/services/objectbox_admin_repository.dart` so the admin browser exposes the new fields.
Avoid duplicating GPX parsing or time math in the UI layer.
Treat time stats as filter-setting dependent and preserve UTC normalization across import and recalc.
</implementation>

<stages>
Phase 1: Add the pure stats logic and model/schema updates, then verify them with unit tests for clustered time math, thresholds, zero defaults, raw fallback, UTC normalization, and serialization.
Phase 2: Wire the calculator into import/reset/manual recalculation so persisted rows receive the new fields from stored filtered XML or raw fallback.
Phase 3: Update ObjectBox admin tooling and regression coverage, then verify the import/recalc paths still complete end-to-end.
</stages>

<illustrations>
- Do not infer `pausedTime` from movement gaps or distance clusters.
- Normalize sample times to UTC for comparison and storage.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for clustered rest detection, threshold/hysteresis handling, `totalTimeMillis`, `movingTime`, `restingTime`, `pausedTime`, zero defaults, raw fallback, UTC normalization, and malformed filtered XML handling.
- Data serialization: model and ObjectBox round-trip tests for the new fields and retained existing fields.
- Persistence wiring: importer and manual recalculation tests that prove the shared calculator output is written back from `filteredTrack` or raw fallback, that invalid or empty `filteredTrack` falls back to raw GPX with a warning, and that `pausedTime` comes from adjacent `<trkseg>` gaps.
- Admin tooling: ObjectBox admin repository/browser tests for the new fields.

TDD expectations:
- Write one failing slice at a time: time math, importer wiring, recalc wiring, then admin exposure.
- Keep the calculator pure and injectable so tests do not depend on the filesystem or ObjectBox.
- Prefer fakes for repository and notifier seams; avoid mocking private XML parsing internals.

Robot-testing expectations:
- Keep existing GPX journey tests green for import/reset/recalc flows.
- Use stable selectors only if any visible admin/maintenance UI text changes are introduced.
- If a new visible path is added later, cover one happy-path journey and one warning-path journey.

Recommended test split:
- Unit tests: math, thresholds, zero-default handling, raw fallback, UTC normalization, and warning behavior for invalid `filteredTrack`.
- Widget tests: ObjectBox admin browser and any affected maintenance UI copy.
- Robot tests: existing GPX import/reset/recalc journey coverage should continue to pass unchanged.
</validation>

<done_when>
- `GpxTrack` persists `totalTimeMillis`, `movingTime`, `restingTime`, and `pausedTime`, and regenerated ObjectBox files match the schema.
- Import, reset, and manual recalculation all populate the new fields from stored filtered XML or raw fallback.
- Invalid or empty `filteredTrack` rows fall back to raw GPX with warning.
- Time values are stored in UTC and `pausedTime` reflects adjacent `<trkseg>` gaps.
- Tests cover the calculator, importer wiring, recalculation wiring, and admin inspection output.
</done_when>
