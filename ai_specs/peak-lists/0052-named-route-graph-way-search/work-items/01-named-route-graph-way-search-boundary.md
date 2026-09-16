---
type: Work Item
title: Add Named Route-Graph Way Search Boundary
parent: ../spec.md
---

## What to build

Add the smallest replaceable public named route-graph way-search API at the existing route-graph query boundary. It must search every active routing coverage for non-empty indexed OSM `name` values with case-insensitive substring semantics, and return already-resolved candidates containing the OSM way ID, indexed name, highway, surface, resolved anchor, routing coverage key, generation, and chunk key.

Resolve each candidate anchor exclusively from the matching active generation's `RouteGraphWayIndex.chunkKey`, `osmWayId`, and authoritative `RouteGraphChunk.payloadJson`. Compute the point halfway along the total geodesic way geometry length by interpolating the segment containing the halfway distance. Consider duplicate occurrences in ascending `(routingCoverageKey, chunkKey)` order. Omit unusable occurrences, continue searching all other occurrences, and omit an OSM way ID only when none resolve. The production implementation must accept an injectable diagnostic callback that defaults to `dart:developer.log` and records each skipped resolution with its OSM way ID and chunk key.

## Required context

- `lib/services/route_graph_query_service.dart` is the existing public query boundary; `activeCoverageKeys` and coverage-scoped way queries establish active coverage and generation scope.
- `lib/models/route_graph_way_index.dart` provides indexed name and metadata. `lib/models/route_graph_chunk.dart` owns the authoritative `payloadJson` geometry; do not add geometry to the index.
- `lib/services/route_graph_repository.dart` and `InMemoryRouteGraphStorage` are the established deterministic route-graph fixture seam.
- Do not use drive-ETA way metadata filtering: Roads search covers every named route-graph way, including paths, tracks, and footways.

## Acceptance criteria

- [x] A replaceable named route-graph way-search API searches every active routing coverage and returns already-resolved candidates with OSM way ID, indexed name, highway, surface, anchor, routing coverage key, generation, and chunk key.
- [x] Matching considers only non-empty indexed OSM `name` values with case-insensitive substring semantics; it does not search `ref`, `alt_name`, raw tag JSON, fuzzy terms, or unindexed name variants.
- [x] Candidate geometry is resolved only from the matched authoritative chunk payload, matched routing coverage, active generation, `chunkKey`, and OSM way ID; no `RouteGraphWayIndex` geometry field is added.
- [x] The midpoint is halfway along the total geodesic geometry length and is interpolated within the segment containing that distance.
- [x] Duplicate occurrences are evaluated in ascending `(routingCoverageKey, chunkKey)` order. An unusable occurrence is skipped without failing the search; an OSM way ID is omitted only when no matching occurrence has a usable midpoint.
- [x] Every skipped midpoint-resolution failure invokes the injectable diagnostic callback, defaulting to `dart:developer.log`, with the OSM way ID and chunk key. The callback does not interrupt search.
- [x] With no active routing coverage, the API returns no candidates and does not begin or retry route-graph import work, use a network service, or require API keys.
- [x] Follow vertical-slice TDD with deterministic unit coverage for indexed-name matching, named paths/tracks/footways, geodesic interpolation, canonical usable occurrence selection, absent active coverage, and failed resolution diagnostics using small in-memory route-graph fixtures.

## Covers

- Requirements: 2, 4, 6, 10-12
- Technical Decisions: 1, 3, 5-6
- Testing Strategy: 1-3
- Interview Ledger: L1, L5, L6, L8-L11

## Blocked by

None - ready to start
