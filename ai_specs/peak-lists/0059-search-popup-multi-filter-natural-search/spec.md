---
type: Spec
title: Search Popup Multi-Filter Natural Search
---

## Problem

The map `Search popup` exposes mutually exclusive entity filters and an All button. Natural is disabled and produces no results even though a local `NaturalFeature` collection exists. Users cannot combine useful result categories or discover and navigate to Natural Features from map search. [L1] [L2]

## Proposed Outcome

Make the Search popup entity controls independent category toggles. Each popup opening starts with Peaks, Tracks/Routes, and Natural enabled, while Roads and Maps start disabled. Natural search reads the existing local `NaturalFeature` collection, presents the agreed result content, and navigates the map using the established Natural Feature behavior. [L1] [L2] [L3] [L4] [L5] [L6]

## User Stories

1. As a map user, I can independently enable or disable Peaks, Tracks/Routes, Natural, Roads, and Maps, so I can combine only the kinds of results relevant to my search. [L2]
2. As a map user, I open Search with Peaks, Tracks/Routes, and Natural already selected, so ordinary hiking-place searches include the most relevant local content without including road or map-sheet results by default. [L3]
3. As a map user, I can search a Natural Feature by its name or alternate name, see its type and region, and center the map on it. [L1] [L4] [L5] [L6]
4. As a map user, I can apply a Track date range without unrelated Natural, Roads, or Maps results being presented as date-qualified matches. [L7]

## Requirements

1. Replace the mutually exclusive entity-filter interaction in the map `Search popup` with independently toggled `Peaks`, `Tracks/Routes`, `Natural`, `Roads`, and `Maps` buttons. Remove the `All` button. A tap toggles only that category and immediately refreshes the first result page using the current query, region, sort, group, and Track date criteria. [L2]
2. Treat the enabled categories as one union result set. Retain the current minimum-query-length, global name-sort, grouping, pagination, region-filter, loading-more, and normal empty-result behavior for the resulting eligible entries. When all category buttons are disabled, return no results; do not retain stale entries or implicitly re-enable a category. [L2]
3. Every Search popup opening, including the app-bar trigger, Search FAB, and keyboard shortcut, must enable `Peaks`, `Tracks/Routes`, and `Natural`, and disable `Roads` and `Maps`. Closing the popup and opening it again resets to that exact selection. Do not persist category selection across popup closes or app restarts. [L3]
4. Enable the existing `Natural` button and retain its exact visible label. Search the local singular `NaturalFeature` entity, using `Natural Feature` as the canonical project term. Match a case-insensitive substring in `name` or a non-empty `altName`; do not match `tag`, OSM type or ID, country, county, region, coordinates, MGRS values, or source-of-truth values. [L1] [L5]
5. A Natural result must use the primary `name` as its title unless the trimmed, lowercased query is a substring of the trimmed, lowercased non-empty `altName`; in that case, even when `name` also matches, its title must be `name / altName`, for example `Lake Echo / The Lake`. Its subtitle must be the normalized natural type from `tag` followed by the resolved map region, joined by ` · ` when both are available, for example `Lake · Tasmania`. Normalize `tag` by trimming whitespace, replacing `_` with spaces, splitting `;`, trimming each non-empty value, title-casing each word, and joining multiple values with ` / `. Use the stored tag value, including the existing refresh behavior that stores the more specific OSM `water` value when available. Apply the existing resolved-coordinate region filter to Natural results. [L6]
6. Natural results must participate in the established name sort, pagination, and type grouping. Type grouping must use the visible group label `Natural`, and the result-list icon must distinguish Natural results using the existing forest icon convention. Each Natural result must use the stable, collision-free selector `map-search-result-natural-<osmType>-<osmId>`, for example `map-search-result-natural-way-12345`. [L1] [L6]
7. Selecting a Natural result must clear existing search-result selection and any existing selected-location marker, close the Search popup, and center the map at the Natural Feature coordinate using the normal map zoom. It must not create a Natural Feature information popup, a selected-location marker, a persistent selection, a saved object, or a new map overlay. [L4]
8. With an active Track date range, retain the existing Track date contract: include Track-date-matching Tracks only when `Tracks/Routes` is enabled and their associated Peaks only when `Peaks` is enabled. Keep every category toggle unchanged, but suppress Natural, Roads, and Maps from the date-qualified result set until the date range is cleared. When neither `Peaks` nor `Tracks/Routes` is enabled, return no date-qualified results. [L7]
9. Preserve the Search popup's existing horizontal control scrolling, keyboard operation, and selected-button visual styling. Each category control must expose its exact label, button role, and selected/unselected state to assistive technology and remain operable at the app's supported desktop text scales. [L2] [L3]
10. Natural search is a synchronous local repository read. Do not add network access, refresh/import work, loading, offline, retry, logging, configuration, secrets, or error UI specific to Natural search. An empty local Natural Feature collection or no matching records uses the existing Search popup empty-result behavior. [L1] [L5]

## Technical Decisions

1. Replace the single `MapSearchEntityFilter` state value in map search criteria, `MapState`, notifier refresh paths, and `MapSearchService` with an immutable set of enabled category values. Remove the obsolete All category rather than retaining compatibility behavior. Invalidate in-flight load-more work and reset pagination whenever the set changes. [L2] [L3]
2. Add a Natural Feature payload and `MapSearchResultType` variant to `MapSearchResult`. Update every exhaustive result-type switch for combined result composition, sorting/grouping labels, row icons, stable result keys, and map-result selection. Use the existing `(osmType, osmId)` OSM feature identity to make the Natural result ID collision-free. [L1] [L4] [L6]
3. Supply `NaturalFeatureRepository` to `MapSearchService` through the existing Riverpod production wiring and through replaceable test construction. Extend `TestMapNotifier` to accept an injected `NaturalFeatureRepository`; widget and robot tests use `NaturalFeatureRepository.test(InMemoryNaturalFeatureStorage(...))`. Keep `MapSearchService` responsible for local Natural Feature matching, result composition, resolved-region filtering, ordering, and pagination. [L1] [L5] [L6]
4. Add a focused map-notifier navigation path for Natural results that issues the same default-zoom camera request as the existing ObjectBox Admin Natural Feature map action. It must clear the ordinary Search result selection and any existing selected-location marker before navigation, and leave no Natural-specific selection state to clean up. [L4]
5. Retain the existing Track date branch as the source of truth for date-qualified eligibility. It must compose eligible Peaks only when `Peaks` is enabled and eligible Tracks only when `Tracks/Routes` is enabled, while suppressing Natural, Roads, and Maps independently of their selected controls. [L7]
6. Preserve the existing `TextEditingController`, debounce timer, focus nodes, request serial, and result-list lifecycle cleanup. This feature does not add controllers, streams, timers, persistence, API boundaries, API keys, or client/server secrets.

## Testing Strategy

Use vertical-slice TDD for category-set state, Natural result composition, and popup interaction.

1. Extend `MapSearchService` unit tests with `NaturalFeatureRepository.test` and `InMemoryNaturalFeatureStorage`. Cover name and alternate-name matching, case-insensitivity, excluded fields, result title/subtitle formatting (including the `name / altName` title whenever the normalized query is a substring of `altName`, even when `name` also matches, and Natural tag normalization), resolved-region filtering, inclusion with the enabled default categories, exclusion when Natural is disabled, all-categories-disabled behavior, ordering, pagination, and the `Natural` type group. [L1] [L2] [L5] [L6]
2. Add service and provider/notifier coverage for the category-set refresh contract: each toggle updates only its category, resets visible results to the first page, invalidates outstanding load-more work, and each popup opening restores exactly Peaks, Tracks/Routes, and Natural. Verify Roads and Maps remain disabled by default and that no category selection is persisted. [L2] [L3]
3. Extend Track date search tests to verify that enabled Natural, Roads, and Maps are suppressed during an active range without changing their enabled state; enabled `Peaks` and `Tracks/Routes` independently retain their existing date-qualified results; and disabling both returns no date-qualified results. [L7]
4. Extend Search popup widget coverage with stable selectors for all category buttons and the exact Natural selector format. Verify toggle semantics, selected-state accessibility semantics, initial/reset states, removed All control, Natural row copy, type grouping, empty local data, and all-disabled results. At desktop `TextScaler.linear(2.0)`, verify the horizontally scrollable category controls remain reachable and expose their exact labels, button roles, and selected/unselected states through semantics. Use repository fakes and in-memory storage; do not use ObjectBox, network services, API keys, or external secrets. [L1] [L2] [L3] [L5] [L6]
5. Extend the existing AppBar Search robot journey with a deterministic Natural Feature fixture and the exact Natural result selector. Verify opening Search exposes the default categories, selecting a Natural result closes the popup, clears any pre-existing selected-location marker, and centers the map at the feature coordinate without creating a detail popup or persistent selection. [L3] [L4]
6. Run targeted service, provider, widget, and robot tests; `flutter analyze`; and the full `flutter test` suite.

## Out of Scope

1. Natural Feature markers, details popups, overlays, persistent selection state, map editing, peak-list integration, peak correlation, routes, tracks, dashboards, or any other new Natural Feature behavior beyond Search popup results and map centering. [L4]
2. Searching Natural Feature administrative, coordinate, identity, tag, or provenance fields; fuzzy matching; full-text indexing; or changes to ObjectBox Admin Natural Feature search. [L5]
3. Persisting Search popup category choices, query text, date filters, or results across popup closes or app launches. [L3]
4. New Natural-specific remote requests, import/refresh calls, background jobs, loading indicators, retry flows, diagnostics, configuration, or secrets. [L1]

## Notes

1. This Spec intentionally supersedes the Search popup portion of the `0058-natural-features-and-contacts` out-of-scope boundary. Its Natural Feature administration, persistence, and refresh contracts remain unchanged.
