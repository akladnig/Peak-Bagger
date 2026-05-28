<goal>
Expand the current GPX import flow from a track-only action into a generic import entry point that can import GPX files as tracks or normalize them into routes.
This keeps the existing map-based import journey intact while letting users choose route output when they need it.
</goal>

<background>
The current entry point lives in `./lib/widgets/map_action_rail.dart` and opens `./lib/widgets/gpx_import_dialog.dart`.
The import handoff flows through `./lib/providers/map_provider.dart` into `./lib/services/gpx_importer.dart`.
Shared UI constants live in `./lib/core/constants.dart`, including `RouteUI`.
The route-creation analytics path lives in `./lib/providers/map_provider.dart` and `./lib/services/route_elevation_sampler.dart`.
Route persistence lives in `./lib/models/route.dart`, `./lib/providers/route_repository_provider.dart`, and `./lib/services/route_repository.dart`.
Existing coverage to extend is in `./test/widget/gpx_import_dialog_test.dart`, `./test/widget/map_action_rail_grouping_test.dart`, `./test/robot/gpx_tracks/gpx_tracks_robot.dart`, `./test/robot/gpx_tracks/single_track_import_journey_test.dart`, and `./test/services/gpx_importer_filter_test.dart`.
</background>

<user_flows>
Primary flow:
1. User taps the import action in the tools rail.
2. The dialog opens with updated wording for importing GPX files.
3. User selects one or more GPX files.
4. User optionally enables `Import as Route`.
5. User edits track names if needed.
6. User starts import and sees the existing progress and success summary flow.

Alternative flows:
- Route mode off: import behaves like the current track import path.
- Route mode on: each selected GPX file is normalized into route GPX before persistence.
- Existing route GPX: rewrite it into the same normalized route output shape rather than rejecting it.
- Multiple files: each file is handled independently, with per-file name edits preserved.

Error flows:
- Picker cancel: dialog stays open and no import begins.
- Picker failure: show the existing failure dialog with the picker error.
- Invalid name: show the field error and do not start import.
- Malformed GPX or unusable geometry: surface the existing import failure path.
- Concurrent import: keep the action disabled while import is in progress.
</user_flows>

<requirements>
**Functional:**
1. Change the tools-rail tooltip from `Import Track` to `Import Data` in `./lib/widgets/map_action_rail.dart`.
2. Change the dialog wording to `Import GPX File(s)` and add an `Import as Route` switch styled to match `Show Tracks/Routes (T)`.
3. The switch defaults to off, uses the stable key `gpx-import-as-route`, and stays disabled while import is running.
4. Thread an `importAsRoute` flag from the dialog through `MapActionRail`, `MapNotifier.importGpxFiles`, and the importer path.
5. Keep the current import path unchanged when `importAsRoute` is false.
6. When `importAsRoute` is true, convert every selected GPX file into route GPX before it is persisted.
7. Route conversion must use fixed defaults from `RouteUI`, not live settings: `defaultHampelWindow = 5`, `defaultElevationWindow = 5`, `defaultPositionWindow = 3`, `defaultOutlierFilter = GpxTrackOutlierFilter.hampel`, `defaultElevationSmoother = GpxTrackElevationSmoother.none`, `defaultPositionSmoother = GpxTrackPositionSmoother.kalman`.
8. Route conversion must flatten all `trkseg` points in source order into a single route.
9. When a GPX file contains both track and route geometry, prefer track geometry; only use route geometry when no track points exist.
10. Route conversion must also normalize GPX files that already contain route data.
11. Route output must copy useful metadata (`name`, `desc`, `ele`), remove track-only structure (`trk`, `trkseg`, `trkpt`), remove time metadata, and save valid GPX 1.1.
12. Convert imported route GPX into a `Route` entity and persist it through `./lib/services/route_repository.dart` / `routeRepositoryProvider`; do not store route-mode imports as `GpxTrack` records.
13. Add route description storage to `Route` so imported route metadata can persist the source `desc` value alongside the existing route fields.
14. Parse GPX XML into a neutral internal point model, `GpxPointSample`, that carries `lat`, `lon`, optional `ele`, optional `time`, and `sourceKind`.
15. Generalize `GpxTrackFilter` into a format-neutral `GpxFilter` that can consume either `trkpt` or `rtept` samples while keeping the same fixed defaults from `RouteUI`.
16. `GpxFilter` must treat time-based pruning as optional; if a point set has no timestamps, it must still simplify and retain geometry/elevation-based filtering.
17. Keep persistence separate from filtering: filtering decides which points survive, and format-specific builders decide how the surviving points are stored.
18. Track imports that do not need filtering or normalization must keep the existing raw fast path and store the original GPX unchanged without invoking `GpxFilter`.
19. Route conversion must build a `Route` from the filtered point series using route-specific output logic, not XML-shape-specific track logic.
20. Route conversion must produce filtered/simplified route geometry using the fixed defaults from `RouteUI` before persistence.
21. Populate route fields from the converted geometry: `gpxRoute`, `gpxRouteElevations`, `displayRoutePointsByZoom`, `distance2d`, `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, `highestElevation`.
22. Route-aware analytics for imported routes must reuse the same route-elevation methods used by route drafting in `./lib/providers/map_provider.dart`: sample point elevations for the converted route and derive the geometry-based route metrics from the converted route geometry.
23. Time-based analytics fields are not part of `Route`; route imports do not need track timestamps.
24. Route-mode imports must use a dedicated route pipeline that bypasses track-only selective import, Tasmanian filtering, managed storage placement, and `GpxTrack` persistence.
25. After saving a route import, increment `routeRevisionProvider` so the route list refreshes immediately.
26. Use one shared import result contract for both modes, with common counts/warnings and an item payload that can represent either a `GpxTrack` or a `Route`.
27. Preserve the existing success summary counts and result dialog behavior, but make the text route-aware when `Import as Route` is enabled.
28. The import dialog field label must switch between track and route copy based on `importAsRoute` (`Track Name` in track mode, `Route Name` in route mode).
29. The import dialog validation message must switch between `A track name is required` and `A route name is required` based on `importAsRoute`.
30. Rename `./lib/widgets/gpx_track_import_dialog.dart` to `./lib/widgets/gpx_import_dialog.dart` and require the dialog to receive `importAsRoute` so it can deterministically switch label, validation, and keys.
31. The dialog-owned keys must be generic: `gpx-import-dialog`, `gpx-import-select-files`, `gpx-import-cancel`, `gpx-import-button`, `gpx-import-progress`, `gpx-import-row-$index`, `gpx-import-name-field-$index`, `gpx-import-result-close`, and `gpx-import-error-close`.

**Error Handling:**
32. Picker and import failures must continue to use the existing failure dialogs.
33. A conversion that yields no usable route points must fail the import rather than producing a broken record.
34. The import controls must reset cleanly after cancel, failure, or success.

**Edge Cases:**
35. Multiple `trkseg` sections must preserve point order across the whole file.
36. Dense tracks must always use the fixed route-conversion defaults, never the user’s current filter preferences.
37. Rapid repeated taps must not create overlapping imports.
38. Files that already contain route data must be rewritten into normalized route output, not rejected.

**Validation:**
39. Add logic coverage for route conversion output, metadata retention, point ordering, fixed-default selection, route-aware analytics reuse, route entity persistence, route description storage, route revision refresh, the shared import result contract, filtered route geometry, the raw fast path for unchanged tracks, the point-based pipeline model, and the dedicated route pipeline bypass.
40. Add widget coverage for the rail tooltip, dialog title/copy, switch default state, and callback wiring.
41. Add robot coverage for the full import journey with deterministic selectors and fake picker/in-memory persistence.
</requirements>

<boundaries>
Edge cases:
- Empty selection: no import starts and the dialog remains usable.
- Single-point or no-point source: reject as an import failure.
- Mixed input files: process each file independently and keep per-file name edits.
- Mixed geometry files: prefer track geometry over route geometry when both exist.

Error scenarios:
- File picker error: show the existing import failure dialog.
- Parse or conversion failure: show the existing import failure dialog and do not persist partial broken output.
- Import already in progress: keep the import button disabled and ignore the extra trigger.

Limits:
- GPX file selection remains GPX-only.
- No new route-management surface is introduced.
- Do not change the existing settings screen persistence behavior unless the route-conversion path specifically needs the fixed defaults.
</boundaries>

<discovery>
Inspect the current import handoff in `./lib/widgets/map_action_rail.dart`, `./lib/widgets/gpx_import_dialog.dart`, `./lib/providers/map_provider.dart`, and `./lib/services/gpx_importer.dart` before changing signatures.
Confirm how `GpxTrackFilter` and `GpxFilterConfig` can be reused without depending on live settings state.
Verify the existing `Route` model and repository path so imported route GPX lands where the app expects route records.
Check the existing robot selectors in `./test/robot/gpx_tracks/gpx_tracks_robot.dart` before adding new ones.
</discovery>

<stages>
1. Wire the UI copy and add the `Import as Route` switch. Verify the dialog/widget tests fail first, then pass.
2. Extend the import contract to carry `importAsRoute` end to end. Verify the wiring with a focused widget or provider test.
3. Implement route conversion with fixed `RouteUI` defaults in the importer. Verify the service tests cover track flattening, metadata, and normalized GPX output.
4. Add the robot journey for route import. Verify the critical happy path and result summary with stable keys.
</stages>

<illustrations>
Desired:
- A track with two `trkseg` sections becomes one route with points in source order.
- A route GPX file is normalized and imported successfully when `Import as Route` is enabled.
- The converted route XML contains the copied metadata and no track-only elements.

Avoid:
- Reading live filter preferences during route conversion.
- Adding a separate import workflow for routes.
- Leaving the route toggle visually inconsistent with the existing tracks/routes styling.
</illustrations>

<implementation>
Update `./lib/widgets/map_action_rail.dart`, `./lib/widgets/gpx_import_dialog.dart`, `./lib/providers/map_provider.dart`, `./lib/services/gpx_importer.dart`, and `./lib/core/constants.dart`.
Add a small conversion helper in `./lib/services/` if keeping the importer readable requires it.
Add stable keys for the new switch and any route-import-specific result text used by tests.
Keep the existing import flow unchanged when the route toggle is off.
Update tests under `./test/widget/`, `./test/services/`, and `./test/robot/gpx_tracks/` rather than replacing the current harness.
</implementation>

<validation>
Use vertical-slice TDD for the logic work: one failing behavior at a time, then implement just enough to pass, then refactor.
Keep tests public-interface focused; avoid testing private helpers directly.

Required coverage:
- Logic/business rules: route conversion output, ordering, copied metadata, dropped track-only structure, and fixed-default selection.
- UI behavior: rail tooltip text, dialog wording, switch default state, switch disablement during import, and disabled import button states.
- Critical user journey: open dialog, select files, toggle route mode, import successfully, and verify the success summary.

Test split:
- Robot tests for the critical end-to-end happy path.
- Widget tests for screen-level copy, toggles, cancel, validation, and progress states.
- Unit/service tests for conversion and importer behavior.

Deterministic seams:
- Fake file picker.
- In-memory repository/storage.
- Route-import flag passed through the dialog callback.
- Stable keys for the import button, cancel button, file picker button, and new route switch.

Known risk to report if needed:
- If GPX metadata parsing or XML serialization cannot preserve every optional GPX element, the spec still requires the documented `name`, `desc`, `ele`, and valid GPX 1.1 output.
</validation>

<done_when>
- The tools rail says `Import Data`.
- The dialog says `Import GPX File(s)` and contains an `Import as Route` switch that defaults off.
- The import pipeline accepts an `importAsRoute` flag end to end and returns a shared import result contract.
- Route conversion produces valid normalized route GPX, stores it as a `Route` entity, and keeps it out of the track repository.
- The fixed `RouteUI` defaults exist and are used for route conversion.
- Updated widget, service, and robot tests pass.
</done_when>
