---
type: Work Item
title: Settings Export Background Jobs for Peak Data and Peak Lists
parent: ../spec.md
---

## What to build
Move `Export Peak Data` and `Export Peak Lists` from Settings-owned progress text into `Background Jobs` while keeping the existing Settings entry points. Each accepted export must hand off immediately to the shared jobs system, keep the user free to leave `Settings`, report real progress in the exact required units, and finish with durable panel entries plus snackbar messaging instead of Settings-only progress ownership.

## Required context
- `lib/screens/settings_screen.dart` currently owns export busy flags and status text for both export flows. This item must remove export-progress ownership from that screen after accepted start rather than keeping Settings as the long-term live progress surface.
- `lib/providers/peak_csv_export_provider.dart`, `lib/providers/peak_list_csv_export_provider.dart`, `lib/services/peak_csv_export_service.dart`, and `lib/services/peak_list_csv_export_service.dart` are the existing seams for export execution, result summaries, and fake file-writer coverage.
- `PeakCsvExportService` currently returns final `path` and `exportedCount`, while `PeakListCsvExportService` returns file-count and warning/skip summaries. Extend seams only where needed so progress can be emitted deterministically without replacing the underlying export services.
- Existing coverage starts in `test/services/peak_csv_export_service_test.dart`, `test/services/peak_list_csv_export_service_test.dart`, `test/widget/peak_csv_export_settings_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, and `test/robot/peaks/peak_list_export_journey_test.dart`.
- Preserve deterministic fake writers, provider overrides, and local-only test execution; do not require live filesystem dialogs, network calls, or secrets.

## Acceptance criteria
- [ ] After the user starts `Export Peak Data` or `Export Peak Lists`, the flow hands off immediately to a running background job, keeps the user free to remain on or leave `Settings`, and shows lightweight started messaging with `Open Jobs`.
- [ ] Ongoing export progress ownership moves to `Background Jobs` rather than the Settings status area.
- [ ] `Export Peak Data` reports real `rows written / total peaks` progress for the generated `peaks.csv` file.
- [ ] `Export Peak Lists` reports real `files completed / total lists` progress plus the current file's `rows written / total rows` while that file is being written.
- [ ] Successful export completion does not auto-navigate anywhere and uses snackbar messaging with `Export complete`, a short counts summary, and `Open Jobs`; failed exports use `Export failed`, the first error summary, and `Open Jobs`.
- [ ] Peak-data export completion details in the jobs panel show rows written and destination path.
- [ ] Peak-list export completion details in the jobs panel show files written, skipped lists, skipped rows, warnings, and destination directory.
- [ ] Jobs that finish with warnings, skipped lists, skipped rows, or other recoverable per-file/per-row issues remain `completed` with warning details rather than being promoted to `failed`.
- [ ] Focused service/notifier coverage proves deterministic progress seams and preserved final export summaries, and widget coverage proves Settings handoff away from Settings-only status ownership without real file dialogs or live filesystem dependencies.

## Covers
- User Stories: 2, 4
- Requirements: 1-2, 7, 11-18
- Technical Decisions: 2-5
- Testing Strategy: 3.3-3.4, 4.4-4.6, 6
- Interview Ledger: L1-L2, L5, L8-L10, L14-L15

## Blocked by
- `01-shared-background-jobs-shell-controller-and-recovery.md`
