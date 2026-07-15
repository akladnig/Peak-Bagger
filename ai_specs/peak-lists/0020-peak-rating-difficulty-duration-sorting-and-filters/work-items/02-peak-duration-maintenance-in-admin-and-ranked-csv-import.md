---
type: Work Item
title: Peak Duration Maintenance In Admin And Ranked CSV Import
parent: ../spec.md
---

## What to build

Add `Peak duration` maintenance to the existing app-owned metadata flows. The dedicated ObjectBox Admin peak details editor must let an admin edit the human-readable `durationLabel` and auto-derive `durationMinutes` from it, while ranked peak-list CSV import must accept an optional `duration` column and update both stored duration fields when present. Invalid imported duration values must fail the import with clear row-level errors matching the project's existing rating-import failure style, and existing peaks with no duration must remain valid and blank until populated.

## Required context

- `lib/screens/objectbox_admin_screen_details.dart` currently owns the dedicated `Peak` editor UI, and `lib/services/peak_admin_editor.dart` plus `test/services/peak_admin_editor_test.dart` own its normalization and validation rules.
- `lib/services/objectbox_admin_repository.dart` and `test/services/objectbox_admin_repository_test.dart` already expose generic admin/schema row mapping for `Peak` fields. Keep the dedicated editor aligned with those generic surfaces.
- `lib/services/peak_list_import_service.dart` currently enforces exact ranked CSV headers and row-level failure semantics. Reuse `_rankedPeakListHeaders`, `_parseRankedRating`, `_applyRankedRow`, and the existing row-numbered `FormatException` style rather than introducing a new import error pattern.
- `test/services/peak_list_import_service_test.dart` already contains deterministic ranked CSV import coverage for metadata updates and invalid `rating` failures. Extend that suite with the new `duration` contract.
- Reuse the shared duration parsing logic from `01-peak-duration-persistence-and-shared-metadata-rules.md` rather than duplicating parsing in admin or import code paths.

## Acceptance criteria

- [ ] The dedicated ObjectBox Admin `Peak` editor exposes editable `Peak duration` input through the human-readable label field and auto-derives `durationMinutes` from the entered label before submit.
- [ ] The dedicated ObjectBox Admin `Peak` editor preserves blank `Peak duration` values as valid input, leaving existing peaks without duration valid and blank until populated.
- [ ] The dedicated ObjectBox Admin `Peak` editor uses the shared duration parsing rules and rejects unsupported duration text clearly instead of saving partial or mismatched duration data.
- [ ] Generic admin/schema tooling continues to inspect both duration fields after dedicated-editor changes.
- [ ] Ranked peak-list CSV import accepts an optional `duration` column and updates both stored duration fields when a row provides a duration value.
- [ ] Ranked peak-list CSV import leaves existing stored duration values unchanged when the optional `duration` column is absent or the row's `duration` cell is blank.
- [ ] Ranked peak-list CSV import uses the shared duration parsing rules and fails invalid duration values atomically with clear row-level errors matching the existing invalid `rating` import style.
- [ ] Invalid imported duration text is not silently coerced into partial data.
- [ ] This slice does not auto-derive `Peak duration` from ascent history, route timing, live ETA, external routing services, or other non-persisted runtime calculations.
- [ ] Targeted coverage in `test/services/peak_list_import_service_test.dart`, `test/services/objectbox_admin_repository_test.dart`, `test/services/objectbox_schema_guard_test.dart`, and directly affected admin-editor or peak-model tests proves duration persistence, round-trip behavior, blank handling, valid exact durations, valid ranges, and invalid row-level import failures.

## Covers

- User Stories: 4
- Requirements: 2-3, 20-22
- Technical Decisions: 1-2, 6
- Testing Strategy: 2
- Interview Ledger: L2, L7

## Blocked by

- `01-peak-duration-persistence-and-shared-metadata-rules.md`
