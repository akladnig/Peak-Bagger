---
type: Work Item
title: Remaining App-Owned Membership Consumers Map Reconciliation And Admin Alignment
parent: ../spec.md
---

## What to build
Move the remaining app-owned peak-list membership consumers and integrity paths to the relational source of truth after migration, including membership lookups, peak-reference integrity flows, map peak-list selection and visibility behavior, unsupported-list omission and fallback reconciliation, and ObjectBox Admin peak-list membership presentation. This slice should finish the app-owned read and write paths that still imply `PeakList.peakList` JSON is authoritative for active behavior.

## Required context
- `lib/services/peak_info_content_resolver.dart`, `lib/services/peak_delete_guard.dart`, `lib/services/peak_repository.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/services/peak_list_visibility.dart`, and `lib/widgets/map_peak_lists_drawer.dart` cover the remaining active app-owned membership lookup, integrity, and map-selection paths named in the Spec.
- `ai_specs/peak-lists/0022-objectbox-admin-peak-duplicate-resolution/work-items/01-peak-duplicate-resolution-engine.md` shows the existing duplicate-resolution seam that must consume relational membership lookups instead of legacy JSON-backed rewrites.
- `lib/services/objectbox_admin_repository.dart` is the current ObjectBox Admin presentation layer that still exposes `peakList` JSON as peak-list membership evidence.
- Follow the existing provider and service test conventions in `test/providers/map_peak_list_selection_persistence_test.dart`, `test/services/objectbox_admin_repository_test.dart`, and related in-memory integrity coverage. Do not require live filesystem dialogs, network calls, or secrets.

## Acceptance criteria
- [x] All remaining app-owned membership reads and writes covered by this slice resolve from relational memberships rather than `PeakList.peakList` JSON, including membership lookups, peak-reference integrity paths such as duplicate resolution or peak delete guards, and other active app-owned consumers named in the Spec.
- [x] Membership lookup surfaces such as peak-info continue to preserve their existing user-visible behavior while reading relational membership data.
- [x] Map peak-list selection and visibility surfaces omit unsupported migrated-failure lists, keep supported lists available, and reconcile previously selected or pinned unsupported lists automatically to a supported fallback without blocking navigation.
- [x] Off-screen `Map`-dependent peak-list state does not force synchronous mutation waiting, and `Export Peak Lists` does not trigger unrelated map refresh work through these remaining membership consumers.
- [x] ObjectBox Admin peak-list membership presentation reflects the relational source of truth and no longer implies `PeakList.peakList` JSON remains authoritative after migration.
- [x] Provider, service, and widget coverage proves the relational read paths across integrity and map-selection flows, unsupported-list omission and fallback reconciliation, and admin presentation alignment using existing fakes or in-memory seams only.

## Covers
- User Stories: 1, 4
- Requirements: 3, 8-10, 15, 18-20
- Technical Decisions: 2, 4, 6
- Testing Strategy: 3, 6, 9-10
- Interview Ledger: L1, L3-L4

## Blocked by
- `01-relational-peak-list-membership-startup-migration-and-readiness.md`
