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

- [ ] Retain highway sources only for Tasmania and Northeast Alps in the catalog. Northeast Alps contains FVG, Veneto, and Slovenia and requires `Highways/slovenia-highways.json`; no absent NSW, Italy aggregate/North East/North West, or Croatia highway declaration remains.
- [ ] Before opening a coverage highway source, determine whether it has a usable active generation. A usable generation is `ready`, has a positive active ID, and every chunk, way-index, and display row has the same coverage/generation and matches recorded chunk, node, edge, way-index, and trail-display counts. A zero-way import is unavailable.
- [ ] Persist `routingCoverageKey` on every route-graph row; make every record key injective across coverage, generation, and row identity. Constrain active reads, counts, stale pruning, and orphan cleanup by both coverage and generation; reject mismatched rows before committing.
- [ ] Immediately exclude legacy rows without `routingCoverageKey` from every read, delete them across all route-graph row tables in one transaction, then independently rebuild only declared coverages lacking usable qualified generations.
- [ ] A usable coverage reads no highway source and stays available if its source later becomes unreadable. Failed/incomplete/orphaned coverage data may read and import; a failed manual refresh preserves the coverage's prior usable generation.
- [ ] Resolve a route segment only when both endpoints resolve to exactly one identical coverage. Zero, multiple, or different coverages are ordinary route-unavailable results; only an unavailable resolved coverage enters Mapping failure flow. Use `route-planning-mapping-unavailable` and `route-planning-mapping-unavailable-retry` after dismissal.
- [ ] Validate complete source input before ObjectBox writes: malformed selected candidates fail without writes; documented non-candidates are diagnostic skips; canonically identical repeated OSM elements merge and conflicting identities fail.
- [ ] Add unit/repository/provider/widget/robot/concurrency coverage for every generation, row key, source, coverage resolution, legacy migration, retention, unavailable/retry, and cross-coverage isolation contract. Run `dart run build_runner build --delete-conflicting-outputs` and review generated ObjectBox changes.

## Covers

- User Stories: 1, 2
- Requirements: 5, 9, 11, 19, 21, 25-27
- Technical Decisions: 2, 4, 9, 11, 15-18, 28
- Testing Strategy: 3-4, 9-13, 16
- Interview Ledger: L1, L3, L5, L9, L10

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
