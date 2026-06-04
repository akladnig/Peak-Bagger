<goal>
Tighten GPX resting-time calculation so it counts only true stationary periods, not slow walking or GPS jitter, and better matches Gaia GPS stopped-time behavior on real bushwalking tracks.

This change keeps `pausedTime` as segment-gap time and leaves the rest of the GPX stats pipeline intact. The primary outcome is that imported, reset, and manually recalculated tracks produce more realistic `restingTime` values by rerunning the same processed-XML path the app already uses, without changing route/track rendering or storage shape.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `xml`, `latlong2`, and the existing GPX import/reset/recalc pipeline.

Relevant context:
- `lib/services/gpx_track_statistics_calculator.dart` currently derives `restingTime` from a low-speed clustered interval heuristic.
- `lib/services/gpx_importer.dart` and `lib/providers/map_provider.dart` both rely on the shared stats calculator.
- `GpxTrack` persists `movingTime`, `restingTime`, `pausedTime`, and `totalTimeMillis`.
- Existing tests already cover time stats, fallback behavior, and track-info display.
- The regression target is a track like `Bushwalking/Tracks/Tasmania/acropolis_(10-03-2025).gpx`, where the current detector overcounts rest compared with Gaia GPS.

Files to examine:
- @lib/services/gpx_track_statistics_calculator.dart
- @lib/services/gpx_importer.dart
- @lib/providers/map_provider.dart
- @lib/models/gpx_track.dart
- @test/gpx_track_test.dart
- @test/services/gpx_importer_filter_test.dart
- @test/widget/map_screen_track_info_test.dart
</background>

<user_flows>
Primary flow:
1. User imports or rescans a GPX track.
2. The app computes time stats from the processed GPX XML selected by the existing pipeline, falling back to raw GPX data when filtered output cannot be produced.
3. `restingTime` reflects only sustained stationary periods, while `pausedTime` still reflects segment gaps.
4. Track details and admin inspection show the updated values.

Alternative flows:
- Existing persisted tracks are recalculated from stored raw/repaired GPX XML through the same processing pipeline without reopening the source file.
- Tracks with sparse timestamps still produce deterministic zero/default time stats when no usable window exists.

Error flows:
- If filtered XML is invalid, empty, or unparsable during processing, fall back to raw GPX time stats.
- If no parseable timestamps exist, time stats remain zero/default rather than inventing rest time.
</user_flows>

<requirements>
**Functional:**
1. Replace the current rest detector with a stationary-window detector that only counts near-zero displacement over a sustained time window.
2. Keep `pausedTime` semantics unchanged: it remains the sum of positive gaps between adjacent `<trkseg>` elements in the chosen source XML.
3. Keep `movingTime = totalTimeMillis - restingTime` and preserve UTC normalization and whole-second duration math.
4. Make the stationary detector deterministic and testable via pure functions/constants in `gpx_track_statistics_calculator.dart`.

**Stationary rule:**
5. A candidate rest cluster must satisfy all of the following for at least 60 seconds of consecutive parseable points:
   - net displacement from first to last point is `<= 5 m`
   - max radius from the cluster centroid is `<= 10 m`
   - cumulative path length inside the cluster is `<= 15 m`
   - every interval speed inside the cluster is `<= 0.2 m/s`
6. Use hysteresis to avoid flapping: once a cluster is active, allow it to continue while it stays within the looser exit thresholds of net displacement `<= 8 m`, max radius `<= 12 m`, cumulative path length `<= 20 m`, and interval speed `<= 0.3 m/s`, and only close it after two consecutive parseable intervals exceed any exit threshold.
7. Do not count slow walking as rest just because it is under the old per-interval speed threshold.
8. Do not infer rest from segment gaps, pauses, or missing timestamps.

**Error Handling:**
9. If filtered XML is invalid, empty, or unparsable, fall back to raw GPX time stats without breaking import/recalc.
10. If the track has no parseable time samples, persist zero/default time stats.

**Edge Cases:**
11. Ignore unparseable timestamps and non-positive `dt` intervals when building clusters.
12. Trackpoints with noisy GPS jitter should only contribute to rest if the full cluster still satisfies the stationary-window rule.
13. Existing track rows should be repairable by recalculation without a full data wipe.

**Validation:**
14. Add synthetic unit coverage for stationary clusters, non-stationary slow movement, jitter inside a true stop, and hysteresis boundary behavior.
15. Add regression tests using checked-in fixtures under `./test/fixtures/`:
   - `acropolis_(10-03-2025).gpx` should assert `pausedTime` is `29m` and `restingTime` is the remaining stopped-time target for that track.
   - `mt-wellington-loop_(04-03-2025).gpx` should assert a stopped time of `38m20s`.
16. Preserve existing assertions for UTC normalization, raw fallback, zero defaults, and pause-gap handling in `test/services/gpx_importer_filter_test.dart`, `test/widget/map_screen_track_info_test.dart`, `test/services/objectbox_admin_repository_test.dart`, and `test/widget/objectbox_admin_browser_test.dart` as needed.
</requirements>

<boundaries>
Edge cases:
- Sparse but legitimate stationary samples: count them only if the cluster still satisfies the minimum duration and displacement constraints.
- Repeated borderline samples: use hysteresis to prevent oscillating rest/move classification.
- Missing timestamps: skip the point, keep the rest of the cluster logic deterministic.

Error scenarios:
- Malformed filtered XML: fall back to raw GPX stats and continue.
- No parseable timestamps: store zero/default time stats.

Limits:
- Do not add new packages.
- Do not change route-vs-track classification, track rendering, or ObjectBox schema shape for this fix.
- Keep time math centralized in the shared calculator so import, reset, and manual recalc stay aligned.
</boundaries>

<implementation>
Update `./lib/services/gpx_track_statistics_calculator.dart` to compute `restingTime` from stationary windows instead of the current low-speed cluster heuristic.

Keep the detector pure and local to the calculator; prefer small helper methods or constants over spreading logic into importer or UI code.

Update `./test/gpx_track_test.dart` with behavior-first coverage for the new detector, then refresh downstream expectations in `./test/services/gpx_importer_filter_test.dart`, `./test/widget/map_screen_track_info_test.dart`, `./test/services/objectbox_admin_repository_test.dart`, and `./test/widget/objectbox_admin_browser_test.dart` that depend on `restingTime`.

If the regression samples are not already checked in, add fixtures under `./test/fixtures/` rather than hard-coding a one-off assertion in the production code.

Avoid changing `pausedTime` computation unless a test proves it is wrong.
</implementation>

<stages>
Phase 1: Add pure unit tests for the new stationary-window rule and hysteresis behavior, then implement the detector until those tests pass.
Phase 2: Add the Acropolis and Mt Wellington Loop regression cases and verify the new `restingTime` aligns with the expected stopped-time behavior.
Phase 3: Run through importer/recalc coverage to confirm filtered XML fallback, paused-time handling, and track-info display still match existing behavior.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for stationary-window detection, threshold/hysteresis handling, zero defaults, raw fallback, UTC normalization, and malformed filtered XML handling.
- Persistence wiring: importer and manual recalculation tests prove the shared calculator output is written back from the processed XML path or raw fallback.
- UI behavior: track info rendering still formats the recalculated time fields correctly.

TDD expectations:
- Write one failing slice at a time: stationary detection, hysteresis, regression sample, then wiring.
- Keep the calculator pure and injectable enough that tests do not need filesystem access.
- Prefer synthetic GPX fixtures and fakes over mocking XML internals.

Robot-testing expectations:
- No new robot journey is required unless the visible track-info copy changes.
- If the Acropolis regression is exposed through an existing journey, keep the current robot coverage green and update only the numeric expectation.
</validation>

<done_when>
- `restingTime` is based on sustained near-stationary windows instead of the old slow-speed per-interval heuristic.
- The regression samples no longer report inflated stationary time, with the Acropolis fixture matching its `29m` paused-time expectation and the Mt Wellington Loop fixture matching `38m20s` stopped time.
- `pausedTime` remains segment-gap time.
- Import, reset, and manual recalculation all continue to share the same time-stat calculation path.
- Tests cover the detector, hysteresis, regression case, and fallback behavior.
</done_when>
