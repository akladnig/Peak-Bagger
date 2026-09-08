---
type: Work Item
title: Persist Coverage-Scoped Route Graphs and Selection Data
parent: ../spec.md
---

## What to build

Replace singleton route-graph persistence with one `RouteGraphManifest` per routing coverage, a separate route-graph import metadata record, globally unique generation reservations, source-region provenance, and persisted unavailable footprints. Make repository, storage, query, and cache contracts select coverage generations without placing a coverage or region key on every child row.

Implement the one-time legacy singleton cleanup and the active/unavailable coverage-footprint selection primitives required by later batch, planner, road-target, and trail-overlay slices.

## Required context

- Update `lib/models/route_graph_manifest.dart`, `lib/services/route_graph_repository.dart`, `lib/services/route_graph_query_service.dart`, storage implementations, and cache keys. Current singleton and in-memory seams are in `RouteGraphStorage`, `ObjectBoxRouteGraphStorage`, and `InMemoryRouteGraphStorage`.
- Changing ObjectBox entities requires `dart run build_runner build --delete-conflicting-outputs` and checked-in `lib/objectbox-model.json` and `lib/objectbox.g.dart`; do not hand-edit either generated file.
- Use `test/services/route_graph_repository_test.dart` and `test/services/migration_marker_store_test.dart` for existing storage fixture conventions.

## Acceptance criteria

- [x] A `RouteGraphManifest` has indexed unique `routingCoverageKey`, active generation, aggregate source hash, schema version, import timestamp, counts, readiness/error state, and ordered source-region keys. A separate singleton metadata record stores the multi-coverage-migration-complete marker and durable `lastReservedGeneration`.
- [x] A short write transaction reserves every generation globally by incrementing and persisting `lastReservedGeneration` before preparation. Generation IDs are never decremented or reused, including after a failed import or restart; child rows remain scoped by their globally unique generation and existing record keys only.
- [x] Before any multi-coverage generation is reserved, one transaction removes only the legacy singleton manifest with primary key `RouteGraphManifest.manifestId` and missing or empty `routingCoverageKey`, including all active and stale rows of all three child-row types, then writes the migration marker. A failed transaction rolls back completely; a completed marker makes cleanup a no-op; no coverage import begins in this transaction.
- [x] Activation and replacement are atomic per coverage, stale pruning is scoped to that coverage, and a failed replacement retains its prior active generation and serving readiness. Repository queries and caches include the selected coverage generation so one coverage cannot serve another coverage's stale rows or indexes.
- [x] Preparation persists an ordered unavailable footprint from inclusive bounds of finite node `lat`/`lon` coordinate pairs before accepted-way filtering, one bound per eligible source asset. When none exist, seed one inclusive envelope per member source-region coverage polygon in priority, path, and declared-polygon order; retain the latest successfully derived footprint after a failed refresh.
- [x] Provide exact inclusive, unbuffered active-chunk and unavailable-footprint matching primitives: multiple bounds or chunks in one coverage count once; unavailable footprints are never used for active graph, road target, or route payload selection; an exact same-key active match takes precedence over unavailable matches.
- [x] Test first with ObjectBox and in-memory storage coverage for legacy cleanup and marker retry/no-op behavior, multiple manifests, globally unique pre-preparation reservations including unused IDs after failure/restart, generation-scoped child queries, provenance, cache invalidation, atomic replacement, prior-generation retention, footprint derivation/fallback, and exact-one inclusive matching.
- [x] Include a fresh ObjectBox migration smoke test seeded with legacy singleton active and stale child rows, proving all are removed before new coverage data is written.

## Covers

- User Stories: 1, 3, 5
- Requirements: 1, 4, 7
- Contract Clarifications: 7, 8
- Technical Decisions: 1-3
- Testing Strategy: 1, 2, 6
- Interview Ledger: L1, L5, L7, L10

## Blocked by

01-routing-coverage-manifest-and-import-inputs.md
