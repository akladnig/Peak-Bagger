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
- [ ] Keep `Refresh Natural Features`, `refresh-natural-features-tile`, and `natural-feature-refresh-status`; refresh reads `naturalFeatures.catalog` through the Mapping boundary and remains a background job.
- [ ] Treat malformed JSON, a missing `elements` list, duplicate source identities, or malformed selected candidates as all-or-nothing operation failures before ObjectBox writes. Documented ineligible records are diagnostic-only skips.
- [ ] Persist source keys including ownership, OSM type, and positive OSM ID, for example `OSM:node:123` and `Manual:node:123`; Manual and OSM rows with the same OSM identity coexist. Refresh updates or creates only OSM rows, preserves Manual rows, and retains OSM rows absent from the source.
- [ ] Migrate legacy duplicate OSM rows by retaining the lowest positive ObjectBox ID and transactionally merging/removing duplicates during reconciliation without touching a Manual row.
- [ ] A failed bootstrap or refresh preserves prior usable rows and uses `natural-features-mapping-unavailable` with `natural-features-mapping-unavailable-retry` after dialog dismissal.
- [ ] Add source-format, repository, provider, widget, and robot coverage for pending/failed states, exact Settings controls, ownership, duplicate migration, retention, no-source-read bootstrap, retry, and typed Mapping failures.

## Covers

- User Stories: 1, 2
- Requirements: 9, 20, 24-26
- Technical Decisions: 4, 9, 15, 17, 26, 28
- Testing Strategy: 3-4, 9-11, 15-16
- Interview Ledger: L1, L5

## Blocked by
02-mapping-store-manifest-boundary-and-catalog.md
04-mapping-failure-and-bootstrap-coordinator.md
