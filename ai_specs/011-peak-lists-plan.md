## Overview

Peak-list CSV import via `PeakListsScreen`; ObjectBox-backed persistence + admin visibility.
Thin slice first: dialog, picker seam, submit/result/failure UX; then schema, matching, admin.

**Spec**: `ai_specs/011-peak-lists-spec.md` (read this file for full requirements)

## Context

- **Structure**: screen/service/provider split; layer-first with repo helpers
- **State management**: Riverpod; local widget state for transient dialog/form state
- **Reference implementations**: `./lib/screens/settings_screen.dart`, `./lib/services/objectbox_admin_repository.dart`, `./test/robot/peaks/peak_refresh_robot.dart`
- **Assumptions/Gaps**: follow spec literally for import-root fallback (`<documents>/Bushwalking`, else user home); no shared feature notifier unless implementation proves needed

## Plan

### Phase 1: UI vertical slice [complete]

- **Goal**: prove import journey shell
- [x] `./pubspec.yaml` - add `file_picker` and `path`
- [x] `./lib/screens/peak_lists_screen.dart` - convert stub to stateful screen; keyed `Import Peak List` FAB
- [x] `./lib/widgets/peak_list_import_dialog.dart` - dialog UI, local field state, disabled import until file selected, duplicate confirm, loading/result/failure hooks
- [x] `./lib/services/peak_list_file_picker.dart` - file-picker seam with resolved Bushwalking root
- [x] `./test/harness/test_peak_list_file_picker.dart` - fake picker
- [x] `./test/widget/peak_lists_screen_test.dart` - dialog open/cancel, disabled import before file, empty-name validation, modal failure pattern
- [x] TDD: FAB opens dialog; import blocked until file selected and name entered
- [x] TDD: picker cancel is no-op; post-submit failure uses settings-style modal dialog
- [x] Robot journey tests + selectors/seams for critical flows: add keys for FAB/dialog/buttons/fields; fake picker seam only
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Schema and repositories [complete]

- **Goal**: persist lists safely
- [x] `./lib/models/peak_list.dart` - `PeakList` entity + JSON item DTO
- [x] `./lib/services/peak_list_repository.dart` - ObjectBox wrapper + in-memory storage; transactional replace-by-name path
- [x] `./lib/services/peak_repository.dart` - add `findByOsmId`/lookup helpers needed by importer
- [x] `./lib/services/objectbox_schema_guard.dart` - include `PeakList` signature surface
- [x] `./test/services/peak_list_repository_test.dart` - save/load/update transaction behavior
- [x] `./test/services/peak_repository_test.dart` - osmId lookup regression
- [x] `./test/services/objectbox_schema_guard_test.dart` - schema signature regression
- [x] TDD: duplicate-name update preserves existing data on failure
- [x] TDD: repository round-trips ordered `peakList` payload unchanged
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Import service and matching [complete]

- **Goal**: parse, correlate, log
- [x] `./lib/services/peak_mgrs_converter.dart` - CSV UTM/MGRS normalization helper
- [x] `./lib/services/peak_list_import_service.dart` - CSV parse, correlation, warning/log result contract, create-vs-update outcome
- [x] `./lib/services/gpx_importer.dart` - reuse/align import-log path resolution if shared helper extraction is warranted
- [x] `./test/services/peak_mgrs_converter_test.dart` - normalization regression
- [x] `./test/services/peak_list_import_service_test.dart` - parse/match/persist/log slices
- [x] TDD: quoted-comma row parses; hard match requires zone + `mgrs100kId` + `<=500m` easting/northing + rounded height, with coordinate-drift warnings when easting/northing differ by more than `50m`
- [x] TDD: name mismatch warns only; zero/multi-match skips row; warningEntries/logEntries differ by timestamping
- [x] TDD: result distinguishes created vs updated; warning count surfaces when log write fails
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Admin and robot completion [complete]

- **Goal**: admin visibility + end-to-end confidence
- [x] `./lib/services/objectbox_admin_repository.dart` - load `PeakList` rows; use `objectBoxAdminPreviewValue()` for payload preview
- [x] `./test/harness/test_objectbox_admin_repository.dart` - add `PeakList` entity/rows
- [x] `./test/services/objectbox_admin_repository_test.dart` - schema + row coverage for `PeakList`
- [x] `./test/robot/peaks/peak_lists_robot.dart` - journey robot
- [x] `./test/robot/peaks/peak_lists_journey_test.dart` - import/create/update/warning journey coverage
- [x] `./lib/objectbox-model.json` - regenerated schema
- [x] `./lib/objectbox.g.dart` - regenerated bindings
- [x] TDD: ObjectBox Admin shows `PeakList` entity and row preview fields
- [x] TDD: robot journey covers create, duplicate update confirm, result dialog, persisted admin-visible row
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 5: Peak correction source of truth [complete]

- **Goal**: persist CSV-driven peak corrections alongside list imports
- [x] `./lib/models/peak.dart` - add persisted `sourceOfTruth` field and copy/update support for CSV corrections
- [x] `./lib/services/peak_repository.dart` - add transactional save/update support for corrected peaks used by the importer
- [x] `./lib/services/peak_list_import_service.dart` - unique matches update `Peak` latitude/longitude/easting/northing/elevation from CSV and set `sourceOfTruth`
- [x] `./test/services/peak_model_test.dart` - default/source parsing coverage for `sourceOfTruth`
- [x] `./test/services/peak_repository_test.dart` - corrected peak update persistence coverage
- [x] `./test/services/peak_list_import_service_test.dart` - unique-match field correction, `HWC`/`OSM`, and mismatch warning coverage
- [x] `./lib/objectbox-model.json` - regenerated schema for `Peak.sourceOfTruth`
- [x] `./lib/objectbox.g.dart` - regenerated bindings for `Peak.sourceOfTruth`
- [x] `./lib/services/objectbox_schema_guard.dart` - include `Peak.sourceOfTruth` in the signature surface
- [x] `./lib/services/objectbox_admin_repository.dart` - expose `Peak.sourceOfTruth` in peak admin rows
- [x] `./test/services/objectbox_schema_guard_test.dart` - schema signature regression for `Peak.sourceOfTruth`
- [x] `./test/services/objectbox_admin_repository_test.dart` - Peak schema/data coverage for `sourceOfTruth`
- [x] TDD: unique match updates differing peak coordinates/height from CSV and marks `sourceOfTruth` as `HWC`
- [x] TDD: unchanged unique match keeps `sourceOfTruth` fixed as `HWC`; correction warnings/logs include drift details
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 6: Name-aware progressive matching [complete]

- **Goal**: recover bad OSM coordinates without silently attaching rows to the wrong peak
- [x] `./lib/services/peak_list_import_service.dart` - progressive `50m..2km` spatial search with name-confirmed acceptance above `50m`
- [x] `./test/services/peak_list_import_service_test.dart` - ambiguity resolution, escalation, and rejected mismatched-name coverage
- [x] TDD: ambiguous nearby peaks resolve only when exactly one strong normalized/fuzzy name match exists
- [x] TDD: unmatched rows may escalate beyond `50m` up to `2km`, but accepted matches above `50m` require name confirmation
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 7: Insert unmatched CSV peaks [complete]

- **Goal**: persist new HWC peaks when no existing peak can be matched
- [x] `./lib/services/peak_list_import_service.dart` - create and persist new `Peak` entities for unmatched rows before saving the `PeakList`
- [x] `./lib/services/peak_repository.dart` - support stable synthetic identifiers for CSV-created peaks used by `PeakList.peakOsmId`
- [x] `./test/services/peak_list_import_service_test.dart` - unmatched-row insertion coverage plus updated warning expectations
- [x] TDD: unmatched rows create new `Peak` records with `sourceOfTruth == HWC` and list entries reference the new peak ids
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: resolved Bushwalking root may vary by platform; JSON-in-entity payload can become hard to evolve; file_picker plugin setup may add platform friction
- **Out of scope**: bagging/tick UI, multi-file import, edit/delete list management beyond duplicate-name update
