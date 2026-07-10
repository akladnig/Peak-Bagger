---
type: Work Item
title: Wire Visible Popup Lazy Loading UI
parent: ../spec.md
---

## What to build

Update `MapSearchPopup` / `MapSearchResultsList` to trigger append when scrolling near the bottom, keep existing results visible, show a small inline loading-more affordance only during append, preserve helper and empty states, preserve stable selectors, and keep selection/entry/close behavior unchanged.

## Required context

`MapSearchPopup` owns the visible controls, debounce behavior, and stable selectors such as `map-search-input`, `map-search-entity-*`, `map-search-filter-*`, `map-search-sort-*`, and `map-search-group-*`. `MapSearchResultsList` owns result rows with stable keys like `map-search-result-<type>-<id>` and group headers. Preserve these selectors and the existing user-visible copy: `Search`, `Results`, `Type at least ${MapConstants.searchPopupMinimumQueryLength} characters`, and `No results found`.

Relevant files include `lib/widgets/map_search_popup.dart`, `lib/widgets/map_search_results_list.dart`, `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `test/widget/map_screen_appbar_search_test.dart`, `test/robot/map/appbar_search_robot.dart`, and `test/robot/map/appbar_search_journey_test.dart`.

## Acceptance criteria

- [x] Scrolling near the bottom of the loaded `Search popup` results requests the next page when the active result set is not exhausted.
- [x] The first page renders initially after a real search and later pages append without replacing the whole results area.
- [x] Already shown results remain visible while another page is being prepared.
- [x] A small inline loading-more affordance appears at the bottom of the results area only during the active append action.
- [x] Helper and empty states remain unchanged: empty query shows no browse-all results, under-threshold query shows the existing minimum-length helper, and no matches show `No results found`.
- [x] Query, entity filter, region filter, sort, and group changes reset the visible list to the first page.
- [x] Existing popup entry points, close behavior, result selection behavior, controls, region filter, sort, grouping controls, and disabled `Natural` / `Roads` buttons remain unchanged.
- [x] Stable selectors remain available for popup root, search field, entity buttons, filter button, sort button, group button, result rows, and any new loading-more affordance.
- [x] Widget tests cover initial render, near-bottom append, inline loading-more visibility, reset on popup state changes, helper/empty states, and duplicate-trigger-safe behavior through deterministic provider overrides.
- [x] Existing robot coverage is updated only if needed for visible paging behavior or selectors; do not add new robot journeys solely for this performance slice.

## Covers

- User Stories: 2-3
- Requirements: 1-8, 17-18
- Testing Strategy: 4-6
- Interview Ledger: L1, L2, L3, L7

## Blocked by

03-add-popup-paging-state-and-load-more-coordination.md
