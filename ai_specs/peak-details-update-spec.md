<goal>
Update the ObjectBox Admin Peak edit UI so admins can safely edit either latitude/longitude or MGRS coordinates without leaving stale coordinate values in the opposite representation.

Admins benefit by having one clear coordinate source while editing, plus an explicit Calculate action that repopulates the cleared coordinate fields before Save. This reduces accidental mismatches between latitude/longitude and `mgrs100kId`/`easting`/`northing` when correcting Peak locations.
</goal>

<background>
This is a Flutter app using Riverpod, ObjectBox, `latlong2`, and `mgrs_dart`. The ObjectBox Admin Peak editor already has custom Peak edit/read-only UI, validation, coordinate conversion, and stable selectors.

Relevant files to examine:
- `./ai_specs/peak-details-update.md` - source task description
- `./pubspec.yaml` - confirms Flutter/ObjectBox/conversion dependencies
- `./lib/screens/objectbox_admin_screen_details.dart` - custom Peak details/edit form, controllers, submit flow, stable keys
- `./lib/services/peak_admin_editor.dart` - Peak form normalization, validation, and coordinate conversion during Save
- `./lib/services/peak_mgrs_converter.dart` - reusable MGRS/lat-lng conversion helpers
- `./lib/services/objectbox_admin_repository.dart` - row-to-Peak reconstruction and admin field metadata
- `./test/services/peak_admin_editor_test.dart` - unit coverage for Peak editor validation/conversion
- `./test/widget/objectbox_admin_shell_test.dart` - ObjectBox Admin widget/edit coverage
- `./test/robot/objectbox_admin/objectbox_admin_robot.dart` - robot helpers and stable selectors for admin journeys
- `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - critical ObjectBox Admin journeys

Existing behavior to preserve:
- Peak edit form order and existing fields remain unchanged except for the new Calculate button above Save.
- `gridZoneDesignator` stays read-only/fixed to `PeakAdminEditor.fixedGridZoneDesignator` (`55G`).
- Save still validates through `PeakAdminEditor.validateAndBuild` and still marks saved Peak data as HWC, but the implementation must preserve the active coordinate source chosen during this edit session when both coordinate groups are populated after Calculate.
- Active-source preservation should live in the editor layer, not the `Peak` model or repository. Use an explicit editor-layer coordinate source value, such as `PeakAdminCoordinateSource.latLng` / `PeakAdminCoordinateSource.mgrs`, and pass it into validation/calculation when needed.
- Existing field validation, duplicate `Alt Name` validation, `Verified`, `sourceOfTruth`, success dialogs, and map refresh behavior must continue to work.
</background>

<user_flows>
Primary flow:
1. Admin opens ObjectBox Admin.
2. Admin selects the `Peak` entity and opens a Peak row.
3. Admin enters edit mode.
4. Admin changes either `Latitude` or `Longitude`.
5. The form clears `mgrs100kId`, `easting`, and `northing` immediately after that first actual text change.
6. Admin clicks `Calculate`.
7. The form calculates MGRS fields from the current latitude/longitude and displays the calculated `mgrs100kId`, `easting`, and `northing` immediately.
8. Admin clicks `Save`.
9. The Peak is saved with synchronized latitude/longitude and MGRS values.

Alternative flows:
- MGRS-first edit: Admin changes `mgrs100kId`, `easting`, or `northing`; the form clears `Latitude` and `Longitude`; Calculate derives and displays latitude/longitude from MGRS.
- Create Peak flow: Admin creates a Peak, enters one complete coordinate representation, uses Calculate to populate the other representation, then saves.
- Change direction during edit: If the admin changes the opposite coordinate group after a first edit, the active source switches to the newly edited group and the previously calculated/source group is cleared according to the same rules.
- Existing complete Peak: On entering edit mode, both coordinate groups may be populated from the stored Peak. No field is cleared until the admin actually changes a coordinate field.

Error flows:
- Incomplete latitude/longitude source: Calculate shows existing coordinate validation feedback for missing or invalid latitude/longitude and leaves all fields unchanged.
- Incomplete MGRS source: Calculate shows field-level validation feedback for missing or invalid `mgrs100kId`, `easting`, or `northing` and leaves all fields unchanged from the moment before Calculate was pressed.
- Out-of-Tasmania calculated location: Calculate surfaces the existing Tasmania bounds error and leaves all fields unchanged.
- Conversion exception: Calculate handles conversion failures without throwing, displays field validation errors, and leaves existing field values unchanged.
</user_flows>

<requirements>
**Functional:**
1. Add a `Calculate` button to the custom Peak edit form in `./lib/screens/objectbox_admin_screen_details.dart` directly above the existing `Save` button.
2. Give the Calculate button a stable key: `objectbox-admin-peak-calculate`.
3. When the admin first changes `Latitude` or `Longitude` during the current edit session, clear `mgrs100kId`, `easting`, and `northing`.
4. When the admin first changes `mgrs100kId`, `easting`, or `northing` during the current edit session, clear `Latitude` and `Longitude`.
5. Clearing must happen on the first actual text change, not on focus/tap alone.
6. Clearing must not affect `gridZoneDesignator`; it remains read-only and fixed to `55G`.
7. Track the active coordinate source for the current edit session as either latitude/longitude or MGRS, based on the most recently changed coordinate group.
8. Calculate from latitude/longitude when the active source is latitude/longitude.
9. Calculate from MGRS when the active source is MGRS.
10. Calculate must update the cleared fields immediately in the visible form; it must not save automatically.
11. Calculate from latitude/longitude must populate uppercase `mgrs100kId` plus five-digit `easting` and `northing` values using the same conversion semantics as `PeakMgrsConverter.fromLatLng`.
12. Calculate from MGRS must accept 1-5 digit `easting` and `northing` source values, right-pad them to five digits before conversion (`123` becomes `12300`), and display the padded five-digit values in the form.
13. Calculate from MGRS must populate `Latitude` and `Longitude` using the same MGRS-to-point conversion semantics currently used by `PeakAdminEditor.validateAndBuild`, after source values are normalized and right-padded.
14. Latitude and longitude must be displayed with fixed precision of six decimal places everywhere they are rendered in Peak admin, including the edit form, read-only details pane, and table previews, after Calculate, after Save refresh, and when reopening an existing Peak.
15. Save after Calculate must persist the synchronized values through the existing `onPeakSubmit` path.
16. Save after Calculate must preserve active-source precedence: if the admin edited latitude/longitude, those entered latitude/longitude values remain authoritative; if the admin edited MGRS, the MGRS values remain authoritative and latitude/longitude are derived from them.
17. When saving with an explicit active source, the active source is authoritative and the other coordinate representation is derived. Tests must use an appropriate tolerance when comparing derived decimal coordinates because five-digit MGRS and six-decimal latitude/longitude do not round-trip exactly.
18. Existing non-coordinate field edits must not clear either coordinate group.
19. Existing validation and save behavior for `Name`, `Alt Name`, `Verified`, `osmId`, `Elevation`, `Area`, `Source of truth`, and success/error dialogs must remain unchanged.

**Error Handling:**
20. Calculate must be visible but disabled with `onPressed: null` until the admin has changed a coordinate field in the current edit session.
21. Calculate may reuse the same `PeakAdminEditor.validateAndBuild` path as Save, and any non-coordinate validation errors already produced by that path are shown in the existing form UI.
22. If Calculate is pressed with incomplete latitude/longitude input, show the existing paired-coordinate error for missing latitude or longitude and leave fields unchanged from the moment before Calculate was pressed.
23. If Calculate is pressed with invalid latitude or longitude, show existing latitude/longitude field errors and leave fields unchanged from the moment before Calculate was pressed.
24. If Calculate is pressed with incomplete active-source MGRS input, show field-level errors under missing `mgrs100kId`, `easting`, or `northing` fields and leave fields unchanged from the moment before Calculate was pressed.
25. If Calculate is pressed with invalid active-source MGRS input, show field-level MGRS errors and leave fields unchanged from the moment before Calculate was pressed.
26. Empty or invalid `mgrs100kId` must use `PeakAdminEditor.mgrs100kIdError`; empty, non-digit, or too-long `easting` must use `PeakAdminEditor.eastingError`; empty, non-digit, or too-long `northing` must use `PeakAdminEditor.northingError`. Return all applicable active-source MGRS field errors in one validation pass.
27. If calculated latitude/longitude is outside Tasmania, show `PeakAdminEditor.tasmaniaError` and leave fields unchanged from the moment before Calculate was pressed.
28. While saving is in progress, Calculate must be disabled or otherwise inert in the same way Save is disabled.
29. Successful Calculate must clear stale coordinate-source validation errors and revalidate the current form.
30. User-initiated coordinate edits must clear stale coordinate error text and stale coordinate-source field errors before revalidating the new active source.

**Edge Cases:**
31. Tapping into a coordinate field and then leaving it unchanged must not clear the opposite coordinate group.
32. Re-entering the original text value after a first change still counts as an edit for that session; do not attempt to restore cleared fields automatically.
33. Switching from one coordinate group to the other in the same edit session must clear the group that is no longer the active source.
34. Calculate must not clear or modify any non-coordinate fields.
35. Programmatic controller writes during Calculate, row sync, create-mode setup, or normalization must not trigger opposite-field clearing. Only user-initiated coordinate edits trigger clearing.
36. Save without pressing Calculate must remain supported for existing create/edit flows. If one complete coordinate source is present, Save continues to derive the missing representation through validation, and partial MGRS `easting`/`northing` values must be right-padded to five digits before validation and persistence. The same right-padding rule applies when Calculate is used.
37. Canceling or closing the details pane without saving must discard unsaved calculated/cleared field changes according to existing details pane behavior.
38. Selecting a different row while editing must reset coordinate edit tracking from that new row's normalized values.
39. Create mode must start with no active coordinate source, Calculate disabled, and no calculated values until the admin edits a coordinate group and clicks Calculate.

**Validation:**
40. Coordinate parsing and conversion must be covered by unit tests through public service/editor APIs, not private widget methods.
41. UI clearing and Calculate behavior must be covered by widget tests using stable keys.
42. Six-decimal coordinate rendering must be covered in widget tests for the edit form, read-only details pane, and table previews.
43. The critical admin edit journey must be covered by robot-driven tests or existing ObjectBox Admin robot helpers extended with Calculate support.
</requirements>

<boundaries>
Edge cases:
- Focus-only interaction: Do not clear fields when a user only taps into a coordinate field.
- Partial source values: Do not calculate from incomplete latitude/longitude or incomplete MGRS.
- Both groups present on edit start: Do not clear anything until a coordinate field actually changes.
- Both groups complete after Calculate: This is the intended post-Calculate state and should Save successfully.
- Active source switch: The newest edited coordinate group wins; the other group is cleared.
- Calculate before coordinate edit: Calculate is disabled, with no no-active-source error message.
- Failed Calculate: Leave field values exactly as they were immediately before pressing Calculate; do not restore values cleared earlier in the edit session.
- Save without Calculate: Existing create/edit flows that provide one complete coordinate representation must still save successfully and derive the other representation.

Error scenarios:
- Invalid numbers: Show existing field-level validation errors and keep form values unchanged.
- Invalid or missing active-source MGRS components: Show field-level `mgrs100kId`/`easting`/`northing` errors and keep form values unchanged.
- Tasmania bounds failure: Show the existing Tasmania coordinate error and keep form values unchanged.
- MGRS-active conversion throws: Convert to MGRS field-level validation feedback.
- Latitude/longitude-active conversion throws after parse/range checks pass: Show a form-level coordinate error and keep form values unchanged.

Limits:
- Do not add a new coordinate system or support non-55G grid zones in this iteration.
- Do not change ObjectBox schema, Peak model fields, or repository persistence semantics.
- Do not change app-wide map popup, peak search, peak list import, or refresh behavior.
- Do not add package dependencies; existing `latlong2`, `mgrs_dart`, and project helpers are sufficient.
</boundaries>

<discovery>
Before implementing, examine thoroughly:
1. How `_PeakAdminDetailsPaneState._currentFormState`, `_updateValidation`, and `_submit` currently pass data between controllers and `PeakAdminEditor`.
2. Whether `PeakAdminEditor.validateAndBuild` should be split or supplemented with a public calculation helper to avoid duplicating coordinate conversion in the widget.
3. Existing widget-test patterns in `./test/widget/objectbox_admin_shell_test.dart` for scrolling the edit form and interacting with stable keys.
4. Existing robot helper naming in `./test/robot/objectbox_admin/objectbox_admin_robot.dart` before adding Calculate helpers.
</discovery>

<implementation>
Use the smallest correct change.

Recommended implementation shape:
1. Add a public, testable calculation API in `./lib/services/peak_admin_editor.dart`, such as a `calculateMissingCoordinates` method or equivalent value/result type, so conversion and validation can be unit tested outside the widget.
2. Reuse `PeakMgrsConverter.fromLatLng`, `PeakMgrsConverter.fromForwardString`, and `mgrs.Mgrs.toPoint` through existing project patterns rather than creating a parallel converter.
3. Add a public editor-layer coordinate source value, such as `PeakAdminCoordinateSource.latLng` and `PeakAdminCoordinateSource.mgrs`.
4. Add an optional coordinate source parameter to `PeakAdminEditor.validateAndBuild` and the public calculation API. Keep Calculate and Save on the same validation path, preserve the existing default behavior where complete MGRS wins when both coordinate groups are complete, and let non-coordinate validation surface through that shared path. If `latLng` is supplied, latitude/longitude are authoritative. If `mgrs` is supplied, MGRS is authoritative.
5. Add edit-session coordinate source tracking in `_PeakAdminDetailsPaneState` in `./lib/screens/objectbox_admin_screen_details.dart`, and pass that source through Save so active-source precedence is preserved after Calculate.
6. Add field-specific change handlers for latitude, longitude, `mgrs100kId`, `easting`, and `northing` instead of routing all coordinate fields through a generic `onChanged: (_) => onChanged()`.
7. Ensure the first actual text change clears the opposite coordinate controllers, clears stale coordinate error text, updates validation state, and records the active coordinate source.
8. Add a Calculate button above Save in `_PeakEditForm`, pass an `onCalculate` callback from `_PeakAdminDetailsPaneState`, and disable it while saving.
9. Add the stable key `objectbox-admin-peak-calculate` to the Calculate button.
10. Disable Calculate until a user-initiated coordinate edit has set an active coordinate source.
11. On successful Calculate, write calculated values into the appropriate controllers, update validation, and clear stale coordinate-source errors.
12. On failed Calculate, set `_validation`/coordinate error state so the existing UI displays feedback, and leave all field controller values unchanged from immediately before Calculate was pressed.
13. Ensure programmatic controller writes during Calculate and `_syncFromRow` do not invoke the opposite-field clearing logic.
14. Reset coordinate edit tracking in `_syncFromRow` whenever create mode, selected row, or create OSM id changes.
15. Keep bottom-of-form order as coordinate error, submit error, Calculate button, then Save button.

Avoid:
- Do not calculate automatically on every keystroke; Calculate is explicit.
- Do not clear fields on focus.
- Do not mutate private widget state from tests.
- Do not duplicate conversion logic in multiple UI callbacks when a service/editor helper can be tested directly.
- Do not add a no-active-source error for Calculate; keep Calculate disabled until a coordinate edit happens.
- Do not add new dependencies.
</implementation>

<validation>
Follow vertical-slice TDD. Write one failing test for the next behavior, implement the minimum code to pass, then refactor while green. Do not batch all tests before implementation.

Behavior-first TDD slices:
1. Unit slice: changing/using complete latitude/longitude calculates expected MGRS fields through a public `PeakAdminEditor` calculation API.
2. Unit slice: changing/using complete MGRS calculates expected latitude/longitude through the same public API.
3. Unit slice: MGRS source input accepts 1-5 digit `easting`/`northing`, right-pads to five digits, and rejects non-digit values with field-level errors.
4. Unit slice: calculated latitude/longitude values are formatted with six decimal places.
5. Unit slice: incomplete latitude/longitude input returns the existing paired-coordinate error and no calculated values.
6. Unit slice: incomplete or invalid source coordinates return validation errors and no calculated values.
7. Unit slice: default `PeakAdminEditor.validateAndBuild` behavior still prefers complete MGRS when both coordinate groups are complete and no explicit coordinate source is supplied.
8. Unit slice: explicit `latLng` coordinate source preserves latitude/longitude as authoritative when both groups are complete.
9. Unit slice: explicit `mgrs` coordinate source preserves MGRS as authoritative when both groups are complete.
10. Widget slice: editing latitude clears `mgrs100kId`, `easting`, and `northing` only after actual text change, not focus, and clears stale coordinate error text.
11. Widget slice: editing MGRS clears latitude and longitude only after actual text change and clears stale coordinate error text.
12. Widget slice: Calculate is visible but disabled until a coordinate field is edited; assert disabled/enabled state by reading the button's `onPressed` state.
13. Widget slice: Calculate from latitude/longitude repopulates MGRS fields and Save persists synchronized values while preserving latitude/longitude as the active source.
14. Widget slice: Save without Calculate still succeeds when one complete coordinate source is present.
15. Widget slice: Calculate from incomplete latitude/longitude input shows the existing paired-coordinate error and leaves fields unchanged.
16. Widget slice: Calculate from invalid/partial source shows validation feedback and leaves fields unchanged from immediately before Calculate.
17. Robot slice: critical ObjectBox Admin happy path opens Peak edit mode, edits one coordinate group, taps Calculate, saves, and observes persisted synchronized Peak data.

Required unit tests:
- Add/update tests in `./test/services/peak_admin_editor_test.dart` for calculation success and failure cases.
- Test public behavior only. Do not test private widget methods or private enum names.
- Prefer deterministic expected values from `PeakMgrsConverter` or `mgrs.Mgrs.toPoint` rather than hard-coded magic coordinates unless already established in nearby tests.

Required widget tests:
- Add/update tests in `./test/widget/objectbox_admin_shell_test.dart` for the edit form clearing and Calculate behavior.
- Use stable keys already present for coordinate fields:
  - `objectbox-admin-peak-latitude`
  - `objectbox-admin-peak-longitude`
  - `objectbox-admin-peak-mgrs100k-id`
  - `objectbox-admin-peak-easting`
  - `objectbox-admin-peak-northing`
  - `objectbox-admin-peak-submit`
- Add and use stable key `objectbox-admin-peak-calculate`.
- Cover focus-only behavior by tapping a coordinate field and asserting opposite fields are not cleared until text changes.
- Cover programmatic Calculate writes by asserting they do not immediately clear the fields just populated by Calculate.

Required robot coverage:
- Extend `./test/robot/objectbox_admin/objectbox_admin_robot.dart` with a Calculate helper and any coordinate-field helpers needed for readable journeys.
- Add or update a journey in `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` for the critical cross-screen ObjectBox Admin edit flow.
- Use existing deterministic `TestObjectBoxAdminRepository`, `PeakRepository.test`, and `InMemoryPeakStorage` seams.

Test split:
- Unit tests: conversion and validation business logic in `PeakAdminEditor`.
- Widget tests: screen-level clearing, Calculate button placement/state, invalid input feedback, and Save integration.
- Robot tests: critical admin happy path using user-level actions and stable selectors.

Final verification commands:
- `flutter analyze`
- `flutter test`
</validation>

<stages>
Phase 1: Calculation logic
- Add a public calculation result/API in `PeakAdminEditor`.
- Prove lat/lng-to-MGRS, MGRS-to-lat/lng, 1-5 digit MGRS right-padding, six-decimal lat/lng formatting, default MGRS precedence, explicit source precedence, and invalid-source outcomes with unit tests.
- Verify with `flutter test test/services/peak_admin_editor_test.dart`.

Phase 2: Edit-form clearing state
- Add coordinate source tracking and field-specific change handlers in `objectbox_admin_screen_details.dart`.
- Prove first actual text change clears the opposite group and focus alone does not clear fields.
- Verify with focused widget tests.

Phase 3: Calculate button UI
- Add the Calculate button above Save with key `objectbox-admin-peak-calculate`.
- Wire successful calculation to update controllers and failed calculation to show validation feedback without changing fields.
- Verify with widget tests for both coordinate directions and invalid input.

Phase 4: Robot journey and full validation
- Extend ObjectBox Admin robot helpers and add/update the critical happy-path journey.
- Run `flutter analyze && flutter test`.
</stages>

<done_when>
- `./ai_specs/peak-details-update-spec.md` exists and is the source spec for planning.
- ObjectBox Admin Peak edit form has a Calculate button above Save with key `objectbox-admin-peak-calculate`.
- Editing latitude or longitude clears `mgrs100kId`, `easting`, and `northing` on first actual text change.
- Editing `mgrs100kId`, `easting`, or `northing` clears latitude and longitude on first actual text change.
- Focus/tap alone does not clear fields.
- Calculate from valid latitude/longitude fills MGRS fields immediately.
- Calculate from valid MGRS fills latitude/longitude immediately using six decimal places and right-padded five-digit MGRS components.
- Calculate is disabled until a coordinate field is edited.
- Calculate from incomplete/invalid input shows validation feedback and leaves field values unchanged from immediately before Calculate.
- Save persists synchronized coordinate values after Calculate while preserving the active coordinate source as authoritative.
- Save without Calculate remains supported for existing create/edit flows when one complete coordinate source is present.
- Existing Peak admin behavior for non-coordinate fields, validation, `Verified`, `Alt Name`, source-of-truth, and success dialogs still works.
- Unit, widget, and robot tests cover the specified behavior.
- `flutter analyze` passes.
- `flutter test` passes.
</done_when>
