<goal>
Optimize GPX track rendering for the Flutter macOS map by keeping the imported GPX XML as the source of truth while persisting precomputed multi-zoom display geometry that is cheap to render.

Who benefits: users viewing imported tracks on the map.
Why it matters: the current implementation stores and renders every decoded track point, which is more detail than the map needs and creates avoidable rendering cost on large desktop map views.
</goal>

<background>
Tech stack: Flutter, flutter_map, Riverpod, ObjectBox, latlong2, xml.
Platform focus: macOS is the performance driver for this slice, but the storage and rendering path should remain shared Flutter code unless a platform-specific constraint forces otherwise.

This is a storage-and-rendering optimization on top of the already-shipped GPX track feature in `./ai_specs/005-gpx-tracks-spec.md`.
Unless this spec explicitly changes something, preserve the current behavior for:
- watched folders and file organization
- Tasmanian vs non-Tasmanian classification
- route handling
- content-hash duplicate detection
- logical-match replacement rules
- startup/manual import summaries, warnings, and recovery surfaces
- `MapNotifier` as the owner of track import/reset/recovery state

Current state:
- `./lib/models/gpx_track.dart` persists `trackPoints` as full segmented geometry JSON and exposes `getSegments()` for rendering.
- `./lib/services/gpx_importer.dart` parses GPX XML, extracts every point, and persists that full geometry.
- `./lib/screens/map_screen.dart` renders each segment as a `Polyline` using the stored full point set.
- `./lib/providers/map_provider.dart` already owns track loading, startup auto-import, reset, and recovery behavior.
- `./lib/router.dart` already shows startup/manual track snackbars and the persistent recovery affordance.

Key decisions already resolved for this spec:
- Persist the imported GPX XML exactly as read into Dart; do not normalize, pretty-print, or rewrite it.
- Do not persist the original filename.
- Future export is out of scope, but the filename contract is `trackName-dd-mm-yyyy.gpx` using local `trackDate` day values.
- Precompute display caches for integer zoom levels 6 through 18 inclusive.
- Use a 2.0 logical-pixel simplification tolerance.
- Use Web Mercator projected pixel coordinates at each target zoom for simplification.
- Preserve segment boundaries in every cache.
- Do not backfill legacy rows. This schema change intentionally uses a destructive persisted-track reset.

Files to examine:
- `./lib/models/gpx_track.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/gpx_track_repository.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/router.dart`
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`
- `./test/gpx_track_test.dart`
- `./test/widget/gpx_tracks_recovery_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User opens the map after this optimization ships.
2. Startup track loading checks persisted `GpxTrack` rows before any track rendering occurs.
3. If persisted rows are legacy pre-optimization rows, the app clears the `GpxTrack` box before publishing tracks into map state.
4. The existing empty-database startup import path runs and rebuilds track rows from disk.
5. Each imported track stores the untouched GPX XML plus simplified display geometry for integer zooms 6 through 18.
6. The map renders the cache selected by the current rounded zoom.
7. User pans and zooms; cache selection changes only when the rounded integer zoom changes.
8. Tracks remain visually faithful while render cost drops compared with rendering the full original geometry.

Alternative flows:
- Startup with valid optimized rows: load tracks normally, show them using cached display geometry, and do not rebuild.
- Manual rescan keeps the existing watched-folder behavior: scan `Tracks` only, reuse the existing import path, and build caches for any newly imported or replacement rows.
- Reset Track Data keeps the existing confirmed destructive rebuild flow and rebuilds optimized rows from both `Tracks` and `Tracks/Tasmania`, assigning fresh ObjectBox IDs from `1` upward after the wipe.
- If no GPX files are available after a destructive reset, the app finishes with an empty database and keeps the existing import/reset affordances available.

Error flows:
- GPX file unreadable or invalid: skip that file, continue processing others, and report it through the existing per-file logging and operation summary behavior.
- Cache generation fails for an otherwise valid GPX: skip that file, log/report it through the same existing error path, and do not persist a partial row.
- Automatic destructive reset succeeds but startup rebuild finds no GPX files: leave the database empty and do not fabricate recovery state.
- Persisted optimized row is corrupt or incomplete: keep the existing recovery/reset path instead of silently wiping that data.
</user_flows>

<requirements>
**Functional:**
1. Replace persisted full-resolution `trackPoints` storage in `./lib/models/gpx_track.dart` with two persisted fields:
   - `gpxFile` (`String`) storing the imported GPX XML exactly as read.
   - `displayTrackPointsByZoom` (`String`) storing JSON-encoded simplified segmented geometry keyed by integer zoom.
2. Remove `trackPoints` from the persisted schema. Full decoded geometry must no longer be stored as its own persisted field once `gpxFile` exists.
3. Keep the existing metadata fields (`contentHash`, `trackName`, `trackDate`, `startDateTime`, `endDateTime`, `distance`, `ascent`, `totalTimeMillis`, `trackColour`) unless a change is strictly required to support the new storage model.
4. Define `displayTrackPointsByZoom` as a JSON object whose keys are decimal zoom strings and whose values preserve segmented geometry, for example:
   `{"15": [[[-42.1,146.1],[-42.2,146.2]]], "16": [[[-42.1,146.1],[-42.15,146.15],[-42.2,146.2]]]}`
5. Add model-level decode helpers that return display geometry for a requested zoom without reparsing GPX XML during rendering.
6. During import, parse the original geometry in memory from the GPX XML, preserve segment boundaries, and build simplified caches for every integer zoom from 6 through 18 inclusive.
7. Perform simplification in Web Mercator projected world-pixel space at the target zoom. Do not simplify directly in latitude/longitude space or by a raw meter threshold.
8. Use the Ramer-Douglas-Peucker algorithm with epsilon `2.0` logical pixels for each zoom-specific simplification pass.
9. Preserve the first and last point of every segment in every zoom cache.
10. Preserve one-point and two-point segments exactly.
11. Generate caches once during import/reset, not lazily during `MapScreen.build()`, map gestures, or first render of a zoom level.
12. Continue computing `contentHash` from the original GPX file bytes so unchanged-file detection remains tied to the source file, not to simplified geometry.
13. Continue using the current import semantics from `005-gpx-tracks-spec.md` for route detection, watched folders, canonical moves, duplicate handling, logical-match replacement, warnings, and summaries unless this optimization explicitly changes them.
14. Persist `gpxFile` exactly as imported. Do not pretty-print XML, strip whitespace, reorder attributes, normalize line endings, or reserialize through `XmlDocument` for storage.
15. Do not persist the original filename. Future export must derive its filename from persisted metadata as `trackName-dd-mm-yyyy.gpx`, using the local `trackDate` day value.
16. Render tracks from `displayTrackPointsByZoom`, not from raw GPX reparsing and not from any legacy `trackPoints` field.
17. Select the rendered cache using the current map zoom rounded to the nearest integer and clamped to the stored range 6 through 18.
18. Cache switching on zoom must not toggle `showTracks`, clear selected state, or require reimport.
19. Keep existing track color, segmented-polyline rendering, and track toggle behavior.
20. Use the existing track state owner in `./lib/providers/map_provider.dart`; do not introduce a second feature-specific track state manager.

**Startup validation and migration:**
21. Use the existing ObjectBox open-store path and `MapNotifier` startup track-loading flow. Do not add a bespoke row-by-row backfill migrator.
22. Treat any persisted row that predates this optimization as incompatible legacy data.
23. Detect the legacy-data wipe via a one-time migration marker stored outside `GpxTrack` rows, such as a dedicated app preference or equivalent app-owned startup flag. Do not rely only on empty-string/default-value heuristics inside migrated rows.
24. On first startup after this optimization ships, if the migration marker is not yet recorded and the `GpxTrack` box is non-empty, clear the entire `GpxTrack` box before rendering and before setting recovery UI state.
25. If the migration marker is not yet recorded and the `GpxTrack` box is already empty, do not treat that as recovery and do not delay marker creation; record the marker on that same startup after the migration check completes.
26. Record the migration marker exactly once after the startup migration check has completed for that installation, whether the outcome was "wiped legacy rows" or "no rows existed to wipe," so later startups do not repeat the automatic legacy pass.
27. After that destructive wipe, rely on the existing empty-database startup import path to rebuild optimized rows from disk.
28. Automatic legacy-data reset is a one-time compatibility operation and must not show a confirmation dialog.
29. If the destructive reset completes but startup rebuild finds no readable GPX files, the database remains empty rather than preserving legacy rows or entering recovery mode.
30. Distinguish legacy rows from corrupt optimized rows by startup phase, not by ambiguous empty defaults. Before the one-time migration marker is recorded, pre-optimization rows are treated as legacy. After the marker is recorded, any invalid optimized row is treated as corruption and uses the existing recovery/reset path.

**Corrupt optimized rows:**
31. A row created under the new schema is corrupt optimized data if its optimized fields are present but unusable, including cases where `displayTrackPointsByZoom` is invalid JSON, missing required zoom keys, cannot decode into segmented geometry, or `gpxFile` is unexpectedly empty.
32. Corrupt optimized rows must trigger the existing `hasTrackRecoveryIssue` behavior and recovery messaging rather than an automatic wipe.
33. Reset Track Data remains the manual rebuild path for corrupt optimized rows and reassigns fresh IDs on the rebuilt rows.

**Error handling:**
34. If a GPX file cannot be read or parsed, skip it, continue the operation, and report it through the existing per-file logging and operation summary behavior.
35. If simplification, cache serialization, or optimized-row construction fails for a track, do not persist that row and report it through the existing skipped-file path.
36. Automatic destructive reset during startup must keep the current startup import UX contract: no extra confirmation step and no new custom migration UI.
37. If startup rebuild after destructive reset fails for reasons other than "no files found", surface the failure through the existing startup/manual track error surfaces and keep import/reset available for retry.

**Edge cases:**
38. Multi-segment GPX tracks must preserve segment boundaries in every zoom cache.
39. Duplicate or unchanged GPX files must continue to use existing `contentHash` semantics; cache generation must not create duplicate persisted rows for identical content.
40. Tracks with dense but nearly straight point sequences should simplify aggressively at lower zooms while remaining within the 2 px tolerance.
41. Tracks with tight switchbacks or short zig-zags must retain enough points at higher zooms to remain within the same tolerance.
42. Zoom levels below 6 render with the zoom-6 cache.
43. Zoom levels above 18 render with the zoom-18 cache.
44. Because `gpxFile` becomes the persisted source of truth, any future geometry rebuild must be able to regenerate `displayTrackPointsByZoom` from `gpxFile` alone.

**Validation discipline:**
45. Every requirement above must be backed by automated coverage across pure logic, startup state behavior, and critical user journeys.
46. Follow the repo's preferred vertical-slice TDD approach: one failing test at a time, minimal implementation to green, then refactor.
47. Prefer pure fakes over mocks. Only mock true external boundaries such as filesystem or ObjectBox seams when a fake is not practical.
</requirements>

<boundaries>
In scope:
- Changing persisted track storage from full raw point JSON to raw GPX XML plus multi-zoom display caches.
- Switching map rendering to zoom-selected cached geometry.
- Adding startup detection that auto-wipes legacy rows before rendering.
- Recording a one-time migration marker so future startups can distinguish legacy data from corrupt optimized data.
- Keeping corrupt optimized-row handling on the existing recovery/reset path.

Out of scope:
- Changing watched folders, route organization, Tasmania classification, duplicate detection, or logical-match replacement semantics beyond what is required to store optimized geometry.
- Implementing GPX export.
- Preserving legacy pre-optimization persisted rows.
- Dynamic per-frame simplification during map interaction.

Limits:
- Cache only integer zooms 6 through 18 inclusive.
- Use Flutter logical pixels, not raw physical display pixels or Retina scale factors, for simplification tolerance.
- Do not store both full decoded raw geometry JSON and `gpxFile`; `gpxFile` is the persisted raw source of truth.
</boundaries>

<implementation>
Create or modify these paths:
- `./lib/models/gpx_track.dart`
  - remove persisted `trackPoints`
  - add persisted `gpxFile`
  - add persisted `displayTrackPointsByZoom`
  - add helpers for decoding zoom-selected display segments and for validating optimized rows
- `./lib/services/gpx_importer.dart`
  - keep reading the original GPX bytes/content for existing metadata and content-hash logic
  - build zoom caches from parsed geometry before persistence
  - persist untouched GPX XML in `gpxFile`
- `./lib/services/gpx_track_repository.dart`
  - keep unchanged-content lookup semantics
  - add small helpers only if they simplify startup validation or destructive reset logic
- `./lib/providers/map_provider.dart`
  - detect legacy rows and clear the `GpxTrack` box before rendering
  - own the one-time legacy migration marker check/update or delegate it to a small app-owned helper
  - record the migration marker even when the box is already empty on first post-ship startup
  - distinguish legacy auto-reset from corrupt optimized-row recovery
  - keep existing auto-import/reset state ownership and snack-bar/recovery flow
- `./lib/screens/map_screen.dart`
  - render using zoom-selected cached segments
  - stop depending on legacy full-resolution `trackPoints`
- `./lib/screens/settings_screen.dart`
  - keep the existing Reset Track Data flow as the manual rebuild path
- `./lib/router.dart`
  - update only if existing startup/manual track surfaces need minor adjustments for the new legacy-vs-corrupt distinction
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`

Add one small pure-Dart helper dedicated to cache construction:
- `./lib/services/track_display_cache_builder.dart`
  - input: full segmented geometry parsed in memory from GPX
  - output: zoom-keyed simplified geometry ready for JSON persistence
  - responsibilities: Web Mercator projection, Ramer-Douglas-Peucker simplification, endpoint preservation, zoom-range iteration, deterministic encoding

Implementation rules:
- Perform simplification independently per segment.
- Serialize caches back to lat/lng pairs so rendering continues to use `LatLng`.
- Keep cache generation deterministic: identical source GPX should produce stable cache JSON.
- Avoid rebuilding caches during rendering or gesture callbacks.
- Keep the legacy-wipe marker logic explicit and one-time so startup behavior is deterministic across app launches.
- Keep changes as a small delta on top of the existing GPX import feature rather than rewriting unrelated import behavior.
</implementation>

<stages>
Stage 1: Schema and cache builder
- Introduce `gpxFile` and `displayTrackPointsByZoom`.
- Add the pure cache builder and cover projection/simplification behavior with unit tests.
- Verify a sample segmented track produces stable zoom keys 6 through 18 and preserves endpoints.

Stage 2: Import and persistence
- Update GPX import to store raw GPX XML unchanged and persist zoom caches.
- Remove legacy raw-point persistence.
- Verify unchanged-content detection still operates on the original file bytes.

Stage 3: Startup validation and rendering
- Switch map rendering to zoom-selected cached geometry.
- Detect legacy rows at startup, wipe them before rendering, and let the existing startup import rebuild them.
- Keep corrupt optimized rows on the existing recovery path.

Stage 4: Recovery and polish
- Ensure startup/manual failure surfaces still work after the storage change.
- Verify Reset Track Data rebuilds optimized rows and clears recovery state when successful.
</stages>

<illustrations>
Desired behavior:
- A dense GPX track with thousands of nearly collinear points imports once, stores the original XML, and renders from a much smaller point set at zoom 15 while remaining within 2 logical pixels of the original shape.
- The same track shows fewer points at zoom 8 and more points at zoom 17, with segment boundaries unchanged.
- Opening the app on a database populated with legacy `trackPoints` rows clears them before any track polyline is rendered, then rebuilds from disk using the normal startup import path.
- Opening the app on a database populated with corrupt optimized rows shows the existing recovery messaging instead of silently wiping the rows.

Avoid:
- Storing rewritten XML that differs from the imported file.
- Measuring tolerance in meters or raw Retina pixels.
- Recomputing simplified geometry every time the map rebuilds.
- Keeping both full decoded raw point JSON and raw GPX XML in ObjectBox.
</illustrations>

<validation>
Baseline automated coverage required:
- Unit coverage for projection math, simplification behavior, cache serialization, and zoom-cache selection.
- Unit/service coverage for GPX import persistence, one-time migration-marker behavior, empty-box first-start behavior, and startup legacy-wipe detection.
- Widget coverage for map rendering selection, recovery-vs-legacy startup behavior, and settings/reset UI states.
- Robot-driven coverage for the critical rebuild journeys that still matter after this storage change.

Behavior-first TDD slices:
1. RED: `TrackDisplayCacheBuilder` produces caches for zooms 6 through 18 and preserves segment boundaries.
2. GREEN: a straight-line dense segment collapses to the minimal endpoint-preserving point set within 2 px tolerance.
3. RED: a switchback segment retains enough points at higher zooms to remain within tolerance.
4. GREEN: `GpxTrack` decodes `displayTrackPointsByZoom` and returns the cache for a requested zoom.
5. RED: zoom selection rounds and clamps correctly for non-integer and out-of-range zoom values.
6. RED: GPX import stores `gpxFile` exactly as read and persists stable zoom caches.
7. GREEN: GPX import no longer persists legacy `trackPoints`.
8. RED: first startup after ship with a non-empty pre-optimization track box clears the box, records the migration marker, and then uses the existing empty-database import path.
9. RED: first startup after ship with an already-empty track box records the migration marker without entering recovery.
10. RED: later startup with corrupt optimized rows enters the existing recovery path instead of auto-wiping.
11. RED: map rendering uses cached geometry for the selected zoom rather than reparsing GPX or using legacy raw points.

Required seams for deterministic tests:
- Keep `TrackDisplayCacheBuilder` pure and free of file I/O.
- Keep zoom-cache selection callable without a real `MapController`.
- Isolate startup migration-marker logic and row validation so tests can distinguish legacy rows from corrupt optimized rows.
- Prefer fake repositories/importers over mocks when testing `MapNotifier` flows.

Robot-driven coverage:
- Critical journey 1: launch the map with importable GPX files, allow startup rebuild/import to finish, and verify tracks are present and visible.
- Critical journey 2: navigate to Settings, run Reset Track Data, confirm the destructive action, and verify tracks rebuild successfully when returning to the map.

Residual risks to report if implementation cannot fully cover them:
- Performance gains may vary with dataset size and desktop hardware, so note any unverified upper-bound GPX sizes.
- Visual fidelity outside the cached zoom range is intentionally clamped to the nearest available cache.
</validation>

<done_when>
- `./ai_specs/005-track-optimization-spec.md` is implementable without extra decisions about schema shape, cache algorithm, startup legacy handling, or recovery behavior.
- Persisted tracks store unchanged GPX XML plus multi-zoom display caches, with no legacy `trackPoints` field.
- The map renders from zoom-selected caches and no longer depends on full raw-point persistence.
- Opening the app with legacy rows clears and rebuilds them automatically before rendering.
- Opening the app with corrupt optimized rows uses the existing deterministic recovery/reset path.
- Automated tests cover cache logic, startup behavior, UI behavior, and the critical rebuild journeys described above.
</done_when>
