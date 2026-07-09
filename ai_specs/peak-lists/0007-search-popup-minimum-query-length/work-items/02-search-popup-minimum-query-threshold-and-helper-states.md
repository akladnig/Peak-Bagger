---
type: Work Item
title: Search Popup Minimum Query Threshold and Helper States
parent: ../spec.md
---

## What to build
Add one app-owned `Search popup` minimum query length constant in `lib/core/constants.dart`, initially set to `2`, and enforce that trimmed-query threshold in the shared map-screen popup search path so empty queries keep the results area blank, non-empty under-threshold queries do not run a real search and instead show the exact helper text `Type at least N characters`, stale results clear immediately when a previously valid query drops back under threshold, and `No results found` appears only after a real threshold-meeting search returns nothing. Keep entity filter, region filter, sort, and group controls visually usable while under threshold, but block real search execution until the query reaches the shared minimum and ensure the first threshold-meeting search applies the current control selections immediately.

## Required context
- `lib/core/constants.dart` is the required home for the single app-owned minimum query length constant from Interview Ledger `L4`; keep helper copy derived from that constant rather than duplicating the number in UI text.
- `lib/services/map_search_service.dart` is the shared popup-search seam identified by the Spec for minimum-length enforcement. Do not move this guard into generic repository APIs such as `PeakRepository.searchPeaks()` because unrelated peak search surfaces remain out of scope.
- `lib/providers/map_provider.dart` currently refreshes popup results through `_refreshSearchPopupResults(...)` and also mirrors peak-only `searchQuery` and `searchResults` state. This item should preserve the current popup state model while preventing under-threshold control changes from running a real search or restoring stale results.
- `lib/widgets/map_search_popup.dart` and `lib/widgets/map_search_results_list.dart` own the visible query-entry and results-area behavior, including the blank-vs-message states that need to distinguish empty, helper, and real no-results outcomes.
- Follow the existing deterministic seams in `test/services/map_search_service_test.dart` and `test/widget/map_screen_peak_search_test.dart`. Reuse fake repositories, provider overrides, and stable selectors instead of adding storage, network, or external-service dependencies.

## Acceptance criteria
- [x] `lib/core/constants.dart` defines one app-owned `Search popup` minimum query length constant, initially set to `2`, and this slice does not expose that value as a user setting.
- [x] The shared popup-search path evaluates the threshold against the trimmed query, returns no results for an empty trimmed query, and does not execute a real popup search for a non-empty under-threshold query.
- [x] When the trimmed popup query is non-empty but below the shared minimum length, the results area shows the exact visible helper text `Type at least N characters`, where `N` comes from the shared constant.
- [x] When the trimmed popup query is empty, the results area stays blank rather than showing helper text or `No results found`.
- [x] If the user deletes a previously valid query back under the threshold, any prior popup results clear immediately and the helper state replaces those stale matches.
- [x] `No results found` appears only after a real popup search runs with a threshold-meeting query and returns no matches; under-threshold input is not treated as a completed no-match search.
- [x] While the query is under the minimum length, entity filter, region filter, sort, and group controls may still update their visible selected state, but entity filter, region filter, and sort do not trigger a real search or repopulate stale results.
- [x] Once the trimmed query reaches the threshold, the first real search immediately applies the current entity filter, region filter, and sort selections, and the current group selection still applies immediately to result presentation.
- [x] Behavior-first TDD drives this item. Service coverage proves empty trimmed queries return no results, non-empty under-threshold queries do not execute a real search, and the first threshold-meeting search uses the current entity filter, region filter, and sort selections.
- [x] Widget or notifier coverage proves the blank empty-query state, helper-text state, stale-result clearing when the query shrinks under threshold, `No results found` only after a real threshold-meeting search, and under-threshold shared popup behavior from the supported entry points.
- [x] Automated tests remain deterministic and use fake or in-memory repositories, provider overrides, and local seams only, with no real storage, network access, external services, or secrets.

## Covers
- User Stories: 1-3
- Requirements: 5-11
- Technical Decisions: 1, 3-5
- Testing Strategy: 1-6
- Interview Ledger: L3-L7

## Blocked by
- `01-canonical-search-popup-wiring-cleanup.md`
