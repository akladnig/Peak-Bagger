## Overview

Settings List Exports: peak CSV + peak-list CSVs.
Prepare/commit service, deterministic seams, Settings wiring, robot journey.

**Spec**: `ai_specs/list-export-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first-ish: `services/`, `providers/`, `screens/`, `widgets/`
- **State management**: Riverpod providers + local `SettingsScreen` state
- **Reference implementations**: `lib/services/peak_list_import_service.dart`, `lib/services/peak_list_file_picker.dart`, `lib/screens/settings_screen.dart`, `test/widget/peak_refresh_settings_test.dart`, `test/robot/peaks/peak_lists_robot.dart`
- **Assumptions/Gaps**: none blocking; use `export.log`, `list-export-*` keys

## Plan

### Phase 1: Export Peaks Slice

- **Goal**: thin end-to-end `Export Peaks` happy path
- [x] `lib/services/data_export_service.dart` - export plan/result models; peak prepare/commit only; CSV payload generation
- [x] `lib/services/data_export_file_picker.dart` - output directory seam; default root convention
- [x] `lib/providers/data_export_provider.dart` - service, picker, filesystem/clock providers
- [x] `lib/screens/settings_screen.dart` - `List Exports` section; `Export Peaks`; confirm, picker, commit, result; busy/status keys
- [x] `test/services/data_export_service_test.dart` - TDD: peak export headers/order/nulls/UTF-8 payload → implement
- [x] `test/widget/list_export_settings_test.dart` - TDD: export peaks confirm → picker → success dialog; cancel no-op
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Peak List CSVs

- **Goal**: peak-list prepare plan, warnings, `export.log`
- [x] `lib/services/data_export_service.dart` - peak-list prepare; decodable lists only; filename sanitization; duplicate suffixes; `Map<int, Peak>` lookup; warning log entries
- [x] `test/services/data_export_service_test.dart` - TDD: one CSV per decodable list; row mapping; item order; deterministic list order
- [x] `test/services/data_export_service_test.dart` - TDD: malformed list no CSV + log warning; missing peak row skipped + log warning; all-malformed success with `0` files
- [x] `test/services/data_export_service_test.dart` - TDD: filename sanitization, duplicate names, ISO timestamp log entries
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Filesystem Semantics

- **Goal**: overwrite, temp writes, partial-failure semantics
- [x] `lib/services/data_export_service.dart` - prepare overwrite conflicts; commit temp writes; final replacement; `export.log` after final success only
- [x] `lib/services/data_export_file_picker.dart` - platform `getDirectoryPath(initialDirectory: ...)`
- [x] `test/services/data_export_service_test.dart` - TDD: prepare no writes/logs; commit uses prepared payloads without repository reread
- [x] `test/services/data_export_service_test.dart` - TDD: overwrite declined no writes/logs; temp write failure cleanup; final replacement failure partial warning and no `export.log`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Settings Integration

- **Goal**: complete Settings UX + busy gating
- [x] `lib/screens/settings_screen.dart` - `Export Peak Lists`; overwrite dialog; error dialogs; `list-export-status`; disable export/maintenance/tile-cache states
- [x] `test/widget/list_export_settings_test.dart` - TDD: peak-list flow; overwrite confirm/decline; log path warning; log failure message
- [x] `test/widget/list_export_settings_test.dart` - TDD: export disables refresh/reset/recalc/tile-cache; export disabled during maintenance
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 5: Robot Journeys

- **Goal**: critical user journeys, key-first selectors
- [x] `test/robot/settings/list_exports_robot.dart` - robot methods for Settings navigation, export actions, confirmations, result assertions
- [x] `test/robot/settings/list_exports_journey_test.dart` - Robot: peak-list happy path via fake picker/service/filesystem
- [x] `test/robot/settings/list_exports_journey_test.dart` - Robot: warning path shows warning count + `export.log` path/log failure message
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: multi-file final replacement can be partially written; platform directory picker behavior in widget tests needs fakes; Settings busy-state coupling can regress existing tests
- **Out of scope**: import/restore compatibility; GPX/tile/ObjectBox backup; cloud/share flows; changing existing peak-list import
