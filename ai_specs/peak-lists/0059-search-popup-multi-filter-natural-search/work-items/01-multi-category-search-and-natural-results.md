---
type: Work Item
title: Multi-Category Search And Natural Results
parent: ../spec.md
---

## What to build

Replace the map Search popup's mutually exclusive `MapSearchEntityFilter` with an immutable set of independently enabled `Peaks`, `Tracks/Routes`, `Natural`, `Roads`, and `Maps` categories. Remove the obsolete `All` category and implement the category-set contract through `MapState`, notifier criteria and refresh paths, `MapSearchService`, the Search popup, result rows, production Riverpod wiring, and `TestMapNotifier`.

Implement synchronous local `NaturalFeature` search through an injected `NaturalFeatureRepository`. Add a Natural Feature payload and `MapSearchResultType` variant to `MapSearchResult`; compose matching Natural Feature entries with the existing result union, resolved-coordinate region filtering, global name sort, type grouping, pagination, loading-more, and ordinary empty-result behavior. Update every affected result-type switch, row icon, grouping label, stable key, and test construction path needed for this slice. Natural-result map selection/navigation is completed by Work Item 02.

## Required context

- `../spec.md` and `../interview-ledger.md` are the source of truth; preserve exact labels, data shapes, matching exclusions, title/subtitle formatting, date-range behavior, selectors, and verification requirements.
- `../../../../GLOSSARY.md` defines the canonical terms `Search popup`, `Track`, `Track date`, `Roads search`, `Natural Feature`, and `OSM feature identity`.
- Follow the existing map search implementation in `lib/models/map_search_result.dart`, `lib/services/map_search_service.dart`, `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `lib/widgets/map_search_popup.dart`, and `lib/widgets/map_search_results_list.dart`.
- Use the existing local repository seam in `lib/services/natural_feature_repository.dart` and production override in `lib/providers/natural_feature_provider.dart`; do not add a network, refresh/import action, controller, timer, persistence, logging, configuration, secret, or Natural-specific loading/error UI.
- Match current notifier and paging test conventions in `test/harness/test_map_notifier.dart`, `test/providers/map_provider_search_selection_test.dart`, `test/services/map_search_service_test.dart`, `test/services/map_search_region_filter_test.dart`, `test/models/map_search_result_test.dart`, `test/widget/map_screen_peak_search_test.dart`, and `test/widget/map_screen_appbar_search_test.dart`.
- Use `NaturalFeatureRepository.test(InMemoryNaturalFeatureStorage(...))` for service, notifier/provider, and widget tests. Do not use ObjectBox, network services, API keys, or external secrets.
- No dependency change is expected; do not modify `pubspec.yaml` unless implementation proves an existing dependency cannot meet an explicit Spec contract.

## Acceptance criteria

- [ ] The Search popup replaces its mutually exclusive controls with independent `Peaks`, `Tracks/Routes`, `Natural`, `Roads`, and `Maps` buttons, removes `All`, and preserves each exact visible label. Tapping one button toggles only that category and immediately refreshes the first result page with the current query, region, sort, group, and Track date criteria.
- [ ] The enabled categories form one union result set and retain the current minimum-query-length, global name sort, grouping, pagination, region filtering, loading-more, and normal empty-result behavior. When all categories are disabled, results are empty with no stale entries and no implicit category re-enable.
- [ ] Every popup opening, including the app-bar trigger, Search FAB, and keyboard shortcut, selects exactly `Peaks`, `Tracks/Routes`, and `Natural`, and leaves `Roads` and `Maps` unselected. Closing then reopening resets to that exact state; no category selection is persisted across popup closes or app restarts.
- [ ] Each category-set change resets pagination and invalidates in-flight load-more work through the existing request-serial lifecycle. Preserve the existing `TextEditingController`, debounce timer, focus nodes, request serial, and result-list cleanup; do not add controllers, streams, or timers.
- [ ] The enabled `Natural` control searches the local singular `NaturalFeature` entity synchronously. It matches only a case-insensitive substring in `name` or non-empty `altName`; it does not match `tag`, OSM type or ID, country, county, region, coordinates, MGRS values, or source-of-truth values.
- [ ] A Natural result title is `name` unless the trimmed, lowercased query is a substring of trimmed, lowercased non-empty `altName`; in that case, including when `name` also matches, the title is exactly `name / altName`. Its subtitle contains the normalized `tag` followed by the resolved map region, joined by ` · ` when both exist. Tag normalization trims whitespace, replaces `_` with spaces, splits `;`, trims non-empty values, title-cases every word, and joins multiple values with ` / `; it uses the stored tag value, including the existing more-specific OSM `water` refresh behavior.
- [ ] Natural entries apply the existing resolved-coordinate region filter and participate in the established name sort, pagination, and type grouping. Their visible group label is `Natural`, their result-list icon follows the existing forest convention, and their selector is exactly `map-search-result-natural-<osmType>-<osmId>` using collision-free OSM feature identity, for example `map-search-result-natural-way-12345`.
- [ ] With an active Track date range, only enabled date-matching Tracks and enabled associated Peaks appear. Natural, Roads, and Maps are suppressed from date-qualified results without changing any enabled-category state; with neither `Peaks` nor `Tracks/Routes` enabled, date-qualified results are empty.
- [ ] Existing horizontal control scrolling, keyboard operation, and selected-button styling remain intact. Every category control exposes its exact label, button role, and selected/unselected state to assistive technology, remains reachable at `TextScaler.linear(2.0)`, and remains operable at supported desktop text scales.
- [ ] Service tests cover injected in-memory Natural Feature data for name and alternate-name matching, case-insensitivity, excluded fields, the exact title/subtitle rules, tag normalization, resolved-region filtering, default-category inclusion, Natural-disabled exclusion, all-disabled emptiness, ordering, pagination, and the `Natural` type group.
- [ ] Service and notifier/provider tests cover one-category-at-a-time updates, first-page refresh, outstanding load-more invalidation, exact open/reset defaults, Roads/Maps disabled defaults, and no persisted selection. Track date tests cover suppression of enabled Natural/Roads/Maps without state mutation, independent Peaks/Tracks eligibility, and empty results when both are disabled.
- [ ] Search popup widget tests use stable selectors for every category button and the exact Natural result selector. They cover toggle semantics, selected-state accessibility semantics, initial/reset state, removed `All`, Natural row copy/grouping, empty local data, all-disabled results, and horizontally reachable accessible controls at `TextScaler.linear(2.0)`.

## Covers

- User Stories: 1, 2, 4; 3 (Natural result discovery and presentation)
- Requirements: 1-6, 8-10
- Technical Decisions: 1-3, 5-6
- Testing Strategy: 1-4
- Interview Ledger: L1, L2, L3, L5, L6, L7

## Blocked by

None - ready to start
