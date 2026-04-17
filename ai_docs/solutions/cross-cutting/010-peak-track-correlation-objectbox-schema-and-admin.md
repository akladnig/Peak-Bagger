---
title: Peak Track Correlation and ObjectBox Schema Checks
date: 2026-04-17
work_type: feature
tags: [objectbox, peak-correlation, admin-ui]
confidence: high
references: [ai_specs/010-peak-track-correlation-spec.md, ai_specs/010-peak-track-correlation-plan.md, lib/models/gpx_track.dart, lib/models/peak.dart, lib/services/objectbox_schema_guard.dart, lib/services/objectbox_admin_repository.dart, lib/main.dart]
---

## Summary

This session delivered persisted peak-to-track correlation for `GpxTrack`, including the `peaks` relation, `peakCorrelationProcessed`, persisted threshold settings, and `Peak.osmId` identity-backed refresh behavior. The most reusable follow-up lesson was that ObjectBox itself can be correct while debug/admin tooling still makes the store look stale if it manually omits new properties or relations.

## Reusable Insights

- When diagnosing a suspected stale ObjectBox schema, check three layers separately:
  1. generated schema files: `lib/objectbox-model.json`, `lib/objectbox.g.dart`
  2. runtime store startup path: `openStore()` in `lib/main.dart`
  3. any admin/debug projection layer, especially code that manually builds field lists or row maps
- In this codebase, `rootBundle` is not part of ObjectBox startup. It is only used by `lib/services/csv_importer.dart` for Tasmap CSV loading, so schema bugs should not be chased through asset loading.
- The admin browser was the misleading layer. `lib/services/objectbox_admin_repository.dart` originally exposed only generated properties it knew about manually and dropped:
  - `Peak.osmId`
  - `GpxTrack.peakCorrelationProcessed`
  - `GpxTrack.peaks`
  This made the store appear stale even though the generated ObjectBox model already contained those members.
- For future ObjectBox-backed admin tools, derive schema metadata from `getObjectBoxModel().model.entities` and include both `properties` and `relations`. If rows are hand-mapped, new persisted fields must also be added explicitly to row values.
- A small startup schema guard is useful when users may run an old build against newer data expectations. `lib/services/objectbox_schema_guard.dart` stores a compact signature based on the generated model and fails fast if that signature changes later.
- For upstream identity, parse and persist external IDs as early as possible. Here, `Peak.fromOverpass()` reads Overpass `id` into `Peak.osmId`, and `PeakRepository.replaceAll()` preserves local ids by matching on `osmId`.

## Decisions

- Kept the startup schema check lightweight by deriving the signature from the generated model instead of introspecting native ObjectBox internals.
- Fixed the admin view instead of treating the database as stale, because the generated schema and generated bindings already contained the missing property and relation definitions.
- Added targeted regression tests around admin schema exposure and row mapping so future schema additions do not silently disappear from diagnostics.

## Pitfalls

- A generated ObjectBox relation can exist while the admin UI still claims it does not if the admin layer only renders `entity.properties` and ignores `entity.relations`.
- A persisted field can look `null` in the admin browser when the row mapper never includes it, even if the underlying entity constructor and ObjectBox binding are correct.
- Nullable/introspection helpers from ObjectBox model classes are not always safe to use from generated-model instances; prefer conservative rendering unless nullability is critical.

## Validation

- Regenerated ObjectBox artifacts after schema changes.
- Verified targeted tests and full suite:
  - `flutter analyze`
  - `flutter test`
- Added focused coverage for:
  - `test/services/objectbox_schema_guard_test.dart`
  - `test/services/objectbox_admin_repository_test.dart`

## Follow-ups

- If startup failures should be user-friendly, convert the schema-guard `StateError` into a dedicated recovery screen with clear instructions to reinstall or clear app data.
- If the admin browser keeps evolving, consider generating more of its entity/row exposure from the ObjectBox model to reduce hand-maintained drift.
