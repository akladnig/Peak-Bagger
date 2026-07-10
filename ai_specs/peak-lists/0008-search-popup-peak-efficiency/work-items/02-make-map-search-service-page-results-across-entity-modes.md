---
type: Work Item
title: Make Map Search Service Page Results Across Entity Modes
parent: ../spec.md
---

## What to build

Update `MapSearchService` so `Search popup` searches return page-windowed results and exhaustion metadata for `Peaks`, `Tracks/Routes`, `Maps`, and `All`. Preserve under-threshold behavior, empty-query behavior, one globally sorted mixed list in `All`, and grouped-mode final display ordering.

## Required context

The current service has a fixed `_maxResults = 20`, truncates after sorting, and returns only `List<MapSearchResult>`. The popup path must change `20` from final total to page size while keeping the older under-threshold guard from `MapConstants.searchPopupMinimumQueryLength`. Tracks, routes, and maps may keep their current visible search semantics, but they must participate in the same incremental-loading and global-ordering contract once the popup builds the combined result list.

Relevant files include `lib/services/map_search_service.dart`, `lib/services/peak_repository.dart`, `lib/models/map_search_result.dart`, `lib/services/map_search_region_filter.dart`, `lib/widgets/map_search_results_list.dart`, and `test/services/map_search_service_test.dart`.

## Acceptance criteria

- [x] `MapSearchService` exposes a popup search result shape that includes loaded page results and enough metadata for callers to know whether the active result set is exhausted.
- [x] Empty query still returns no results and does not become a browse-all mode.
- [x] Trimmed under-threshold popup queries still return no results without triggering peak search work.
- [x] The first page contains up to `20` results and later page requests append the next `20` for `Peaks`, `Tracks/Routes`, `Maps`, and `All`.
- [x] A final page shorter than `20`, or an empty next page, marks the active result set as exhausted.
- [x] `All` mode preserves one combined globally sorted result list for the active query, region filter, and sort, with pages containing any mix of peaks, tracks, routes, and maps according to that single ordering.
- [x] Grouped mode pages from the final grouped display order for the active query, entity filter, region filter, sort, and group so later pages append without moving already rendered result rows.
- [x] Peak result enrichment uses the popup-specific page-windowed peak candidate lookup from `01-add-popup-specific-paged-peak-candidate-lookup.md` and enriches only the requested page window.
- [x] Service tests cover first page, later page, exhaustion, reset inputs, `All` global ordering, grouped display-order paging, unchanged matching semantics, and enrichment-only-current-page behavior.

## Covers

- User Stories: 1-3
- Requirements: 2-8, 14-18
- Technical Decisions: 1, 3, 5
- Testing Strategy: 1-2, 6
- Interview Ledger: L2, L3, L4, L7

## Blocked by

01-add-popup-specific-paged-peak-candidate-lookup.md
