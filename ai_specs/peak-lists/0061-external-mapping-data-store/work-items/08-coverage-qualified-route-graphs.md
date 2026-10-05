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
- [ ] Before opening a coverage highway source, determine whether it has a usable active generation. A usable generation is `ready`, has a positive active ID, and every chunk, way-index, and display row has the same coverage/generation and matches recorded chunk, node, edge, way-index, and trail-display counts. A zero-way import is unavailable.
- [ ] Persist `routingCoverageKey` on every route-graph row; make every record key injective across coverage, generation, and row identity. Constrain active reads, counts, stale pruning, and orphan cleanup by both coverage and generation; reject mismatched rows before committing.
- [ ] Immediately exclude legacy rows without `routingCoverageKey` from every read, delete them across all route-graph row tables in one transaction, then independently rebuild only declared coverages lacking usable qualified generations.
- [ ] A usable coverage reads no highway source and stays available if its source later becomes unreadable. Failed/incomplete/orphaned coverage data may read and import; a failed manual refresh preserves the coverage's prior usable generation.
- [ ] Resolve a route segment only when both endpoints resolve to exactly one identical coverage. Zero, multiple, or different coverages are ordinary route-unavailable results; only an unavailable resolved coverage enters Mapping failure flow. Use `route-planning-mapping-unavailable` and `route-planning-mapping-unavailable-retry` after dismissal.
- [ ] Validate complete source input before ObjectBox writes: malformed selected candidates fail without writes; documented non-candidates are diagnostic skips; canonically identical repeated OSM elements merge and conflicting identities fail.
- [ ] Add unit/repository/provider/widget/robot/concurrency coverage for every generation, row key, source, coverage resolution, legacy migration, retention, unavailable/retry, and cross-coverage isolation contract. Run `dart run build_runner build --delete-conflicting-outputs` and review generated ObjectBox changes.

## Verification — 2026-10-05

**Incomplete; remains a blocker for Work Item 12.** Reviewed the implementation
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

## Covers

- User Stories: 1, 2
- Requirements: 5, 9, 11, 19, 21, 25-27
- Technical Decisions: 2, 4, 9, 11, 15-18, 28
- Testing Strategy: 3-4, 9-13, 16
- Interview Ledger: L1, L3, L5, L9, L10

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
