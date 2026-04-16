---
title: Tasmap reset must read live CSV data
date: 2026-04-16
work_type: bugfix
tags: [tasmap, csv, objectbox]
confidence: high
references:
  - lib/services/csv_importer.dart
  - lib/services/tasmap_repository.dart
  - lib/services/gpx_importer.dart
  - assets/tasmap50k.csv
  - test/csv_importer_test.dart
---

## Summary
Tasmap reset was re-importing from `rootBundle`, so while the app was already running it could keep loading a stale bundled CSV even after the on-disk `assets/tasmap50k.csv` changed. Restarting the app refreshed the asset bundle, which is why the reset appeared to work only after restart.

## Reusable Insights
- If a reset/import flow must reflect edits made during a running dev session, prefer the filesystem copy when it exists and fall back to `rootBundle` only when no file is present.
- Seeing the correct imported count does not prove the right source was read; verify a known changed row in the persisted store, not just the summary message.
- When a bug fixes itself after app restart, check whether startup uses a different source path or cache boundary than the runtime reset path.
- Keep import logging in the repository layer and append to the shared `import.log` path used elsewhere, so reset and startup paths produce consistent diagnostics.

## Decisions
- `CsvImporter.importFromCsv()` now checks `File(csvPath)` first, then falls back to `rootBundle.loadString(csvPath)`.
- A regression test clones the real Tasmap CSV to a temp file, mutates a row, and confirms the importer reads the filesystem copy.

## Pitfalls
- A temporary CSV that does not satisfy the Tasmap parser rules can fail before proving the source-of-truth issue.
- UI refresh work can hide a data-source bug; the persisted ObjectBox row was the real signal here.

## Validation
- `flutter test test/csv_importer_test.dart test/robot/tasmap/tasmap_journey_test.dart test/widget/tasmap_refactor_test.dart`
- `flutter analyze`
