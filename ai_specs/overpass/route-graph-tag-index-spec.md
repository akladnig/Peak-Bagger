<goal>
Add an efficient ObjectBox-side tag index for route graph ways so the app can answer tag filters such as `highway=footway`, `surface=...`, `route=...`, and `name=...` without decoding every `payloadJson` blob.
This matters because the current chunk model is spatial, not query-friendly for tag filters, and route planning or future map overlays need fast indexed reads while keeping the chunk payload as the source of truth.
</goal>

<background>
The app already stores route-graph data in ObjectBox as `RouteGraphManifest` plus spatial `RouteGraphChunk` rows.
Current import code builds chunk payloads from bundled Overpass-shaped JSON and writes them through `RouteGraphImportService` and `RouteGraphRepository`.

Files to examine:
- `./lib/models/route_graph_chunk.dart`
- `./lib/models/route_graph_manifest.dart`
- `./lib/services/route_graph_import_service.dart`
- `./lib/services/route_graph_repository.dart`
- `./lib/services/route_graph_query_service.dart`
- `./lib/objectbox.g.dart`
- `./test/services/route_graph_import_service_test.dart`
- `./test/services/route_graph_repository_test.dart`
- `./test/services/route_graph_query_service_test.dart`
</background>

<discovery>
Inspect the current import pipeline and ObjectBox transaction boundaries before coding.
Confirm how to keep chunk payloads authoritative while adding a separate query index that can be pruned and activated atomically with each generation.
Confirm the smallest query API needed for AND-style filters across common tags without introducing a full-text or arbitrary tag search engine.
Confirm how the same way-index rows can later back map highlighting of matching search results without re-scanning chunk JSON.
</discovery>

<requirements>
**Functional:**
1. Add a dedicated ObjectBox entity for per-way tag indexing.
   Store one row per OSM way occurrence per chunk per generation, not one row per chunk.
   Each row must carry a stable record key plus `generation`, `chunkKey`, and `osmWayId`.
2. Persist the hot query fields as real ObjectBox columns.
   The initial indexed set must include `highway`, `surface`, `footway`, `foot`, `route`, `access`, `name`, and a normalized name field for case-insensitive exact/prefix lookup.
   Add derived query fields for `lengthMeters` and `tagCount` so Overpass-style filters such as `length() > 500` and `count_tags() > 1` can be replicated without scanning raw JSON.
   Define `tagCount` as the count of scalar key/value pairs in the original OSM `tags` map, excluding non-scalar values and empty-string values.
3. Keep the raw tag map available for rare or unsupported lookups.
   Store a fallback `tagsJson` blob on the index row so the full payload does not need to be decoded for every query, but do not make `tagsJson` the primary query path.
4. Build the tag index during `RouteGraphImportService` generation preparation from the same decoded Overpass JSON that creates chunk payloads.
   The chunk payload and the tag index must stay in sync for the same generation.
5. Add or extend the query service so tag filters are executed through ObjectBox first.
    The query path must support AND semantics across multiple tag filters and return matching way-index rows first.
    A second-step helper may resolve the matching rows to deduped `chunkKey` values for route payload loading or map highlighting, but chunk resolution must be derived from the way-index results.
6. Make name queries explicit.
   Support normalized contains matching via the indexed normalized field; do not promise a full regex engine or full-text search.
   The public query API must list the supported operators so unsupported semantics can fail fast.
   Use a single typed query DTO named `RouteGraphWayQuery` with `include`, `exclude`, `nameContains`, `minLengthMeters`, `maxLengthMeters`, and `minTagCount` fields.
   Supported v1 operators are exact include/exclude filters on scalar tags, AND composition across include filters, normalized contains matching for `name`, and numeric comparisons for `lengthMeters`, `maxLengthMeters`, and `tagCount`.
7. Preserve the chunk payload as the route-graph source of truth.
   The new index must only accelerate lookups and must not replace the existing chunk payload format.
8. Prune stale tag-index rows together with stale chunk rows when a new generation replaces the active one.
   A generation must never become active with missing tag rows or missing chunks.

**Error Handling:**
9. If a way is missing one of the indexed tags, store that field as null or empty and skip it in the filter rather than inventing a value.
10. If a tag value is malformed or non-scalar, ignore only that field for the index row and keep the rest of the way importable if the payload is otherwise valid.
11. If import or write fails partway through, do not activate a partial generation or a partial tag index.

**Edge Cases:**
12. A way may appear in multiple overlapping chunks; the index row must remain unique per `generation|chunkKey|osmWayId`.
13. Case handling for `name` must be deterministic: normalize once at import time and query the normalized field, not the raw display string.
14. If a query requests unsupported tag semantics, fail fast with a clear error instead of silently falling back to a full scan.
15. Keep the schema narrow for the first iteration; add new indexed columns only when there is a concrete query requirement.
16. Supported operators in v1 are exact include/exclude filters on scalar tags, AND composition across include filters, normalized exact/prefix matching for `name`, and numeric comparisons for `lengthMeters` and `tagCount`.

**Validation:**
17. Add behavior-first tests for import indexing, multi-tag query filtering, name normalization, and stale-generation pruning.
18. Keep tests deterministic with in-memory storage, small raw JSON fixtures, and public service/repository APIs.
19. Require baseline automated coverage for storage/model behavior, import-time indexing, query selection, and failure atomicity.
</requirements>

<boundaries>
Edge cases:
- Missing tag fields: exclude the row from that filter rather than treating missing as a wildcard.
- Duplicate ways across overlapping chunks: preserve duplicate chunk membership in the index, then dedupe chunk keys at query time.
- Mixed-case names: normalize once at import and query the normalized field.
- Very long names: keep the original value in the index row if storage allows it; do not truncate unless a concrete ObjectBox constraint appears.

Error scenarios:
- Invalid JSON payload: fail the generation and keep the previous active generation unchanged.
- Partial ObjectBox write failure: abort the whole generation write so chunks and tag rows cannot diverge.
- Unsupported query operator: return a clear route-graph query error.

Limits:
- No full-text search engine.
- No fuzzy name search.
- No arbitrary ad hoc tag scan across raw JSON blobs as the primary query strategy.
- No UI changes are in scope.
</boundaries>

<implementation>
Create or update these files:
- `./lib/models/route_graph_way_index.dart`
- `./lib/services/route_graph_import_service.dart`
- `./lib/services/route_graph_repository.dart`
- `./lib/services/route_graph_query_service.dart`
- `./test/services/route_graph_import_service_test.dart`
- `./test/services/route_graph_repository_test.dart`
- `./test/services/route_graph_query_service_test.dart`

Implementation approach:
- Keep `RouteGraphChunk` as the spatial payload container.
- Add a new `RouteGraphWayIndex` entity with indexed scalar fields for the hot tags plus `tagsJson` as a fallback.
- Add derived scalar fields for `lengthMeters` and `tagCount` on the way index entity, and require `@Index()` on both fields.
- Write the index rows during import from the same decoded way maps used to build chunk payloads.
  The preparation step must return a single prepared generation object that contains both prepared chunks and prepared way-index rows.
  Build both row sets from the same decoded way iteration so chunk payloads and tag rows cannot drift.
- Use a single ObjectBox write transaction so chunks and tag rows activate together for a generation.
- Extend `RouteGraphPreparedGeneration`, `RouteGraphStorage`, `ObjectBoxRouteGraphStorage`, and `InMemoryRouteGraphStorage` so the generation write/prune path accepts and persists way-index rows alongside chunks.
- Build query APIs around typed tag filters instead of raw dynamic maps, so include/exclude semantics, name matching, and derived numeric range filters are explicit.
- The primary query should return matching way-index rows via `queryWays(RouteGraphWayQuery query)`, and a separate helper `chunkKeysForWays(...)` may resolve those rows to unique `chunkKey` values for route payload assembly.
- Map highlighting may resolve geometry from `chunkKey + osmWayId` by opening the matching chunk payload; do not add extra geometry fields unless a later requirement needs direct overlay rendering without chunk reads.
- Regenerate the ObjectBox artifacts (`./lib/objectbox-model.json` and `./lib/objectbox.g.dart`) from the annotated model changes using the ObjectBox generator; do not hand-edit generated code.

What to avoid:
- Avoid storing tag filters on `RouteGraphChunk`; a chunk contains many ways, so chunk-level tags are too coarse for accurate queries.
- Avoid decoding every chunk payload for common tag filters.
- Avoid a generic key-value tag table as the primary solution unless a later requirement needs arbitrary tag search.
- Avoid a full regex engine for name matching.
</implementation>

<stages>
Phase 1: Add the index entity and generation storage path.
Verify with tests that ObjectBox can persist the new row shape and prune stale index rows with stale chunks.

Phase 2: Populate the index during import.
Verify with tests that the importer writes hot tag fields, normalizes names, and leaves missing fields null.

Phase 3: Add tag query selection.
Verify with tests that multi-tag include/exclude filters, name contains filters, and numeric derived-field filters return the expected way-index rows, then resolve to the expected chunk keys through the helper.

Phase 4: Verify failure atomicity.
Verify with tests that invalid payloads or write failures do not activate a partial generation.
</stages>

<validation>
Use vertical-slice TDD.
- Write one failing test at a time.
- Keep each green step minimal.
- Refactor only after the current behavior is green.

Baseline automated coverage outcomes:
- Logic/business rules: tests for index row shape, name normalization, and query filter semantics.
- Import behavior: tests that generation preparation creates the expected tag rows alongside chunks.
- Failure handling: tests that import/write failures leave the previous active generation intact.

Required test slices:
1. Model slice: add a test for the new index entity fields and record-key shape.
2. Import slice: add a test that a small Overpass fixture produces index rows for `highway`, `surface`, `footway`, `foot`, `route`, and `name`.
   Add a duplicate-membership test for a way that appears in overlapping chunks to prove the import emits one index row per chunk occurrence.
3. Query slice: add tests that `highway=footway` and multi-tag include/exclude filters return the expected way-index rows, plus a follow-up helper test that those rows resolve to the expected chunk keys.
   Add tests for `lengthMeters > 500`, `maxLengthMeters < 2000`, and `tagCount > 1` on the same query path.
4. Name slice: add tests for normalized contains matching on `name`.
5. Prune slice: add a test that replacing a generation removes stale chunks and stale tag rows together.
6. Atomicity slice: add a test that a malformed payload or repository failure does not publish a partial generation.
7. Schema slice: add a test or verification step that the checked-in ObjectBox schema is regenerated for the new entity.

Required seams:
- A raw JSON or asset-loader seam in the importer so small fixtures can drive the indexer deterministically.
- A repository/storage fake or in-memory store for generation-switch tests.
- A typed tag-filter object for query tests so the public API is exercised instead of private helpers.

Expected behavior by layer:
- Storage/model tests should prove the index can be written, pruned, and queried without scanning chunk JSON.
- Import tests should prove the hot tags are projected during generation creation.
- Query tests should prove common filters are resolved through ObjectBox on the way index first, then optionally mapped back to chunks by a separate helper.
</validation>

<done_when>
The route graph stores a dedicated ObjectBox tag index alongside chunks, and common tag filters are answered without scanning every payload blob.
Import, generation switching, and query behavior are covered by deterministic tests, and partial failures never activate broken tag data.
</done_when>
