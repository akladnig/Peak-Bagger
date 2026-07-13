---
type: Work Item
title: Persist Peak List Coverage Bounds And Mixed Region Classification
parent: ../spec.md
---

## What to build

Add nullable derived `PeakList` ObjectBox fields `minLat`, `maxLat`, `minLng`, and `maxLng`, keep them preserved across `PeakList` write paths unless intentionally recomputed, and make member peak coordinates the source of truth for recalculating cached coverage bounds. This slice must normalize `PeakList.region` as a stored classification field, persisting `mixed` when a list spans more than one canonical region, recomputing or resaving bounds on in-scope membership and affected peak-coordinate write paths, and running a one-time migration-marker-backed backfill for existing stored data. Regenerate ObjectBox artifacts after the schema change and keep ObjectBox Admin `PeakList` row mapping aligned so the new persisted values remain inspectable.

## Required context

- `lib/models/peak_list.dart` is the current `PeakList` entity and its `copyWith` implementation will need to preserve any newly added derived fields.
- `lib/services/peak_list_repository.dart`, `lib/services/peak_list_import_service.dart`, `lib/screens/peak_lists_screen.dart`, and `lib/widgets/peak_list_peak_dialog.dart` cover the create, import, add, remove, and delete write paths named in the Spec.
- `lib/services/peak_repository.dart` already participates in write paths that can change referenced peak coordinates or ids and already has rewrite hooks into peak-list persistence.
- `lib/services/migration_marker_store.dart`, `lib/services/item_visibility_backfill_service.dart`, and `lib/providers/map_provider.dart` show the existing one-time startup backfill pattern with a migration marker that this slice should reuse.
- `lib/services/objectbox_admin_repository.dart`, `lib/objectbox-model.json`, and `lib/objectbox.g.dart` must stay aligned after ObjectBox schema changes.
- Reuse deterministic service and provider test patterns from `test/services/peak_refresh_service_test.dart`, `test/services/migration_marker_store_test.dart`, `test/providers/peak_list_mutation_provider_test.dart`, and related in-memory repository coverage instead of live ObjectBox app data.

## Acceptance criteria

- [x] Behavior-first TDD drives the derived-bounds calculation and persistence logic before implementation is finalized, covering multi-point bounds, null-bounds cases, collapsed single-point bounds input, and backfill behavior.
- [x] `PeakList` persists nullable derived fields `minLat`, `maxLat`, `minLng`, and `maxLng` exactly as scalar ObjectBox properties, and `PeakList.copyWith` or equivalent cloning paths preserve those values unless the caller is intentionally recomputing them.
- [x] Cached bounds are computed from resolvable member peak coordinates and stored on the owning `PeakList`, while member peak coordinates remain the source of truth.
- [x] `PeakList.region` remains a classification field rather than a geometry field, and write paths that classify a list from its member peaks persist `PeakList.region = mixed` when the list spans more than one canonical region while single-region lists keep or regain their canonical classification.
- [x] Peak-list create, import, add, remove, and whole-list delete flows recompute and resave derived bounds when the resulting stored list membership changes, while point-value edits that do not change membership do not trigger bounds recomputation.
- [x] If this slice updates existing peak-coordinate write paths that can change a referenced peak's location, affected peak lists receive refreshed derived bounds before later navigation relies on stale cached geometry.
- [x] A one-time startup backfill with a migration marker computes and saves derived bounds for existing stored peak lists and normalizes `PeakList.region` from current member peaks, including rewriting mixed-region lists to `mixed`, without requiring users to edit or reimport lists first.
- [x] The backfill and recompute logic leave all four derived bounds fields null when a list has no resolvable member peak coordinates rather than inventing fallback geometry.
- [x] ObjectBox regeneration is completed for the new `PeakList` schema, and ObjectBox Admin `PeakList` rows expose the new persisted fields so they remain inspectable in the existing admin tooling.
- [x] Automated coverage uses fake or in-memory data only and verifies recomputation after list-mutation flows, backfill plus migration-marker behavior, mixed-region classification normalization, and ObjectBox Admin row exposure without depending on live app data, networking, or real map rendering.

## Covers

- User Stories: 2, 3
- Requirements: 4-5, 7-12, 15, 17
- Technical Decisions: 1-2, 4-5
- Testing Strategy: 1-3, 8-10
- Interview Ledger: L2-L4

## Blocked by

None - ready to start
