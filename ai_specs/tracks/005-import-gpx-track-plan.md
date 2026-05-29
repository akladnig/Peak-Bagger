## Overview

Add selective GPX file import via dialog. Repurpose the FAB from folder rescan to multi-file picker + batch dialog.

**Spec**: `ai_specs/005-import-gpx-track-spec.md`

## Context

- **Structure**: feature-first, services/ models/ widgets/ providers/
- **State management**: Riverpod, MapNotifier (StateNotifier)
- **Reference implementations**:
  - `lib/services/peak_list_file_picker.dart` - picker pattern to mirror
  - `lib/widgets/peak_list_import_dialog.dart` - dialog pattern to mirror
  - `lib/services/gpx_importer.dart` - existing processing pipeline
- **Assumptions**:
  - New fields `managedPlacementPending`, `managedRelativePath` added to GpxTrack
  - ObjectBox codegen run after model change

## Plan

### Phase 1: Core scaffolding + picker

- [x] `lib/services/gpx_file_picker.dart` - create GpxFilePicker mirroring PeakListFilePicker with `allowMultiple: true`, `allowedExtensions: ['gpx']`
- [x] `lib/services/gpx_file_picker_provider.dart` - add `gpxFilePickerProvider` for test overrides (provider in same file)
- [x] `lib/services/import_path_helpers.dart` - extract shared `resolveBushwalkingRoot()` used by both picker and importer
- [x] `lib/services/import/gpx_track_import_models.dart` - define `GpxTrackImportPlan`, `GpxTrackImportPlanItem`, `GpxTrackImportResult`, `GpxTrackImportItem`
- [x] `lib/models/gpx_track.dart` - add `managedPlacementPending: bool`, `managedRelativePath: String?` fields, update `fromMap()` / `toMap()`
- [x] TDD: verify picker resolves Bushwalking root when available, fallback otherwise
- [x] TDD: verify new model fields survive fromMap/toMap roundtrip
- [x] Verify: `dart run build_runner build && flutter analyze`

### Phase 2: Importer selective-import API

- [x] `lib/services/gpx_importer.dart` - extract public `deriveDefaultTrackName(gpxXml, filePath)` helper
- [x] `lib/services/gpx_importer.dart` - extract public `deriveTrackDate(gpxXml, fallbackFileMtime)` helper
- [x] `lib/services/gpx_importer.dart` - add `planSelectiveImport(pathToEditedNames: Map<String, String>, seenContentHashes: Set<String>, existingContentHashes: Set<String>) -> GpxTrackImportPlan`
- [x] TDD: planSelectiveImport skips duplicates, counts unchanged/nonTasmanian/errors correctly
- [x] TDD: name/date derivation helpers match existing behavior
- [x] Verify: `flutter analyze && flutter test`

### Phase 3: Dialog UI

- [x] `lib/widgets/gpx_track_import_dialog.dart` - multi-file dialog mirroring PeakListImportDialog
- [x] Add `Key('gpx-track-select-files')`, `Key('gpx-track-import-dialog')`, `Key('gpx-track-row-*')`, `Key('gpx-track-name-field-*')`, `Key('gpx-track-import-button')`, `Key('gpx-track-import-cancel')`, `Key('gpx-track-import-summary')`, `Key('gpx-track-import-result-close')`
- [x] TDD: dialog shows selected files, prefills names, validates empty input
- [x] TDD: dialog disables controls during import, shows result dialog on completion
- [x] Verify: `flutter analyze`

### Phase 4: Provider integration

- [x] `lib/providers/map_provider.dart` - add `importGpxFiles(pathToEditedNames: Map<String, String>) -> GpxTrackImportResult`
- [x] Wire `importGpxFiles()` to: set busy state, call importer plan API, persist tracks additively, run peak correlation, move files to managed storage, handle placement failures
- [x] `lib/widgets/map_action_rail.dart` - replace FAB `rescanTracks()` call with dialog launch
- [x] TDD: provider batch method returns correct counts, handles failures
- [x] TDD: FAB respects busy state and recovery gate
- [x] Verify: `dart run build_runner build && flutter analyze && flutter test`

### Phase 5: Tests + migration

- [ ] `test/harness/test_gpx_file_picker.dart` - test harness for picker overrides
- [ ] `test/services/gpx_file_picker_test.dart` - picker service tests
- [ ] `test/services/gpx_importer_selective_import_test.dart` - selective import service tests
- [ ] `test/widget/gpx_track_import_dialog_test.dart` - dialog widget tests (basic structure done, expand)
- [ ] Update existing `import-tracks-fab` robot tests to expect dialog instead of rescan
- [ ] Update test harnesses for new selective-import API
- [ ] Verify: `flutter test`

## Risks / Out of scope

- **Risks**:
  - ObjectBox codegen may break existing tests if model migration not handled
  - Managed file placement failures must not lose the imported track row
- **Out of scope**:
  - Settings recovery UI for managed-placement-pending tracks
  - Logical-match replacement (additive-only)
  - Route file relocation to Routes folder for selective import