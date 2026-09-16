---
type: Work Item
title: Compose Roads Search Results
parent: ../spec.md
---

## What to build

Extend map-search result modelling and `MapSearchService` to consume the optional named route-graph way-search boundary. Compose Roads results for both `MapSearchEntityFilter.roads` and `MapSearchEntityFilter.all`, while retaining every other existing entity-filter behavior. An unavailable dependency returns no candidates without import work or an error surface.

Use one result per matching OSM way ID, retaining distinct ways that share a name. Deduplicate resolved candidates by OSM way ID before existing name sorting, grouping, pagination, and minimum-query-length behavior. The canonical result must use the first usable occurrence in ascending `(routingCoverageKey, chunkKey)` order, including its metadata and provenance. When a Track date range is active, Roads returns no results and All omits Roads results while retaining existing date-scoped results.

Add a road-specific result type and payload that can carry the matching route-graph way and resolved anchor. Its title is the way name. Its subtitle is title-cased `highway` and optional title-cased `surface`, joined by ` · `; replace `_` with spaces, split semicolon values and join them with ` / `, and capitalize every word. A selected Region filter uses the resolved midpoint and excludes points outside that region or outside all manifest regions. Grouped results use the distinct `Roads` group.

## Required context

- `lib/models/map_search_result.dart` contains `MapSearchResultType`, `MapSearchEntityFilter.roads`, and result payloads; exhaustive UI switches will depend on the added road type.
- `lib/services/map_search_service.dart` owns combined composition, name ordering, grouping, pagination, minimum query length, and Track date-range behavior. Keep duplicate collapse here, before pagination.
- `lib/services/map_search_region_filter.dart` contains existing non-peak region-filter conventions. Roads uses its resolved midpoint.
- The named route-graph way-search dependency must remain optional and replaceable for map-search tests; tests use a deterministic fake and no real import, network access, or API key.

## Acceptance criteria

- [x] `MapSearchResultType` has a road-specific result type and payload capable of carrying the matching route-graph way data and resolved anchor; all map-search composition remains type-safe.
- [x] Roads results are included for `MapSearchEntityFilter.roads` and `MapSearchEntityFilter.all`; named paths, tracks, footways, and vehicle roads are eligible without a drive-ETA highway restriction.
- [x] With an active Track date range, Roads produces no results and All omits Roads results while retaining its existing date-scoped results.
- [x] Roads matching has the existing name sort, grouping, pagination, and minimum-query-length behavior. Grouped results use a distinct `Roads` group.
- [x] Results have one entry per matching OSM way ID. Distinct OSM ways with identical names remain separate, and duplicate collapse occurs before pagination using the first usable `(routingCoverageKey, chunkKey)` candidate as canonical metadata and provenance.
- [x] A Roads title is the route-graph way name. Its subtitle uses the exact highway/surface formatting contract: title case, `_` replaced with spaces, semicolon values joined by ` / `, and highway and optional surface joined by ` · `.
- [x] A selected Region filter includes a Roads result only when its resolved midpoint is in the selected region; it excludes midpoints outside the selected region or outside all manifest regions.
- [x] An unavailable named way-search dependency and a normal empty candidate set produce no Roads results through the existing `No results found` state contract, with no import work and no Roads-specific loading or error UI.
- [x] Follow vertical-slice TDD with deterministic unit coverage for matching result composition, subtitle formatting, duplicate collapse and post-deduplication pagination, midpoint Region filtering, absent dependency/coverage, and Track date-range behavior using an injected fake query seam.

## Covers

- User Stories: 1, 2, 4
- Requirements: 2-8, 10
- Technical Decisions: 2, 4-5
- Testing Strategy: 1-4
- Interview Ledger: L1, L2, L4-L10

## Blocked by

01-named-route-graph-way-search-boundary.md
