<goal>
Add Peak-only edit and delete capability to ObjectBox Admin so maintainers can correct Peak metadata in place without leaving the admin browser.

This matters because the admin surface is already the in-app maintenance tool for local ObjectBox data, and Peak rows carry coordinate data that needs careful correction without changing the read-only behavior for other entities.
</goal>

<background>
Flutter app with Riverpod, GoRouter, ObjectBox, and the existing admin browser already split into screen-scoped widgets.

Relevant files to examine:
- @lib/screens/objectbox_admin_screen.dart
- @lib/screens/objectbox_admin_screen_details.dart
- @lib/screens/objectbox_admin_screen_table.dart
- @lib/screens/objectbox_admin_screen_states.dart
- @lib/providers/objectbox_admin_provider.dart
- @lib/providers/peak_provider.dart
- @lib/services/objectbox_admin_repository.dart
- @lib/services/peak_repository.dart
- @lib/services/peak_delete_guard.dart
- @lib/services/peak_mgrs_converter.dart
- @lib/models/geo_areas.dart
- @lib/widgets/dialog_helpers.dart
- @lib/screens/peak_lists_screen.dart
- @test/harness/test_objectbox_admin_repository.dart
- @test/harness/test_peak_repository.dart
- @test/robot/objectbox_admin/objectbox_admin_robot.dart
- @test/robot/objectbox_admin/objectbox_admin_journey_test.dart
- @test/widget/objectbox_admin_shell_test.dart
- @test/widget/objectbox_admin_browser_test.dart
- @test/services/objectbox_admin_repository_test.dart
</background>

<discovery>
- Confirm Peak-only edit/delete behavior stays isolated to the `Peak` entity and does not add mutation affordances to other ObjectBox entities.
- Confirm the editable Peak field set is explicit before coding the form: `id` and `gridZoneDesignator` stay read-only, while the other displayed Peak fields use inline controls.
- Confirm Peak save/delete goes through `PeakRepository` via `peakRepositoryProvider`, while `ObjectBoxAdminRepository` stays read-only for browsing.
- Confirm Peak delete dependency checks go through a dedicated `PeakDeleteGuard` service that can inspect `GpxTrack` and `PeaksBagged`, exposed through `peakDeleteGuardProvider` in `./lib/providers/peak_provider.dart` and backed by `objectboxStore` at runtime while remaining overridable in widget tests.
- Confirm the current provider refresh/selection behavior so save can keep the edited Peak selected and delete can clear only the removed selection.
- Confirm the coordinate conversion path can reuse existing MGRS helpers and `mgrs_dart` without adding packages.
- Confirm stable selectors for the new edit, submit, field, and delete controls before wiring the UI.
</discovery>

<user_flows>
Primary flow:
1. User opens ObjectBox Admin and selects a Peak row.
2. User taps the edit FAB in the details pane.
3. User edits the Peak fields, with `id` and `gridZoneDesignator` remaining read-only.
4. User submits the form.
5. If validation passes, the Peak is saved, the success dialog appears, and the refreshed details remain on the edited Peak.
6. User closes the success dialog and sees the updated Peak data.

Alternative flows:
- Non-Peak entity flow: the admin browser stays read-only for all other entities and shows no edit/delete controls.
- Delete flow: the user deletes a Peak from the data table actions column after confirming the danger dialog.
- Row-change flow: the user selects a different Peak or closes the details pane, and any unsaved edits are discarded.
- Coordinate-entry flow: the user may enter either complete coordinate representation; if both are entered, the entered latitude/longitude are discarded and save derives latitude/longitude from the MGRS values.

Error flows:
- Invalid numeric or MGRS input: the form shows inline field errors and blocks submit.
- Location outside Tasmania: the form shows `Entered location is not with Tasmania.` and blocks submit.
- Save failure: the editor stays open and surfaces the persistence error instead of clearing the form.
- Delete cancel: the confirmation dialog closes with no data change.
</user_flows>

<requirements>
**Functional:**
1. Add a Peak-only edit affordance to the right-side details pane in `./lib/screens/objectbox_admin_screen_details.dart`, with an edit FAB placed to the left of the close icon.
2. Render Peak fields in edit mode as inline form controls, not a modal dialog, and keep `id` and `gridZoneDesignator` read-only while allowing the remaining Peak fields to be edited inline.
3. Render `sourceOfTruth` as read-only text with a one-way `mark as HWC` control that saves as `HWC` on edit save.
4. Treat `gridZoneDesignator` as fixed to `55G` for Peak editing, keep it read-only in the form, and persist `55G` on save.
5. Keep all other ObjectBox entities browse-only and unchanged.
6. Add a Peak-only actions column in `./lib/screens/objectbox_admin_screen_table.dart` with a per-row delete icon, pinned for Peak data rows only, and use the same confirm-dialog pattern used by Peak Lists, including stable cancel/confirm dialog keys.
   The delete confirmation dialog must use title `Delete Peak?` and message `This will permanently delete the <peak name>. Do you want to proceed?`.
7. Wire Peak save and delete through `PeakRepository` via `./lib/providers/peak_provider.dart`, while keeping `ObjectBoxAdminRepository` read-only for browsing.
8. Preserve current browse/search/sort/detail-pane behavior for existing read-only admin flows.
9. After a successful Peak save, show `showSingleActionDialog` with title `Update Successful` and content text `<name> updated.` using the saved Peak name.
10. If saving an `osmId` change would conflict with another Peak, show `showSingleActionDialog` with title `Error: cannot change osmId` and content `This osmId is already tied to NameOfPeak, so cannot be over written.` where `NameOfPeak` is the name of the conflicting Peak, and do not count the Peak currently being edited as a conflict.
11. If an `osmId` change succeeds, update `PeaksBagged.peakId` from the old `osmId` to the new `osmId` and update any Peak List `peakOsmId` references from the old `osmId` to the new `osmId` in the same transaction so dependent records stay in sync.
    `PeakRepository` may access the ObjectBox `Store` directly to read and rewrite `PeakList` rows for this cascade.
     Add a `PeakListRewritePort` interface and inject it into `PeakRepository` so repository tests can exercise the cascade path without a live ObjectBox store.
    `PeakRepository` must accept the port in its constructor, production must provide the Store-backed implementation, and tests must be able to inject a fake port alongside `PeakStorage`.
    Production wiring for the Store-backed port should live in `./lib/providers/peak_provider.dart`, and the port implementation should be created from `objectboxStore`.
     Use `PeakRepository(Store store, {required PeakListRewritePort peakListRewritePort})` in production and `PeakRepository.test(PeakStorage storage, {required PeakListRewritePort peakListRewritePort})` in tests.
     The port must expose `rewriteOsmIdReferences({required int oldOsmId, required int newOsmId})` and return a result containing `rewrittenCount` and `skippedMalformedCount`.
     For Peak List updates, parse each `PeakList.peakList` JSON payload, rewrite only the matching `peakOsmId` values, preserve item order and `points`, skip malformed payloads unchanged, and append a warning section below the success message in the same success dialog after the save completes.
12. Preserve row selection by Peak primary key across save refreshes, and after delete keep the current selection if the selected Peak still exists or clear it only when the deleted Peak was the selected row.

**Error Handling:**
13. Validate `latitude` as a number between `-90.0` and `90.0` and show the exact error message `Latitude must be a number between -90.0 and 90.0`.
14. Validate `longitude` as a number between `-180.0` and `180.0` and show the exact error message `Longitude must be a number between -180.0 and 180.0`.
15. Validate `easting` as a 1 to 5 digit number and show the exact warning `easting must be a 1-5 digit number`.
16. Validate `northing` as a 1 to 5 digit number and show the exact warning `northing must be a 1-5 digit number`.
17. Validate `mgrs100kId` as exactly two letters and show the exact warning `The MGRS 100km identifier must be exactly two letter`.
18. Validate the resulting Peak location against `GeoAreas.tasmaniaBounds` after coordinate normalization, and block submit if the location is outside Tasmania.
19. Show validation errors inline beside the affected field or coordinate section, and recompute them live as the user types.
20. Keep the edit form open on any save or delete failure, surface the error in the same screen context, and disable the in-flight Peak mutation controls until the request completes.
21. Block delete when the Peak is still referenced by any `GpxTrack.peaks` relation, any Peak List `peakOsmId` entry, or any `PeaksBagged.peakId` row, and surface a dependency error that names the dependent record types.
22. Use a dedicated `PeakDeleteGuard` service for delete dependency checks before calling `PeakRepository.delete`.
23. `PeakDeleteGuard` returns a structured result containing blocker descriptors with a dependency type and display name, ordered deterministically as `GpxTrack` blockers first, `PeakList` blockers second, and `PeaksBagged` blockers third, so the UI can compose the delete-blocked dialog copy without guessing.
    Use `trackName` for `GpxTrack`, `name` for `PeakList`, and a fixed human label such as `bagged record` for `PeaksBagged`.
24. In widget tests, override `peakDeleteGuardProvider` with a fake guard so dependency-blocked delete remains deterministic without a live ObjectBox store.
25. Ignore malformed `PeakList.peakList` JSON payloads when computing delete blockers.
26. Validate `name` as required with the exact error message `A peak name is required`.
27. Validate `osmId` as an integer.
28. Treat `elevation` as optional; if blank, keep it `null`, and if provided it must parse as an integer.
29. Allow `area` to be blank or any string.
30. If any Peak List rewrites are skipped because their payloads are malformed, append the exact warning `1 PeakList has been skipped as it's malformed.` when one PeakList is skipped, or `X PeakLists have been skipped as they're malformed.` when more than one PeakList is skipped.

**Edge Cases:**
31. Coordinate contract:
    - either complete coordinate representation may be supplied at submit time;
    - if latitude/longitude are entered, derive `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` from them on save;
    - if MGRS fields are entered, derive `latitude` and `longitude` from them on save;
   - if both representations are entered, discard the entered latitude/longitude and derive all saved coordinates from the MGRS fields;
   - partial mixed input is invalid and must be rejected inline.
32. Preserving the edited Peak selection after a successful save must also preserve any cascaded `PeaksBagged.peakId` updates.
33. Clear selection only when the deleted Peak was the selected row; keep any other selection intact after deleting a different row.
34. Reset unsaved edit state when the selected Peak changes, the details pane closes, or the row is deleted.
35. Preserve the current read-only admin UX for `Tasmap50k`, `GpxTrack`, and `PeakList`.

**Validation:**
36. Add deterministic unit tests for the pure Peak-edit helper covering parsing, Tasmania bounds checks, MGRS derivation, and the coordinate source-of-truth rules.
37. Add deterministic unit tests for `PeakDeleteGuard` covering dependency checks against `GpxTrack`, `PeakList`, and `PeaksBagged`.
38. Add a Peak List rewrite seam to `PeakRepository` so tests can cover `osmId` cascade updates without a live ObjectBox store.
39. Add deterministic unit tests for `osmId` cascade updates into `PeaksBagged.peakId`.
40. Add widget tests for Peak edit mode, inline validation, successful save dialog, delete confirmation, dependency-blocked delete, delete-row refresh behavior, and the Peak-only visibility of edit/delete affordances.
41. Add a robot-driven journey test for the Peak edit/save happy path from the admin shell.
42. Use stable, app-owned `Key` selectors for the edit FAB, submit button, editable Peak fields, and Peak delete actions.
43. Keep the test seam deterministic by using the existing `objectboxAdminProvider` refresh flow plus the `peakRepositoryProvider` override and a mutable fake Peak repository that mirrors save/delete behavior in memory.
</requirements>

<boundaries>
Edge cases:
- `id` and `gridZoneDesignator` are visible but not editable.
- `sourceOfTruth` is read-only text with a one-way `mark as HWC` control, and any edit save must persist `HWC`.
- If latitude/longitude and MGRS are both entered, save uses MGRS and discards the entered latitude/longitude.
- If the stored or derived location cannot be resolved into a valid Tasmania location, the save is rejected inline.
- If the user deletes the selected Peak, the details pane closes after refresh.
- If the user deletes a non-selected Peak, the current selection should stay on the still-existing row.
- The Peak actions column is pinned and visible only for Peak data rows.
- The Peak actions column has a `Delete` header, stays fixed on the right, and scrolls vertically with the table rows.
- User-entered coordinate values remain visible until submit, then normalize after a successful save.
- After an `osmId` conflict dialog is closed, the edited Peak remains selected.
- Tasmania validation implies the only valid `gridZoneDesignator` value is `55G`.
- If dependency-blocked delete has more than two blockers, the dialog body lists every blocker name in the same deterministic sentence rather than truncating.
- `sourceOfTruth` is a one-way control that always saves as `HWC` on edit save.
- Peak row selection and delete targeting use `Peak.id` / `primaryKeyValue`; `Peak.osmId` is reserved for uniqueness checks and `PeaksBagged.peakId` cascade updates.

Error scenarios:
- Blank or partially filled coordinate groups are invalid.
- ObjectBox unique-constraint or save/delete failures must surface visibly and not silently fall through.
- Dependency-blocked delete must leave the Peak in place and tell the user why the delete was refused.
- Delete confirmation cancel returns without changing the store or the selection.
- The exact validation copy requested by the task must not be rewritten or normalized.
- `PeakDeleteGuard` should be exposed through `peakDeleteGuardProvider`, backed by `objectboxStore` at runtime and overridable in widget tests, and injected into the Peak delete flow before mutation.
- Dependency-blocked delete should use `showSingleActionDialog` with title `Delete Blocked`, a close button keyed `objectbox-admin-peak-delete-blocked-close`, and body text generated from the structured blocker result: one blocker shows a single blocker message with that dependency name; two blockers show both blocker names in the same dialog body; three or more blockers list all blocker names in the same deterministic sentence.

Limits:
- No new dependencies.
- No router or shell-branch changes.
- No redesign of the general ObjectBox Admin browsing layout.
- No mutation support for non-Peak entities in this pass.
- No network dependency.
</boundaries>

<implementation>
Modify `./lib/services/peak_repository.dart` to add Peak save/delete methods backed by the ObjectBox store and to keep mutation behavior consistent with the existing Peak write seam.

Modify `./lib/providers/objectbox_admin_provider.dart` so the admin browser can refresh rows while preserving the selected Peak after save, and clear selection only when the selected row no longer exists.

Create `./lib/services/peak_admin_editor.dart` as a pure helper for Peak edit drafts, parsing, validation, coordinate derivation, and Tasmania-bounds checks.

Modify `./lib/screens/objectbox_admin_screen.dart` to wire Peak save/delete callbacks, keep route/search/sort behavior unchanged, and refresh the browser after mutations.

Modify `./lib/screens/objectbox_admin_screen_details.dart` to add Peak edit mode, the edit FAB, inline form controls, inline validation text, submit handling, and edit-state reset on row changes.

Modify `./lib/screens/objectbox_admin_screen_table.dart` to add a Peak-only actions column and per-row delete icon buttons.

Modify `./test/harness/test_peak_repository.dart` so the fake Peak repository mutates Peak rows in memory and returns the updated rows on refresh.

Update `./test/services/peak_repository_test.dart` for Peak save/delete behavior, including dependency-guarded delete.

Add `./test/services/peak_delete_guard_test.dart` for dependency checks against `GpxTrack` and `PeaksBagged`.

Add `./test/services/peak_admin_editor_test.dart` for the pure Peak-edit helper.

Update `./test/widget/objectbox_admin_shell_test.dart` and `./test/widget/objectbox_admin_browser_test.dart` for the new edit/delete controls, inline validation, and selection retention.

Update `./test/robot/objectbox_admin/objectbox_admin_robot.dart` and `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` for the Peak edit/save journey.

Selectors to add or preserve:
- Preserve the existing `objectbox-admin-*` selectors already used by the current shell and browser tests.
- Add a stable key for the edit FAB, for example `objectbox-admin-peak-edit`.
- Add a stable key for the submit button, for example `objectbox-admin-peak-submit`.
- Add stable keys for the editable Peak fields, using field-specific names such as `objectbox-admin-peak-name`, `objectbox-admin-peak-osm-id`, `objectbox-admin-peak-elevation`, `objectbox-admin-peak-latitude`, `objectbox-admin-peak-longitude`, `objectbox-admin-peak-area`, `objectbox-admin-peak-mgrs100k-id`, `objectbox-admin-peak-easting`, `objectbox-admin-peak-northing`, and `objectbox-admin-peak-source-of-truth`.
- Add row-specific delete keys derived from the Peak primary key, for example `objectbox-admin-peak-delete-<id>`.
- Reuse the existing danger-dialog action keys `cancel-delete` and `confirm-delete` for Peak delete confirmation.
- Use `showSingleActionDialog` for dependency-blocked delete and `osmId` conflict failures.

Implementation notes:
- Keep the admin screen as the coordinator for route visibility, provider refresh, and dialog side effects.
- Keep the edit form local to the details pane rather than moving Peak edit state into the global browser provider.
- Reuse `showDangerConfirmDialog` and `showSingleActionDialog` from `./lib/widgets/dialog_helpers.dart`.
- Reuse existing MGRS helpers instead of introducing another coordinate library.
- Inject `PeakDeleteGuard` into the Peak delete path so delete checks stay separate from Peak row storage.
- Expose `PeakDeleteGuard` through `peakDeleteGuardProvider`, backed by `objectboxStore`, and inject that provider into the Peak delete flow before mutation.
- Keep the `osmId` cascade update inside `PeakRepository` in the same ObjectBox transaction so `PeaksBagged.peakId` stays in sync with the edited Peak.
- Reuse `PeakRepository` as the persistence seam for Peak edits and deletes, and expose it through the existing `peakRepositoryProvider`.
- Keep the Peak edit helper pure so unit tests can cover the full validation matrix without a live store.
</implementation>

<stages>
Phase 1: Lock down the Peak edit contract.
- Confirm the save/delete repository methods, selection-retention behavior, and selector names before coding the UI.
- Add the pure Peak-edit helper and unit tests first.

Phase 2: Wire persistence.
- Add Peak save/delete methods to `PeakRepository` and the mutable fake Peak repository.
- Add `./lib/services/peak_delete_guard.dart` for dependency checks before delete, and have Peak delete use it.
- Verify save/delete mutation paths with focused tests before changing the UI.

Phase 3: Add the editable Peak UI.
- Add the details-pane edit mode and the Peak table actions column.
- Verify inline validation, Tasmania rejection, and the success dialog before broadening the test surface.

Phase 4: Hardening.
- Add the robot journey for edit/save, update shell/browser regressions, and run the full analysis and test suite.
- Verify selection retention, delete behavior, and no-regression behavior for the other admin entities.
</stages>

<illustrations>
Desired:
- Selecting a Peak exposes an edit FAB and a delete icon in the row actions column, but other entities stay unchanged.
- Saving a Peak updates the stored record, shows the success dialog, and keeps the edited Peak selected.
- Invalid coordinate input stays inline and does not mutate ObjectBox.

Avoid:
- Modal edit dialogs for Peak editing.
- Moving Peak edit state into the global admin provider just to make the form work.
- Changing the read-only admin browsing model for non-Peak entities.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: the Peak-edit helper must have unit coverage for parsing, validation, MGRS derivation, and Tasmania-bounds enforcement.
- UI behavior: widget tests must cover Peak edit mode, inline errors, success dialog, delete confirmation, and selection refresh.
- Critical journey: robot coverage must prove a user can open ObjectBox Admin, select a Peak, edit it, submit it, and see the success state.

TDD expectations:
- Build the feature in vertical slices: helper logic first, repository mutation next, then Peak edit UI, then delete UI, then hardening.
- Write one failing test at a time and implement only enough code to make it pass before moving to the next slice.
- Prefer fakes and pure helpers over mocks; mock only true external boundaries.
- Keep async and selection behavior deterministic through explicit provider overrides and mutable fake repository state.

Robot/widget/unit split:
- Robot tests: cover the Peak edit/save happy path through the admin shell.
- Widget tests: cover field-level validation, Tasmania rejection, save dialog content, delete confirmation, and row refresh after delete.
- Unit tests: cover the pure Peak-edit helper and any row-to-peak conversion logic used before save.

Verification commands:
- `flutter test test/services/peak_admin_editor_test.dart`
- `flutter test test/widget/objectbox_admin_shell_test.dart`
- `flutter test test/widget/objectbox_admin_browser_test.dart`
- `flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- Peak rows in ObjectBox Admin can be edited inline and deleted from the table actions column.
- `id` and `gridZoneDesignator` are not user-editable, and all non-Peak entities remain read-only.
- Validation is inline, Tasmania-aware, and blocks invalid saves.
- Successful Peak saves show the requested update dialog and keep the edited row selected.
- Delete uses the existing danger-confirm pattern and refreshes the table correctly.
- The new unit, widget, and robot tests pass, along with `flutter analyze` and the full test suite.
</done_when>
