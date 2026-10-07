---
type: Work Item
title: Migrate Coverage-Qualified Route Graphs
parent: ../spec.md
---

## What to build

Migrate route-graph source resolution to `MappingCatalog` and make all persisted route-graph state coverage-qualified. Rebuild legacy/unusable generations independently per routing coverage, retain a usable active generation during another coverage's failure, and surface Mapping failures only for the affected route segment or coverage.

## Required context

- Extend the existing route-graph import/coordinator/readiness patterns and the prior multi-coverage Work Items under `0048-multi-coverage-route-graph-import/`; the new coverage key contract supersedes child-row assumptions there.
- Update every route-graph ObjectBox model and regenerate `lib/objectbox.g.dart` and `lib/objectbox-model.json` after reviewing the generated changes.

## Acceptance criteria

- [x] Retain highway sources only for Tasmania and Northeast Alps in the catalog. Northeast Alps contains FVG, Veneto, and Slovenia and requires `Highways/slovenia-highways.json`; no absent NSW, Italy aggregate/North East/North West, or Croatia highway declaration remains.
- [x] Before opening a coverage highway source, determine whether it has a usable active generation. A usable generation is `ready`, has a positive active ID, and every chunk, way-index, and display row has the same coverage/generation and matches recorded chunk, node, edge, way-index, and trail-display counts. A zero-way import is unavailable.
- [x] Persist `routingCoverageKey` on every route-graph row; make every record key injective across coverage, generation, and row identity. Constrain active reads, counts, stale pruning, and orphan cleanup by both coverage and generation; reject mismatched rows before committing.
- [x] Immediately exclude legacy rows without `routingCoverageKey` from every read, delete them across all route-graph row tables in one transaction, then independently rebuild only declared coverages lacking usable qualified generations.
- [x] A usable coverage reads no highway source and stays available if its source later becomes unreadable. Failed/incomplete/orphaned coverage data may read and import; a failed manual refresh preserves the coverage's prior usable generation.
- [x] Resolve a route segment only when both endpoints resolve to exactly one identical coverage. Zero, multiple, or different coverages are ordinary route-unavailable results; only an unavailable resolved coverage enters Mapping failure flow. Use `route-planning-mapping-unavailable` and `route-planning-mapping-unavailable-retry` after dismissal.
- [x] Validate complete retained source input before ObjectBox writes: malformed selected candidates fail without writes; documented non-candidates are diagnostic skips; canonically identical repeated OSM elements merge. Apply Spec requirement 32's approved complete-element FVG-over-Slovenia precedence in Northeast Alps; other conflicts and conflicting repeats within a source region fail.
- [x] Add unit/repository/provider/widget/robot/concurrency coverage for every generation, row key, source, coverage resolution, legacy migration, retention, unavailable/retry, and cross-coverage isolation contract. Run `dart run build_runner build --delete-conflicting-outputs` and review generated ObjectBox changes.

## Verification — 2026-10-05

**Initial verification, superseded by remediation below.** Reviewed the implementation
at `85f93c1`, including the Work Item 08 commit `98b4b91`. The retained highway
contract is verified by the catalog fixture/parser tests. Legacy ObjectBox row
filtering and transactional deletion are implemented and tested, but the complete
rebuild criterion remains unchecked because usable-generation validation is
incomplete.

### Checks performed

- Shared focused prerequisite suite: **95 passed** across 14 test files,
  including route-graph resolver/import/repository/readiness/refresh, Settings,
  robot journeys, Mapping operations, and catalog tests.
- `flutter test --no-pub --reporter expanded`: **2,127 passed, 5 skipped**.
- `flutter analyze`: exit 1, **9 existing findings** (2 async-return warnings,
  7 style infos, including route-graph code).
- `dart run build_runner build --delete-conflicting-outputs`: succeeded; the
  installed runner ignores this removed flag. Reviewed the generated outputs:
  no tracked ObjectBox changes.
- Supplemental temporary Flutter-test probes outside the repository reproduced
  the six failures below without mounted data or live services. They exercise
  catalog-mode resolution, real import/retry behavior, and repository operations;
  they are verification evidence, not committed regression coverage.

### Reproduced acceptance failures

| Contract | Reproduction and observed result | Relevant implementation |
| --- | --- | --- |
| Reject empty ready generations | Supply a coverage manifest with `ready`, active generation 1, zero counts, and no rows. `hasUsableActiveGenerationFor` returns true, so catalog bootstrap can skip an unusable coverage. | `lib/services/route_graph_repository.dart::hasUsableActiveGenerationFor` |
| Validate all recorded counts | Supply a qualified chunk containing two nodes and one way, one matching way-index row, and a manifest recording 999 nodes and 999 edges. Usability returns true; only chunk, way-index, and display-row counts are compared. | `lib/services/route_graph_repository.dart::hasUsableActiveGenerationFor` |
| Route malformed sources through the Mapping failure flow | Run catalog-mode bootstrap with a declared highway reader returning `{}`. The coverage outcome is failed, but the Mapping coordinator has no failure or retry entry for its bootstrap key. `FormatException` and import/zero-way errors are not converted into path-bearing Mapping exceptions. | `lib/services/route_graph_coverage_resolver.dart::resolveCoverage`; `lib/services/route_graph_import_coordinator.dart::_runCatalogBatch`; `lib/services/route_graph_import_service.dart::_importRawJson` |
| Update coverage state after successful retry | First fail a declared highway read with a typed Mapping exception, repair the fake reader, then invoke `retryActive`. The generation commits and the Mapping failure clears, but `stateFor('tasmania').status` remains `failed`. The stored retry closure runs only the import body, not its state transitions. | `lib/services/route_graph_import_coordinator.dart::_runCatalogBatch` |
| Reject malformed selected highway tags | Resolve a way with valid identity/nodes but `tags.highway: 123`. Resolution succeeds instead of failing validation. Candidate validation skips the non-string tag while accepted-way counting still accepts it. | `lib/services/route_graph_coverage_resolver.dart::_validateSelectedRouteGraphWays`, `isAcceptedRouteGraphWay` |
| Reject mismatched row coverage before committing | Call `writePreparedGeneration` for `tasmania` with a chunk explicitly owned by `other`. The write succeeds; repository qualification rewrites the supplied coverage before storage validation can reject it. | `lib/services/route_graph_repository.dart::writePreparedGeneration`, `_qualifyPreparedGeneration` |

### Additional source-review gap

`MapNotifier._routeCoverageFor` still selects endpoint coverage from persisted
graph chunk/unavailable footprints. It does not use
`MappingCatalog.routingCoverageForPoint`, whose only production occurrence is its
declaration. The required catalog-priority/ambiguity contract is therefore not
connected to route requests. Coverage rejections set a generic route-draft error
and point to Settings refresh rather than the affected operation's Mapping
failure/retry flow. Existing `route-planning-mapping-unavailable` widget tests
exercise DEM failures, not route-graph coverage failures.

### Required follow-up before acceptance

- Fix usability/count validation, path-bearing typed source failures, retry state
  transitions, complete selected-candidate validation, and mismatched-row writes.
- Connect route endpoint selection to the injected catalog and coverage-scoped
  failure/retry state, preserving another coverage's usable generation.
- Add catalog-mode no-source-read, rebuild, retention, source-format, row-count,
  mismatched-write, concurrency, and widget/robot dismissal/retry coverage. The
  current import-coordinator tests exercise the legacy injected-loader branch.
- Re-run ObjectBox generation/review, focused checks, analysis, and the full
  suite before completing the remaining criteria.

## Remediation and final verification — 2026-10-05

**Complete.** The six reproduced failures and the catalog-selection gap are
fixed. Usability rejects empty graphs and compares manifest node/way counts
against unique persisted geometry, accounting for chunk overlap. Count parsing is
cached by generation and payload set. Import manifests now record the geometry
actually persisted, excluding unused diagnostic nodes.

Catalog-mode source and zero-way failures are typed Mapping exceptions carrying
the affected declared paths. The retried action includes importing/ready/failed
state transitions. Independent coverage reads proceed concurrently; actual
generation writes share table locks. A duplicate pending coverage request joins
the same execution. Failed refresh retains the previous generation and source
hash, while another coverage remains usable. Pruning removes stale/orphan rows
only for the written coverage; mismatched supplied coverage rows are rejected
before qualification and commit.

Selected-way validation requires a non-empty string highway, valid tag shape,
positive identities/references, and geographically valid supporting nodes. It is
shared with in-process preparation. Canonical duplicate merging remains intact.
Route requests now use `MappingCatalog.routingCoverageForPoint`, including highest
priority and ambiguity handling, instead of graph footprints. Only a resolved,
unusable coverage triggers its operation-scoped import/failure flow; the route
surface retains its stable unavailable keys after dismissal and can retry the
coverage followed by its retained segment. Readiness listens to successful
coverage retries.

- Focused prerequisite suite: **76 passed**; additional catalog overlap/priority
  and refreshed-trail journey checks passed after correcting legacy fixtures.
- Full suite: `flutter test --no-pub --reporter expanded` — **2,152 passed,
  5 skipped**.
- Original temporary verification probes: **11 passed** across both Work Items.
- `dart run build_runner build --delete-conflicting-outputs`: succeeded and
  reviewed. No route-graph schema changes were required; the only additive
  ObjectBox change is Work Item 07's nullable unique identity index.
- `flutter analyze`: **7 pre-existing findings** (2 async-return warnings and
  5 style infos); no new findings. Exit status remains 1 for existing warnings.
- Coverage includes `route_graph_mapping_contract_test.dart`,
  `route_graph_catalog_selection_test.dart`, real ObjectBox legacy/orphan and
  cross-coverage repository checks, existing resolver/import/coordinator tests,
  and production route-overlay robot verification. Legacy synthetic fixtures now
  contain geometry consistent with their recorded counts.

### Journey Verification

- Journey: Route segment coverage failure, dismissal, source repair, coverage retry, retained segment completion
- Verification command(s): `flutter test test/robot/route_graph_mapping_journey_test.dart`
- Required seams/selectors: injected Mapping catalog, deterministic highway reader
  and generation preparation, production `MapNotifier`, route overlay and shared
  failure dialog; `route-planning-mapping-unavailable` and its Retry key; robot
  methods `pumpSurface`, `expectFailure`, `dismiss`, `expectUnavailable`,
  `retryFeature`, `expectAvailable`.
- Result: `pass`
- Remaining risk: live mounted-store and packaged macOS flows are reserved for
  Work Item 12. The UI journey uses deterministic generation preparation; real
  preparation, import, ObjectBox persistence, and routing behavior have separate
  service/repository coverage in the passing full suite.

## Approved FVG/Slovenia precedence — 2026-10-07

L11 permits complete FVG OSM elements to win over conflicting Slovenia elements
in Northeast Alps. One provenance-aware merger handles both resolver modes and
both source orders. It preserves complete FVG ways/supporting nodes, retains
Slovenia-only records, logs precedence decisions, and still rejects same-region
inconsistent repeats or conflicts involving a third region. Final selected-way
validation remains before ObjectBox writes. The full source hash includes the
explicit merge-policy revision and all snapshots, including losing records.

The unchanged mounted sources resolved into **8,343,986 merged elements** and
**558,284 accepted ways**. All **52 diagnosed conflicts** retained the exact FVG
records. A real temporary ObjectBox import committed a usable generation with
**4,081 chunks, 7,780,038 nodes, 558,284 edges/ways**. Resolve and import together
took approximately **6 minutes** in the full-source Flutter-test probe. Source
files and the ObjectBox schema remain unchanged. Packaged final acceptance
evidence is recorded in Work Item 12.

## Covers

- User Stories: 1, 2
- Requirements: 5, 9, 11, 19, 21, 25-27, 32
- Technical Decisions: 2, 4, 9, 11, 15-18, 28, 31
- Testing Strategy: 3-4, 9-13, 16-17
- Interview Ledger: L1, L3, L5, L9-L11

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
