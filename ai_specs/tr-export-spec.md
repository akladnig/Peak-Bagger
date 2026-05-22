<goal>
Add an export action to the existing tracks/routes end drawer so the currently selected track or route can be saved as a GPX file in the expected desktop folder.

Who: desktop users working with imported GPX tracks and routes.

Why: they need a direct, reliable way to export one selected item from the app without changing map selection behavior or adding new export state.
</goal>

<background>
Desktop Flutter app using Riverpod, ObjectBox, `flutter_map`, and existing drawer/end-drawer patterns.

The current drawer surface is `./lib/widgets/map_tracks_routes_drawer.dart`, and map state already exposes `selectedTrackId`, `selectedRouteId`, `showTracks`, and `showRoutes` in `./lib/providers/map_provider.dart`.

Routes materialize coordinates into `gpxRoute` and expose `gpxRouteJson` as a derived helper in `./lib/models/route.dart`; there is no route export helper yet.

The app already uses `showDangerConfirmDialog` in `./lib/widgets/dialog_helpers.dart` for destructive confirmations and `ScaffoldMessenger` snackbars for export feedback in other screens.

Files to examine:
- `./lib/widgets/map_tracks_routes_drawer.dart`
- `./lib/providers/map_provider.dart`
- `./lib/models/route.dart`
- `./lib/models/gpx_track.dart`
- `./lib/widgets/dialog_helpers.dart`
- `./lib/screens/map_screen.dart`
- `./lib/services/peak_csv_export_service.dart`
- `./lib/services/peak_list_csv_export_service.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./test/widget/map_tracks_routes_drawer_test.dart`
- `./test/widget/map_screen_route_info_test.dart`
- `./test/providers/map_provider_selected_route_test.dart`
- `./test/robot/map/route_info_journey_test.dart`
- `./test/robot/map/route_info_robot.dart`
- `./test/harness/test_map_notifier.dart`
</background>

<user_flows>
Primary flow:
1. User selects one track or one route using the existing map selection behavior.
2. User opens the tracks/routes end drawer.
3. User taps export.
4. App resolves the selected item, prompts if the destination file already exists, then writes a GPX file to the correct default directory.
5. App shows a snackbar confirming success.

Alternative flows:
- No selection: the export control is disabled and indicates that a track or route must be selected first.
- Track selected: export writes the track's stored `gpxFile` XML to `~/Downloads`.
- Route selected: export writes a standalone GPX route file from the loaded `route.gpxRoute` points to `~/Documents/Bushwalking/routes`.
- Existing file: user confirms overwrite or cancels without changing the file.

Error flows:
- Missing or invalid GPX payload: export aborts and shows a snackbar failure message.
- File creation, directory creation, or file writing fails: export aborts and shows a snackbar failure message.
- User cancels the overwrite prompt: no file is changed and no success snackbar is shown.
</user_flows>

<requirements>
Stable IDs: `F1` to `F10`, `E1` to `E5`, `X1` to `X5`, `V1` to `V5`.

**Functional:**
1. Add a single export control to the bottom of `./lib/widgets/map_tracks_routes_drawer.dart`.
2. The export control acts on the currently selected item only. Do not add a separate export selection model or bulk export behavior.
3. When the active selection is a track, export the track's canonical `gpxFile` XML to `~/Downloads/<track-stem>.gpx`. `gpxFile` is the only track payload eligible for export in this slice; `gpxFileRepaired` and `filteredTrack` are not export sources.
4. When the active selection is a route, export a standalone valid GPX 1.1 route file to `~/Documents/Bushwalking/routes/<route-stem>.gpx` using the loaded `route.gpxRoute` points. The exported GPX `<name>` must exactly match the filename stem. If the loaded point list is empty, or the normalized route name is blank, treat that as an export failure.
5. Create destination directories recursively when they do not exist.
6. The route GPX file must contain one `<rte>` element with the route name and one `<rtept>` per valid coordinate. Preserve coordinate order from the model and map latitude/longitude into GPX `lat`/`lon` attributes.
   - Root the document in `<gpx version="1.1" creator="peak-bagger" xmlns="http://www.topografix.com/GPX/1/1">` and close it with `</gpx>`.
   - XML-escape the route name and point attribute values.
   - Include `<author><name>Adrian Kladnig</name></author>` in the GPX metadata.
   - Include an `<ele>` element inside each `<rtept>` when a point elevation is available; otherwise omit `<ele>` rather than inventing values.
7. If the target file already exists, prompt before overwriting and do not replace the file unless the user confirms.
8. On successful export, show a snackbar that confirms the saved file.
9. Keep export logic isolated in a small service/helper so the widget stays thin and testable.
10. Do not change track/route selection semantics, drawer mode semantics, or map visibility behavior as part of this slice.

**Error Handling:**
1. If no selectable track or route is currently active, or the selected entity cannot be resolved from the repository, disable the export control.
2. If a selected route contains no valid coordinates after parsing, abort the export and show a snackbar failure.
3. If a selected track has no writable GPX payload, abort the export and show a snackbar failure.
4. If directory creation or file writing fails, surface the failure in a snackbar and leave existing files unchanged.
5. If the user cancels the overwrite prompt, stop the export with no file changes.

**Edge Cases:**
1. File stems must be filesystem-safe and derived from the selected item name, with a readable fallback when the name is blank.
   - Trim the name.
   - Replace whitespace and path separators with `-`.
   - Remove other unsafe filename characters.
   - Collapse repeated separators.
   - Use `track-export` if a track name sanitizes to empty.
   - Do not use a blank fallback for route exports; if the sanitized route name is empty, the export fails.
2. Route names and GPX XML content must escape special characters correctly.
3. If both `selectedTrackId` and `selectedRouteId` are non-null due to a bug, rely on the existing notifier contract rather than inventing tie-breaking state.
4. Export should remain responsive and not add custom loading UI beyond the existing snackbar/dialog flow.
5. If two different items normalize to the same filename stem, the overwrite prompt is the only collision resolution in this slice; do not auto-suffix filenames.
6. Resolve the export target from `mapProvider`'s `selectedTrackId` / `selectedRouteId`, then load the concrete track or route entity from the existing repository before exporting.
7. The same export surface must work from the drawer whether it is opened from `EndDrawerMode.tracksRoutes` or from a test harness.

**Validation:**
1. Add stable selectors for the new UI. Existing selector: `Key('tracks-routes-drawer')`. New selectors: `Key('tracks-routes-export-button')`, `Key('tracks-routes-export-confirm')`, and `Key('tracks-routes-export-cancel')`.
2. Keep validation split explicit: unit tests for pure serialization and path logic, widget tests for drawer state and dialog/snackbar reactions, and robot-driven journey tests for the critical export flow.
3. If a pure GPX route serializer is extracted, unit test it directly against the loaded `List<LatLng>` route points with deterministic exact-string assertions.
4. Unit tests must cover valid route point lists, blank route names, malformed legacy route payloads that decode to an empty point list, and filesystem-safe filename derivation.
5. Widget tests must cover disabled export with no selection, track export, route export, overwrite confirmation, cancel behavior, success snackbar, and failure snackbar.
6. Robot tests must cover the end-to-end happy path from selection to drawer export to snackbar for both track and route branches if the harness can drive both deterministically.
7. Baseline automated coverage outcomes:
   - logic/business rules: unit tests
   - UI behavior and state reactions: widget tests
   - critical user journey: robot-driven test
</requirements>

<boundaries>
Edge cases:
- This is a single-item export feature, not a bulk export workflow.
- The app already has mutually exclusive track/route selection semantics; do not add new selection resolution state.
- The route export file must be a real GPX route document, not a JSON dump with a `.gpx` extension.

Error scenarios:
- A missing home directory or unavailable export directory should fail fast with user-visible feedback.
- A confirmed overwrite must replace the existing file in place rather than creating a second copy.
- User cancellation must leave the filesystem untouched.

Limits:
- No new persistence for export preferences.
- No background export job or progress UI.
- No change to map rendering, route drawing, or track drawing behavior.
</boundaries>

<implementation>
1. Modify `./lib/widgets/map_tracks_routes_drawer.dart` to add the export action and hook it into the current selection contract.
2. Add a small export service/helper under `./lib/services/gpx_export_service.dart` for track file writing and route GPX generation. Use explicit constructor-injected seams for path resolution and file writing so the logic can be unit tested without the filesystem. The service must support a plan-then-write flow: first return the resolved output path and serialized GPX text, then write only after the widget confirms overwrite if the target already exists.
3. If Riverpod wiring is useful, add a narrow provider wrapper in `./lib/providers/gpx_export_provider.dart`; do not assume an existing CSV export provider pattern.
4. Reuse `./lib/widgets/dialog_helpers.dart` for overwrite confirmation.
5. Use `ScaffoldMessenger` for export feedback, matching the existing app pattern.
6. Add tests in `./test/services/`, `./test/widget/`, and `./test/robot/map/` with stable keys and deterministic fixtures.
7. Avoid adding new global state, and avoid pushing file-I/O logic directly into the widget tree.
</implementation>

<stages>
Phase 1: Build the export service/helper and GPX route serializer. Verify track export writes the existing GPX payload, route export emits valid GPX 1.1 XML, and filename/path logic is deterministic.

Phase 2: Wire the drawer UI to the current selection contract. Verify the export control appears at the bottom of the drawer, disables cleanly with no selection, and prompts before overwrite.

Phase 3: Add widget and robot coverage. Verify success/failure snackbars, overwrite confirmation/cancel behavior, and the end-to-end export journey from selection to saved file.
</stages>

<done_when>
1. The drawer contains a usable export action for the currently selected track or route.
2. Track exports land in `~/Downloads` and route exports land in `~/Documents/Bushwalking/routes`.
3. Route exports are valid GPX route files built from `route.gpxRoute`.
4. Existing files prompt before overwrite.
5. Users get snackbar feedback on success or failure.
6. Tests cover serialization, drawer behavior, confirmation handling, and the end-to-end export journey.
</done_when>
