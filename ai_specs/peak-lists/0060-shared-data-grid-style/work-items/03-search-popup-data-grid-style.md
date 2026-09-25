---
type: Work Item
title: Apply Data Grid Style to Search Popup Results
parent: ../spec.md
---

## What to build

Refactor `MapSearchResultsList` to use the shared Data grid style for Search popup result rows without changing its result data, grouping, pagination, empty/loading states, keys, or selection callbacks.

## Required context

- `lib/widgets/map_search_results_list.dart` owns Search popup row construction and pagination notifications.
- `test/widget/map_screen_peak_search_test.dart` provides the current deterministic Search popup coverage and stable keys.
- Use the `DataGridTheme` from Work Item 01. Search popup results are not persistently selected.

## Acceptance criteria

- [x] Result rows use shared row padding, row typography, `columnGap` between icon, title/subtitle content, and trailing metadata, plus shared hover and pressed feedback without a persistent selected state.
- [x] A shared divider appears only between adjacent result rows, including ungrouped rows and rows within one group.
- [x] No divider appears between a group header and its first result, between a group's final result and the next group header or loading-more row, or around empty, minimum-query, and no-results states.
- [x] Existing entity-type icons, title/subtitle content, trailing metadata, grouping, sort ordering, loading-more behavior, pagination, keys, result taps, and scroll model remain unchanged.
- [x] Widget coverage uses a `1280 x 800` viewport and `TextScaler.linear(2.0)` to verify grouped, ungrouped, and loading-more divider placement, title/subtitle/trailing layout, no framework exception, result semantics, and keyboard activation.
- [x] `flutter test test/widget/map_screen_peak_search_test.dart test/widget/map_screen_appbar_search_test.dart` passes.

## Covers

- User Stories: 2
- Requirements: 4, 6, 7, 8
- Technical Decisions: 4, 5
- Testing Strategy: 4
- Interview Ledger: L1, L3, L4, L5, L7

## Blocked by

- `01-data-grid-theme-and-peak-lists.md`
