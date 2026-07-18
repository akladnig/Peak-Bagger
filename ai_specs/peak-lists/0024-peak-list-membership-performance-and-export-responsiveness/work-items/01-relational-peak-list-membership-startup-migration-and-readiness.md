---
type: Work Item
title: Relational Peak List Membership Startup Migration And Readiness
parent: ../spec.md
---

## What to build
Add persisted relational `PeakListItem` membership rows as the peak-list membership source of truth, run the one-time automatic startup migration from legacy `PeakList.peakList` JSON with the app's existing backfill and migration-marker pattern, and gate membership-dependent surfaces behind deterministic loading or disabled states until migration finishes. Preserve the existing unsupported legacy-list behavior for unreadable payloads: affected lists stay visible by name and deletable in `My Peak Lists`, blocked for membership edits, skipped by supported-only export and map selection surfaces, and accompanied by the existing delete-and-reimport guidance plus a one-time non-blocking warning.

## Required context
- `lib/models/peak_list.dart`, `lib/objectbox-model.json`, and `lib/objectbox.g.dart` are the current persistence surfaces that still expose `PeakList.peakList` JSON and will need the relational `PeakListItem` source-of-truth shift aligned with ObjectBox schema regeneration.
- `lib/services/peak_list_repository.dart`, `lib/services/migration_marker_store.dart`, `lib/services/peak_list_coverage_backfill_service.dart`, `lib/providers/map_provider.dart`, and `lib/router.dart` show the existing one-time startup backfill, persisted completion marker, and startup warning patterns this item must reuse rather than replacing.
- `lib/screens/peak_lists_screen.dart`, `lib/widgets/map_peak_lists_drawer.dart`, and `lib/providers/peak_list_selection_provider.dart` already contain unsupported legacy-list behavior that should be preserved and made consistent during the migration window.
- Follow the existing service and provider testing seams in `test/services/peak_list_coverage_backfill_service_test.dart`, `test/providers/map_provider_peak_bootstrap_test.dart`, `test/widget/peak_lists_screen_test.dart`, and related in-memory ObjectBox-style coverage. Do not require live filesystem dialogs, network calls, or secrets.

## Acceptance criteria
- [x] Behavior-first TDD drives the migration and readiness logic before final UI wiring, covering successful JSON-to-relational migration with preserved integer `points`, malformed or unreadable legacy payload handling without partial membership writes, and persisted completion-marker behavior.
- [x] Peak-list memberships persist as relational ObjectBox `PeakListItem` rows linked to `PeakList` and `Peak`, carrying integer `points`, and no new steady-state active behavior reads or writes `PeakList.peakList` JSON after a list migrates successfully.
- [x] App startup triggers the migration once through the existing backfill and migration-marker patterns and remains non-blocking while the migration runs.
- [x] Until migration finishes, membership-dependent surfaces do not fall back to stale JSON-backed reads and instead show deterministic loading or disabled states for peak-list membership actions, `Export Peak Lists`, `Map` peak-list selection surfaces, and other membership-dependent affordances that would otherwise depend on incomplete relational state.
- [x] For each list whose legacy payload migrates successfully, relational `PeakListItem` rows become the only source of truth for membership reads, writes, lookups, exports, and peak-list-derived metadata such as region and stored bounds.
- [x] If a legacy payload is malformed or unreadable, the affected peak-list row remains visible by name and deletable in `My Peak Lists`, add, remove, and edit actions stay blocked for that list, map peak-list selection surfaces omit it, previously selected or pinned unsupported lists reconcile automatically to a supported fallback without blocking navigation, and the app surfaces the existing unsupported-state guidance instructing the user to delete and re-import the list plus a one-time non-blocking warning that some peak lists could not be migrated.
- [x] The migration does not silently drop members, guess missing rows, or create partial migrated lists from malformed legacy payloads.
- [x] Automated coverage uses provider overrides, fakes, or in-memory storage only and proves startup trigger behavior, deterministic readiness states, one-time warning behavior, unsupported legacy handling, and schema alignment without live filesystem, network, or secrets.

## Covers
- User Stories: 4
- Requirements: 2-3, 11-16, 19
- Technical Decisions: 2, 6-7
- Testing Strategy: 1-3, 7, 9-10
- Interview Ledger: L1, L4

## Blocked by
None - completed
