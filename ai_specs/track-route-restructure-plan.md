## Overview

Move imported tracks into managed country/region folders from first-point polygon lookup; keep reset/rescan discoverable via recursive track scan.

**Spec**: `ai_specs/track-route-restructure-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`services` -> `providers` -> `widgets` -> tests)
- **State management**: Riverpod
- **Reference implementations**: `lib/services/gpx_importer.dart`, `lib/providers/map_provider.dart`, `lib/widgets/gpx_import_dialog.dart`, `test/widget/gpx_tracks_shell_test.dart`
- **Assumptions/Gaps**: route handling out of scope; `unsupportedCount` replaces `nonTasmanianCount` across import result contracts, provider status copy, and UI copy

## Plan

### Phase 1: Track placement core

- **Goal**: first-point classification -> managed path -> recursive rescan
- [ ] `lib/services/gpx_importer.dart` - polygon-backed country/region resolution; recursive `Tracks` discovery; managed relative path mirrors final destination; keep reset/rescan behavior intact
- [ ] `lib/services/import/gpx_track_import_models.dart` - rename `nonTasmanianCount` -> `unsupportedCount`
- [ ] `lib/providers/map_provider.dart` - thread renamed result contract; keep `_importTracks()`, `rescanTracks()`, `resetTrackData()` behavior aligned with new count semantics
- [ ] `test/services/gpx_importer_selective_import_test.dart` - TDD: first-point-only routing, supported-track acceptance outside Tasmania, unsupported fallback count, recursive nested-folder discovery, managed-path mirroring
- [ ] `test/providers/map_provider_import_test.dart` - TDD: provider result contract, add/remove/rebuild path still stable after rename
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - TDD: import track journey lands in nested country/region path; stable keys: `gpx-import-select-files`, `gpx-import-button`, `gpx-import-summary`, `gpx-import-result-close`, `map-interaction-region`
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: UI copy + status surfaces

- **Goal**: rename unsupported wording everywhere user sees counts
- [ ] `lib/widgets/gpx_import_dialog.dart` - show `unsupportedCount` wording in result dialog
- [ ] `lib/screens/settings_screen.dart` - update reset summary text to renamed unsupported wording
- [ ] `lib/providers/map_provider.dart` - update track status/snackbar copy for rescan/reset outputs
- [ ] `test/widget/gpx_import_dialog_test.dart` - TDD: result dialog copy renders renamed unsupported count
- [ ] `test/widget/gpx_tracks_shell_test.dart` - TDD: rescan/reset snackbar + settings warning/copy use renamed wording
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Regression hardening

- **Goal**: keep reset/rescan, import warning, and folder discovery coherent
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - TDD: nested-folder discovery still works after reset/rescan; file placement + summary copy consistent
- [ ] `test/harness/test_gpx_file_picker.dart` - extend only if import dialog path selection needs extra deterministic coverage
- [ ] `test/harness/test_map_notifier.dart` - extend only if reset/rescan needs new deterministic seams
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: recursive scan vs existing watched-folder assumptions; count rename touches multiple UI surfaces; polygon precedence must stay deterministic
- **Out of scope**: route export/import changes; migration of already-imported files; user-editable country mapping
