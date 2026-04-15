<goal>
Refactor GPX statistics so all pairwise distance math comes from `./lib/services/geo.dart`.

This removes duplicate logic from the GPX stats path, keeps track metrics aligned with the shared geo helpers, and prevents future drift between GPX calculations and the rest of the app.
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, `latlong2`, `xml`, and the in-repo `geo.dart` helper.

Relevant context:
- `./lib/services/geo.dart` already exposes `Location.distance2d()` / `distance3d()` and the lower-level `distance()` helper.
- `./lib/services/gpx_track_statistics_calculator.dart` currently computes pairwise 2D/3D distance directly instead of delegating to `Location`.
- `./lib/services/gpx_importer.dart` and `./lib/providers/map_provider.dart` consume the calculator output and should not need behavior changes unless numeric results shift.
- The project already depends on `latlong2`; do not add new packages.

Files to examine:
- @lib/services/geo.dart
- @lib/services/gpx_track_statistics_calculator.dart
- @lib/services/gpx_importer.dart
- @lib/providers/map_provider.dart
- @lib/models/gpx_track.dart
- @test/gpx_track_test.dart
- @test/services/objectbox_admin_repository_test.dart
</background>

<discovery>
Before implementing, confirm:
- `GpxTrackStatisticsCalculator` is the only place in the app that still reimplements GPX track-point distance math.
- The `geo.dart` semantics are the canonical behavior for 2D and 3D distance, including haversine fallback for distant pairs and elevation fallback rules.
- No schema or persistence changes are needed; this should stay an internal behavioral refactor.
- Existing numeric GPX tests still express the desired behavior after the refactor, especially for peak split and elevation edge cases.
</discovery>

<requirements>
**Functional:**
1. Replace direct 2D/3D distance math in `GpxTrackStatisticsCalculator` with `Location.distance2d()` and `Location.distance3d()` from `./lib/services/geo.dart`.
2. Preserve the current `GpxTrackStatistics` public shape (`distance2d`, `distance3d`, `distanceToPeak`, `distanceFromPeak`, `lowestElevation`, `highestElevation`).
3. Keep current elevation and peak-selection rules unchanged while swapping only the distance implementation.
4. Match `geo.dart` semantics exactly for distance calculation, including haversine fallback for distant point pairs and elevation-based 3D behavior.
5. Do not introduce new packages, new distance helpers, or a parallel math implementation.

**Error Handling:**
6. Preserve existing handling for malformed GPX XML, missing trackpoints, and missing elevation samples.
7. If either point in a pair lacks elevation, 3D distance must fall back to the 2D result exactly as `geo.dart` does.
8. If elevations are identical, 3D distance must equal 2D distance.

**Edge Cases:**
9. Large coordinate deltas must use the existing `geo.dart` haversine path, not a custom approximation.
10. Existing negative-elevation handling rules must remain intact.
11. A partially missing elevation track should still compute `lowestElevation` and `highestElevation`, but keep `distanceToPeak` and `distanceFromPeak` at zero, matching current behavior.

**Validation:**
12. Add or adjust unit tests so the calculator proves the refactor against `geo.dart` semantics for near points, distant points, missing elevation, and equal elevation.
13. Keep assertions focused on behavior and numeric results, not implementation details.
14. Verify that the public GPX importer and consumer paths still pass with the refactored calculator and no schema changes.
</requirements>

<implementation>
Update `./lib/services/gpx_track_statistics_calculator.dart` to build `Location` instances from parsed GPX points and use `distance2d()` / `distance3d()` for pairwise accumulation.
Remove the calculator’s custom distance math once the shared `geo.dart` path is in place.
Keep `./lib/services/gpx_importer.dart` and `./lib/providers/map_provider.dart` behavior unchanged unless the refactor exposes a real numeric mismatch.
Do not change ObjectBox schema or `./lib/models/gpx_track.dart`; this is a distance-math refactor, not a persistence refactor.
Avoid re-encoding the `geo.dart` fallback rules inside the calculator; delegate to the shared helper instead.
</implementation>

<stages>
Phase 1: Replace calculator internals with `geo.dart`-backed distance calls and verify near-point behavior stays stable.
Phase 2: Add regression tests for distant-point haversine fallback and elevation-sensitive 3D distance behavior.
Phase 3: Sweep the codebase for any remaining custom GPX point-distance math and remove or reroute it to `geo.dart`.
Phase 4: Run the full test suite and analysis, fixing any numeric expectation drift caused by the shared helper.
</stages>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: unit tests for 2D distance, 3D distance, missing elevation fallback, equal-elevation fallback, and distant-point haversine behavior.
- UI behavior: no UI changes expected; keep existing UI tests green as regression coverage only.
- Critical user journeys: none; this is an internal refactor.

TDD expectations:
- Use one failing slice at a time: near-point parity first, then 3D/elevation rules, then distant-point fallback.
- Keep the calculator testable via public inputs only; prefer synthetic GPX XML fixtures over internal method testing.
- Do not mock `geo.dart`; treat it as the shared behavior under test.

Recommended test split:
- Unit tests: calculator numeric behavior and edge cases.
- Regression tests: existing importer and model round-trip coverage remain unchanged unless a refactor bug requires updates.

Verification commands:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- `GpxTrackStatisticsCalculator` uses `geo.dart` for all pairwise 2D/3D distance math.
- No custom duplicate GPX distance math remains in the codebase.
- Existing numeric behavior is preserved or intentionally updated in tests to match `geo.dart`.
- `flutter analyze` and `flutter test` pass.
</done_when>
