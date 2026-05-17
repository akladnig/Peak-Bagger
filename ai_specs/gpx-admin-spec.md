<goal>
Update ObjectBox Admin so `GpxTrack` rows are easier to inspect and manage. Admins should be able to view a track on the main map, delete a track from admin, and read duration/XML fields without huge multiline noise.
</goal>

<background>
Flutter app using Riverpod and ObjectBox admin UI.

Relevant files:
- `./ai_specs/gpx-admin.md`
- `./lib/models/gpx_track.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/screens/objectbox_admin_screen_details.dart`
- `./lib/screens/objectbox_admin_screen_table.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/providers/map_provider.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/widget/objectbox_admin_browser_test.dart`
- `./test/robot/objectbox_admin/objectbox_admin_robot.dart`
- `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

Existing Peak patterns to mirror:
- Peak row delete button uses the table actions column.
- Peak details header uses the visibility icon for map navigation.
- Shared admin field formatting already lives in `objectbox_admin_repository.dart`.
- Peak delete confirmation already uses `showDangerConfirmDialog`.
</background>

<user_flows>
Primary flow:
1. User opens ObjectBox Admin and selects `GpxTrack`.
2. User sees track rows with a Delete action in the table actions column.
3. User selects a track row and sees the details pane with a View icon.
4. User taps View and the app opens the main map focused on that track.
5. User taps Delete, confirms, and the row disappears from admin.

Alternative flows:
1. Browse-only inspection: user selects a track and reads the row without opening the map.
2. Long GPX payloads: user views `gpxFile` or `filteredTrack` and only the first five lines are shown.
3. Null durations: user sees a placeholder instead of a bogus time string.

Error flows:
1. Delete canceled: no state changes.
2. View target unavailable: no crash, admin remains usable.
3. Track already removed or stale row: delete completes safely or refreshes to the latest state.
</user_flows>

<requirements>
**Functional:**
1. Format `totalTimeMillis`, `movingTime`, `restingTime`, and `pausedTime` as `hh:mm:ss` wherever `GpxTrack` values are rendered in ObjectBox Admin.
2. Show a Delete action for `GpxTrack` rows using the same table actions-column pattern as Peak rows, with stable key `objectbox-admin-gpx-track-delete-<gpxTrackId>`.
3. Show a View icon in the `GpxTrack` details header using the same icon-button pattern as Peak, with stable key `objectbox-admin-gpx-track-view-on-map`.
4. Wire the View icon to existing map navigation by calling `showTrack(trackId)` and then routing to `/map`; if the track is missing, treat the action as a no-op and keep the admin screen usable.
5. Render `gpxFile` and `filteredTrack` only in the details view as non-selectable text with `maxLines: 5` and ellipsis/clipping overflow.
6. Preserve stored values, schema, and non-`GpxTrack` admin behavior.

**Error Handling:**
7. Keep null duration values readable, using the existing placeholder style rather than raw null/zero output.
8. Delete must confirm with `showDangerConfirmDialog`, using the Peak delete dialog wording with `Track` and `trackName` substituted for `Peak` and `name`, call the existing `GpxTrackRepository.deleteTrack(trackId)` path, and refresh admin state so the deleted row is no longer shown. The map cleanup helper must be named `MapNotifier.deleteTrack(trackId)`; if the deleted track is currently loaded or selected in map state, remove it from `tracks`, clear `selectedTrackId`, `selectedLocation`, and `hoveredTrackId`, invalidate `selectedTrackFocusSerial`, and recompute `showTracks` so the visible map state updates consistently.

**Edge Cases:**
9. Duration formatting must work for values longer than 24 hours.
10. Line limiting must be line-aware, not just character-aware.
11. `GpxTrack` rows must not inherit Peak delete-blocker logic.
12. Only the details-view `gpxFile` and `filteredTrack` fields are line-capped in this slice; other large `GpxTrack` fields stay on their existing rendering path unless they already share a helper.
13. Existing Peak admin keys, actions, and edit behavior must stay unchanged.

**Validation:**
13. Add unit coverage for the formatting helpers in `test/services/objectbox_admin_repository_test.dart`.
14. Add widget coverage for `GpxTrack` actions and details-view truncation in `test/widget/objectbox_admin_shell_test.dart` and `test/widget/objectbox_admin_browser_test.dart`.
15. Add robot coverage for the critical `GpxTrack` admin journey in `test/robot/objectbox_admin/objectbox_admin_journey_test.dart`.
16. Add explicit edge-case checks for delete cancel, stale/missing view targets, deleting the selected track, and duration values longer than 24 hours.
17. Use public UI/service APIs only; do not test private widget methods.
</requirements>

<boundaries>
Edge cases:
1. Do not mutate the stored GPX text, only its admin presentation.
2. Do not change Peak behavior except for shared formatting helpers that must stay backward-compatible.
3. Do not add new dependencies or schema fields.
4. Do not introduce line-capping behavior for GPX fields beyond the details-view `gpxFile` and `filteredTrack` fields unless a shared helper already covers them.
5. Do not add a second delete-confirmation helper when `showDangerConfirmDialog` already exists.

Error scenarios:
1. Missing or empty GPX text should still render safely.
2. Large XML payloads should not expand the details view beyond the intended five-line cap.
3. A delete that races with external data changes should fail gracefully through existing refresh behavior.
4. If a deleted track was active on the map, the cleanup path must leave no stale `tracks` entry, no stale selection, and a recomputed `showTracks` value.

Limits:
1. This slice is limited to ObjectBox Admin presentation and row actions.
2. No GPX import, parsing, or map rendering redesign is in scope.
</boundaries>

<discovery>
Before implementing, inspect:
1. `./lib/screens/objectbox_admin_screen_table.dart` for the Peak-only actions-column gate.
2. `./lib/screens/objectbox_admin_screen_details.dart` for the Peak view icon pattern and read-only details rendering.
3. `./lib/screens/objectbox_admin_screen.dart` for the main-map navigation hook.
4. `./lib/services/objectbox_admin_repository.dart` for shared field formatting and preview helpers.
5. `./lib/providers/map_provider.dart` for the existing `showTrack` API.
</discovery>

<implementation>
Modify:
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/screens/objectbox_admin_screen_table.dart`
- `./lib/screens/objectbox_admin_screen_details.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/providers/map_provider.dart`

Recommended approach:
1. Add `GpxTrack`-aware formatting helpers for duration fields and line-limited multiline fields.
2. Extend the table actions-column gate so `GpxTrack` gets the Delete button.
3. Extend the details header so `GpxTrack` gets the View button.
4. Route the View action through the existing `showTrack(trackId)` + `/map` flow, and add a tiny map-state helper such as `removeTrack(trackId)` for pruning a deleted track from in-memory map state if that track is currently loaded or selected.
5. Reuse `showDangerConfirmDialog` for both Peak and GpxTrack delete flows instead of introducing a new dialog API.
6. Add stable keys for the new `GpxTrack` controls so widget and robot tests can target them.

Avoid:
1. Do not duplicate formatting rules across multiple widgets if a shared helper can serve both.
2. Do not generalize Peak-specific edit behavior beyond this slice.
3. Do not hide the Delete action behind entity-specific privilege logic unless the app already has that concept.
</implementation>

<validation>
Follow vertical-slice TDD. One failing test, one minimal implementation, then refactor while green.

Behavior slices:
1. Duration formatting returns `hh:mm:ss` for each `GpxTrack` duration field.
2. `gpxFile` and `filteredTrack` render only in the details view as non-selectable text with `maxLines: 5` and ellipsis/clipping overflow.
3. `GpxTrack` rows expose a Delete action with key `objectbox-admin-gpx-track-delete-<gpxTrackId>`.
4. `GpxTrack` details expose a View action with key `objectbox-admin-gpx-track-view-on-map`.
5. View navigation reaches the main map track-selection path and routes to `/map`.
6. Delete removes the row, removes any in-memory instance of that track from map state, and refreshes admin state.
7. Delete cancel leaves the row and selection unchanged.
8. View tap on a missing track is a no-op.
9. Duration values longer than 24 hours still format correctly.
10. Existing Peak admin behavior stays green.

Test split:
1. Unit tests: formatting and field-value helpers.
2. Widget tests: table actions, details header controls, and details-view truncation.
3. Robot tests: the critical admin happy path for view and delete.

Required coverage outcomes:
1. Logic/business rules: duration formatting and line truncation helpers.
2. UI behavior: keyable buttons, visible line caps, confirm-delete flow.
3. Critical journey: select track, view it on the map, delete it from admin.
4. Map-state cleanup: deleting an active track via `MapNotifier.deleteTrack(trackId)` removes it from `tracks`, clears selection and hover state, invalidates focus serial state, and updates `showTracks` consistently.

Final verification:
1. `flutter test`
2. `flutter analyze`
</validation>

<stages>
Phase 1: Formatting
1. Add the shared `GpxTrack` field formatting behavior.
2. Verify with unit tests.

Phase 2: Admin controls
1. Add the `GpxTrack` delete action and view icon.
2. Verify with widget tests.

Phase 3: Journey coverage
1. Extend the ObjectBox admin robot helpers and journey test.
2. Verify the end-to-end admin flow with the full test suite.
</stages>

<done_when>
1. `GpxTrack` durations render as `hh:mm:ss`.
2. `GpxTrack` rows have a Delete action.
3. `GpxTrack` details have a View icon.
4. View opens the main map on the selected track.
5. `gpxFile` and `filteredTrack` are non-selectable details-view fields capped at five visible lines with ellipsis/clipping overflow.
6. Peak admin behavior remains unchanged.
7. Unit, widget, and robot tests cover the new behavior.
8. Deleting the active track leaves no stale track entry or selection in map state.
9. `flutter analyze` and `flutter test` pass.
</done_when>
