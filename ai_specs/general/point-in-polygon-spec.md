<goal>
Add a reusable lat/long polygon containment utility so the app can later answer whether a point lies inside a non-rectangular region such as `./assets/polygons/tasmania.poly`.
This matters because rectangular `LatLngBounds` checks are not sufficient for irregular coastlines, map regions, or future area filters.
</goal>

<background>
The app is a Flutter codebase with existing geo helpers in `./lib/services/geo.dart`, polygon asset loading in `./lib/services/polygon_asset_repository.dart`, rectangular area constants in `./lib/models/geo_areas.dart`, Tasmania-only region validation in `./lib/services/peak_admin_editor.dart`, and Tasmap50k polygon access in `./lib/services/tasmap_repository.dart`.
Polygon assets already exist in the repo under `./assets/polygons/`, including `./assets/polygons/tasmania.poly`, `./assets/polygons/slovenia.poly`, and other bundled `.poly` files.
The `.poly` files use standard Osmosis-style text format: a name line, a ring id line, coordinate lines in `lon lat` order, then `END` markers.
Files to examine: `./lib/services/geo.dart`, `./lib/services/polygon_asset_repository.dart`, `./lib/models/map_polygon_asset.dart`, `./lib/models/geo_areas.dart`, `./lib/services/peak_admin_editor.dart`, `./lib/services/tasmap_repository.dart`, and `./assets/polygons/tasmania.poly`.
</background>

<discovery>
The current repo `.poly` assets are all single outer-ring files with `lon lat` coordinates and terminal `END` markers only; no bundled asset currently requires hole or multi-ring support.
</discovery>

<requirements>
**Functional:**
1. Add a pure containment helper that accepts a `LatLng` point and a polygon region expressed in lat/long vertices.
2. Treat longitude as `x` and latitude as `y` consistently across the algorithm and parser.
3. Return `true` for points strictly inside the polygon and for points on the boundary.
4. Allow callers to pass an open ring; the helper must not require the first vertex to be repeated at the end.
5. Ignore a duplicate closing vertex if it is already present.
6. Reject polygons with fewer than 3 distinct vertices.
7. Add or extract a pure `.poly` parser helper that can read `./assets/polygons/tasmania.poly` style files and return reusable polygon vertices for containment.
8. Support a single closed outer ring only; do not add hole or multi-ring semantics in this spec.
9. Keep all geometry code deterministic and independent of Flutter widgets, map camera state, or network access.

**Error Handling:**
10. The containment helper must throw `ArgumentError` when supplied an empty polygon or fewer than 3 distinct vertices after normalizing duplicate closure.
11. Malformed coordinate lines, missing `END` markers, empty rings, or invalid number formats must fail fast through a typed immutable success/failure result that follows the repo's existing named-constructor style.
12. If parsing is extracted into pure geometry code, its success payload must be generic polygon data rather than `MapPolygonAsset`; `PolygonAssetRepository` remains responsible for wrapping parsed data into `MapPolygonAsset` instances.
13. Parse failures must not crash the app; callers must be able to preserve their existing region and handle the failure explicitly.

**Edge Cases:**
14. Points exactly on an edge or vertex count as inside.
15. Concave polygons must return correct results.
16. Duplicate consecutive vertices should not break containment checks.
17. Antimeridian-crossing polygons are out of scope unless a later spec explicitly adds support.

**Validation:**
18. Use TDD-first unit coverage for the core algorithm: start with a square, then add boundary, concave, invalid-input, and malformed-input cases.
19. Add a regression test that parses `./assets/polygons/tasmania.poly` and verifies a known inside point and a known outside point.
20. Baseline coverage must be logic/unit tests only; no widget or robot coverage is required for this utility.
21. Keep test fixtures deterministic and avoid network, device location, or map rendering dependencies.
</requirements>

<boundaries>
Edge cases:
- On-boundary points are inside.
- Open rings are allowed.
- Duplicate closing points are allowed but optional.
- Self-intersecting polygons are not supported unless a later spec explicitly adds that behavior.

Error scenarios:
- Malformed `.poly` input: return a typed failure and preserve the caller’s existing region.
- Empty polygon input: containment must throw `ArgumentError` immediately.
- Polygon with fewer than 3 distinct vertices: containment must throw `ArgumentError` immediately.

Limits:
- This work only adds geometry detection and optional `.poly` parsing.
- This work targets containment decisions only; camera fitting, default map extents, and other viewport calculations remain bounds-based and out of scope.
- This spec is utility-only. Do not replace existing production callers such as `PeakAdminEditor._isInsideTasmania(...)`, map-name lookup flows, or map-screen/settings behavior in this work.
- The helper must be compatible with `TasmapRepository.getMapPolygonPoints(...)`, but this spec does not add new `TasmapRepository` containment methods.
</boundaries>

<implementation>
Create `./lib/services/polygon_geometry.dart` as the home for pure polygon logic, including the containment algorithm, ring normalization/validation, and any extracted pure `.poly` parsing helpers.
Keep `./lib/services/polygon_asset_repository.dart` responsible for manifest loading, asset reads, failure logging, and wrapping parsed polygon data into `MapPolygonAsset`; if parser extraction is needed, make the repository delegate to the pure parser layer rather than duplicating logic.
Prefer a minimal `bool` containment API over plain polygon vertices such as `List<LatLng>`. Do not add a new polygon model unless implementation proves one is needed; if a reusable generic polygon-region model is introduced, place it under `./lib/models/` rather than inside the service module.
Do not add new `TasmapRepository` containment APIs in this spec; future consumer specs can build on the generic helper using `TasmapRepository.getMapPolygonPoints(...)`.
Add tests in `./test/services/polygon_geometry_test.dart` covering containment, boundary behavior, ring closure, invalid-input `ArgumentError`s, malformed `.poly` parsing, and the `./assets/polygons/tasmania.poly` regression case.
Keep `./test/services/polygon_asset_repository_test.dart` as repository-level coverage for manifest loading, asset filtering, and parser delegation/wrapping behavior.
Avoid adding a third-party geometry library; the required behavior is small enough to keep in-repo and easier to test deterministically.
</implementation>

<stages>
Phase 1: Core containment
- Implement point-in-polygon for a single ring.
- Verify inside, outside, on-edge, on-vertex, and concave cases with unit tests.

Phase 2: `.poly` parsing
- Parse standard `.poly` text into reusable polygon vertices for containment.
- Verify Tasmania asset parsing and malformed input handling.

Phase 3: Future consumer readiness
- Expose a stable API that later map-region consumers can call directly.
- Verify the API is simple enough for future polygon-asset region checks, Tasmania-style region-membership replacement, and `Tasmap50k` point-in-polygon checks without further refactoring.
- Do not adopt the helper in production callers during this spec.
</stages>

<validation>
Follow vertical-slice TDD:
- Start with the smallest failing test for a square containment check.
- Add edge-boundary inclusion next.
- Add concave-polygon coverage.
- Add invalid-input `ArgumentError` coverage before parser failure cases.
- Add `.poly` parsing and malformed-input failures last.
- Keep the production code minimal until each test passes, then refactor.

Required automated coverage:
- Logic/business rules: point-in-polygon containment, boundary inclusion, ring closure handling, invalid-input `ArgumentError`s, and malformed `.poly` parsing.
- Regression coverage: parse `./assets/polygons/tasmania.poly` successfully and verify `(-42.896016, 147.237306)` is inside and `(-33.865143, 151.209900)` is outside.
- No UI, widget, or robot coverage is required for this work.

Testability seams:
- A pure function for containment that accepts plain geometry input and returns `bool`.
- A pure parser for `.poly` text that returns generic polygon data through a typed success/failure result using the repo's existing named-constructor pattern.
- Small hand-built polygon fixtures plus the checked-in Tasmania asset.
- The same containment API must work for both bundled polygon assets and `Tasmap50k` polygon points returned by `TasmapRepository.getMapPolygonPoints(...)`.
- Repository-level tests must continue to cover manifest loading and `MapPolygonAsset` wrapping separately from pure parser tests.
</validation>

<done_when>
The work is complete when the repo has a reusable lat/long point-in-polygon helper, a deterministic `.poly` parser for future area-region use, passing unit coverage for boundary, invalid-input, and malformed cases, a regression test proving `./assets/polygons/tasmania.poly` can be evaluated correctly, and repository-level coverage confirming manifest loading and `MapPolygonAsset` wrapping still pass after any parser extraction or delegation.
</done_when>
