<goal>
Replace Tasmap sheet resolution that currently relies on crude `eastingMin/eastingMax` and `northingMin/northingMax` rectangle checks with polygon containment based on each sheet's stored polygon vertices.

This matters because the app already stores real sheet outlines in `Tasmap50k.p1..p12`, but point-to-map lookups still use rectangular approximations that can assign the wrong map near irregular edges, corners, and shared boundaries. The result should be that every current point-to-map lookup resolves the sheet from the actual polygon while preserving current user-facing fallbacks such as `Unknown` and `Outside Tasmania 50k coverage` when no sheet matches.
</goal>

<background>
The app is a Flutter/Riverpod/ObjectBox codebase.

Relevant existing behavior:
- `./lib/services/tasmap_repository.dart` exposes `findByMgrsCodeAndCoordinates()` and currently decides the map from `findByMgrs100kId()` plus `_inRange()` rectangle checks.
- `./lib/models/tasmap50k.dart` already stores polygon vertices in `p1..p12` and exposes them through `polygonPoints`.
- `./lib/services/polygon_geometry.dart` now exists as the completed pure polygon utility and exposes `polygonContainsPoint(LatLng point, List<LatLng> vertices)` for boundary-inclusive containment checks.
- `./lib/providers/map_provider.dart` currently stores `currentMgrs`, `cursorMgrs`, and `infoMgrs` strings but does not retain a live cursor `LatLng` in `MapState`, so direct-point readout adoption requires an explicit state seam.
- `./lib/screens/map_screen.dart` currently resolves the readout text and map name from `cursorMgrs ?? gotoMgrs ?? _liveCamera?.mgrs ?? currentMgrs`, so the direct-point readout migration must define a point-based equivalent for the same precedence.
- `./lib/services/peak_info_content_resolver.dart`, `./lib/widgets/peak_list_peak_dialog.dart`, `./lib/screens/map_screen.dart`, and `./lib/providers/map_provider.dart` all rely on the repository lookup path for user-visible map names.
- `./test/harness/test_tasmap_repository.dart` currently mirrors the same rectangle-based lookup behavior and will need to stay aligned with production behavior.

Relevant files to examine:
- `./lib/services/tasmap_repository.dart`
- `./lib/models/tasmap50k.dart`
- `./lib/services/polygon_geometry.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/services/peak_info_content_resolver.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./test/harness/test_tasmap_repository.dart`
- `./test/services/peak_info_content_resolver_test.dart`
- `./test/widget/map_screen_persistence_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/map_screen_peak_search_test.dart`
- `./test/widget/peak_list_peak_dialog_test.dart`

Dependency status:
- The reusable boundary-inclusive polygon containment helper from `./ai_specs/general/point-in-polygon-spec.md` and `./ai_specs/general/point-in-polygon-plan.md` is complete and available in `./lib/services/polygon_geometry.dart`.
- This Tasmap work must reuse the existing `polygonContainsPoint(LatLng point, List<LatLng> vertices)` helper rather than re-implementing containment logic inside `TasmapRepository`.
- The `.poly` parsing work from the general polygon utility is already complete and is not part of this Tasmap spec except as background context for the shared geometry module.
</background>

<user_flows>
Primary flow:
1. A user triggers any existing point-to-map lookup, such as the map info popup, the cursor MGRS readout, the peak search result subtitle, the peak info popup, or the peak dialog map link.
2. The app converts the source input to a geographic point when needed.
3. The repository resolves the containing sheet from the Tasmap polygon data rather than from the old rectangle approximation.
4. The UI shows the correct map name for that point.

Alternative flows:
- MGRS-based lookup: when the caller has an MGRS string, the app converts it to `LatLng`, narrows candidate sheets cheaply, then uses polygon containment for the final decision.
- Lat/lng-based lookup: when the caller already has a `LatLng` point, the app must use the repository point-lookup seam directly rather than converting the point to MGRS first.
- Boundary point: if the point lies exactly on a polygon edge or vertex, it still counts as inside and resolves to one deterministic sheet.

Error flows:
- Point outside all Tasmap polygons: preserve current user-facing fallback text such as `Unknown` or `Outside Tasmania 50k coverage`, depending on the caller.
- Invalid MGRS input or failed point conversion: return no match without throwing and preserve existing safe fallbacks.
- Missing or unusable polygon geometry for a candidate sheet: treat that sheet as a non-match rather than silently accepting the old rectangle result.
</user_flows>

<discovery>
Before implementation:
- Confirm the Tasmap lookup wiring reuses the existing `polygonContainsPoint(...)` helper from `./lib/services/polygon_geometry.dart` without changing its boundary-inclusive semantics.
- Identify the hot lookup paths, especially cursor/readout updates, so the implementation avoids repeated polygon conversion and avoids unnecessary `LatLng -> MGRS -> LatLng` round-tripping on every pointer move.
- Define the state seam and precedence mapping for live cursor/readout adoption before implementation begins. The default approach for this spec is to add `LatLng? cursorPoint` to `MapState` while keeping `cursorMgrs` as display-only text.
- Define the direct-point equivalent of the current readout precedence: `cursorPoint` for the cursor branch, `gotoMgrs` remaining MGRS-based unless a separate `gotoPoint` seam is added, `_liveCamera.center` for the live-camera branch, and `state.center` for the current-center branch.
- Confirm whether any existing tests already depend on the rectangle false-positive behavior; convert those to polygon-correct expectations rather than preserving the bug.
</discovery>

<requirements>
**Functional:**
1. Add one repository-owned public seam for sheet resolution by geographic point, for example `findByPoint(LatLng point)`, and make it the single source of truth for Tasmap point-to-sheet lookup.
2. Update `findByMgrsCodeAndCoordinates(String mgrsString)` to convert the MGRS input to `LatLng` and delegate the final match decision to the new point-based lookup seam.
3. Keep `mgrs100kIds` and the existing easting/northing range fields only as a cheap candidate prefilter when they are available; they must no longer decide the final winning sheet on their own.
4. Use `polygonContainsPoint(LatLng point, List<LatLng> vertices)` from `./lib/services/polygon_geometry.dart` against the stored Tasmap polygon vertices for the final match decision.
5. Route all existing production callers that resolve a sheet from a point or MGRS-derived point through the unified repository seam.
6. Flows that already own a `LatLng` source point must resolve the sheet from `findByPoint(LatLng)` directly rather than converting to MGRS first. This includes the info-popup/current-center path and the live cursor/readout path.
7. For live cursor/readout flows, add `LatLng? cursorPoint` to `MapState` as the display-independent source point for map-name lookup. Keep `cursorMgrs` as display text only.
8. The readout map-name precedence must continue to mirror the displayed readout precedence. Use `cursorPoint` for the cursor branch, `_liveCamera.center` for the live-camera branch, and `state.center` for the current-center branch. The `gotoMgrs` branch may remain MGRS-based unless this work explicitly adds a separate `gotoPoint` seam.
9. Clearing or replacing cursor-derived readout state must keep `cursorPoint` and `cursorMgrs` synchronized. Any path that clears `cursorMgrs` must also clear `cursorPoint`, and any notifier method that updates cursor-derived readout state must define both values together.
10. Existing MGRS-only callers may continue to use `findByMgrsCodeAndCoordinates()`, but that method must remain a conversion/delegation wrapper around the point-based seam rather than a separate rectangle-based decision path.
11. `MapNotifier.mapNameForMgrs()` remains available for MGRS-only and compatibility use after readout migration.
12. Live readout callers must migrate off `mapNameForMgrs()` to a direct-point helper or equivalent direct `findByPoint(LatLng)` path.
13. Info-popup/current-center lookup must migrate from MGRS-derived repository lookup to direct point lookup from `state.center`; it does not need to keep or reuse `mapNameForMgrs()`.
14. Peak-related callers that already have `latitude`/`longitude` available must use direct point lookup rather than MGRS delegation.
15. Current callers affected by this work include:
- `MapNotifier.mapNameForMgrs()` as an MGRS-only helper after readout migration
- `MapNotifier._findMapByMgrsWithCoordinates()` and the info-popup path
- `PeakInfoContentResolver._resolvePeakMapName()`
- `PeakListPeakDialog._resolveMap()`
- `MapScreen._mapNameForPeak()`
16. Treat points exactly on a polygon edge or vertex as inside the sheet.
17. If more than one polygon contains the same point, sort matching maps by `name` case-insensitively, then by `series`, then by `id`, and return the first result. Tests must assert this behavior. Do not depend on incidental ObjectBox iteration order.
18. Keep current user-facing copy and null-safe behavior intact: the feature changes how a map is resolved, not how each screen formats its fallback text.
19. Cache or otherwise reuse derived polygon geometry so repeated lookups do not re-parse the same `p1..p12` values into `LatLng` on every hot-path lookup.
20. Any cached derived polygon geometry must remain internal to the repository, build lazily on first use, and be invalidated whenever the underlying Tasmap set changes.
21. The cache invalidation rules must cover `addMaps()`, `loadFromCsvIfEmpty()`, `clearAndReloadFromCsv()`, and `clearAll()` in production code and equivalent mutations in the test harness repository.
22. Ensure the production repository and the test harness repository use the same lookup semantics and the same cache invalidation rules so tests cannot pass with stale rectangle-only behavior.

**Error Handling:**
23. Invalid or incomplete MGRS input must still return `null` rather than throwing.
24. A Tasmap row with fewer than 3 usable polygon vertices must not match any point.
25. If candidate narrowing succeeds but polygon containment finds no match, the lookup must return `null` instead of falling back to the old rectangle result.

**Edge Cases:**
26. Preserve wrap-around range handling in the prefilter for sheets whose old rectangle metadata crosses a 100k boundary; this remains a candidate filter only.
27. A point that is inside a rectangle but outside the real polygon must no longer resolve to that map.
28. Duplicate closing vertices or open polygon rings must behave correctly through the existing normalization behavior already implemented in `polygonContainsPoint(...)`.
29. The lookup must remain deterministic for shared borders where adjacent sheets both include the boundary point, using the explicit `name` -> `series` -> `id` rule above.

**Validation:**
30. Drive the repository lookup change with TDD-first unit slices: one inside match, one outside match, one rectangle false-positive regression, one boundary-inclusive match, then the MGRS delegation path.
31. Add focused widget regressions for one live map surface and one peak-related surface so the change is proven through real UI consumption paths, not only repository tests.
32. At least one UI regression must use a fixed polygon fixture and a literal expected sheet name such as `Resolved Map` or `Unknown`; it must not compute the expected value by calling the same repository lookup under test.
33. Keep the test seams deterministic with fake Tasmap data and the existing test repositories; do not depend on live ObjectBox data, network calls, or device location.
34. Create dedicated repository behavior coverage in a new service-level file such as `./test/services/tasmap_repository_lookup_test.dart` rather than overloading the current entity-focused `./test/tasmap_repository_test.dart`.
35. If Tasmap boundary or shared-border tests expose a gap in `polygonContainsPoint(...)`, expand `./test/services/polygon_geometry_test.dart` with the failing edge/shared-border case before completing Tasmap adoption. Do not fork a second boundary rule in `TasmapRepository`.
</requirements>

<boundaries>
Edge cases:
- Boundary points are inside.
- Shared boundaries may produce more than one polygon hit; resolve them using the explicit `name` -> `series` -> `id` tie-break.
- Polygon data with too few valid vertices is ignored for containment.
- The implementation may use rectangle/range metadata to reduce candidate count, but never to override polygon containment.

Error scenarios:
- Invalid MGRS string: return `null` and let the caller preserve existing fallback UI.
- Polygon conversion failure for a candidate map: skip that candidate and continue safely.
- No polygon contains the point: return `null` even if the old rectangle metadata would have matched.

Limits:
- Do not change the Tasmap CSV schema or ObjectBox entity shape for this task.
- Do not add a third-party geometry package.
- Do not change map rendering, map labels, or selected-map zoom behavior.
- Do not preserve the old rectangle result as a fallback for ambiguous or missing polygon matches.
- Do not move repository lookup behavior into the existing entity-focused `./test/tasmap_repository_test.dart` unless a later cleanup explicitly consolidates test layout.
</boundaries>

<implementation>
Modify these files:
- `./lib/services/tasmap_repository.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/services/peak_info_content_resolver.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./test/harness/test_tasmap_repository.dart`

Create this file:
- `./test/services/tasmap_repository_lookup_test.dart`

Modify these files:
- `./test/services/peak_info_content_resolver_test.dart`
- `./test/widget/map_screen_persistence_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/map_screen_peak_search_test.dart`
- `./test/widget/peak_list_peak_dialog_test.dart`

Recommended approach:
- Centralize the new logic in `TasmapRepository` rather than letting each caller perform its own candidate filtering or polygon checks.
- Reuse `polygonContainsPoint(...)` from `./lib/services/polygon_geometry.dart` so boundary semantics stay identical everywhere.
- Introduce a small internal cached geometry structure storing a sheet plus its derived `LatLng` polygon and any precomputed candidate metadata needed for cheap lookups.
- Keep the public API minimal. Prefer one new repository method plus delegation from existing methods over adding multiple overlapping lookup APIs.
- For live map surfaces that already have a `LatLng`, add or use a direct point-based helper rather than round-tripping through MGRS text.
- For cursor/readout adoption, store `cursorPoint` in `MapState` and treat `cursorMgrs` as display text only.
- Keep the map-name precedence aligned with the displayed readout precedence across cursor, goto, live-camera, and current-center branches.
- Define and implement `cursorPoint` clear/update rules alongside the existing `cursorMgrs` update paths.
- Keep `MapNotifier.mapNameForMgrs()` as an MGRS-only helper after readout migration; do not let live readout callers continue using it.

What to avoid:
- Do not duplicate polygon containment logic in `TasmapRepository`, `MapNotifier`, `MapScreen`, or widget code.
- Do not leave the test harness repository rectangle-based while production becomes polygon-based.
- Do not rely on `getAllMaps()` insertion order as the only tie-break rule.
- Do not repeatedly convert the same polygon point strings to `LatLng` inside hot UI loops.
- Do not leave peak-related callers on MGRS delegation when they already have direct coordinates available.
</implementation>

<stages>
Phase 1: Repository seam and lookup semantics
- Add the point-based repository lookup seam.
- Make MGRS lookup delegate to it.
- Define and test the explicit `name` -> `series` -> `id` tie-break.
- Verify unit tests cover inside, outside, boundary, and rectangle false-positive cases.
- Create repository behavior coverage in `./test/services/tasmap_repository_lookup_test.dart`.

Phase 2: Caller migration
- Switch all existing point-to-map callers to rely on the unified repository behavior.
- Update live point-owned surfaces to use direct `LatLng` lookup instead of MGRS round-tripping.
- Preserve the current readout precedence while replacing the cursor/live-camera/current-center map-name branches with direct-point resolution.
- Update peak callers with existing coordinates to use direct point lookup.
- Verify user-visible map-name surfaces still show their existing fallback text and now resolve the polygon-correct sheet.

Phase 3: Hot-path hardening
- Add or confirm geometry caching for repeated lookups.
- Verify cache invalidation on Tasmap data mutations.
- If shared-border failures appear, add the failing boundary case to `./test/services/polygon_geometry_test.dart` first and then complete Tasmap wiring.
- Verify cursor/readout and info-popup tests still pass without introducing obvious lookup churn or flaky timing.
</stages>

<illustrations>
Desired:
- A peak whose MGRS rectangle would have matched sheet A but whose actual coordinates fall outside sheet A's polygon now resolves to `Unknown` or the correct neighboring sheet.
- The map info popup at the current center shows the sheet that truly contains the point.
- The peak dialog map link opens the polygon-correct sheet for the selected peak.

Avoid:
- Returning a map purely because the point falls within `eastingMin/eastingMax` and `northingMin/northingMax`.
- Recomputing polygon `LatLng` vertices from `p1..p12` every time the cursor moves.
- Converting a live `LatLng` to MGRS text and back to `LatLng` when the source point is already available.
- Producing different results for the same boundary point depending on which caller asked for the map name.
</illustrations>

<validation>
Follow vertical-slice TDD:
- Start with the smallest failing repository test for a point clearly inside one polygon.
- Add one failing test for a point inside the rectangle metadata but outside the polygon.
- Add one boundary-inclusive test.
- Add one failing test proving `findByMgrsCodeAndCoordinates()` delegates through the polygon-backed path.
- Refactor only after each slice is green.

Required automated coverage:
- Logic/business rules: polygon-backed repository lookup, MGRS delegation, boundary inclusion, rectangle false-positive rejection, deterministic tie-breaking, and cache invalidation behavior.
- UI behavior: at least one live map surface and one peak-related surface display the polygon-correct map name through existing production flows.
- The minimum required UI regressions are one map-screen readout or info-popup test and one peak-related test such as peak search or peak dialog.
- Repository behavior coverage must be created in `./test/services/tasmap_repository_lookup_test.dart` or equivalent dedicated service-level test file.
- Suggested concrete updates: `./test/widget/map_screen_persistence_test.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/widget/map_screen_peak_search_test.dart`, and `./test/widget/peak_list_peak_dialog_test.dart`.
- Any map-screen regression included for this feature must use a fixed fixture and a literal expected name rather than deriving the expected result from `findByMgrsCodeAndCoordinates()`.
- Robot coverage: no new dedicated robot journey is required if widget coverage proves the affected surfaces and the change remains repository-driven rather than introducing a new cross-screen interaction path. If an existing robot already exercises one of these surfaces cheaply, extending it is acceptable but optional.
- If repository/shared-border tests show a boundary mismatch in `polygonContainsPoint(...)`, expand `./test/services/polygon_geometry_test.dart` first before accepting any Tasmap-specific workaround.

Testability seams:
- A public repository method that resolves a map from `LatLng`.
- The existing `polygonContainsPoint(...)` helper as the single containment seam shared by production and test repositories.
- `MapState.cursorPoint` as the source-of-truth seam for live cursor/readout point lookup while `cursorMgrs` remains display-only.
- The readout precedence contract mapping cursor, goto, live-camera, and current-center sources to their direct-point or MGRS-backed lookup path.
- Reusable fake Tasmap fixtures with polygons that intentionally diverge from their old rectangle metadata.
- A shared test harness repository that mirrors production lookup semantics and cache invalidation behavior.

Run `flutter analyze` and `flutter test` at the end.
</validation>

<done_when>
- The repository has one polygon-backed source of truth for point-to-sheet lookup.
- `findByMgrsCodeAndCoordinates()` no longer returns a match solely from rectangle metadata.
- Live map surfaces that already own a `LatLng` resolve through the direct point-based path rather than MGRS round-tripping, while preserving the current readout source precedence.
- Peak-related callers with existing coordinates resolve through the direct point-based path rather than MGRS delegation.
- All other current point-to-map callers resolve through the polygon-backed repository path.
- Boundary points count as inside and ambiguous boundary cases resolve deterministically using the explicit tie-break rule.
- Hot-path lookups avoid repeated polygon re-parsing, and cache invalidation is covered for repository mutations.
- Unit and widget regressions prove that polygon containment replaced the old crude rectangle behavior without breaking existing fallback text.
</done_when>
