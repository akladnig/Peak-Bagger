---
title: Settings Peak CSV Export
date: 2026-05-03
work_type: feature
tags: [flutter, riverpod, csv, testing]
confidence: high
references: [ai_specs/settings/csv-export-spec.md, ai_specs/settings/csv-export-plan.md, lib/screens/settings_screen.dart, lib/providers/peak_csv_export_provider.dart, lib/services/peak_csv_export_service.dart, test/services/peak_csv_export_service_test.dart, test/widget/peak_csv_export_settings_test.dart]
---

## Summary

Added a Settings action that exports ObjectBox `Peak` rows to `/Users/adrian/Documents/Bushwalking/Features/peaks.csv`.

The implementation stayed small: one export service, one Riverpod runner seam for widgets, and one Settings tile with async status feedback.

## Reusable Insights

- Use a runner-provider seam for widget injection when the UI only needs one callable async action. `peakCsvExportRunnerProvider` mirrored the existing `peakListImportRunnerProvider` pattern and kept widget tests simple.
- Keep the service pure-ish: repository in, file writer out. A small `PeakCsvFileWriter` seam let the service test write to a temp dir without touching the real macOS export path.
- When a screen already has shared status text, give each flow its own key. A small `_statusKey` field avoided breaking existing `peak-refresh-status` assertions while adding `peak-export-status`.
- If a new action can affect other async actions on the same screen, disable both sides explicitly. Here, export and refresh both gate each other via `onTap: null`.
- Long Settings lists can hide new actions below existing robot/test anchors. Place the new tile carefully and make widget tests scroll to it by key.
- For CSV exports, use the `csv` package and assert on parsed rows, not raw concatenation. That avoids brittle escaping assumptions and makes blank-cell behavior explicit.

## Decisions

- Export order follows `PeakRepository.getAllPeaks()` instead of sorting. That kept the implementation aligned with the spec and avoided mutating repository results.
- The export file name is fixed: `peaks.csv`.
- Failure handling is visible in the Settings status area; no dialog or save picker.

## Pitfalls

- `csv` conversion does not guarantee a trailing newline. Tests should verify line endings and rows, not require an ending newline.
- Widget tests may need `scrollUntilVisible` for long Settings screens.
- Full-suite runs can include noisy `RootUnavailable` messages from unrelated robot tests; rely on pass/fail, not log noise.

## Validation

- `flutter test test/services/peak_csv_export_service_test.dart`
- `flutter test test/widget/peak_refresh_settings_test.dart test/widget/peak_csv_export_settings_test.dart`
- `flutter test`
- `flutter analyze`
