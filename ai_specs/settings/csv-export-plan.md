## Overview

Peak CSV export from Settings. Small export service + runner provider + status-key wiring.

**Spec**: `ai_specs/settings/csv-export-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`lib/screens`, `lib/services`, `lib/widgets`, `lib/providers`)
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/settings_screen.dart`, `lib/services/objectbox_admin_repository.dart`, `lib/providers/peak_list_provider.dart`, `test/widget/peak_refresh_settings_test.dart`, `test/services/peak_repository_test.dart`
- **Assumptions/Gaps**: no main.dart change expected; preserve existing `peak-refresh-status` behavior via a separate export status key/state field

## Plan

### Phase 1: Export service slice

- **Goal**: deterministic CSV write path, no UI coupling
- [x] `lib/services/peak_csv_export_service.dart` - export result type, CSV row building, fixed path write, directory create, overwrite
- [x] `lib/providers/peak_csv_export_provider.dart` - concrete service provider + `PeakCsvExportRunner` provider
- [x] `test/services/peak_csv_export_service_test.dart` - TDD: header/order, field mapping, blank cells, escaping, LF, overwrite, empty export, repository-order preservation
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_csv_export_service_test.dart` && `flutter test`

### Phase 2: Settings wiring slice

- **Goal**: export action, loading state, success/failure feedback, mutual exclusion with refresh
- [x] `lib/screens/settings_screen.dart` - export tile, `_isExportingPeaks`, `_statusKey`, runner call, status text, disable refresh/export overlap
- [x] `test/widget/peak_csv_export_settings_test.dart` - TDD: tap triggers runner, pending disabled state, success path, failure path, refresh/export mutual exclusion, `peak-export-status` key
- [x] Verify: `flutter analyze` && `flutter test test/widget/peak_csv_export_settings_test.dart` && `flutter test`

## Risks / Out of scope

- **Risks**: fixed macOS path permissions; ObjectBox row order stability; `peak-refresh-status` vs `peak-export-status` coordination
- **Out of scope**: save dialog, CSV import, schema changes, robot journey test
