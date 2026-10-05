---
type: Work Item
title: Refresh Natural Features from Mapping Store
parent: ../spec.md
---

## What to build

Move Natural Features bootstrap and refresh from its fixed source path to `naturalFeatures.catalog`, preserving the existing `Refresh Natural Features` Settings action, background-job behavior, and stable controls. Add Mapping-store unavailable state and exact source ownership/migration semantics.

## Required context

- Extend the existing reader/converter/persistence seams in `natural_feature_refresh_service.dart` and preserve the established ObjectBox transaction conventions.
- Use the shared coordinator rather than a screen-local error path. Natural Feature source identity must now distinguish OSM and Manual ownership.

## Acceptance criteria

- [ ] Bootstrap runs only while the Natural Features table is empty; a populated table performs no source read. Pending or failed bootstrap remains unavailable rather than silently empty and retry resumes only the original operation.
- [x] Keep `Refresh Natural Features`, `refresh-natural-features-tile`, and `natural-feature-refresh-status`; refresh reads `naturalFeatures.catalog` through the Mapping boundary and remains a background job.
- [ ] Treat malformed JSON, a missing `elements` list, duplicate source identities, or malformed selected candidates as all-or-nothing operation failures before ObjectBox writes. Documented ineligible records are diagnostic-only skips.
- [ ] Persist source keys including ownership, OSM type, and positive OSM ID, for example `OSM:node:123` and `Manual:node:123`; Manual and OSM rows with the same OSM identity coexist. Refresh updates or creates only OSM rows, preserves Manual rows, and retains OSM rows absent from the source.
- [x] Migrate legacy duplicate OSM rows by retaining the lowest positive ObjectBox ID and transactionally merging/removing duplicates during reconciliation without touching a Manual row.
- [ ] A failed bootstrap or refresh preserves prior usable rows and uses `natural-features-mapping-unavailable` with `natural-features-mapping-unavailable-retry` after dialog dismissal.
- [ ] Add source-format, repository, provider, widget, and robot coverage for pending/failed states, exact Settings controls, ownership, duplicate migration, retention, no-source-read bootstrap, retry, and typed Mapping failures.

## Verification — 2026-10-05

**Incomplete; remains a blocker for Work Item 12.** Reviewed the implementation
at `85f93c1`, including the Work Item 07 commit `855e3f4`. Passing existing tests
do not establish the unchecked acceptance criteria.

### Checks performed

- Focused Natural Features, route-graph, Mapping coordinator, and catalog suite:
  **95 passed** across 14 test files. The first invocation exceeded its 120-second
  shell limit; the completed rerun used a 600-second limit.
- `flutter test --no-pub --reporter expanded`: **2,127 passed, 5 skipped**.
- `flutter analyze`: exit 1, **9 existing findings** (2 async-return warnings in
  `map_provider.dart` / `gpx_importer.dart`, 7 route-graph style infos).
- `dart run build_runner build --delete-conflicting-outputs`: succeeded; the
  installed runner ignores this removed flag. Reviewed the generated outputs:
  no tracked changes to `lib/objectbox.g.dart` or `lib/objectbox-model.json`.
- Supplemental temporary Flutter-test probes outside the repository reproduced
  the five failures below. They use fake readers, in-memory repositories, or
  temporary ObjectBox stores; no mounted Mapping data or live services are used.
  These probes are verification evidence, not committed regression coverage.

### Reproduced acceptance failures

| Contract | Reproduction and observed result | Relevant implementation |
| --- | --- | --- |
| Bootstrap availability updates after commit | Observe `naturalFeatureAvailabilityProvider` with bootstrap enabled and an empty repository; run a successful `naturalFeaturesBootstrap` action that saves a row. The repository becomes populated but the observed provider still returns unavailable. Successful first attempts do not notify coordinator listeners. | `lib/providers/mapping_store_operation_provider.dart::naturalFeatureAvailabilityProvider`; `lib/services/mapping_store_operation_coordinator.dart::run`, `_clearPending`, `_removeFailure` |
| Reject every duplicate source identity | Give `buildNaturalFeatureRefreshPlan` two identical untagged `node` records with ID 1. It returns a successful empty plan instead of rejecting the duplicate supporting identity. Duplicate detection currently covers selected candidates only. | `lib/services/natural_feature_refresh_service.dart::buildNaturalFeatureRefreshPlan`, `_NaturalFeatureSource` |
| Validate ignored relation members | Give a selected non-multipolygon relation one valid way member and a node member with `ref: 0`. It produces a feature instead of failing source validation. Ignoring a member for centroid construction does not exempt its positive-reference contract. | `lib/services/natural_feature_refresh_service.dart::_centroidForRelation` |
| Persist unique ownership-qualified source keys | Insert two new OSM features with identical `OSM:node:1` keys into a temporary ObjectBox store. Both inserts succeed with distinct IDs; `sourceKey` has no unique constraint. | `lib/models/natural_feature.dart::sourceKey`; generated ObjectBox schema |
| Preserve refresh failure availability after dismissal | With a populated repository, record a `naturalFeaturesRefresh` Mapping failure and dismiss it. The coordinator retains its retryable failure, but availability reports available. The provider checks only the bootstrap key, and the map's Natural Features retry targets only that key. | `lib/providers/mapping_store_operation_provider.dart::naturalFeatureAvailabilityProvider`; `lib/screens/map_screen.dart::onRetryNaturalFeatures` |

### Required follow-up before acceptance

- Fix the reproduced startup/refresh availability, source-validation, and unique
  source-key contracts, retaining legacy-duplicate migration and Manual ownership.
- Add the required provider/widget/robot tests for no-source-read bootstrap,
  pending/failure/success transitions, exact Mapping dialog paths, dismissal,
  original-operation retry, and same-identity Manual/OSM persistence. The current
  Settings widget tests do not verify the shared Mapping failure journey.
- Re-run focused tests, ObjectBox generation/review, analysis, and the full suite
  before completing the remaining criteria.

## Covers

- User Stories: 1, 2
- Requirements: 9, 20, 24-26
- Technical Decisions: 4, 9, 15, 17, 26, 28
- Testing Strategy: 3-4, 9-11, 15-16
- Interview Ledger: L1, L5

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
