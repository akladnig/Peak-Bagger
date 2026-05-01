<goal>
Add `Peak.altName` and `Peak.verified` to the ObjectBox model, expose both fields in ObjectBox Admin, and show `altName` in the clicked-peak popup when it is available.

This matters because users need one canonical peak name, one manually managed alternate name, and one manual verification flag, and those values must survive refresh, import, and save flows.
</goal>

<spec_path>
Use `ai_specs/peaks/alt-name-verified-fields-spec.md` for follow-up workflow commands. Do not use the non-existent workspace-root path `peaks/alt-name-verified-fields-spec.md`.
</spec_path>

<background>
Flutter app using ObjectBox, Riverpod, `flutter_map`, and a custom ObjectBox Admin UI.
Peak data is rebuilt in several places, so the new fields must be preserved in every `Peak` construction or copy path that can overwrite stored records.

The new fields are metadata only:
- `name` remains the canonical identifier for sorting, OSM matching, delete prompts, and identity.
- `altName` is supplementary admin/display/search text only.
- `verified` is a manual user flag and does not replace `sourceOfTruth`.

Files to examine:
- `./lib/models/peak.dart`
- `./lib/objectbox.g.dart`
- `./lib/objectbox-model.json`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/services/objectbox_schema_guard.dart`
- `./lib/services/peak_admin_editor.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./lib/screens/objectbox_admin_screen_details.dart`
- `./lib/screens/objectbox_admin_screen_table.dart`
- `./lib/providers/map_provider.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peak_refresh_service.dart`
- `./lib/services/peak_list_import_service.dart`
- `./lib/screens/map_screen_panels.dart`
- `./test/services/peak_model_test.dart`
- `./test/services/peak_repository_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/services/objectbox_schema_guard_test.dart`
- `./test/services/peak_admin_editor_test.dart`
- `./test/services/peak_refresh_service_test.dart`
- `./test/services/peak_list_import_service_test.dart`
- `./test/widget/objectbox_admin_shell_test.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/harness/test_objectbox_admin_repository.dart`
- `./test/robot/objectbox_admin/objectbox_admin_robot.dart`
- `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. Admin opens ObjectBox Admin and selects a Peak.
2. Admin edits `Alt Name` and toggles `Verified` in the custom Peak edit form.
3. Save succeeds and the table, details sidebar, and edit form reflect the persisted values.
4. Reopening the same Peak shows the same values.

Alternative flows:
- Admin searches Peaks in ObjectBox Admin: `altName` matches the query, but `name` remains the primary label and existing id sort behavior is preserved.
- User clicks a peak on the map: the peak popup shows canonical `name` and, when non-empty, secondary text `Alt Name: <altName>`.
- Existing database records are expected to load with `altName == ''` and `verified == false` through ObjectBox/codegen defaults, without any manual migration UI. This legacy persisted-row defaulting is an accepted unverified risk for this iteration; do not add a binary legacy ObjectBox store fixture.

Error flows:
- Empty `altName` does not create validation errors.
- Whitespace-only `altName` is saved as `''`.
- `altName` is rejected before save when it is the same as that Peak's canonical `name`.
- `verified == false` is a valid state and never blocks save.
- Existing unrelated Peak validation errors and save failures still behave exactly as before.
</user_flows>

<requirements>
**Functional:**
F1. Add `altName` (`String`) and `verified` (`bool`) to `./lib/models/peak.dart` with defaults of `''` and `false`.
F2. Update `Peak` construction, `copyWith`, and every Peak-cloning path so the two new fields survive saves, refreshes, imports, and other record replacement flows.
F3. Regenerate ObjectBox output from the updated entity model with `dart run build_runner build` and check in both `./lib/objectbox.g.dart` and `./lib/objectbox-model.json`. Do not hand-edit generated/schema-managed ObjectBox files.
F4. Update `./lib/services/objectbox_schema_guard.dart` so the schema signature includes `Peak.altName` and `Peak.verified`.
F5. Update `./lib/services/objectbox_admin_repository.dart` row projection so Peak rows include both new fields; entity metadata should come from the regenerated ObjectBox model.
F6. Add separate admin-specific Peak field-order helpers instead of relying on Dart source order, ObjectBox property order, or one reordered `ObjectBoxAdminEntityDescriptor.fields` list. Keep schema metadata order tied to the regenerated ObjectBox model unless a schema-specific change is explicitly needed. Required table data-field visual order: fixed primary `name`, then horizontal columns `altName`, `id`, followed by existing fields in order: `elevation`, `latitude`, `longitude`, `area`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `verified`, `osmId`, `sourceOfTruth`. This data-field order excludes non-data action columns; keep the existing Peak `Delete` action column appended after the data fields when delete actions are enabled.
F7. Required Peak details list order: `id`, `name`, `altName`, followed by existing fields in order: `elevation`, `latitude`, `longitude`, `area`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `verified`, `osmId`, `sourceOfTruth`.
F8. Update `./lib/services/peak_admin_editor.dart`, `./lib/screens/objectbox_admin_screen.dart`, `./lib/screens/objectbox_admin_screen_details.dart`, and `./lib/screens/objectbox_admin_screen_table.dart` so Peak admin create/edit/details views show `Alt Name` and `Verified` with the required placement. For the custom Peak create/edit form, keep the existing form order, insert `Alt Name` immediately after `Name`, and insert `Verified` immediately after `Northing`, before `Source of truth`.
F9. Render `verified` in the admin table as text `true`/`false` using the table's normal read-only value rendering. Do not render `verified` as a checkbox in the table.
F10. Render boolean fields through one shared read-only details value renderer used by both the generic details pane and the custom Peak details pane. When `row.values[field.name] is bool`, render a disabled checkbox only for the value area, with no duplicate text value. Preserve accessibility by keeping the field title as the label and exposing checked/unchecked semantics on the disabled checkbox. `verified` and future boolean row values should get consistent read-only details rendering.
F11. Render `verified` as an editable checkbox in the custom Peak edit form with stable key `objectbox-admin-peak-verified`.
F12. Render `altName` as a text field in the custom Peak edit form with label `Alt Name` and stable key `objectbox-admin-peak-alt-name`.
F13. Update ObjectBox Admin Peak search so it matches both canonical `name` and `altName`, while preserving existing id sort behavior. `altName` search must use the same trimmed, case-insensitive substring semantics as existing canonical `name` search.
F14. Update `objectBoxAdminFilterAndSortRows` with a Peak-specific search value helper so fake ObjectBox Admin searches used by tests match `altName` the same way production Peak admin searches do, including trimmed, case-insensitive substring matching.
F15. Update only the clicked-peak popup path to show `Alt Name: <altName>` as secondary/supporting text when `altName.trim().isNotEmpty`; do not replace the canonical peak name. Exact popup line order is canonical name title, optional `Alt Name: <trimmed altName>`, `Height`, `Map`, then optional `List(s)`.
F16. Keep app-wide peak search, peak list selection widgets, and Peak Lists screen display out of scope for this iteration unless they are directly needed by the clicked-peak popup change.
F17. Preserve the existing `sourceOfTruth` behavior; `verified` is separate metadata and does not replace or auto-toggle it.
F18. When peak markers are reloaded after admin save or repository refresh, update an already-open clicked-peak popup's `content.peak` to point at the refreshed Peak when the same `osmId` still exists. Keep the existing `mapName` and `listNames` values unchanged during this refresh. Continue closing the popup only when the peak was removed. Use the same popup-refresh helper from both `MapNotifier.reloadPeakMarkers` and `MapNotifier.refreshPeaks` so direct refreshes and admin-triggered marker reloads behave consistently.
F19. Replace duplicated admin row-to-`Peak` reconstruction with one shared helper that carries `altName` and `verified`, and use it from both ObjectBox Admin screen call sites.

**Error Handling:**
E1. In the clicked-peak popup, empty `altName` should collapse cleanly with no extra blank row or placeholder text. ObjectBox Admin table/details may still show the `altName` field according to the required admin field ordering, even when the value is empty.
E2. `verified == false` should display as `false` in the admin table, as an unchecked disabled checkbox in details, and as an unchecked editable checkbox in the custom Peak edit form.
E3. Refresh, import, startup backfill, marker reload, and update flows must not clear `altName` or `verified` when other Peak fields change.
E4. Reject `altName` before save when the trimmed non-empty `altName` equals the same Peak's trimmed canonical `name`, comparing case-insensitively. `altName` may match any other Peak's canonical `name` or `altName`. Surface this validation as `fieldErrors['altName']` under the `Alt Name` field using named error constant `PeakAdminEditor.altNameDuplicateNameError = 'Alt Name must be different from Name'`. Run this independent field validation before coordinate-validation early returns so the `Alt Name` field error is not hidden behind unrelated coordinate errors.

**Edge Cases:**
X1. Existing peaks created before this change are expected to read back with default `altName` and `verified` values through ObjectBox/codegen defaults. This is an accepted unverified risk for this iteration because no binary legacy ObjectBox store fixture will be added.
X2. Peak refresh/import/startup backfill code paths that rebuild `Peak` instances must copy forward the new fields rather than dropping them.
X3. When a refreshed Overpass peak matches an existing `osmId`, merge user-owned fields (`altName`, `verified`) from the existing peak into the refreshed/enriched Peak before replacement. If the preserved `altName` equals the refreshed canonical `name` after trimming and case-insensitive comparison, clear `altName` to `''` during refresh so stored data does not violate the admin validation rule.
X4. When a protected synthetic HWC peak is upgraded to a real OSM id during refresh, preserve `altName` and `verified` from the existing synthetic peak into the upgraded Peak. Compare preserved `altName` against the upgraded Peak's final stored canonical `name` only; if they are equal after trimming and case-insensitive comparison, clear `altName` to `''` during refresh so stored data does not violate the admin validation rule.
X5. `altName` should not change peak sort order, delete prompts, OSM identity matching, or `sourceOfTruth`.
X6. `altName` validation must trim on save, treat whitespace-only as `''`, reject `altName` when it equals that same Peak's canonical `name`, and impose no additional max length beyond normal text field behavior.

**Validation:**
V1. Baseline automated coverage must include model defaults and copy behavior, ObjectBox schema metadata, admin search behavior, admin persistence/rendering, clicked-peak popup rendering, and refresh/import/startup backfill preservation.
V2. Follow TDD slices in this order: model defaults and copy behavior, ObjectBox schema/admin row behavior, admin validation/search/rendering, clicked-peak popup rendering, then refresh/import/startup backfill preservation. Keep each slice small and green before moving on.
V3. Use deterministic seams in tests: `PeakRepository.test`, `InMemoryPeakStorage`, `TestObjectBoxAdminRepository`, and existing widget/robot harness fakes instead of live ObjectBox or network dependencies. Legacy persisted ObjectBox rows relying on new-field defaults are an accepted ObjectBox/codegen risk for this iteration. Verify constructor defaults, copy behavior, and generated model metadata; do not add a binary legacy ObjectBox store fixture or require a proof of old-store readback defaults.
V4. Add or update unit tests in `./test/services/peak_model_test.dart`, `./test/services/peak_repository_test.dart`, `./test/services/objectbox_admin_repository_test.dart`, `./test/services/objectbox_schema_guard_test.dart`, `./test/services/peak_admin_editor_test.dart`, `./test/services/peak_refresh_service_test.dart`, and `./test/services/peak_list_import_service_test.dart`. `peak_repository_test.dart` must cover persistence/copy/save preservation only, not app-wide `altName` search; ObjectBox Admin search must be verified in `objectbox_admin_repository_test.dart`.
V5. Add or update widget tests in `./test/widget/objectbox_admin_shell_test.dart` and `./test/widget/map_screen_peak_info_test.dart` to verify exact Peak admin table data-field visual order, exact Peak details list order, edit/create form placement, `Alt Name` placement, table boolean text rendering, generic and Peak details checkbox rendering, edit checkbox behavior, same-peak name/alt-name validation, and empty-state behavior.
V6. Add or update robot coverage in `./test/robot/objectbox_admin/` so the admin edit flow exercises the `Alt Name` text field and `Verified` checkbox.
V7. Update `./test/robot/objectbox_admin/objectbox_admin_robot.dart` with dedicated helpers for the `verified` checkbox instead of relying only on text-field helpers.
V8. Update `./test/harness/test_objectbox_admin_repository.dart` and local ObjectBox Admin test descriptor/row helpers so fake Peak descriptors and rows include `altName` and `verified`. Keep fake descriptors schema-like; verify required Peak admin visual ordering through the separate table/details field-order helpers rather than by reordering descriptor metadata.
</requirements>

<boundaries>
- `name` remains the canonical peak identifier for sorting, identity, OSM matching, and destructive prompts.
- `altName` is supplementary display/search data for ObjectBox Admin and the clicked-peak popup only in this iteration.
- `verified` is a manual user flag, not derived from coordinates, elevation, `altName`, or `sourceOfTruth`.
- `verified` does not auto-toggle `sourceOfTruth`, and the existing `Mark as HWC` action remains separate.
- No runtime backfill script is required; existing records rely on ObjectBox/codegen defaults only.
- Do not introduce a separate parallel peak naming system or extra schema beyond these two fields.
</boundaries>

<implementation>
1. Modify `./lib/models/peak.dart` first, then run `dart run build_runner build` so both `./lib/objectbox.g.dart` and `./lib/objectbox-model.json` are updated together.
2. Update ObjectBox schema signature coverage in `./lib/services/objectbox_schema_guard.dart`.
3. Update `./lib/services/objectbox_admin_repository.dart` and add separate Peak admin table-field and details-field order helpers so the admin UI can read, search, order, and render the new fields without mutating schema metadata order.
4. Update `./lib/services/peak_admin_editor.dart` and the Peak admin screen files so the edit form can validate, edit, and save `altName` and `verified`. `PeakAdminFormState` must include `altName` and `verified`; `PeakAdminEditor.normalize` must populate them; `PeakAdminEditor.validateAndBuild` must trim `altName`, validate it against the same Peak's canonical `name` before coordinate early returns, and write `altName` plus `verified` into the returned `Peak`. Add one shared admin row-to-`Peak` helper and use it everywhere the ObjectBox Admin UI reconstructs a Peak from `ObjectBoxAdminRow`.
5. Update refresh/import/copy paths in `./lib/services/peak_repository.dart`, `./lib/services/peak_refresh_service.dart`, `./lib/services/peak_list_import_service.dart`, and any other direct `Peak(...)` construction sites that must preserve the new fields.
6. Update the clicked-peak popup in `./lib/screens/map_screen_panels.dart` by reading `content.peak.altName` directly in `PeakInfoPopupCard`. Do not add duplicate `altName` fields to `PeakInfoContent` or `MapState` unless implementation proves it necessary. Add a shared popup-refresh helper used by both `MapNotifier.reloadPeakMarkers` and `MapNotifier.refreshPeaks` so an open clicked-peak popup's `content.peak` is refreshed to the latest Peak object when the same `osmId` still exists, while preserving the existing `mapName` and `listNames`.
7. Keep the implementation small: prefer one shared boolean details renderer, separate table/details field-order helpers, and one shared admin row-to-`Peak` helper over scattered special cases.
</implementation>

<stages>
Phase 1: Add the entity fields, regenerate ObjectBox files, and preserve fields through model/copy paths, then verify with unit tests.
Phase 2: Wire ObjectBox schema/admin metadata, field ordering, search, duplicate validation, and edit persistence.
Phase 3: Update admin table/details boolean rendering and clicked-peak popup alt-name rendering.
Phase 4: Verify refresh/import/startup backfill/update flows keep the new fields intact, then run the full relevant test set.
</stages>

<validation>
- `./test/services/peak_model_test.dart` must prove new defaults and copy behavior.
- `./test/services/objectbox_schema_guard_test.dart` must prove the schema signature includes `Peak.altName` and `Peak.verified`.
- Treat pre-change ObjectBox store defaulting as an accepted ObjectBox/codegen risk for this iteration; do not add a binary legacy store fixture. Verify constructor defaults, copy behavior, and generated model metadata only.
- `./test/services/objectbox_admin_repository_test.dart` must prove Peak entity metadata, admin row values, exact table data-field and details field ordering, production admin search, and `objectBoxAdminFilterAndSortRows` fake-harness search include the new fields.
- `./test/services/peak_admin_editor_test.dart` must prove `PeakAdminFormState` includes `altName` and `verified`, admin normalize/validate/build trims `altName`, rejects `altName` when it equals the same Peak's canonical `name` via `fieldErrors['altName']` and `PeakAdminEditor.altNameDuplicateNameError` before coordinate early returns, allows `altName` matches against other Peaks, and round-trips `verified`.
- `./test/services/peak_refresh_service_test.dart` and `./test/services/peak_list_import_service_test.dart` must prove the fields are preserved through record replacement flows, including startup backfill, matched OSM refresh replacement, protected synthetic HWC-to-OSM upgrade, and refresh-time clearing when preserved `altName` equals the resulting stored canonical `name`.
- `./test/widget/objectbox_admin_shell_test.dart` must prove the admin UI can edit and persist both fields, uses the exact table data-field visual order and details list order, keeps the Peak `Delete` action column appended after data fields, displays `verified` as table text `true`/`false`, displays boolean row values as accessible disabled details checkboxes without duplicate text values in both details panes, displays `verified` as an editable form checkbox, uses the shared row-to-`Peak` conversion for edit/view flows, and surfaces same-peak name/alt-name validation under the `Alt Name` field.
- `./test/widget/map_screen_peak_info_test.dart` must prove the clicked-peak popup shows `Alt Name: <altName>` only when non-empty, uses the exact popup line order, uses `content.peak.altName` rather than duplicated map state, and refreshes an open popup's `content.peak` when marker reload returns a newer Peak with the same `osmId` while leaving existing `mapName` and `listNames` unchanged.
- Robot tests must cover the admin edit/save journey using stable keys, including the `verified` checkbox helper.
</validation>

<done_when>
- `Peak` has `altName` and `verified` with correct defaults.
- ObjectBox generated/schema-managed files are updated consistently using `dart run build_runner build`.
- ObjectBox schema signature includes the new fields.
- ObjectBox Admin can display, search, validate, edit, and persist both fields.
- Clicked-peak popup shows non-empty `altName` as secondary `Alt Name: <altName>` text.
- Refresh, import, and update flows preserve the new fields.
- Startup backfill preserves the new fields.
- An open clicked-peak popup refreshes `content.peak` to the latest Peak when marker reload keeps the same `osmId`, while preserving the existing `mapName` and `listNames`.
- Implementation/test notes state that legacy persisted-row defaulting is an accepted unverified ObjectBox/codegen risk and was not verified with a binary legacy store fixture.
- Automated tests cover the model, schema guard, repository/admin behavior, UI rendering, and key journeys.
</done_when>
