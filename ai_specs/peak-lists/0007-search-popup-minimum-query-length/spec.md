---
type: Spec
title: Search Popup Minimum Query Length
---

## Problem

The map screen `Search popup` can feel very slow on short live queries because every non-empty query runs the shared multi-entity search path, including broad matching and result enrichment work. The map flow also still carries obsolete peak-only search plumbing and naming even though `MapSearchPopup` is now the actual shared surface, which increases the risk of future behavior drift.

## Proposed Outcome

The map screen has one canonical `Search popup` surface shared by the existing entry points. That popup uses one app-owned minimum query length constant in `constants.dart`, initially set to `2`, to block expensive real searches for under-threshold input while showing a clear helper state. The threshold behavior is fully covered by deterministic service and widget tests, and the map flow no longer keeps a separate peak-only search path in parallel. [L1] [L2] [L4] [L7]

## User Stories

1. As a map user, I want the `Search popup` to stay responsive while I type, so short partial input does not trigger an expensive live search.
2. As a map user, I want a clear helper state for under-threshold queries, so I can tell the difference between "type more" and "no matches found".
3. As a map user, I want the existing popup entry points to behave the same way, so I get one consistent search experience regardless of how I open it.
4. As a maintainer, I want one canonical map-search path, so future search fixes and tests do not drift across duplicate implementations.

## Requirements

1. Scope this slice to the map screen `Search popup` (`MapSearchPopup`) flow only; do not change unrelated peak-only search or peak-picking behavior outside that popup. [L1]
2. Keep `Search popup` as the canonical term for the map screen multi-entity popup flow in requirements, tests, and user-facing documentation for this slice. [L1]
3. Remove the separate peak-only map-search path so map-screen search entry points use one shared `Search popup` state and behavior instead of parallel peak-only logic or UI. [L2]
4. Preserve the existing shared popup entry points on the map screen, including the current AppBar trigger, the existing map Search FAB, and the current `Meta+F` keyboard shortcut, while routing them through the same popup state and cleanup behavior. [L2]
5. Add one app-owned minimum query length constant in `lib/core/constants.dart` for the `Search popup`, set its initial value to `2`, and do not expose it as a user setting in this slice. [L4]
6. Evaluate the threshold against the trimmed popup query. When the trimmed query is empty, keep the results area blank rather than showing helper or no-results text. [L3] [L4]
7. When the trimmed popup query is non-empty but below the shared minimum length, do not run a real search and show helper text in the results area using the exact visible format `Type at least N characters`, where `N` comes from the shared constant. [L3] [L5]
8. If the user deletes a previously valid query back under the minimum length, clear any prior results immediately and show the helper state instead of leaving stale matches on screen. [L3]
9. Show `No results found` only after a real popup search runs with a threshold-meeting query and returns no matches. Under-threshold input must not be treated as a completed no-match search. [L3]
10. While the query is under the minimum length, entity filter, region filter, sort, and group controls may still update their visible selected state, but entity filter, region filter, and sort must not trigger a real search or repopulate stale results. [L3] [L6]
11. Once the trimmed query reaches the threshold, the first real search must apply the current entity filter, region filter, and sort selections immediately. The current group selection must still be reflected immediately in result presentation. [L6]
12. Preserve current popup close and focus cleanup behavior after closing search from any shared entry point so map keyboard shortcuts and other transient overlays continue to recover cleanly. Opening search from the keyboard shortcut must still focus the popup search field, and closing the popup must restore map shortcut handling.

## Technical Decisions

1. Implement the minimum-length guard in the shared `Search popup` search path owned by the map-screen search controller/service layer, not inside generic repository APIs such as `PeakRepository.searchPeaks()`, so other peak-related UIs keep their current behavior. [L1] [L2] [L6]
2. Use the existing popup state and entry wiring rather than introducing a second controller or compatibility layer for peak-only map search. If obsolete peak-only state, selectors, or widgets remain in the map flow, remove or consolidate them as part of this slice. [L2]
3. Keep the under-threshold helper copy derived from the shared constant so a later threshold change from `2` to `3` does not require a separate copy update. [L4] [L5]
4. Keep `Search popup` state transient to the current map session. This slice does not introduce persistence, background prefetch, or offline caching for search input or results.
5. Reuse existing deterministic seams around `MapSearchService`, repository fakes, provider overrides, and popup widget tests rather than adding real storage or service dependencies. [L7]

## Testing Strategy

1. Use behavior-first TDD for the shared popup-search logic that enforces the minimum query length guard. [L7]
2. Extend service coverage for the popup search layer to verify:
   - empty trimmed query returns no results
   - non-empty under-threshold query does not execute a real search
   - the first threshold-meeting query executes using the current entity filter, region filter, and sort selections [L3] [L4] [L6] [L7]
3. Extend notifier or widget coverage for the popup state/UI to verify:
   - empty trimmed query keeps the results area blank
   - under-threshold helper state replaces stale prior results when the query shrinks
   - helper text `Type at least N characters` appears for non-empty under-threshold input
   - `No results found` appears only after a real threshold-meeting search returns nothing [L3] [L4] [L5] [L6] [L7]
4. Extend widget coverage for the popup UI to verify the shared popup behavior remains consistent from existing entry points such as the AppBar trigger, map Search FAB, and `Meta+F` keyboard shortcut. [L5] [L7]
5. Do not add new robot coverage solely for this threshold change. Update an existing robot journey only if the helper text or shared popup behavior causes a small necessary expectation change. [L7]
6. Keep automated tests deterministic with fake or in-memory repositories, provider overrides, and local seams only. Do not require real storage, network access, external services, or secrets. [L7]

## Out of Scope

1. Changing search behavior in unrelated non-popup peak search or peak-picking surfaces such as dialogs or admin tools. [L1]
2. Adding a user-configurable search threshold setting. [L4]
3. Broader popup search performance work such as storage-backed peak lookup, pre-enriched metadata caches, or candidate limiting beyond the threshold guard.

## Open Questions

1. After the threshold guard ships, should the shared popup threshold remain at `2` or be raised to `3` based on observed performance and usability feedback? The surrounding UX contract should remain unchanged either way. [L4]

## Follow-Ups

1. If popup search remains noticeably slow after the minimum-length guard, evaluate follow-up optimizations in the shared search path such as limiting candidates before enrichment or replacing full in-memory peak scans with more targeted lookup paths.

## Notes

1. Relevant implementation surfaces include `lib/core/constants.dart`, `lib/providers/map_provider.dart`, `lib/services/map_search_service.dart`, `lib/widgets/map_search_popup.dart`, `lib/widgets/map_search_results_list.dart`, `lib/screens/map_screen.dart`, `lib/widgets/map_action_rail.dart`, `lib/screens/map_screen_panels.dart`, `test/services/map_search_service_test.dart`, `test/widget/map_screen_appbar_search_test.dart`, and `test/widget/map_screen_peak_search_test.dart`.
2. Current code already renders `MapSearchPopup` from `showPeakSearch` state and `togglePeakSearch()` entry points, while still retaining obsolete peak-only naming and a legacy `MapPeakSearchPanel`; this slice should align that implementation with the single-surface product model.
