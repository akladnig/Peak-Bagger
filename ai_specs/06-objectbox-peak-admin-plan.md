## Overview

Add Peak-only inline edit/delete to the ObjectBox Admin browser. Keep all non-Peak entities read-only, preserve current browse behavior, and drive the work in small TDD slices.

**Spec**: `ai_specs/06-objectbox-peak-admin-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/services`, `lib/providers`, `lib/screens`, `lib/widgets`, `test/harness`, `test/services`, `test/widget`, `test/robot`
- **State management**: Riverpod providers with screen-scoped UI state in the admin shell/details pane
- **Reference implementations**: `lib/screens/peak_lists_screen.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/widgets/dialog_helpers.dart`, `lib/services/peak_repository.dart`, `test/services/peak_repository_test.dart`, `test/robot/peaks/peak_lists_robot.dart`
- **Assumptions/Gaps**: Peak save likely needs a richer result than `Future<Peak>` so the UI can surface PeakList rewrite warnings; keep `PeakListRewritePort` and `PeakDeleteGuard` testable via provider overrides

## Plan

### Phase 1: Lock down the mutation seams

- **Goal**: define the pure edit/delete contracts before touching the UI
- [x] `lib/services/peak_admin_editor.dart` - add a pure helper for Peak draft parsing, normalization, Tasmania bounds checks, and inline validation copy
- [x] `lib/services/peak_delete_guard.dart` - add dependency checks for `GpxTrack`, `PeakList`, and `PeaksBagged`, ignoring malformed `PeakList.peakList` JSON
- [x] `lib/services/peak_repository.dart` - add the `PeakListRewritePort` seam and the save/delete result shapes needed for cascade warnings
- [x] `lib/providers/peak_provider.dart` - wire production `PeakDeleteGuard` and `PeakListRewritePort` from `objectboxStore`
- [x] `test/services/peak_admin_editor_test.dart` - TDD helper coverage for parsing, derivation, and validation
- [x] `test/services/peak_delete_guard_test.dart` - TDD guard coverage for blocker ordering and display names
- [x] `test/services/peak_repository_test.dart` - TDD save/delete and cascade rewrite coverage
- [x] Verify: `flutter test test/services/peak_admin_editor_test.dart test/services/peak_delete_guard_test.dart test/services/peak_repository_test.dart`

### Phase 2: Wire the admin UI

- **Goal**: Peak rows gain inline edit/delete affordances; other entities stay browse-only
- [x] `lib/screens/objectbox_admin_screen_details.dart` - add Peak edit mode, edit FAB, inline form controls, submit action, and edit-state reset on selection change/close/delete
- [x] `lib/screens/objectbox_admin_screen_table.dart` - add a Peak-only actions column with per-row delete affordance and stable keys
- [x] `lib/screens/objectbox_admin_screen.dart` - coordinate save/delete refresh, dialogs, and selection retention
- [x] `lib/providers/objectbox_admin_provider.dart` - keep Peak selection stable across save refreshes and clear it only when the selected row is removed
- [x] `test/widget/objectbox_admin_shell_test.dart` - cover edit mode, validation, success dialog, and delete confirmation
- [x] `test/widget/objectbox_admin_browser_test.dart` - cover Peak-only affordances and non-Peak read-only behavior
- [x] Verify: `flutter test test/widget/objectbox_admin_shell_test.dart test/widget/objectbox_admin_browser_test.dart`

### Phase 3: Journey + hardening

- **Goal**: lock the happy path and the delete-blocked path end to end
- [x] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - add selectors for edit, submit, fields, and delete controls
- [x] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - add the Peak edit/save journey from the admin shell
- [x] `test/widget/objectbox_admin_shell_test.dart` - cover dependency-blocked delete and malformed PeakList warning handling
- [x] `test/widget/objectbox_admin_browser_test.dart` - cover delete refresh and selection behavior after row removal
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Main-map shortcut

- **Goal**: let Peak details jump straight to the main map without leaving the admin shell
- [ ] `lib/screens/objectbox_admin_screen_details.dart` - add a Peak-only `View Peak on Main Map` icon button with `visibilityOutlined`, placed left of the edit FAB
- [ ] `lib/screens/objectbox_admin_screen.dart` - wire the shortcut so it opens `MapScreen` and centers the map on the selected Peak at zoom 15
- [ ] `test/widget/objectbox_admin_shell_test.dart` - cover shortcut visibility and click behavior from the Peak details pane
- [ ] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - cover the Peak details -> main map shortcut journey end to end
- [ ] Verify: `flutter test test/widget/objectbox_admin_shell_test.dart test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

### Follow-up: New Peak default id

- [ ] `lib/screens/objectbox_admin_screen_details.dart` - prefill create-mode `osmId` with the next available negative number while keeping it editable
- [ ] `lib/screens/objectbox_admin_screen.dart` - ensure newly created Peaks remain selected on save

### Follow-up: Map marker refresh

- [ ] `lib/screens/objectbox_admin_screen.dart` - refresh `MapScreen` peak markers after any Peak save, including create and edit, via `reloadPeakMarkers()`

## Risks / Out of scope

- **Risks**: cascade warning shape may require a small save-result refactor; selector churn in the details pane; keeping delete blockers deterministic without a live store
- **Out of scope**: mutation support for non-Peak entities, router/shell changes, new dependencies, broad layout redesign
