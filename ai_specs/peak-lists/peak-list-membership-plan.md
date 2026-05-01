## Overview

Peak dialog `List(s)` derived from all memberships for the clicked peak; comma-separated.
Keep the current dialog flow; add a small repository lookup plus widget and robot coverage.

**Spec**: None (quick plan from task description)

## Context

- **Structure**: feature-first; widgets/services/tests co-located
- **State management**: Riverpod; dialog already receives `PeakListRepository`
- **Reference implementations**: `lib/widgets/peak_list_peak_dialog.dart`, `lib/services/peak_list_repository.dart`, `test/services/peak_list_repository_test.dart`, `test/robot/peaks/peak_lists_journey_test.dart`
- **Assumptions/Gaps**: alphabetical membership order; empty membership => `—`; add stable key for membership value

## Plan

### Phase 1: Membership lookup + dialog render

- **Goal**: derive all list names for a peak; render them in `List(s)`
- [x] `lib/services/peak_list_repository.dart` - add lookup helper over `getAllPeakLists()` + `decodePeakListItems`; match by peak OSM id; dedupe; sort names
- [x] `lib/widgets/peak_list_peak_dialog.dart` - replace `widget.peakList.name` with derived membership text; keep `List(s)` label; add stable key on value text
- [x] `test/services/peak_list_repository_test.dart` - TDD: peak in 2 lists returns 2 names; no duplicates; deterministic order
- [x] `test/widget/peak_list_peak_dialog_test.dart` - TDD: dialog shows comma-separated memberships in `List(s)` row
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_list_repository_test.dart test/widget/peak_list_peak_dialog_test.dart`

### Phase 2: Journey coverage

- **Goal**: lock click path + visible membership text
- [x] `test/robot/peaks/peak_lists_robot.dart` - add selector/helper for the `List(s)` membership value
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - TDD: open peak dialog; assert all memberships shown
- [x] Verify: `flutter analyze` && `flutter test test/robot/peaks/peak_lists_journey_test.dart`

## Risks / Out of scope

- **Risks**: ordering may differ from existing list display; repository lookup scans encoded list payloads
- **Out of scope**: data model / schema rewrite; editing memberships UI
