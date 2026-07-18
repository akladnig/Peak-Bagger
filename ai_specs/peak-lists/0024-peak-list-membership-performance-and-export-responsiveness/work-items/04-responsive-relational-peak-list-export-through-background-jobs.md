---
type: Work Item
title: Responsive Relational Peak List Export Through Background Jobs
parent: ../spec.md
---

## What to build
Keep the existing `Settings` entry point and `Background job` workflow for `Export Peak Lists`, but move export execution onto the relational membership source of truth with a responsive handoff that does not freeze `Settings` or shell navigation. Preserve the existing CSV column set, warning semantics, and destination behavior while exporting supported lists only, skipping unsupported migrated-failure lists as warnings, processing peak-list files alphabetically by peak-list name, and sorting rows within each exported CSV by peak name ascending with `Peak.osmId` ascending as the deterministic secondary key.

## Required context
- `lib/screens/settings_screen.dart`, `lib/providers/peak_list_csv_export_provider.dart`, `lib/providers/background_jobs_provider.dart`, and `lib/services/peak_list_csv_export_service.dart` are the current `Export Peak Lists` handoff, progress, and execution seams.
- `ai_specs/peak-lists/0011-background-jobs-import-export-progress/spec.md` and `ai_specs/peak-lists/0011-background-jobs-import-export-progress/work-items/04-settings-export-background-jobs-for-peak-data-and-peak-lists.md` define the existing `Background job` contract and progress semantics this item must preserve.
- `test/services/peak_list_csv_export_service_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, and `test/robot/peaks/peak_list_export_journey_test.dart` are the current deterministic service, widget, and cross-shell export coverage seams.
- Reuse fake file writers, provider overrides, deterministic progress callbacks, and robot selectors already used by the existing export coverage. Do not require live filesystem dialogs, network calls, or secrets.

## Acceptance criteria
- [x] Starting `Export Peak Lists` returns control to the app immediately, with the started snackbar and jobs entry appearing within about 250 ms, while `Settings` remains responsive and the user can still navigate between shell destinations during the in-app export.
- [x] The flow preserves the existing `Background job` contract from `ai_specs/peak-lists/0011-background-jobs-import-export-progress/spec.md`, including in-app-only execution, no user cancellation, and no new promise of OS-level background execution.
- [x] Running export continues to report real `files completed / total lists` progress plus the current file's `rows written / total rows` through `Background Jobs` while shell interaction remains responsive.
- [x] Peak-list export resolves membership from relational `PeakListItem` rows rather than decoding `PeakList.peakList` JSON blobs and preserves the existing CSV column set, warning semantics, and destination behavior.
- [x] Export processes peak-list files alphabetically by peak-list name, and rows within each exported CSV are sorted by peak name ascending with `Peak.osmId` ascending as the deterministic secondary key.
- [x] When unsupported migrated-failure lists exist, export supported lists only, skip unsupported affected lists, and report those skips through the existing warning and completion semantics rather than failing the whole export job.
- [x] `Export Peak Lists` does not trigger unrelated map refresh work.
- [x] Deterministic service, provider, and widget coverage proves immediate handoff, durable `Background job` progress updates, supported-list-only warning-bearing completion, and required sorting; if service and widget coverage alone cannot safely prove the cross-shell responsiveness contract, extend the robot journey using stable selectors and deterministic export seams.

## Covers
- User Stories: 3
- Requirements: 1, 6-7, 10, 17-18
- Technical Decisions: 1-5
- Testing Strategy: 3, 5, 8, 11
- Interview Ledger: L1-L2, L4

## Blocked by
- `01-relational-peak-list-membership-startup-migration-and-readiness.md`
