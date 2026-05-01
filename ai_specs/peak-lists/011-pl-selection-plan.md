## Overview

Inline multi-select peak add flow in `PeakListPeakDialog`; new row widget, inline points, partial-save reporting.
Keep shared map-search behavior untouched; wire screen handoff + robot journey after the dialog slice.

**Spec**: `ai_specs/011-pl-selection-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first widgets + screen + robot/widget tests
- **State management**: Riverpod + local dialog `StatefulWidget` state
- **Reference implementations**: `lib/widgets/peak_list_peak_dialog.dart`, `lib/screens/peak_lists_screen.dart`, `test/widget/peak_list_peak_dialog_test.dart`, `test/robot/peaks/peak_lists_robot.dart`, `test/robot/peaks/peak_lists_journey_test.dart`
- **Assumptions/Gaps**: add mode only; shared `PeakSearchResultsList` unchanged; first saved alphabetical peak becomes active selection after add

## Plan

### Phase 1: Dialog slice

- **Goal**: search results list + separate selected-peaks list + save semantics
- [x] `lib/widgets/peak_multi_select_results_list.dart` - search-mode row widget; checkbox, compact single row, stable keys, lazy-loaded results
- [x] `lib/widgets/peak_selected_peaks_list.dart` - new selected-peaks list below results; checkbox, highlight, inline points control, stable keys
- [x] `lib/widgets/peak_list_peak_dialog.dart` - split add-mode layout into search results + selected list; keep alphabetical save order and partial failures
- [x] `test/widget/peak_list_peak_dialog_test.dart` - update coverage for separate selected list, selection handoff, points editing there, lazy-loaded search results, and unknown-height dash rendering
- [x] `TDD:` search row selects peaks into the separate list; selected list renders default points `1`; editing points auto-selects and clamps `0-10`; unknown height renders as `—`
- [x] `TDD:` save selected peaks in alphabetical order; continue through failures; report all failed peaks after the loop
- [ ] Verify: `flutter analyze` && `flutter test` (focused peak slice tests pass; full suite still has unrelated failures)

### Phase 2: Screen handoff + robot journey

- **Goal**: add-dialog result drives list selection; critical journey covered end-to-end
- [x] `lib/screens/peak_lists_screen.dart` - consume multi-add outcome; select first saved alphabetical peak; preserve cancel/error behavior
- [x] `test/widget/peak_lists_screen_test.dart` - assert add-dialog close updates selected peak row and pane state
- [x] `test/robot/peaks/peak_lists_robot.dart` - add stable selectors/actions for selected-list rows and points fields
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - critical journey: search, select multiple peaks, edit points in selected list, save, verify selected row and point totals
- [x] `TDD:` first saved peak becomes active selection after dialog close; cancel leaves current selection unchanged
- [x] `Robot:` key-first flow only; no semantics reliance
- [ ] Verify: `flutter analyze` && `flutter test` (focused peak slice tests pass; full suite still has unrelated failures)

## Risks / Out of scope

- **Risks**: compact row width at 320px; partial-save error reporting after per-item writes; selector drift if keys are not kept stable
- **Out of scope**: map-search `PeakSearchResultsList`; edit/view mode changes; peak model/schema migrations
