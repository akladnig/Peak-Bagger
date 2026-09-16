---
type: Spec
title: Named Route-Graph Way Search
---

## Problem

The Search popup exposes a disabled `Roads` filter, while route-graph data already persists indexed named OpenStreetMap ways in `RouteGraphWayIndex`. Users cannot currently discover or navigate to a named route-graph way through map search. The existing `natural` filter is unrelated and remains deferred.

## Proposed Outcome

Enable named route-graph way discovery in the Search popup through the `Roads` filter and the `All` filter. Results use existing indexed name and metadata fields, resolve their map anchor from the authoritative route-graph chunk payload, and center the map when selected.

## User Stories

1. As a map user, I can search for a named route-graph way from the Roads filter regardless of whether it is a motor road, path, track, or footway.
2. As a map user, I can find named route-graph ways while searching All entities.
3. As a map user, I can select a road result and navigate the map to that way without a new persistent overlay or details surface.
4. As a user with a selected Region filter, I see only Roads results whose resolved midpoint is in that region.

## Requirements

1. Enable the existing `Roads` control in `MapSearchPopup`, preserving its label and vehicle icon. Its selected state and interaction must match the existing entity-filter controls. [L1]
2. Treat `Roads` as the Search popup label for all named **route-graph ways**. Eligible results include named paths, tracks, and footways as well as vehicle roads; no drive-ETA highway restriction applies. [L1]
3. Add Roads results to both `MapSearchEntityFilter.roads` and `MapSearchEntityFilter.all`. When a Track date range is active, preserve the existing date-range scope: Roads returns no results and All omits Roads results. The other existing entity-filter behavior remains unchanged. [L2]
4. Match only a non-empty indexed OSM `name` through case-insensitive substring semantics. Do not search `ref`, `alt_name`, raw tag JSON, fuzzy terms, or unindexed name variants. [L8]
5. Show the route-graph way name as the result title. Show its title-cased `highway` value and optional title-cased `surface` value as the subtitle, joined with ` · `. A missing surface produces only the highway label. For each OSM tag value, replace `_` with spaces, split semicolon-delimited values and join them with ` / `, then capitalize each word; for example, `motorway_link` becomes `Motorway Link` and `asphalt;paving_stones` becomes `Asphalt / Paving Stones`. [L4]
6. Present one result for each matching OSM way ID even if it occurs in multiple chunks or active routing coverages. Resolve duplicate occurrences in ascending `(routingCoverageKey, chunkKey)` order and use the first occurrence with a usable midpoint as the canonical result, including its metadata and provenance. Do not collapse distinct OSM ways merely because their names match. [L5]
7. Apply the existing name sort, grouping, pagination, and minimum-query-length behavior to Roads results. When grouped by type, Roads results use a distinct `Roads` group. [L2]
8. Apply the existing Region filter to a Roads result using its resolved midpoint. A selected region excludes results with a midpoint outside that region or outside all manifest regions. [L7]
9. Selecting any Search popup result must first clear existing selected peaks, selected track, selected route, selected map, and their associated popups. Selecting a Roads result must then close the Search popup, preserve the current zoom, center the map on the result midpoint, and set that point as the selected location. It must not create a persistent road highlight, a road details popup, or a saved object. [L3]
10. Keep Roads enabled when no active route-graph coverage exists. In that state, and when no matching results remain, use the existing `No results found` empty state. Search must not start or retry a route-graph import and must not add a Roads-specific loading or error UI. [L6]
11. Resolve a way midpoint as the point halfway along its total geodesic geometry length, interpolated within the segment that contains the halfway distance. Omit an occurrence when its corresponding authoritative chunk payload cannot provide that usable midpoint; omit an OSM way ID only when no matching occurrence resolves. Continue evaluating other results; do not fail the complete search. [L9]
12. Log each skipped midpoint-resolution failure with `dart:developer`, including the OSM way ID and chunk key, without surfacing that diagnostic in the Search popup. [L11]

## Technical Decisions

1. Keep `RouteGraphChunk.payloadJson` as the source of truth for way geometry. Resolve a result anchor from the matched routing coverage, generation, `RouteGraphWayIndex.chunkKey`, and `osmWayId`; do not add a geometry field to `RouteGraphWayIndex` for this feature. [L3] [L9]
2. Add a road-specific `MapSearchResultType` and result payload capable of carrying the matching route-graph way data and resolved anchor. Update all exhaustive result-type switches for icons, groups, and map selection. [L2] [L3] [L4]
3. Extend the existing route-graph query boundary with the smallest replaceable public named route-graph way-search API needed to search every active routing coverage and return already-resolved matching candidates. Each candidate carries the OSM way ID, indexed name, highway, surface, resolved anchor, routing coverage key, generation, and chunk key. `MapSearchService` must consume that boundary rather than decode route-graph payloads itself.
4. Keep `MapSearchService` as the owner of combined result composition, duplicate collapse, region filtering, ordering, pagination, and presentation metadata. Deduplicate before pagination so overlapping chunk copies cannot consume result slots. [L4] [L5] [L7]
5. Make the named route-graph way-search dependency optional and replaceable in map-search tests. `MapNotifier` wires its production implementation through Riverpod and accepts an injected fake for tests; an unavailable dependency returns no candidates without import work or an error surface. Its production implementation accepts an injectable diagnostic callback that defaults to `dart:developer.log`; tests can capture the skipped way ID and chunk key through that callback. Avoid a real import, network call, or external service dependency for a search request. [L10]
6. Do not introduce new persistence, ObjectBox schema fields, background jobs, timers, streams, controller lifecycle, API keys, or configuration for this feature.

## Testing Strategy

Use vertical-slice TDD for the new query and map-search behavior.

1. Add deterministic unit coverage for case-insensitive indexed-name matching, inclusion of named paths/tracks/footways, result subtitle formatting including underscore and semicolon handling, geodesic midpoint interpolation, OSM way-ID duplicate collapse with canonical occurrence selection, pagination after deduplication, and Region filtering by resolved midpoint. [L1] [L4] [L5] [L7] [L8]
2. Add unit coverage for absent active coverage and failed midpoint resolution: Roads remains enabled at the service contract, produces the normal empty result set, does not initiate import work, skips only invalid occurrences, and records the diagnostic with way ID and chunk key through the injected callback. [L6] [L9] [L11]
3. Use a deterministic fake route-graph query seam, capture its diagnostic callback, and use small in-memory route-graph fixtures. Automated coverage must not use network access, a real route-graph import, or API keys. [L10]
4. Add unit coverage for an active Track date range: Roads produces no results and All omits Roads while retaining its existing date-scoped results. [L2]
5. Add widget or robot journey coverage using `map-search-entity-roads` and the new stable result selector `map-search-result-road-<osmWayId>` for selecting Roads, rendering a result, and selecting that result to clear any prior search-result selection and associated popup, close the popup, and center the map at the current zoom. Add regression coverage that each existing Search popup result type also clears prior search-result selection and associated popup state. [L3] [L10]

## Out of Scope

- Search support for the disabled `Natural` filter, including indexing OSM nodes, relations, or `natural` tags.
- `ref`, `alt_name`, fuzzy, full-text, or arbitrary raw-tag search.
- Persistent road highlighting, road-specific information popups, saved-road entities, or changes to route planning.
- Route-graph import changes, new ObjectBox fields, or backfilling existing generations.
