---
title: Peak Source of Truth and Refresh Protection
date: 2026-04-19
work_type: feature
tags: [peak-import, source-of-truth, objectbox]
confidence: high
references: [ai_specs/011-peak-lists-spec.md, ai_specs/011-peak-lists-plan.md, ai_specs/003-peaks-to-mgrs-spec.md, ai_specs/003-peaks-to-mgrs-plan.md, lib/models/peak.dart, lib/services/peak_list_import_service.dart, lib/services/peak_refresh_service.dart, lib/services/objectbox_admin_repository.dart, lib/services/objectbox_schema_guard.dart]
---

## Summary

This session added a persisted `Peak.sourceOfTruth` field and used it to coordinate two competing writers of `Peak` data:

- `lib/services/peak_list_import_service.dart` can now correct `Peak` latitude, longitude, elevation, easting, and northing from CSV-backed HWC data and mark the row as `HWC`.
- `lib/services/peak_refresh_service.dart` now treats those corrected rows as protected and only refreshes peaks whose `sourceOfTruth` is unset, empty, or `OSM`.

The important reusable outcome is the pattern: when multiple ingestion paths can update the same entity, persist explicit ownership on the entity and make background refresh logic respect it.

## Reusable Insights

- If one import path is considered more authoritative than another, encode that directly on the entity instead of trying to infer it later from timestamps or heuristics. Here that became `Peak.sourceOfTruth` in `lib/models/peak.dart`.
- When a corrective import changes an existing row, do not treat that as a side effect outside the main flow. Persist the corrected entity as part of the import service, then make downstream refresh behavior key off that persisted state.
- For mixed-authority systems, refresh should merge, not blindly replace. `lib/services/peak_refresh_service.dart` now:
  1. preserves existing `HWC` rows
  2. refreshes only rows whose `sourceOfTruth` is `OSM` or empty
  3. still inserts newly fetched peaks
- Separate matching tolerance from correction tolerance. The importer can use relaxed matching rules to identify a row, then still log correction warnings when the matched data drifts meaningfully from stored values.
- Keep user-facing warnings and log-file warnings distinct. `warningEntries` stay raw and readable, while `logEntries` add timestamps and can include coordinate drift or height correction details.
- In this repo, ObjectBox schema work is not complete until four surfaces agree:
  1. entity model (`lib/models/peak.dart`)
  2. generated artifacts (`lib/objectbox-model.json`, `lib/objectbox.g.dart`)
  3. schema guard (`lib/services/objectbox_schema_guard.dart`)
  4. admin projection (`lib/services/objectbox_admin_repository.dart`)

## Decisions

- Kept `sourceOfTruth` string-backed with explicit constants (`OSM`, `HWC`) instead of adding a new enum serialization layer. That made ObjectBox schema updates and test doubles simpler.
- Treated empty `sourceOfTruth` as `OSM` during refresh so old rows remain refreshable without a separate migration pass.
- Kept `PeakList` storage as ordered JSON payloads referencing `peakOsmId`, while `Peak` corrections remain direct entity updates. That avoids duplicating corrected values inside list payloads.

## Pitfalls

- A new persisted field can look missing even when ObjectBox is correct if the admin layer manually omits it. `sourceOfTruth` had to be added to both schema exposure and row mapping in `lib/services/objectbox_admin_repository.dart`.
- Generated schema changes alone are not enough during local verification. A full app restart is needed after regenerating `lib/objectbox.g.dart`; hot reload can make the admin view look stale.
- A schema guard can become noisy if it treats every schema change as fatal. In this session the guard was kept as a signature recorder, while still expanding the signature surface to include `Peak.sourceOfTruth`.
- If refresh logic still uses unconditional replacement semantics, a later Overpass refresh will silently wipe higher-authority CSV corrections.

## Validation

- Regenerated ObjectBox artifacts after adding `Peak.sourceOfTruth`.
- Verified the correction and refresh interaction with focused tests:
  - `test/services/peak_list_import_service_test.dart`
  - `test/services/peak_refresh_service_test.dart`
  - `test/services/peak_repository_test.dart`
  - `test/services/objectbox_schema_guard_test.dart`
  - `test/services/objectbox_admin_repository_test.dart`
- Full validation commands:
  - `flutter analyze`
  - `flutter test`

## Follow-ups

- If more authorities are introduced later, convert `sourceOfTruth` from a binary convention into a documented precedence model before adding new writers.
- If the ObjectBox admin screen needs to surface data ownership more clearly, consider a dedicated filter or badge for `sourceOfTruth` so protected `HWC` rows are easier to inspect.
