---
type: Work Item
title: Martin Refresh Import And Staged Publish Pipeline
parent: ../spec.md
---

## What to build
Add the repo-owned `osm2pgsql` `flex` import and Docker Compose-managed `PostGIS` plus `Martin` refresh workflow that rebuilds preview OSM data from the exact existing Tasmania extract-selection contract already used by the rebuild workflow, keeps `npm run stack:up`, `npm run stack:up:preview`, and `npm run stack:up:static` serve-only, imports preview OSM data into the staged schema `local_topo_preview_stage`, validates the staged dataset before promotion, promotes into the active schema `local_topo_preview_active` only after import and validation succeed, explicitly restarts Martin on successful publish, and preserves the last successful active dataset if import, validation, or promotion fails.

## Required context
- Current rebuild and refresh seams live in `local_topo/tasmania/scripts/rebuild_stack.sh`, `local_topo/tasmania/scripts/manual_refresh.sh`, `local_topo/tasmania/scripts/scheduled_refresh.sh`, `local_topo/tasmania/docker-compose.yml`, and `local_topo/tasmania/package.json`.
- Preserve the exact existing Tasmania extract-selection seams `LOCAL_TOPO_OSM_EXTRACT_PATH` and `LOCAL_TOPO_OSM_EXTRACT_OVERRIDE`; related rebuild behavior should stay aligned with existing refresh workflow conventions rather than introducing a second selection path.
- Deterministic script-level test seams are preferred over live Docker Compose, `PostGIS`, or `Martin` in the primary automated regression path.
- This item depends on the Martin style and runtime boundary established in `01-martin-preview-style-and-runtime-contract.md`.

## Acceptance criteria
- [x] The preview OSM database is derived from the exact existing Tasmania OSM extract-selection contract already used by the rebuild workflow: normal rebuild selection continues using `LOCAL_TOPO_OSM_EXTRACT_PATH` or its existing default managed-cache location, `LOCAL_TOPO_OSM_EXTRACT_OVERRIDE` remains the explicit local override seam, and Martin preview import consumes the same selected extract resolved through those seams.
- [x] `npm run stack:up`, `npm run stack:up:preview`, and `npm run stack:up:static` remain serve-only and do not download, select, copy, import, or rebuild OSM data on demand.
- [x] Docker Compose-managed `PostGIS` is the canonical preview OSM runtime for this workflow and the only required runtime path for this first Spec.
- [x] Preview OSM data is built and refreshed during `npm run refresh:manual` and `npm run refresh:scheduled` as maintainer-managed derived state rather than a checked-in artifact.
- [x] `npm run refresh:scheduled` preserves the current stale-managed-extract fallback behavior when refresh download fails and a previously usable managed extract already exists, and this scheduled-only fallback is not broadened into `npm run refresh:manual`.
- [x] The Martin-backed preview OSM import uses repo-owned `osm2pgsql` `flex` configuration that loads only the required preview layers and attributes into a preview-specific PostGIS schema and does not adopt the full OpenMapTiles import pipeline.
- [x] For normal preview traffic, Martin serves only from the fixed active PostGIS schema `local_topo_preview_active`.
- [x] A refresh run imports into the staged PostGIS schema `local_topo_preview_stage` first and promotes that staged schema into `local_topo_preview_active` only after import and validation succeed.
- [x] Validation reads `local_topo_preview_stage` directly before promotion; if tile-read validation is used, it runs through a staged validation seam rather than the normal active preview route.
- [x] The minimum validation contract before promotion is enforced: the staged schema contains the required first-slice layers, deferred layers are not required for success, the staged dataset is readable through the expected Martin configuration, deterministic schema-read validation passes, and an explicit Martin restart occurs as part of successful promotion so the publish boundary stays deterministic.
- [x] If contours and relief rebuild successfully but the preview OSM import fails, the refresh run fails clearly, keeps the last successful published Martin preview dataset active, and does not publish a partially replaced preview dataset.
- [x] Deterministic script-level coverage proves generated import command arguments, required-layer mapping, deferred-layer omission, schema-target selection to `local_topo_preview_stage`, promotion into `local_topo_preview_active`, required schema-read validation, any staged tile-read validation seam used in addition to schema-read validation, the explicit Martin restart publish step, reuse of the exact extract-selection workflow, preservation of the scheduled stale-managed-extract fallback behavior, and preservation of `local_topo_preview_active` when a new import, validation step, or promotion step fails.

## Covers
- User Stories: 1, 3
- Requirements: 1, 3, 9-16
- Technical Decisions: 2-3, 6-8
- Testing Strategy: 4-5
- Interview Ledger: L1-L4, L6-L10, L12

## Blocked by
- 01-martin-preview-style-and-runtime-contract.md
