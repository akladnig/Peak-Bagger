---
type: Work Item
title: Export Complete Peak CSV Schema
parent: ../spec.md
---

## What to build

Update `PeakCsvExportService` as the single CSV output-shape boundary so `Export Peak Data` writes every declared scalar ObjectBox `Peak` property, including `id`, in the exact specified order. Extend the existing service unit tests and retain the Settings export widget journey to verify the unchanged background-job experience.

## Required context

- `lib/models/peak.dart` defines the 25 scalar `Peak` fields; no ObjectBox relation fields exist.
- `lib/services/peak_csv_export_service.dart` owns the ordered CSV headers and row mapping. Retain its `CsvEncoder`, fixed `peaks.csv` filename, configured destination directory, overwrite behavior, and progress reporting.
- `test/services/peak_csv_export_service_test.dart` uses `InMemoryPeakStorage`, a temporary output directory, and `CsvDecoder`; do not write to the macOS production export path.
- `test/widget/peak_csv_export_settings_test.dart` overrides `peakCsvExportBackgroundRunnerProvider` to cover Settings loading, completion, and failure states. Preserve that deterministic seam and its existing stable keys.

## Acceptance criteria

- [x] Extend `PeakCsvExportService` unit tests first, then update the implementation to satisfy them.
- [x] `peaks.csv` has these exact headers in this exact order: `id`, `osmId`, `peakbaggerPid`, `name`, `altName`, `elevation`, `prominence`, `country`, `county`, `range`, `rating`, `durationMinutes`, `durationLabel`, `difficulty`, `viaFerrata`, `notes`, `latitude`, `longitude`, `region`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `verified`, `sourceOfTruth`.
- [x] Every exported data row places each declared scalar `Peak` value, including ObjectBox `id`, under its matching header; no legacy title-cased or duplicate columns remain.
- [x] Absent `peakbaggerPid`, `elevation`, `prominence`, `rating`, `durationMinutes`, and `region` values produce blank cells at their corresponding column indices.
- [x] Non-null CSV values retain existing `CsvEncoder` quoting and escaping for commas, quotes, and line breaks, and repository-provided peak order is preserved.
- [x] The export retains the `peaks.csv` filename, configured destination directory, overwrite behavior, header-only output for an empty repository, and row progress events.
- [x] The existing Settings widget export journey, using its `peakCsvExportBackgroundRunnerProvider` override, continues to show immediate `Export started` feedback, background-job progress, completion details, and failure visibility without changing the Settings entry, routes, copy, job labels, retry behavior, or scheduling.
- [x] `flutter test test/services/peak_csv_export_service_test.dart test/widget/peak_csv_export_settings_test.dart` and `flutter analyze` pass.

## Covers

- User Stories: 1-2
- Requirements: 1-6
- Technical Decisions: 1-3
- Testing Strategy: 1-5
- Interview Ledger: L1-L2

## Blocked by

None - ready to start
