## Overview

Fix GPX import dialog layout only. Keep current import semantics; tighten shell spacing, no-wrap title, and scrollable selected-file area.

**Spec**: `ai_specs/import-dialog-fix-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first Flutter UI; dialogs/widgets under `lib/widgets`; importer/result logic under `lib/services`
- **State management**: Riverpod/Notifier elsewhere; dialog itself uses local widget state + injected callbacks
- **Reference implementations**: `lib/widgets/gpx_import_dialog.dart`, `lib/widgets/dialog_helpers.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/core/constants.dart`, `test/widget/gpx_import_dialog_test.dart`
- **Assumptions/Gaps**: no robot journey currently opens the import dialog UI; widget tests are the primary verification lane

## Plan

### Phase 1: Dialog shell + title

- **Goal**: fixed title/actions, popup-aligned padding, no title wrap
- [x] `lib/widgets/gpx_import_dialog.dart` - keep `AlertDialog`; add constrained body layout; title row fixed; actions fixed; content padding aligned to `UiConstants.dialogMargin`
- [x] `test/widget/gpx_import_dialog_test.dart` - TDD: title remains single-line on narrow/standard widths; dialog stays within viewport
- [x] `test/widget/gpx_import_dialog_test.dart` - TDD: cancel / picker-failure regressions still unchanged
- [x] Verify: `flutter analyze` && `flutter test test/widget/gpx_import_dialog_test.dart`

### Phase 2: Multi-file scroll behavior

- **Goal**: selected-file list expands then scrolls when height exhausted
- [x] `lib/widgets/gpx_import_dialog.dart` - constrain content area to viewport minus top/bottom padding; make only file list scroll
- [x] `test/widget/gpx_import_dialog_test.dart` - TDD: multi-file selection exposes all rows via scrolling; single-file case stays compact
- [ ] `test/widget/gpx_import_dialog_test.dart` - TDD: success dialog still shows existing counts; unchanged summary preserved (blocked: widget-test selection path does not reliably surface the completion modal without a new test seam)
- [x] Verify: `flutter analyze` && `flutter test test/widget/gpx_import_dialog_test.dart`

## Risks / Out of scope

- **Risks**: `AlertDialog` intrinsic sizing can fight custom height constraints; long filenames can still wrap if title/content constraints are too loose
- **Out of scope**: duplicate-track copy changes; import parsing/dedup rules; robot journey coverage for this dialog
