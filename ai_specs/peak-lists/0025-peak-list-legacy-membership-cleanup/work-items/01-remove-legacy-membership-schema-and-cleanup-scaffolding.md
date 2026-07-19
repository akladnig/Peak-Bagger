---
type: Work Item
title: Remove Legacy Membership Schema And Cleanup Scaffolding
parent: ../spec.md
---

## What to build
Start this cleanup only after `ai_specs/peak-lists/0024-peak-list-membership-performance-and-export-responsiveness/spec.md` has been implemented, verified against real existing user data, and confirmed to have migrated all 7 peak lists successfully. Then remove the legacy `PeakList.peakList` and `PeakList.membershipState` contract entirely from the Dart model, ObjectBox schema, and repository foundation, remove JSON membership helpers and migration-only infrastructure, and leave relational `PeakListItemEntity` membership as the only steady-state app-owned membership storage path.

## Required context
- `lib/models/peak_list.dart`, `lib/objectbox.g.dart`, and `lib/objectbox-model.json` are the schema and codegen surfaces that still persist the legacy `peakList` JSON payload and `membershipState`.
- `lib/services/peak_list_repository.dart` is still the central dual-mode seam; this item should remove repository branching that exists only to support legacy JSON-backed membership.
- `lib/services/peak_list_coverage_backfill_service.dart`, `lib/services/migration_marker_store.dart`, `lib/providers/map_provider.dart`, and `lib/main.dart` currently carry the migration-only startup path, readiness state, and persisted marker behavior that should be deleted once this cleanup begins from the fully migrated state.
- `lib/services/objectbox_schema_guard.dart` and `test/services/objectbox_schema_guard_test.dart` contain schema expectations that must be updated alongside regenerated ObjectBox artifacts.
- Preserve existing in-memory and provider-override test seams. Automated coverage must stay deterministic and must not require live filesystem dialogs, network calls, or secrets.

## Acceptance criteria
- [x] The implementation assumes the verified post-`0024` state and removes startup migration triggers, persisted migration markers, migration-only loading branches, and other temporary cleanup scaffolding rather than preserving another fallback window.
- [x] `PeakList.peakList` is removed entirely from `PeakList`, ObjectBox schema metadata, and generated artifacts. No dead persisted debug, fallback, or admin-only copy of the field remains.
- [x] `PeakList.membershipState` is removed entirely from `PeakList`, ObjectBox schema metadata, and generated artifacts.
- [x] Legacy JSON membership helpers such as `encodePeakListItems` and `decodePeakListItems` are removed, along with repository or model helpers that exist only to support app-owned JSON membership behavior.
- [x] `PeakListRepository` becomes relational-only for active membership behavior and no longer exposes dual-mode branching based on legacy JSON storage.
- [x] `lib/objectbox.g.dart`, `lib/objectbox-model.json`, and any schema-guard expectations are regenerated and committed in the final relational-only shape.
- [x] Focused service and schema regression coverage proves the legacy membership fields and migration-only state are gone and that no active repository path still requires the removed JSON contract.

## Covers
- User Stories: 1-2
- Requirements: 1-4, 6, 9-10
- Technical Decisions: 1-3
- Testing Strategy: 1, 3, 5

## Blocked by
None - ready to start
