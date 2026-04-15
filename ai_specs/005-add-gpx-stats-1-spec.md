<goal>
Add deterministic GPX statistics to the existing `GpxTrack` entity and add a Settings action that rebuilds those statistics from the XML already stored in `gpxFile`.

This lets imported and reset tracks keep distance and elevation summaries in sync, and gives users a one-tap repair path for stale analytics without moving files.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `xml`, `latlong2`, and the existing GPX import/reset flow.

Relevant context:
- `GpxTrack` already stores raw GPX XML in `gpxFile` and is persisted with ObjectBox.
- `GpxImporter` already parses GPX metadata and track geometry during import/reset.
- `MapNotifier` owns track import, reset, status, and warning state.
- `SettingsScreen` already shows `Reset Track Data` and the shared track-operation status surface.
- The project already includes the needed dependencies; do not add new packages unless a blocker is found.

Files to examine:
- @lib/models/gpx_track.dart
- @lib/services/gpx_importer.dart
- @lib/services/gpx_track_repository.dart
- @lib/providers/map_provider.dart
- @lib/screens/settings_screen.dart
- @lib/objectbox-model.json
- @lib/objectbox.g.dart
- @test/gpx_track_test.dart
- @test/widget/gpx_tracks_summary_test.dart
- @test/widget/gpx_tracks_shell_test.dart
- @test/robot/gpx_tracks/gpx_tracks_journey_test.dart
- @ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md
</background>

<user_flows>
Primary flow:
1. User imports GPX tracks, rescans tracks, or runs Reset Track Data.
2. The app recalculates track statistics from the stored GPX XML before persisting each row.
3. The user opens Settings and taps Recalculate Track Statistics to refresh analytics for all persisted tracks in place.
4. The action uses the same modal shell pattern as Reset Track Data but shows a stats-specific result body, preserves the current `showTracks` state, and refreshes `MapState.tracks` from the repository when it completes.

Alternative flows:
- Existing tracks with stale analytics are repaired without changing file paths, track IDs, or track names.
- New imports and rebuilds use the same calculation path, so freshly imported rows and repaired rows produce the same stats.
- Tracks with missing elevation samples still persist usable defaults instead of failing the batch.

Error flows:
- One stored GPX row has malformed XML: skip that row, continue processing the rest, and surface a warning.
- A track operation is already running: ignore the repeat request and keep the operation single-flight.
</user_flows>

<requirements>
**Functional:**
1. Retrofit `GpxTrack` with `distanceToPeak` (`double`), `distanceFromPeak` (`double`), `lowestElevation` (`double`), and `highestElevation` (`double`) while keeping existing fields intact.
2. Keep `distance` as an existing persisted field and populate it from the GPX track geometry during import, reset, and manual recalculation.
3. Derive all statistics from the GPX XML stored in `GpxTrack.gpxFile`; manual recalculation must not read the filesystem or move files.
4. Add a `Recalculate Track Statistics` action to `SettingsScreen` directly below `Reset Track Data`.
5. Recalculate stats for every imported track row during any GPX import/rescan/reset operation, and for every existing persisted row when the Settings action is tapped.
6. Define track statistics over the parsed trackpoint order across all segments by summing geodesic distance between consecutive valid trackpoints within each segment and not bridging segment gaps.
7. When multiple points share the highest elevation, use the first occurrence as the peak reference so `distanceToPeak` and `distanceFromPeak` are deterministic.
8. Reuse the existing `trackOperationStatus` and `trackOperationWarning` pattern for success and non-fatal failures.
9. The `Recalculate Track Statistics` action must use `isLoadingTracks` as the single busy flag, disable repeat taps while an operation is running, preserve the current `showTracks` state, and refresh `MapState.tracks` from the repository after success.
10. The recalc flow must use a dedicated `TrackStatisticsRecalcResult` contract with `updatedCount`, `skippedCount`, and `warning` so the success dialog can describe stats recalculation without import-centric counters.
11. On success, the recalc dialog title must be `Track Statistics Recalculated`, and the body must summarize `Updated X tracks, skipped Y tracks`, appending the warning text below when `warning` is present.

**Error Handling:**
11. If a row's stored GPX XML cannot be parsed, skip that row's stats update, continue processing the remaining rows, and surface a warning rather than failing the whole batch.
12. If elevation data is missing or partially missing, persist zero defaults for all elevation-derived values instead of failing the track.
13. If a track operation is already running, ignore repeat presses of the new Settings action.
14. Preserve current reset/import behavior when a stats recalculation warning occurs; do not lose already-imported rows because one row failed.

**Edge Cases:**
15. Single-point tracks must produce zero distance and zero/default elevation stats.
16. Multi-segment tracks must keep their segment structure in the stored geometry and in any distance accumulation logic.
17. If all parseable elevation samples are absent, store zero defaults for `lowestElevation` and `highestElevation`.
18. Manual recalculation must update existing rows in place without changing `gpxTrackId`, `trackName`, or file organization.

**Validation:**
17. Add explicit numeric assertions for synthetic GPX samples so the stats math is verified with known values, not just null/non-null checks.
18. Validate that the new Settings action is wired to the same track-operation summary surface used by the existing reset flow.
19. Validate that batch recalculation continues past one malformed row and still updates the remaining rows.
</requirements>

<boundaries>
Edge cases:
- Existing rows with legacy or stale stats should be repaired by recalculation without requiring a full data wipe.
- The feature does not change route-vs-track classification, Tasmania organization, or track rendering behavior.
- The feature does not introduce new dashboard UI for stats display.

Error scenarios:
- Stored GPX XML is invalid: leave that row unchanged for stats, record the failure, and keep the batch moving.
- Missing or partial elevation data: zero the stats rather than inventing heuristics.
- Concurrent import/rescan/recalc requests: only one track operation may run at a time.

Limits:
- Use the existing macOS track-storage assumptions and current ObjectBox schema flow.
- Do not add new packages; the current XML and geodesic dependencies are sufficient.
- Keep stats logic shared between import/rescan/reset and manual recalculation so there is one source of truth.
</boundaries>

<implementation>
Create `./lib/services/gpx_track_statistics_calculator.dart` as the single pure helper for GPX track statistics so the math stays isolated from I/O and UI code.
Update `./lib/models/gpx_track.dart` and regenerate `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` for the new stats fields, storing zero defaults as concrete `double` values when no statistic can be derived.
Add a dedicated `TrackStatisticsRecalcResult` contract in the track service layer so the recalc dialog can report `updatedCount`, `skippedCount`, and `warning` without import-specific counters.
Use the calculator from `./lib/services/gpx_importer.dart` so import/rebuild and manual recalculation share one code path.
Update `./lib/providers/map_provider.dart` so the import/rescan/reset flow recalculates stats automatically, the Settings action can trigger a batch refresh of persisted rows, and the refreshed tracks are written back into `MapState` before the operation completes.
Add `Recalculate Track Statistics` to `./lib/screens/settings_screen.dart` using the same loading, disabled, and completion-dialog pattern as `Reset Track Data`, with a stable key for testing.
Keep `./lib/services/gpx_track_repository.dart` focused on persistence; add only the minimal query/update support needed for the recalculation pass.
Avoid duplicating GPX parsing or statistic math in the UI layer.
</implementation>

<stages>
Phase 1: Add a pure stats calculator and cover it with unit tests for distance, peak split, elevation extrema, single-point tracks, and malformed input handling.
Phase 2: Wire the calculator into the GPX import/rescan/reset path so new and rebuilt rows persist the computed values.
Phase 3: Add the Settings maintenance action and batch recalculation flow for existing rows, including success and warning state handling.
Phase 4: Update ObjectBox generation and journey tests, then verify the reset/import/recalculate paths still complete end-to-end.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for the stats calculator, including numeric expectations, peak tie-breaking, multi-segment accumulation, missing elevation defaults, and malformed XML handling.
- UI behavior: widget tests for the new Settings action, its disabled/loading behavior, and the status/warning surface after completion.
- Critical user journeys: robot-driven coverage for opening Settings, triggering recalculation, and observing the resulting summary or warning.

TDD expectations:
- Write one failing slice at a time: calculator happy path, elevation edge cases, parse-failure handling, persistence wiring, then Settings UI.
- Keep the calculator pure and injectable so tests do not depend on the filesystem or ObjectBox.
- Prefer fakes for repository and notifier seams; avoid mocking private XML parsing internals.

Robot-testing expectations:
- Use stable `Key` selectors for the new Settings tile and any completion controls.
- Keep the robot journey deterministic by faking the GPX repository/state rather than relying on real files.
- Cover at least one happy-path journey and one warning-path journey.

Recommended test split:
- Unit tests: math, parsing, extrema, zero defaults, and batch continuation behavior.
- Widget tests: Settings tile placement, disabled/loading states, and summary text rendering.
- Robot tests: the visible maintenance flow from Settings through completion.
</validation>

<done_when>
- `GpxTrack` persists the new GPX statistics fields and regenerated ObjectBox files match the schema.
- Every GPX import/rescan/reset path recalculates stats before persisting rows.
- `SettingsScreen` exposes `Recalculate Track Statistics` directly below `Reset Track Data`.
- Existing rows can be batch-recalculated from stored `gpxFile` XML without moving files.
- Tests cover the calculator, the Settings entry point, and the critical maintenance journey.
</done_when>
