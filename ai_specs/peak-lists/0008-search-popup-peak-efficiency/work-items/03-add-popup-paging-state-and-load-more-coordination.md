---
type: Work Item
title: Add Popup Paging State And Load-More Coordination
parent: ../spec.md
---

## What to build

Extend `MapNotifier` / `MapState` popup-owned transient state with loaded-page, exhausted, and loading-more state. Reset paging on query, entity filter, region filter, sort, group, and popup close; prevent concurrent append duplication for the current query/filter/sort/group state.

## Required context

Current popup state lives in `MapState` and is updated by `MapNotifier._refreshSearchPopupResults(...)`. Opening and closing the popup already reset query, results, entity filter, region filter, sort, and group. Keep this as transient popup-owned state; do not add popup persistence, query/history storage, background prefetch, or a second parallel search controller.

Relevant files include `lib/providers/map_provider.dart`, `test/harness/test_map_notifier.dart`, `test/services/map_search_service_test.dart`, and existing widget tests that override `mapProvider`.

## Acceptance criteria

- [x] `MapState` tracks popup loaded-page or loaded-count state, loading-more state, and exhausted state for the active query/filter/sort/group result set.
- [x] Opening the `Search popup` starts from defaults and does not preserve prior loaded-page state.
- [x] Closing the `Search popup` clears query, results, entity filter, region filter, sort, group, loaded-page state, loading-more state, and exhausted state.
- [x] Changing popup query, entity filter, region filter, sort, or group resets paging to the first loaded page for the new result set.
- [x] Loading more keeps already shown results visible and appends the next page returned by `MapSearchService`.
- [x] Only one append may be active at a time for the current query/filter/sort/group state; repeated load-more triggers during that append do not duplicate requests or duplicate rendered rows.
- [x] Exhausted result sets do not request more pages until query/filter/sort/group changes create a new active result set.
- [x] Existing popup entry points, close behavior, minimum-query-length helper behavior, empty states, selection behavior, entity buttons, region filter, sort, and grouping controls remain unchanged except for lazy-loading additions.
- [x] Provider/notifier tests cover initial load, append, exhaustion, duplicate-trigger suppression, reset on each popup state change, and reset on popup close.

## Covers

- User Stories: 2-3
- Requirements: 2-8, 17-18
- Technical Decisions: 1-2
- Testing Strategy: 2, 6
- Interview Ledger: L2, L3, L7

## Blocked by

02-make-map-search-service-page-results-across-entity-modes.md
