<goal>
Add persisted peak-to-track correlation so every imported or rebuilt GPX track stores the peaks that fall within a user-configurable distance threshold, with explicit processed/unprocessed state. This lets hikers and route planners ask "which peaks are near this track?" without recomputing the answer every time the track is read.
This is storage-only: no peak-correlation display surface is in scope.
</goal>

<background>
Flutter app with ObjectBox, Riverpod, SharedPreferences, and existing GPX import/reset/recalculate flows. `GpxTrack` already stores GPX XML, display cache, and track statistics; `Peak` already exists and has persisted MGRS fields. `lib/services/geo.dart` provides finite-segment distance helpers for peak correlation, which must be segment-based rather than line-extension-based. Current track maintenance entry points live in `./lib/providers/map_provider.dart` (`_importTracks()`, `resetTrackData()`, `recalculateTrackStatistics()`), and Settings already uses Riverpod-backed settings providers plus dropdown controls in `./lib/screens/settings_screen.dart`.
Peak refresh must preserve logical identity via a persisted upstream `osmId` on `Peak`.

Files to examine:
`./lib/models/gpx_track.dart`
`./lib/models/peak.dart`
`./lib/providers/map_provider.dart`
`./lib/providers/gpx_filter_settings_provider.dart`
`./lib/screens/settings_screen.dart`
`./lib/services/geo.dart`
`./lib/services/gpx_importer.dart`
`./lib/services/peak_refresh_service.dart`
`./lib/services/peak_repository.dart`
`./test/...`
</background>

<discovery>
Before implementation, confirm the ObjectBox schema changes needed for a `GpxTrack` -> `Peak` relation and how `objectbox.g.dart` is regenerated in this repo. Verify whether `GpxTrack.fromMap()` / `toMap()` need to carry the new processed flag, and inspect the existing peak refresh path so peak ids stay stable for unchanged peaks.
Confirm the `Peak.osmId` migration path: the first migration may delete and reinsert peak rows, but future refreshes must upsert by `osmId`.
</discovery>

<user_flows>
Primary flow:
1. User imports or refreshes tracks.
2. App parses each track, computes nearby candidate peaks from the raw GPX geometry, and persists the matched peaks on the track.
3. App marks the track as peak-correlation-processed even when no peaks are found.
4. User can later open the track normally without any extra recomputation on read.

Alternative flows:
- First-time app launch with legacy stored tracks: old tracks remain unprocessed until the user runs Reset Track Data or Recalculate Track Statistics.
- User changes the peak-distance threshold in Settings: the new value applies to future imports/rebuilds and to any later maintenance rerun.
- User runs Reset Track Data or Recalculate Track Statistics: the same peak-correlation path is rerun for each track in that batch, so recalculation refreshes both stored track statistics and stored peak-correlation state.
- Peak refresh occurs: preserve peak ids for unchanged peaks so existing track-to-peak links remain valid and do not need an automatic track rebuild.

Error flows:
- A malformed track file or invalid track geometry: skip that track, keep the batch moving if other tracks can still be processed, and surface the existing import/recalc error path.
- Peak correlation fails for a track because of bad coordinates or a storage error: do not write a partial track update; leave the previously stored track data unchanged.
- User cancels any confirmation dialog: no data changes.
</user_flows>

<requirements>
**Functional:**
1. Add a persistent track-side peak correlation model to `GpxTrack` with a relation named `peaks` that points to `Peak`, plus an explicit `peakCorrelationProcessed` flag. `peaks.isEmpty` must mean "processed but no matches" only when `peakCorrelationProcessed == true`.
2. Add a persisted upstream identity field `osmId` to `Peak`, parse the Overpass node id into it, and refresh peaks by upserting on `osmId` rather than treating rows as anonymous records.
3. Correlate peaks from the stored raw GPX XML, not from rendered display caches or simplified geometry. Scan each `<trkpt>` to compute the track bounding box, expand that box by the selected threshold value, use it to collect candidate peaks, and only then evaluate those candidates with `distanceFromLine()`.
4. For every candidate peak, compute the minimum distance from the peak to any adjacent track segment using a finite-segment distance helper. A peak is a match when that minimum distance is less than or equal to the configured threshold.
5. Correlate tracks during every create/refresh path that writes `GpxTrack` rows, including import, Reset Track Data, Recalculate Track Statistics, and any equivalent track refresh path already routed through `MapNotifier`. Recalculate Track Statistics must not be statistics-only; it must also refresh `peaks` and `peakCorrelationProcessed` using the current threshold.
6. Add a dedicated, persisted correlation-threshold setting in `./lib/providers/peak_correlation_settings_provider.dart` or an equivalent provider. Expose it in `./lib/screens/settings_screen.dart` with a stable key and a dropdown of fixed meter values from `10m` to `100m` in `10m` increments. Default to `50m`.
7. Preserve peak ids across peak refresh so existing track-to-peak links remain valid. Do not clear and repopulate the peak store in a way that changes ids for logically unchanged peaks, except during the first `osmId` migration where rows may be rebuilt.
8. Keep correlation writes atomic at the track level. When a track is saved, its processed flag and relation contents must be updated together.

**Error Handling:**
9. If a track cannot be parsed or correlated, fail that track update and keep the previously stored dataset unchanged.
10. If one candidate peak is malformed, skip that peak for the current track and continue evaluating the rest of the candidates.
11. If no peaks match, store an empty relation and set `peakCorrelationProcessed = true`; do not treat that as an error.

**Edge Cases:**
12. Single-point tracks and zero-length segments must use the existing point-to-point fallback behavior in `distanceFromLine()`.
13. De-duplicate correlated peaks before persistence so a peak matched by multiple segments is stored once.
14. A peak exactly on the threshold boundary counts as a match.
15. Changing the threshold does not retroactively rebuild old tracks; users must rerun a maintenance flow to refresh stored correlations.

**Validation:**
16. Add stable selectors for the new correlation settings section and threshold control so widget and robot tests do not rely on localized text.
17. Require a `GpxTrack.fromMap()` / `toMap()` round-trip test for `peakCorrelationProcessed`.
</requirements>

<boundaries>
Edge cases:
- Legacy unprocessed tracks: empty relation plus `peakCorrelationProcessed == false` means the track has not yet been rebuilt.
- Tracks with no nearby peaks: empty relation plus `peakCorrelationProcessed == true` is a valid processed state.
- Peak refresh: keep existing links valid by preserving peak ids for unchanged peaks; do not automatically rebuild track correlations as part of peak refresh.
- No new peak-search, filter, or map-overlay feature is in scope for this task.

Error scenarios:
- Correlation math fails for one track: do not partially persist that track.
- ObjectBox write failure: fail the batch item and leave existing track data intact.
- Missing or corrupt threshold setting: fall back to the default threshold value.

Limits:
- Keep the threshold as a non-negative integer in meters.
- Keep candidate filtering conservative so the threshold-based bounding-box prefilter does not drop a peak that could still be inside the threshold.
</boundaries>

<implementation>
1. Update `./lib/models/gpx_track.dart` to add the `peaks` relation and `peakCorrelationProcessed` field, and keep any `toMap()` / `fromMap()` helpers backward compatible for the new processed flag.
2. Update `./lib/models/peak.dart` and `./lib/services/overpass_service.dart` to persist `osmId` and parse the Overpass node id.
3. Add `./lib/services/track_peak_correlation_service.dart` (or equivalent) to encapsulate bounds extraction, peak candidate filtering, and minimum-segment-distance matching.
4. Add `./lib/providers/peak_correlation_settings_provider.dart` (or equivalent) using the same Riverpod + SharedPreferences pattern as the GPX filter settings provider.
5. Update `./lib/screens/settings_screen.dart` with a dedicated peak-correlation section, stable keys, and a current-value subtitle.
6. Refactor `./lib/providers/map_provider.dart` so the import/reset/recalculate paths call the shared correlation service before persisting tracks.
7. Update `./lib/services/peak_refresh_service.dart` and `./lib/services/peak_repository.dart` so peak refresh preserves ids for logically unchanged peaks.
8. Regenerate `./lib/objectbox.g.dart` and any related ObjectBox artifacts after the schema change.
9. Add tests under `./test/services/` for the correlation math, `./test/widget/` for the settings control, and `./test/robot/gpx_tracks/` for the critical maintenance journey.
10. Prefer a shared GPX point/segment extraction helper if that avoids duplicating XML parsing between statistics and correlation code.
11. Keep all matching logic in the data/domain layer; do not compute correlation in widget code.
</implementation>

<stages>
Phase 1: Add the correlation service and track schema fields, then verify the core matching rules with unit tests for threshold boundary, de-duplication, no-match, and single-point fallback.

Phase 2: Wire the service into import/reset/recalculate paths and peak refresh id preservation, then verify repository and provider tests for atomic persistence and stable correlations.

Phase 3: Add the Settings threshold control and finish widget/robot coverage for the maintenance journey, then verify stable selectors, persisted settings, and unchanged error handling.
</stages>

<validation>
1. TDD slice order: correlation math tests first, then persistence/schema tests, then provider integration tests, then widget and robot tests. Keep each red-green-refactor cycle small and behavior-first.
2. Use fakes or injected test data for the peak source and threshold setting; do not mock private helpers or internal geometry functions.
3. Unit tests must verify:
   - a peak inside the threshold is matched
   - a peak exactly on the threshold boundary is matched
   - a peak outside the threshold is not matched
   - duplicate matches from multiple segments are stored once
   - single-point and zero-length track geometry still resolves via the fallback path
   - no-match tracks are marked processed with an empty relation
4. Repository and provider tests must verify:
   - track correlation is written atomically with the processed flag
   - failed correlation leaves the existing track untouched
   - Reset Track Data and Recalculate Track Statistics both rebuild the stored correlation state, including `peaks` and `peakCorrelationProcessed`
   - peak refresh preserves ids for unchanged peaks so existing track links remain valid
5. Widget tests must verify:
   - the new correlation settings section renders with stable keys
   - changing the threshold persists the new value
   - the settings screen still shows the existing track maintenance dialogs and close buttons with stable selectors
6. Robot coverage must verify the critical maintenance journey end to end using stable selectors:
   - `Key('peak-correlation-settings-section')`
   - `Key('peak-correlation-distance-meters')`
   - `Key('reset-track-data-tile')`
   - `Key('reset-track-data-confirm')`
   - `Key('recalculate-track-statistics-tile')`
   - `Key('track-stats-recalc-result-close')`
7. Baseline coverage outcome:
   - logic and business rules: unit tests
   - UI behavior: widget tests
   - critical user journey: robot test
</validation>

<done_when>
1. Imported or rebuilt tracks persist the correct nearby peaks and a processed flag.
2. Processed-but-empty tracks are distinguishable from unprocessed legacy tracks.
3. Changing the threshold updates future correlations and is persisted in Settings.
4. Peak refresh does not break existing track links for unchanged peaks.
5. Automated tests cover the matching logic, persistence, settings UI, and the maintenance journey.
</done_when>
