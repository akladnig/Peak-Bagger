## Overview

ObjectBox Admin Peak coordinate editing. Explicit Calculate, source tracking, synchronized Save.

**Spec**: `ai_specs/peak-details-update-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `services/`, `providers/`, `models/`
- **State management**: Riverpod providers; Peak edit state remains widget-local
- **Reference implementations**: `lib/services/peak_admin_editor.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `test/robot/objectbox_admin/objectbox_admin_robot.dart`
- **Assumptions/Gaps**: none; prefer existing local form/controller pattern over new provider state

## Plan

### Phase 1: Lat/Lng Vertical Slice

- **Goal**: edit lat/lng, Calculate MGRS, Save authoritative lat/lng
- [x] `lib/services/peak_admin_editor.dart` - add `PeakAdminCoordinateSource`; source-aware `validateAndBuild`
- [x] `lib/services/peak_admin_editor.dart` - add public calculation API; lat/lng to MGRS path first
- [x] `lib/services/peak_admin_editor.dart` - add six-decimal lat/lng formatter for form values
- [x] `lib/screens/objectbox_admin_screen_details.dart` - track active source; pass source to Save
- [x] `lib/screens/objectbox_admin_screen_details.dart` - add Calculate button key `objectbox-admin-peak-calculate`
- [x] `lib/screens/objectbox_admin_screen_details.dart` - lat/lng change handler clears MGRS only on user text change
- [x] `test/services/peak_admin_editor_test.dart` - TDD: lat/lng calculation returns uppercase MGRS + five-digit components
- [x] `test/services/peak_admin_editor_test.dart` - TDD: explicit `latLng` Save keeps lat/lng authoritative when both groups present
- [x] `test/widget/objectbox_admin_shell_test.dart` - TDD: edit latitude clears MGRS, Calculate repopulates, Save persists lat/lng source
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: MGRS, Errors, Formatting

- **Goal**: MGRS path, invalid states, six-decimal admin rendering
- [ ] `lib/services/peak_admin_editor.dart` - MGRS calculation path; right-pad 1-5 digit easting/northing before conversion
- [ ] `lib/services/peak_admin_editor.dart` - apply same MGRS padding in Save path
- [ ] `lib/services/peak_admin_editor.dart` - source-aware errors; incomplete lat/lng, invalid fields, Tasmania failure, conversion failure
- [ ] `lib/screens/objectbox_admin_screen_details.dart` - MGRS change handler clears lat/lng only on user text change
- [ ] `lib/screens/objectbox_admin_screen_details.dart` - failed Calculate updates validation, leaves controller text unchanged
- [ ] `lib/services/objectbox_admin_repository.dart` - field-aware six-decimal Peak lat/lng formatting helper
- [ ] `lib/screens/objectbox_admin_screen_details.dart` - use six-decimal formatting in edit + read-only details
- [ ] `lib/screens/objectbox_admin_screen_table.dart` - use six-decimal formatting in Peak table previews
- [ ] `test/services/peak_admin_editor_test.dart` - TDD: MGRS calculation derives six-decimal lat/lng
- [ ] `test/services/peak_admin_editor_test.dart` - TDD: 1-5 digit MGRS padding applies to Calculate and Save
- [ ] `test/services/peak_admin_editor_test.dart` - TDD: incomplete/invalid coordinates return expected errors, no values
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: edit MGRS clears lat/lng, Calculate repopulates, Save persists MGRS source
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: incomplete lat/lng Calculate shows paired-coordinate error, no field mutation
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: six-decimal lat/lng in edit form, read-only details, table previews
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey Hardening

- **Goal**: critical admin journey + regressions green
- [ ] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - add Calculate helper; coordinate field helpers if needed
- [ ] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - robot journey: open Peak, edit coordinate group, Calculate, Save, assert persisted sync
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: focus-only does not clear opposite group
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: programmatic Calculate writes do not trigger reciprocal clearing
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: Calculate disabled before coordinate edit and while saving
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: non-coordinate edits do not clear coordinate groups
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: row switch/create mode resets active source and Calculate state
- [ ] Robot journey tests + selectors/seams: use existing `TestObjectBoxAdminRepository`, `PeakRepository.test`, `InMemoryPeakStorage`; selectors key-first
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: controller writes causing recursive clearing; MGRS/lat-lng round-trip tolerance; scroll-dependent widget tests
- **Out of scope**: schema/model changes; non-55G grids; map popup/search/import behavior; new dependencies
