## Overview

ObjectBox way-tag index for route graph queries.  
Way-first lookup, chunk resolution secondary.

**Spec**: `ai_specs/overpass/route-graph-tag-index-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/models`, `lib/services`, `test/services`, `test/models`
- **State management**: no new Riverpod/UI state; service/repository layer only
- **Reference implementations**: `./lib/services/route_graph_import_service.dart`, `./lib/services/route_graph_repository.dart`, `./lib/services/route_graph_query_service.dart`, `./test/services/route_graph_repository_test.dart`, `./test/services/route_graph_query_service_test.dart`
- **Assumptions/Gaps**: ObjectBox artifacts regenerated via build_runner; map highlighting resolves from `chunkKey + osmWayId` via chunk payload reads

## Plan

### Phase 1: Schema + atomic generation

- **Goal**: add way index entity; make generation contract carry way rows
- [x] `./lib/models/route_graph_way_index.dart` - entity, indexes, derived fields (`lengthMeters`, `tagCount`)
- [x] `./lib/services/route_graph_repository.dart` - extend `RouteGraphPreparedGeneration`, `RouteGraphStorage`, `ObjectBoxRouteGraphStorage`, `InMemoryRouteGraphStorage` for way rows
- [x] `./lib/services/route_graph_import_service.dart` - prepared generation map includes way rows, not chunks only
- [x] `./lib/objectbox.g.dart` / `./lib/objectbox-model.json` - regenerate artifacts via ObjectBox codegen
- [x] `./test/models/route_graph_way_index_test.dart` - TDD: persistence shape, indexed fields, `tagCount` empty-string exclusion
- [x] `./test/services/route_graph_repository_test.dart` - TDD: generation write/prune atomicity across chunks + way rows
- [ ] Verify: `dart run build_runner build --delete-conflicting-outputs` && `flutter analyze` && `flutter test` (blocked: full suite has pre-existing unrelated failures outside this slice)

### Phase 2: Import projection

- **Goal**: project hot tags, counts, and overlap duplicates during import
- [x] `./lib/services/route_graph_import_service.dart` - emit way index rows from same decoded iteration as chunk build
- [x] `./test/services/route_graph_import_service_test.dart` - TDD: `highway/surface/footway/foot/route/access/name`, `lengthMeters`, `tagCount`, duplicate membership, missing/empty tag handling
- [x] `./test/services/route_graph_repository_test.dart` - TDD: stale generation prune removes stale way rows with chunks
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: full suite has pre-existing unrelated failures outside this slice)

### Phase 3: Way query API

- **Goal**: typed query DTO; ObjectBox-first filtering; chunk-key helper second
- [x] `./lib/services/route_graph_query_service.dart` - `RouteGraphWayQuery`, `queryWays(...)`, `chunkKeysForWays(...)`, `nameContains`, include/exclude, numeric range filters
- [x] `./test/services/route_graph_query_service_test.dart` - TDD: `highway=footway`, include/exclude, `nameContains`, `lengthMeters` bounds, `tagCount`, `maxLengthMeters`, helper dedupe to chunk keys
- [x] `./lib/services/route_graph_repository.dart` - way-row access path for query service if needed
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: full suite has pre-existing unrelated failures outside this slice)

## Risks / Out of scope

- **Risks**: ObjectBox model drift; overlapping chunks duplicating rows; query semantics mismatched to Overpass if `tagCount`/numeric bounds are off
- **Out of scope**: UI changes, regex/full-text search, direct geometry storage on way rows, arbitrary tag search beyond the explicit indexed set
