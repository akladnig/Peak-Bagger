## Overview

Fix GPX import dialog layout only. Keep current import semantics; tighten shell spacing, keep the title single-line, remove the production double-dialog cap, and let the selected-file area expand vertically before it scrolls.

**Spec**: `ai_specs/import-dialog-fix-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first Flutter UI; dialogs/widgets under `lib/widgets`; importer/result logic under `lib/services`
- **State management**: Riverpod/Notifier elsewhere; dialog itself uses local widget state + injected callbacks
- **Reference implementations**: `lib/widgets/gpx_import_dialog.dart`, `lib/widgets/map_action_rail.dart`, `lib/widgets/dialog_helpers.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/core/constants.dart`, `test/widget/gpx_import_dialog_test.dart`
- **Assumptions/Gaps**: no robot journey currently opens the import dialog UI; widget tests are the primary verification lane

## Plan

### Phase 1: Dialog shell + title

- **Goal**: fixed title/actions, popup-aligned padding, no title wrap
- [x] `lib/widgets/gpx_import_dialog.dart` - replace the previous dialog shell with a custom `Dialog` + `Card`; title row fixed; actions fixed; content padding aligned to the popup spacing rhythm
- [x] `lib/widgets/map_action_rail.dart` - remove the extra outer `Dialog` / `ConstrainedBox(maxWidth: 320, maxHeight: 360)` wrapper so the production path uses `GpxImportDialog` directly
- [x] `test/widget/gpx_import_dialog_test.dart` - TDD: title remains single-line on narrow/standard widths; dialog stays within viewport
- [x] `test/widget/gpx_import_dialog_test.dart` - TDD: cancel / picker-failure regressions still unchanged
- [x] Verify: `flutter analyze` && `flutter test test/widget/gpx_import_dialog_test.dart`

### Phase 2: Multi-file scroll behavior

- **Goal**: selected-file list expands then scrolls when height exhausted
- [x] `lib/widgets/gpx_import_dialog.dart` - measure dialog chrome at runtime and render selected files as plain content first, switching only the file section to a bounded `ListView` when the available height is exhausted
- [x] `lib/widgets/gpx_import_dialog.dart` - restore the previous narrow dialog width (`320`) while keeping the dynamic vertical-fit behavior
- [x] `test/widget/gpx_import_dialog_test.dart` - TDD: multi-file selection exposes all rows via scrolling; dialog height increases as more files are selected when space allows
- [ ] `test/widget/gpx_import_dialog_test.dart` - TDD: success dialog still shows existing counts; unchanged summary preserved (still deferred: widget-test selection path does not reliably surface the completion modal without a new test seam)
- [x] Verify: `flutter analyze` && `flutter test test/widget/gpx_import_dialog_test.dart`

## Risks / Out of scope

- **Risks**: runtime chrome-height measurement may need retuning if the dialog typography or button heights change; long filenames can still wrap if field constraints change substantially
- **Out of scope**: duplicate-track copy changes; import parsing/dedup rules; robot journey coverage for this dialog
