---
type: Spec
title: Search Popup Peak Efficiency And Lazy Loading
---

## Problem

The map screen `Search popup` still becomes slow on threshold-meeting peak queries because the current peak path scans all peaks in memory and enriches every matched peak with region and sheet-map metadata before the popup truncates results. The current popup path also still carries a fixed `20`-result contract, so even when the query can legitimately match more items, users cannot scroll beyond that first page. The newer minimum-query-length slice avoids expensive work for under-threshold input, but it does not address the main cost once a real peak query runs. [L1] [L2] [L4] [L6] [L7]

## Proposed Outcome

The map screen `Search popup` keeps its current visible search semantics, controls, entry points, helper states, and mixed-entity behavior, but replaces the fixed final `20`-result cap with incremental loading. Peak results use a popup-specific, storage-backed candidate lookup path that pages and filters candidates before expensive enrichment, so the popup can append more results as the user scrolls without reintroducing the current full-scan/full-enrichment cost. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## User Stories

1. As a map user, I want the `Search popup` to stay responsive when I run real peak queries, so threshold-meeting searches do not feel stalled while the popup computes all peak matches up front. [L1] [L4] [L6]
2. As a map user, I want to scroll for more `Search popup` results instead of being hard-stopped at `20`, so broad valid queries remain explorable without turning the popup into a full browse-all view. [L2] [L7]
3. As a map user, I want `All` mode to preserve one correctly sorted mixed result list while additional pages load, so lazy loading does not change what `All` means. [L3]
4. As a maintainer, I want popup-specific peak lookup and paging seams instead of reusing the current generic full-scan peak search path, so the popup can be optimized without changing unrelated peak search surfaces. [L1] [L4] [L6]

## Requirements

1. Scope this slice to the map screen `Search popup` only. Do not redesign unrelated peak-only search, peak-picking, admin, or peak-list add-picker behavior outside the popup. [L1]
2. Keep `Search popup` as the canonical term for this map-screen multi-entity search surface, and preserve the current popup entry points, popup close behavior, minimum-query-length helper behavior, empty states, selection behavior, entity buttons, region filter, sort, and grouping contract unless explicitly changed below. [L1] [L2] [L3] [L7]
3. Replace the current fixed final `20`-result `Search popup` contract with incremental loading. The popup must show the first `20` results immediately after a real search and append the next `20` when the user scrolls near the bottom of the loaded list. A final page shorter than `20`, or an empty next page, marks the active result set as exhausted; after exhaustion, the popup must not request more pages for that unchanged query/filter/sort/group state. [L2] [L7]
4. Incremental loading applies to every active popup entity mode: `Peaks`, `Tracks/Routes`, `Maps`, and `All`. Empty query must not turn into a browse-all mode. [L2] [L7]
5. When the popup query, entity filter, region filter, sort, or group changes, reset paging to the first loaded page for the new result set. Closing the popup must also clear any loaded-page state. [L2] [L7]
6. While an additional page is being prepared, keep already shown results visible and show a small inline loading-more affordance at the bottom of the results area only for the active load-more action. Do not replace the whole results area with a blocking loading state during append. Only one append may be active at a time for the current query/filter/sort/group state; repeated near-bottom triggers during that append must not duplicate page requests or duplicate rendered rows. [L2]
7. In `All` mode, lazy loading must preserve one combined globally sorted result list for the active query, region filter, and sort. The first and later pages may contain any mix of peaks, tracks, routes, and maps according to that single ordering. Do not force peaks into a separate trailing block. [L3]
8. Preserve current grouping semantics. When grouping is active, incremental loading must extend the final grouped display order for the active query, entity filter, region filter, sort, and group. Page windows in grouped mode are computed from that final grouped display order so later pages append rows without moving already rendered result rows, changing group meaning, or reclassifying already rendered rows. [L3]
9. Preserve current user-visible peak matching semantics in the `Search popup`. Keep case-insensitive substring matching on peak name and preserve the current elevation substring matching performed by `PeakRepository.searchPeaks()`. [L5] [L6]
10. Do not narrow peak matching to prefix-only search, do not change query syntax, and do not introduce a new relevance model in this slice. [L5]
11. Add a popup-specific peak candidate lookup path that is separate from the current generic `PeakRepository.searchPeaks()` path used by other surfaces. This popup path must support ordered paging before expensive per-result enrichment. [L4]
12. The popup-specific peak candidate lookup must use a storage-backed name search as its primary source of truth rather than loading all peaks into memory and scanning them in Dart. The same popup-specific seam must exist for in-memory test storage so automated tests stay deterministic. [L6]
13. Apply the active popup region filter to peak candidates as early as practical in the popup-specific peak path so later enrichment and rendering work is reduced. [L4]
14. Enrich only the currently requested page of peak candidates with map-name, region, subtitle, and other per-result projection work. Do not eagerly enrich every matched peak before page selection. [L4]
15. Popup peak candidate ordering must match the current visible popup result ordering before page windows are selected: compare the normalized display title according to the active popup sort direction, then use the stable result id string as the ascending tie-breaker. ObjectBox-backed and in-memory storage seams must produce the same ordered page windows. [L3] [L6]
16. If preserving current elevation-text matching requires a non-name fallback path, keep that fallback narrow and compatible with the popup paging contract rather than forcing the primary name path back to a full in-memory scan. Elevation-only fallback candidates must be merged with name candidates, deduplicated by peak identity, ordered by the same popup candidate ordering, and paged after that merged ordering is established. [L5] [L6]
17. Tracks, routes, and maps may keep their current visible search semantics in this slice, but they must participate in the same incremental-loading and global-ordering contract as peaks once the popup builds the combined result list. [L1] [L3] [L7]
18. This slice explicitly supersedes the older `Search popup` fixed-`20`-total-results contract in `ai_specs/app-skeleton/appbar-search-spec.md`. After this slice, `20` becomes the page size, not the final total. [L7]

## Technical Decisions

1. Keep the existing minimum-query-length guard in the shared `Search popup` path. This slice optimizes threshold-meeting searches and does not revisit the current under-threshold contract. [L1] [L7]
2. Keep `MapNotifier` or the existing popup state owner as the transient source of truth for popup query/filter/sort/group state, and extend that same popup-owned state with any loaded-page or load-more state needed for incremental loading rather than introducing popup persistence or a second parallel search controller.
3. Split popup peak work into two phases: candidate lookup first, enrichment second. Candidate lookup owns filtering, deterministic ordering, and page-window selection; enrichment owns subtitle/map/region projection only for the current page. [L4] [L6]
4. Prefer extending existing `PeakRepository` / `PeakStorage` seams with popup-specific paged lookup methods over introducing direct ObjectBox access from widgets or bypassing the repository layer. [L4] [L6]
5. Preserve deterministic popup ordering across storage implementations. The storage-backed ObjectBox path and in-memory test path must agree on how popup peak candidates are ordered before paging, including active sort direction and stable tie-breaking. [L3] [L6]
6. Avoid broad cross-app search unification in this slice. Existing non-popup peak search surfaces may continue using `PeakRepository.searchPeaks()` until a later dedicated migration or cleanup slice. [L1] [L4]

## Testing Strategy

1. Use behavior-first TDD for the popup peak-efficiency logic, especially the popup-specific peak candidate lookup, paging window behavior, and enrichment-only-current-page contract.
2. Extend service and repository coverage for the `Search popup` path to verify:
   - the first page returns `20` results and later pages append the next `20`
   - short or empty next pages mark the active result set exhausted and repeated near-bottom triggers do not duplicate append requests or rows
   - paging resets when query, entity filter, region filter, sort, or group changes
   - `All` mode preserves one combined globally sorted result list across pages
   - grouped mode pages from the final grouped display order and appends without moving already rendered result rows
   - popup peak matching semantics remain unchanged while the implementation moves to a popup-specific paged lookup path
   - name and elevation-only peak candidates are merged, deduplicated, ordered, and paged consistently across storage implementations
   - peak enrichment runs only for the requested page window, not for all matched peak candidates [L2] [L3] [L4] [L5] [L6] [L7]
3. Extend storage-level tests for both `ObjectBoxPeakStorage` and `InMemoryPeakStorage` to verify the popup-specific paged peak lookup seam stays deterministic and compatible with current visible peak matching behavior. [L6]
4. Extend widget coverage for `MapSearchPopup` / `MapSearchResultsList` behavior to verify:
   - helper and empty states remain unchanged
   - the first page renders initially
   - scrolling near the bottom appends another page
   - the inline loading-more affordance appears only during append
   - query/filter/sort/group changes reset the visible list to the first page [L2] [L7]
5. Update existing robot coverage only if needed for visible paging behavior or selectors. Do not add new robot journeys solely for this performance slice.
6. Keep automated tests deterministic with in-memory repositories, provider overrides, and existing popup seams. Do not require real storage setup beyond current ObjectBox-backed unit seams, network access, external services, or secrets.

## Out of Scope

1. Redesigning popup controls, changing visible copy, or changing entry/exit behavior outside the lazy-loading additions. [L1]
2. Changing non-popup peak search or picker surfaces to use the new popup-specific paged lookup path. [L1] [L4]
3. Changing peak matching semantics, such as switching to prefix-only matching or a new relevance model. [L5]
4. Adding persistent popup query/history state, background prefetch, offline caching, or a full browse-all search mode.
5. Broad search optimization work for unrelated features outside the map screen `Search popup`.

## Follow-Ups

1. If popup peak performance is still meaningfully slow after candidate paging and page-only enrichment ship, evaluate whether tracks/routes or map result projection also need candidate limiting or similar staged enrichment.
2. If other peak search surfaces later need the same performance profile, decide whether to migrate them to the popup-specific paged lookup seam or define a broader shared search contract.

## Notes

1. Relevant implementation surfaces include `lib/providers/map_provider.dart`, `lib/services/map_search_service.dart`, `lib/services/peak_repository.dart`, `lib/widgets/map_search_popup.dart`, `lib/widgets/map_search_results_list.dart`, `test/services/map_search_service_test.dart`, and `test/widget/map_screen_appbar_search_test.dart`.
2. The current code already has a storage-backed name query in `ObjectBoxPeakStorage.getByName(...)`, while the popup peak path still routes through a generic full-scan `PeakRepository.searchPeaks()` flow. This slice should realign the popup toward storage-backed candidate lookup and page-limited enrichment. [L4] [L6]
