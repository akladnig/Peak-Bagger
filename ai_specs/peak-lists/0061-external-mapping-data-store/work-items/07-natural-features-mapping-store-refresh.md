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

- [x] Bootstrap runs only while the Natural Features table is empty; a populated table performs no source read. Pending or failed bootstrap remains unavailable rather than silently empty and retry resumes only the original operation.
- [x] Keep `Refresh Natural Features`, `refresh-natural-features-tile`, and `natural-feature-refresh-status`; refresh reads `naturalFeatures.catalog` through the Mapping boundary and remains a background job.
- [x] Treat malformed JSON, a missing `elements` list, duplicate source identities, or malformed selected candidates as all-or-nothing operation failures before ObjectBox writes. Documented ineligible records are diagnostic-only skips.
- [x] Persist source keys including ownership, OSM type, and positive OSM ID, for example `OSM:node:123` and `Manual:node:123`; Manual and OSM rows with the same OSM identity coexist. Refresh updates or creates only OSM rows, preserves Manual rows, and retains OSM rows absent from the source.
- [x] Migrate legacy duplicate OSM rows by retaining the lowest positive ObjectBox ID and transactionally merging/removing duplicates during reconciliation without touching a Manual row.
- [x] A failed bootstrap or refresh preserves prior usable rows and uses `natural-features-mapping-unavailable` with `natural-features-mapping-unavailable-retry` after dialog dismissal.
- [x] Add source-format, repository, provider, widget, and robot coverage for pending/failed states, exact Settings controls, ownership, duplicate migration, retention, no-source-read bootstrap, retry, and typed Mapping failures.

## Verification — 2026-10-05

**Initial verification, superseded by remediation below.** Reviewed the implementation
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

## Remediation and final verification — 2026-10-05

**Complete.** All five reproduced failures are fixed. The Mapping operation
coordinator now publishes pending/completed transitions, retains failure causes
and original retry identities, and suppresses notifications after disposal.
Natural Features availability includes manual refresh failures and successful
empty-source bootstrap; the map retry uses the actual failed operation key.

Source validation rejects duplicate supporting identities, invalid relation
references, and malformed selected geometry before persistence. MGRS conversion
failure is also all-or-nothing, with a typed source-path failure. Ineligible
records emit diagnostics. Actual same-type/same-ID Manual and OSM rows coexist.

ObjectBox adds a **nullable unique `sourceRecordKey`** alongside the retained
`sourceKey`. Existing databases can open with unindexed legacy rows, including
duplicates. Reconciliation deletes duplicate OSM rows before indexing the lowest
positive-ID survivor in the same transaction, without touching Manual rows.
Repository saves assign the canonical ownership/type/ID key. Generated property
18 and index 29 were reviewed; existing property and entity UIDs are preserved.

- Focused prerequisite suite: **76 passed**, plus final catalog-selection checks.
- Full suite: `flutter test --no-pub --reporter expanded` — **2,152 passed,
  5 skipped**.
- Original temporary verification probes: **11 passed** across both Work Items.
- `dart run build_runner build --delete-conflicting-outputs`: succeeded; the
  installed runner ignores the removed flag. Final regeneration was stable.
- `flutter analyze`: **7 pre-existing findings** (2 async-return warnings and
  5 style infos); no new analysis findings. Exit status remains 1 for those
  existing warnings.
- Regression coverage lives in `natural_feature_refresh_service_test.dart`,
  `natural_feature_repository_test.dart`, `natural_feature_availability_test.dart`,
  and `natural_feature_refresh_settings_test.dart`, with dedicated popup/dialog
  robot journeys and harnesses.

### Journey Verification

- Journey: Natural Features first-run bootstrap failure, dismissal, repair, retry
- Verification command(s): `flutter test test/robot/natural_feature_mapping_journey_test.dart`
- Required seams/selectors: controlled source/commit harness, ready provider
  overrides, production `MapSearchPopup`, shared Mapping dialog keys,
  `natural-features-mapping-unavailable` and its Retry key; robot methods
  `pumpSurface`, `expectFailure`, `dismiss`, `expectUnavailable`, `retryFeature`.
- Result: `pass`
- Remaining risk: real mounted-store and packaged macOS interaction is deferred
  to Work Item 12's explicit release verification; these journeys use deterministic
  in-memory commits, with real importer/ObjectBox behavior verified separately.

### Journey Verification

- Journey: Populated Natural Features manual refresh failure, dismissal, repair, retry
- Verification command(s): `flutter test test/robot/natural_feature_mapping_journey_test.dart`
- Required seams/selectors: same production popup/dialog controls and deterministic
  harness, populated repository, original `naturalFeaturesRefresh` key.
- Result: `pass`
- Remaining risk: the mounted source is not accessed in automated tests. Settings
  background-job handoff and the shared failure dialog are covered by separate
  production Settings widget tests.

## Covers

- User Stories: 1, 2
- Requirements: 9, 20, 24-26
- Technical Decisions: 4, 9, 15, 17, 26, 28
- Testing Strategy: 3-4, 9-11, 15-16
- Interview Ledger: L1, L5

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
