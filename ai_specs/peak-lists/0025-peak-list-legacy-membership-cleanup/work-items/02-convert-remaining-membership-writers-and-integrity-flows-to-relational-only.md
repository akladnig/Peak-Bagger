---
type: Work Item
title: Convert Remaining Membership Writers And Integrity Flows To Relational Only
parent: ../spec.md
---

## What to build
Finish the remaining non-UI membership producer and integrity flows on the relational source of truth only. This includes import, `Tassy Full` maintenance, duplicate-resolution or peak-reference rewrite paths, delete guards, and any remaining service-level membership lookups or mutations that still encode, decode, or preserve legacy `PeakList.peakList` JSON for active behavior.

## Required context
- `lib/services/peak_list_import_service.dart`, `lib/services/tassy_full_peak_list_sync_service.dart`, `lib/services/peak_repository.dart`, and `lib/services/peak_delete_guard.dart` are the main remaining write and integrity surfaces called out by the Spec.
- `lib/services/peak_list_repository.dart` should already expose the relational-only contract from `01-remove-legacy-membership-schema-and-cleanup-scaffolding.md`; this item should consume that final contract rather than reintroducing compatibility helpers.
- `ai_specs/peak-lists/0022-objectbox-admin-peak-duplicate-resolution/work-items/01-peak-duplicate-resolution-engine.md` is relevant context for the duplicate-resolution seam that must stop rewriting list membership through legacy JSON payloads.
- Follow existing in-memory repository, fake storage, and service injection patterns in `test/services/peak_list_repository_test.dart`, `test/services/peak_delete_guard_test.dart`, `test/services/peak_list_coverage_backfill_service_test.dart`, and related integrity tests.

## Acceptance criteria
- [x] Import flows create and update membership using relational membership rows only and do not encode or persist legacy `PeakList.peakList` JSON for active behavior.
- [x] `Tassy Full` maintenance reads and writes membership from the relational source of truth only while preserving the existing user-visible maintenance outcome and labels.
- [x] Duplicate-resolution, OSM id rewrite, and other peak-reference integrity flows stop decoding or rewriting legacy membership JSON and instead operate only on relational membership data.
- [x] Peak delete guards and related membership-derived integrity checks resolve dependencies from relational membership only.
- [x] Repository and service-level membership lookups covered by this slice no longer depend on removed JSON helpers or legacy fields.
- [x] Service regression coverage proves import, `Tassy Full` maintenance, duplicate-resolution, and delete-guard behavior still work using only relational membership data and deterministic existing seams.

## Covers
- User Stories: 1-2
- Requirements: 4-5, 10
- Technical Decisions: 1-4
- Testing Strategy: 1-2, 5

## Blocked by
- `01-remove-legacy-membership-schema-and-cleanup-scaffolding.md`
