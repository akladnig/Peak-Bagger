<goal>
Extend the existing GPX track stats pipeline with elevation analytics that are derived from the raw GPX XML already stored in `GpxTrack.gpxFile`.

This slice adds persisted elevation summary fields and a serialized elevation profile so imported tracks, reset tracks, and manually recalculated tracks all share one source of truth without reopening the source files.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `xml`, `latlong2`, and the existing GPX stats/import/reset flow.

Relevant context:
- `GpxTrack` already stores raw GPX XML in `gpxFile`, segmented geometry in `displayTrackPointsByZoom`, and the distance/peak stats added by `005-add-gpx-stats-1-spec.md`.
- `lib/services/geo.dart` already exposes `calculateUphillDownhill()` and the lower-level distance helpers.
- `lib/services/gpx_track_statistics_calculator.dart` is the shared pure stats entry point used by import/reset/recalc.
- `lib/services/gpx_importer.dart` parses GPX XML and persists `GpxTrack` rows.
- `lib/providers/map_provider.dart` owns import, reset, and manual statistics recalculation.
- `lib/screens/settings_screen.dart` is the maintenance entry point for track repair actions.
- ObjectBox schema changes require regenerating both `lib/objectbox-model.json` and `lib/objectbox.g.dart`.
- The existing ObjectBox admin browser/repository should be kept in sync when entity fields change.

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
</background>

<user_flows>
Primary flow:
1. User imports GPX tracks, rescans tracks, or runs Reset Track Data.
2. The app parses the stored GPX XML once and calculates the full stats set for each persisted track.
3. The track row is saved with elevation summary fields and a serialized elevation profile.
4. The user can later run manual statistics recalculation from Settings and receive the same values without reading the source files again.

Alternative flows:
- Track has valid geometry but some missing elevation samples: keep the track import/recalc successful and persist usable defaults plus a partial profile.
- Track has no parseable elevation samples: persist zero/default elevation stats and an empty elevation profile.
- Track contains valid sub-sea-level elevations in `[-100, 0)`: keep those values as-is.
- Track contains samples below `-100m`: normalize those samples to `0` before any elevation math or profile generation.

Error flows:
- Stored GPX XML cannot be parsed: skip that row for stats update, continue the batch, and keep the existing warning behavior from `005-add-gpx-stats-1-spec.md`.
- A track operation is already running: ignore repeat requests and keep the operation single-flight.
</user_flows>

<requirements>
**Functional:**
1. Retrofit `GpxTrack` with `descent` (`double`), `startElevation` (`double`), `endElevation` (`double`), and `elevationProfile` (`String`), while keeping the existing fields intact.
2. Keep the existing `ascent` field and continue populating it from the shared calculator.
3. Populate all elevation analytics from `GpxTrack.gpxFile` during import, reset, and manual recalculation. Manual recalculation must not read the filesystem or move files.
4. Use `geo.dart`'s `calculateUphillDownhill()` as the source of truth for `ascent` and `descent`.
5. Feed `calculateUphillDownhill()` the ordered elevation samples after normalizing any parsed elevation below `-100m` to `0` and omitting missing elevations.
6. Set `startElevation` to the first trackpoint in order with a parseable `<ele>` value greater than `-100`, and `endElevation` to the last trackpoint in order with a parseable `<ele>` value greater than `-100`. If no such point exists, persist `0` for both.
7. Persist `elevationProfile` as a JSON-encoded ordered array that includes every parsed trackpoint in sequence, grouped by segment so gaps can be reconstructed later.
8. Each `elevationProfile` sample must include `segmentIndex`, `pointIndex`, `distanceMeters`, `elevationMeters`, and `timeLocal`.
9. `distanceMeters` in `elevationProfile` must be the cumulative distance from track start, using the same 2D geodesic accumulation rules as the existing distance stats and not bridging segment gaps.
10. `elevationMeters` in `elevationProfile` must use the normalized elevation value for the point when present, or `null` when no elevation was parsed.
11. `timeLocal` in `elevationProfile` must store the sample time converted to local time when a parseable `<time>` exists, otherwise `null`.
12. Update `GpxTrack.fromMap()` and `GpxTrack.toMap()` so the new fields round-trip cleanly with the existing JSON/object serialization style.
13. Update ObjectBox schema artifacts and admin tooling so the new fields persist and remain inspectable.

**Error Handling:**
14. If a GPX point has no parseable elevation, keep it in `elevationProfile` with `elevationMeters = null`, omit it from elevation math, and keep the row import/recalc successful.
15. If a GPX point has no parseable time, keep the elevation sample and set `timeLocal` to `null`.
16. If every parseable elevation sample is absent, persist zero/default values for `ascent`, `descent`, `startElevation`, and `endElevation`, while still preserving the parsed trackpoint order in `elevationProfile` with `null` elevation values.
17. If a stored GPX XML row cannot be parsed, skip that row's elevation update and continue the batch.

**Edge Cases:**
18. Single-point tracks must produce zero `ascent`, zero `descent`, zero `startElevation`, zero `endElevation`, and at most one profile sample.
19. Multi-segment tracks must not bridge segment gaps when accumulating profile distance, and the serialized profile must keep segment boundaries explicit.
20. Valid negative elevations in `[-100, 0)` must remain unchanged.
21. Manual recalculation must update existing rows in place without changing `gpxTrackId`, `trackName`, or file organization.

**Validation:**
22. Add explicit numeric assertions for synthetic GPX samples covering `ascent`, `descent`, `startElevation`, `endElevation`, and profile distance values.
23. Add a regression test proving that a sample below `-100m` is treated as `0` for elevation math and profile output.
24. Add serialization tests proving `elevationProfile` round-trips through `GpxTrack.fromMap()` / `toMap()` and preserves segment gaps.
25. Add importer tests proving newly imported rows populate the new elevation fields from stored XML.
26. Add recalc tests proving existing rows are updated from `gpxFile` without filesystem reads.
27. Update admin-browser/repository tests so the new fields appear in ObjectBox inspection output.
</requirements>

<boundaries>
Edge cases:
- Existing rows with legacy or stale stats should be repaired by recalculation without requiring a full data wipe.
- The feature does not change route-vs-track classification, Tasmania organization, or track rendering behavior.
- The feature does not introduce elevation chart UI yet; it only persists the data needed for future plots.

Error scenarios:
- Invalid GPX XML: leave that row unchanged for stats, record the failure, and keep the batch moving.
- Missing or partial elevation data: zero or omit as defined above rather than inventing heuristics.
- Concurrent import/rescan/recalc requests: only one track operation may run at a time.

Limits:
- Use the existing macOS track-storage assumptions and current ObjectBox schema flow.
- Do not add new packages; the current XML, geodesic, and JSON dependencies are sufficient.
- Keep elevation stats logic shared between import/rescan/reset and manual recalculation so there is one source of truth.
</boundaries>

<implementation>
Update `./lib/services/gpx_track_statistics_calculator.dart` to compute elevation summary fields and the serialized elevation profile from parsed GPX XML.
Update `./lib/models/gpx_track.dart`, `./lib/objectbox-model.json`, and `./lib/objectbox.g.dart` for the new schema.
Update `./lib/services/gpx_importer.dart` and `./lib/providers/map_provider.dart` so import/reset/manual recalc all use the same stats calculator output.
Update `./lib/services/objectbox_admin_repository.dart` so the admin browser exposes the new fields.
Avoid duplicating GPX parsing or elevation math in the UI layer.
</implementation>

<stages>
Phase 1: Add the pure stats logic and model/schema updates, then verify them with unit tests for elevation math and serialization.
Phase 2: Wire the calculator into import/reset/manual recalculation so persisted rows receive the new fields from stored GPX XML.
Phase 3: Update ObjectBox admin tooling and regression coverage, then verify the import/recalc paths still complete end-to-end.
</stages>

<illustrations>
Elevation profile example:
```json
[
  {"distanceMeters":0,"elevationMeters":123.0,"timeLocal":"2024-01-15T08:00:00"},
  {"distanceMeters":842.3,"elevationMeters":141.0,"timeLocal":"2024-01-15T08:12:00"}
]
```

Counterexamples:
- Do not store the profile as nested segment arrays.
- Do not convert sample times to UTC for storage.
- Do not bridge segment gaps when calculating profile distance.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for elevation normalization, uphill/downhill calculation, start/end elevation selection, and profile distance accumulation.
- Data serialization: model and ObjectBox round-trip tests for the new fields.
- Persistence wiring: importer and manual recalculation tests that prove the shared calculator output is written back to rows.
- Admin tooling: ObjectBox admin repository/browser tests for the new fields.

TDD expectations:
- Write one failing slice at a time: elevation math, profile serialization, importer wiring, recalc wiring, then admin exposure.
- Keep the calculator pure and injectable so tests do not depend on the filesystem or ObjectBox.
- Prefer fakes for repository and notifier seams; avoid mocking private XML parsing internals.

Robot-testing expectations:
- Keep existing GPX journey tests green for import/reset/recalc flows.
- Use stable selectors only if any visible admin/maintenance UI text changes are introduced.
- If a new visible path is added later, cover one happy-path journey and one warning-path journey.

Recommended test split:
- Unit tests: math, normalization, profile generation, and zero-default handling.
- Widget tests: ObjectBox admin browser and any affected maintenance UI copy.
- Robot tests: existing GPX import/reset/recalc journey coverage should continue to pass unchanged.
</validation>

<done_when>
- `GpxTrack` persists `descent`, `startElevation`, `endElevation`, and `elevationProfile` and regenerated ObjectBox files match the schema.
- Import, reset, and manual recalculation all populate the new fields from stored `gpxFile` XML.
- `elevationProfile` round-trips as a JSON string and uses local sample times.
- Tests cover the calculator, importer wiring, recalculation wiring, and admin inspection output.
</done_when>
