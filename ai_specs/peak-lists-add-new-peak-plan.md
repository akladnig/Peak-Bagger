## Overview

Keep selected peaks visible in `Add New Peak`; show checked state in the top results list.
Split the add-dialog space evenly between search results and selected peaks.

**Spec**: None (quick plan from task description)

## Context

- **Structure**: feature-first; dialog + list widgets + widget/robot tests
- **State management**: Riverpod; dialog state local to `PeakListPeakDialog`
- **Reference implementations**: `lib/widgets/peak_list_peak_dialog.dart`, `lib/widgets/peak_multi_select_results_list.dart`, `lib/widgets/peak_selected_peaks_list.dart`, `test/widget/peak_lists_screen_test.dart`, `test/robot/peaks/peak_lists_journey_test.dart`
- **Assumptions/Gaps**: top list should keep selected rows in search results; equal height means split remaining dialog body space 50/50 when bottom list is shown

## Plan

### Phase 1: Keep selected rows visible

- **Goal**: stop filtering selected peaks out of the top list; preserve checked rows
- [x] `lib/widgets/peak_list_peak_dialog.dart` - remove `_searchResults()` exclusion of `_selectedPeakIds`; keep selected peaks in result set; preserve sort/order
- [x] `lib/widgets/peak_multi_select_results_list.dart` - keep checkbox state and selected styling for visible selected rows; no removal-on-select behavior
- [x] `test/widget/peak_list_peak_dialog_test.dart` - TDD: selected peak stays in top list after tap; checkbox remains checked; save still persists points/order
- [x] `test/widget/peak_multi_select_results_list_test.dart` - TDD: retained row stays highlighted when checked
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: add peak; selected row still visible in search list with checked selector
- [ ] Verify: `flutter analyze` && `flutter test test/widget/peak_list_peak_dialog_test.dart test/widget/peak_multi_select_results_list_test.dart test/robot/peaks/peak_lists_journey_test.dart` (blocked: full `flutter test` still has unrelated failures in `gpx_tracks_shell_test.dart`, `gpx_tracks_selection_test.dart`)

### Phase 2: Equal-height panes

- **Goal**: split add-dialog content into matching top/bottom heights
- [x] `lib/widgets/peak_list_peak_dialog.dart` - replace bottom `ConstrainedBox(maxHeight: 240)` with shared flex layout; top/bottom panels each `Expanded`
- [x] `lib/widgets/peak_selected_peaks_list.dart` - keep internal scroll behavior; ensure empty/short lists do not break equal-height split
- [x] `test/widget/peak_list_peak_dialog_test.dart` - TDD: both panels render with same available height; bottom list still scrolls when long
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: add multiple peaks; verify both panes remain visible and scroll independently
- [ ] Verify: `flutter analyze` && `flutter test test/widget/peak_list_peak_dialog_test.dart test/robot/peaks/peak_lists_journey_test.dart` (blocked: full `flutter test` still has unrelated failures in `gpx_tracks_shell_test.dart`, `gpx_tracks_selection_test.dart`)

## Risks / Out of scope

- **Risks**: dialog height on small screens; existing filter/order assumptions in save flow; empty selected list may need a placeholder if equal-height split is always enforced
- **Out of scope**: data model changes; list editing beyond add-dialog selection behavior
