<goal>
Rework GPX track import so imported files are moved into managed country/region folders derived from the first geometry point in the file.
Route export folder structure is handled separately and is not in scope for this spec.
This keeps Bushwalking imports organized by location while preserving the existing import, parsing, and counting behavior.
</goal>

<background>
Flutter/Riverpod map app with an existing GPX track import flow.
Route handling exists elsewhere in the app, but it is out of scope for this spec.

Relevant code paths:
- @./lib/services/gpx_importer.dart - current track parsing, folder organization, and filename normalization.
- @./lib/services/import_path_helpers.dart - canonical Bushwalking root resolution.
- @./lib/services/polygon_asset_repository.dart - loads polygon assets from `assets/polygons/manifest.json`.
- @./lib/services/polygon_geometry.dart - point-in-polygon helper used for polygon containment.
- @./lib/providers/map_provider.dart - track import entry point and file-move state wiring.
- @./lib/widgets/map_action_rail.dart - import FAB and dialog entry point.
- @./lib/widgets/gpx_import_dialog.dart - import result summary copy.
- @./lib/screens/settings_screen.dart - track import summary copy.
- @./lib/services/import/gpx_track_import_models.dart - import result model contract.
- @./assets/polygons/manifest.json - polygon asset manifest.
- @./assets/polygons/new-south-wales.poly
- @./assets/polygons/tasmania.poly
- @./assets/polygons/italy-nord-est.poly
- @./assets/polygons/italy-nord-ovest.poly
- @./assets/polygons/slovenia.poly
- @./assets/polygons/croatia.poly
- @./test/services/import_path_helpers_test.dart - Bushwalking root resolution coverage.
- @./test/services/polygon_geometry_test.dart - polygon containment coverage.
- @./test/services/gpx_importer_selective_import_test.dart - importer behavior coverage.
- @./test/providers/map_provider_import_test.dart - import journey coverage.
- @./test/widget/gpx_import_dialog_test.dart - result dialog summary coverage.
- @./test/widget/gpx_tracks_shell_test.dart - import summary and settings warning coverage.
- @./test/robot/gpx_tracks/gpx_tracks_journey_test.dart - existing end-to-end GPX track import journey.

Current behavior to preserve:
- `resolveBushwalkingRoot()` is treated as the canonical Bushwalking root for this flow.
- Existing GPX parsing, dedupe, and collision handling stay unchanged.
- Existing filename normalization and collision suffixing stay unchanged; only the managed destination path changes.
- No migration of already-imported files is in scope.
</background>

<discovery>
Before implementation, confirm these points in code:
1. Where the current selective import path decides its managed destination path so the new resolver can be shared.
2. Whether the file move/organize logic already has a single seam that can accept a computed managed relative path and recurse through nested folders.
3. Which asset-loading seam should be used for polygon lookup so tests can inject a deterministic polygon set.
4. Which current import tests already exercise the real file-system move path and can be extended with country/region assertions.
</discovery>

<user_flows>
Primary flow:
1. User imports a GPX track through the existing app flow.
2. The importer reads the first valid track point from the raw GPX geometry.
3. The app resolves that point against the supported polygon assets using the explicit country/region priority order.
4. The track row is persisted.
5. The source GPX file is moved into managed storage under `~/Documents/Bushwalking/Tracks/<Country>/<Region?>`.
6. The existing import summary and state updates continue to behave as they do today, except the unsupported-count wording is generalized away from Tasmania.

Alternative flows:
- Cross-boundary geometry: if a track crosses multiple supported areas, the first point still decides the destination folder.
- Region-less country: Slovenia and Croatia save under the country folder only.
- Unsupported point: if the first point does not match any supported polygon, the importer falls back to the existing root-level `Tracks` destination and skips the file.
- Returning import: re-importing the same file uses the same destination rules and the same existing collision behavior.

Error flows:
- Missing or unreadable first point: the importer keeps the existing parse/error handling path and does not guess a destination folder.
- Polygon data unavailable or malformed: the importer falls back to the existing root-level `Tracks` destination rather than failing the import.
- Destination collision or file move failure: preserve the current manual-review/logging semantics and do not silently overwrite data.
- Existing route/track state refresh fails after import: preserve the current error handling behavior; this change must not introduce a new failure mode.
</user_flows>

<requirements>
**Functional:**
1. Add a shared destination resolver that maps a GPX first point to a supported country and optional region using polygon assets from `assets/polygons`.
2. Use the first valid geometry point from the raw GPX source only.
   For tracks, use the first point of the first track segment.
   Do not use later points, centroid logic, filename hints, metadata, or post-processing geometry to choose the folder.
3. Move imported tracks into managed storage under the following structure, anchored at the canonical Bushwalking root:
   - `./Tracks/Australia/NSW`
   - `./Tracks/Australia/Tasmania`
   - `./Tracks/Italy/nord-est`
   - `./Tracks/Italy/nord-ovest`
   - `./Tracks/Slovenia`
   - `./Tracks/Croatia`
4. Map polygon assets to folders as follows, and resolve ties by this priority order when more than one polygon could match: `italy-nord-est.poly`, `italy-nord-ovest.poly`, `slovenia.poly`, `croatia.poly`, `tasmania.poly`, `new-south-wales.poly`.
   - `italy-nord-est.poly` -> `Italy/nord-est`
   - `italy-nord-ovest.poly` -> `Italy/nord-ovest`
   - `slovenia.poly` -> `Slovenia` with no region subfolder
   - `croatia.poly` -> `Croatia` with no region subfolder
   - `tasmania.poly` -> `Australia/Tasmania`
   - `new-south-wales.poly` -> `Australia/NSW`
5. If a supported polygon match cannot be found, keep the file in the existing root-level `Tracks` folder rather than inventing a new country or region.
6. Preserve the current import pipeline for parsing, filtering, dedupe, collision handling, and persistence; this change affects destination folder selection plus unsupported-track classification and reporting.
7. Keep file naming rules deterministic and platform-safe.
   Preserve the existing canonical filename normalization and collision suffixing rules.
8. Create destination directories recursively before any move or rename.
   Create or use `~/Documents/Bushwalking` directly for this flow; do not let the HOME fallback change the target tree.
9. Centralize the folder decision so the track import code path does not duplicate the country/region lookup.
10. Recursively discover files under the `Tracks` tree so nested country/region folders remain visible to future rescans.

**Error Handling:**
11. If the file cannot be parsed enough to obtain a first point, use the existing import error path and do not move the file.
12. If polygon assets fail to load, return the existing root-level `Tracks` destination and continue the import.
13. If the chosen destination already exists or cannot be created, preserve the current manual-review or logging behavior and do not overwrite data.
14. If the importer encounters a supported country but no supported region, only the country folder should be created.
15. If a track is unsupported by the polygon lookup, keep the existing skip behavior and count it in `unsupportedCount` rather than imported.
    `unsupportedCount` means tracks whose first point falls outside the supported polygon set.

**Edge Cases:**
16. A track that crosses country boundaries must still be assigned by first point only.
17. A point on a polygon boundary should follow the explicit polygon priority order and remain deterministic.
18. Unsupported geography must not be misclassified into the nearest supported country.
19. Existing files on disk are out of scope; only new imports and re-organization paths use the new structure.

**Validation:**
20. Add behavior-first TDD slices for destination resolution, managed placement, and import-path wiring.
21. Keep tests deterministic by overriding the canonical Bushwalking root and injecting polygon data or an asset loader seam instead of reading real user folders.
22. Require baseline automated coverage for logic/business rules, file-system behavior, and the import journey.
23. If the import UI changes, cover that with widget tests; otherwise keep the validation focused on service and provider tests.
</requirements>

<boundaries>
Edge cases:
- No migration of existing imported files.
- No new countries or regions beyond the six polygon assets already listed.
- No change to GPX parsing rules, track statistics, or route generation.
- No change to the meaning of `resolveBushwalkingRoot()` outside this flow.
- Route export folder structure is handled in a separate export flow and is out of scope for this spec.

Error scenarios:
- Unsupported or missing polygon data falls back to the existing root-level import folder.
- A malformed GPX file still fails through the current import error path.
- Destination collisions still use the current collision/logging semantics.
- Unsupported-track summary text must not say Tasmania when the skip reason is outside the supported polygon set; the renamed unsupported-count wording should be used instead.

Limits:
- Do not add per-country configuration files or a user-editable mapping UI.
- Do not split a single file across multiple folders.
- Do not infer destination folders from anything other than the first valid geometry point.
</boundaries>

<implementation>
Likely files to update:
- @./lib/services/gpx_importer.dart
- @./lib/services/import_path_helpers.dart
- @./lib/services/polygon_asset_repository.dart
- @./lib/services/polygon_geometry.dart
- @./lib/providers/map_provider.dart
- @./lib/widgets/map_action_rail.dart
- @./lib/widgets/gpx_import_dialog.dart
- @./lib/screens/settings_screen.dart
- @./lib/services/import/gpx_track_import_models.dart
- @./test/services/gpx_importer_selective_import_test.dart
- @./test/providers/map_provider_import_test.dart
- @./test/services/import_path_helpers_test.dart
- @./test/services/polygon_geometry_test.dart
- @./test/widget/gpx_import_dialog_test.dart
- @./test/widget/gpx_tracks_shell_test.dart
- @./test/robot/gpx_tracks/gpx_tracks_journey_test.dart

Implementation shape:
- Add a small shared destination resolver that loads polygon assets once and returns country plus optional region for a supplied point.
- Keep the resolver pure apart from its asset-loading seam so it is easy to unit test.
- Reuse the existing filename helpers in `GpxImporter`; replace the Tasmania-only managed-path planning with country/region placement and make discovery recursive.
- Rename the `nonTasmanianCount` contract to `unsupportedCount` end-to-end across `TrackImportResult` in `lib/services/gpx_importer.dart`, selective-import models in `lib/services/import/gpx_track_import_models.dart`, provider results, provider snackbar/status copy in `lib/providers/map_provider.dart`, import dialog copy, Settings copy, and tests.
- Keep root resolution, import state management, and file moves in the existing provider flow.
</implementation>

<stages>
Phase 1: Destination resolution.
- Add unit tests for first-point detection, country/region mapping, unsupported-point fallback, region-less countries, explicit polygon priority, and supported-track acceptance outside Tasmania.
- Verify the resolver can be exercised with injected polygon data and a deterministic Bushwalking root.

Phase 2: Import path wiring.
- Wire track import organization to the shared resolver.
- Verify with service/provider and widget tests that only the parent destination changes, nested folders remain discoverable, managed paths mirror destination paths, `unsupportedCount` replaces `nonTasmanianCount`, provider snackbar/status copy uses the renamed unsupported wording, and existing import counts stay intact.

Phase 3: Journey coverage.
- Extend the existing GPX import journey coverage so at least one track import lands in the expected nested folders.
- Verify no new UI behavior is introduced unless the import surface itself changes.
</stages>

<illustrations>
Desired:
- First point in `tasmania.poly` moves a track into `./Tracks/Australia/Tasmania`.
- First point in `slovenia.poly` moves a track into `./Tracks/Slovenia`.
- A track that begins in NSW and later crosses into another supported area still moves into `./Tracks/Australia/NSW`.

Counter-examples:
- Choosing the folder from the last point, midpoint, or centroid.
- Saving Slovenia or Croatia files into a spurious region folder.
- Moving existing imported files as part of a one-time migration.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: country/region lookup, first-point-only selection, explicit polygon priority, supported-track acceptance, `unsupportedCount` rename, and unsupported-point fallback are covered by unit tests.
- File-system behavior: managed-path organization writes to the expected nested destination, recursively rediscovers nested folders, and preserves existing filename/collision behavior.
- UI behavior: provider snackbar/status copy, import result dialogs, and Settings summary copy display the renamed unsupported wording instead of `non-Tasmanian`.
- Critical journey: an end-to-end GPX track import run verifies that a track lands in the correct country/region folders after import.

TDD expectations:
- Write one failing test slice at a time: resolver mapping first, managed placement second, recursive folder discovery third.
- Keep each implementation change minimal until the current test slice is green.
- Prefer public seams and injected loaders over testing private helpers directly.

Test split:
- Unit tests: polygon lookup, first-point extraction, and fallback behavior.
- Service tests: destination folder selection in the importer, managed placement, and recursive track organization behavior.
- Widget tests: result dialog summary copy, Settings summary copy, provider snackbar/status copy, and any import UI text tied to the renamed unsupported field.
- Robot tests: extend the existing GPX import journey only if you need to prove the file lands in the right folder through the app flow; otherwise keep the journey coverage at the service/provider level.
</validation>

<done_when>
1. Track imports resolve their destination folder from the first geometry point.
2. Supported track files are moved into `Tracks/<Country>/<Region?>` under the canonical Bushwalking root.
3. Managed relative paths mirror the destination path.
4. Nested track folders remain discoverable through recursive rescan.
5. Unsupported or malformed inputs fall back to the existing behavior without corrupting import results.
6. The required automated tests pass.
</done_when>
