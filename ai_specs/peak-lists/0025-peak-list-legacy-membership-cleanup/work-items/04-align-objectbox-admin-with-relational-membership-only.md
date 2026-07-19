---
type: Work Item
title: Align ObjectBox Admin With Relational Membership Only
parent: ../spec.md
---

## What to build
Update `ObjectBox Admin` peak-list presentation so it uses relational membership data only and no longer exposes raw legacy `peakList` JSON or migration-only membership state. Keep the cleanup scoped to the admin membership presentation, details, and related editing surfaces needed to reflect the final schema rather than redesigning `ObjectBox Admin` beyond that.

## Required context
- `lib/services/objectbox_admin_repository.dart`, `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_details.dart`, and `lib/services/peak_list_admin_editor.dart` are the main admin surfaces that still expose legacy peak-list fields or imply the JSON payload remains authoritative.
- `test/services/objectbox_admin_repository_test.dart`, `test/widget/objectbox_admin_shell_test.dart`, and `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` hold the current deterministic service, widget, and admin journey seams that should be extended rather than replaced.
- `01-remove-legacy-membership-schema-and-cleanup-scaffolding.md` removes the underlying schema fields first; this item should align admin descriptors, details, and presentation with that final model.

## Acceptance criteria
- [x] `ObjectBox Admin` peak-list rows, details, and related presentation use relational membership data as the only membership source of truth.
- [x] Raw legacy `peakList` JSON and removed migration-only membership state are no longer exposed in `ObjectBox Admin` descriptors, details, or editing surfaces.
- [x] Admin presentation continues to support peak-list inspection through relational membership data without changing unrelated admin behavior beyond what is needed for this cleanup.
- [x] Service, widget, and robot regression coverage proves admin peak-list inspection reflects relational membership only and no longer implies the deleted legacy fields exist.

## Covers
- User Stories: 2-3
- Requirements: 5, 8-10
- Technical Decisions: 1-4
- Testing Strategy: 2-5

## Blocked by
- `01-remove-legacy-membership-schema-and-cleanup-scaffolding.md`
