---
type: Spec
title: Export Peak Data Complete Entity Schema
---

## Problem

Settings `Export Peak Data` writes only a subset of ObjectBox `Peak` properties to `peaks.csv`, so exported data cannot represent each stored peak record completely.

## Proposed Outcome

The existing Settings export produces a complete, schema-aligned CSV representation of every stored `Peak`, including the ObjectBox `id`, without changing the export entry point or its background-job experience.

## User Stories

1. As a maintainer, I can export every stored `Peak` property so the CSV is a complete record extract rather than a partial report.
2. As a Settings user, I retain the existing export progress, completion, and failure feedback while the expanded CSV is written.

## Requirements

1. `Export Peak Data` must export all declared scalar properties of each ObjectBox `Peak`, including the internal `id`. [L1]
2. The CSV must use these exact headers, in this exact order: `id`, `osmId`, `peakbaggerPid`, `name`, `altName`, `elevation`, `prominence`, `country`, `county`, `range`, `rating`, `durationMinutes`, `durationLabel`, `difficulty`, `viaFerrata`, `notes`, `latitude`, `longitude`, `region`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `verified`, `sourceOfTruth`. [L2]
3. Each data row must place values under its matching header. Nullable `Peak` values (`peakbaggerPid`, `elevation`, `prominence`, `rating`, `durationMinutes`, and `region`) must produce blank CSV cells when absent. [L1]
4. Non-null values must retain the existing CSV encoder behavior, including quoting and escaping text containing commas, quotes, or line breaks.
5. Preserve the repository-provided peak order, fixed `peaks.csv` filename, configured destination directory, overwrite behavior, and header-only output for an empty repository.
6. Preserve the existing Settings `Export Peak Data` entry, immediate `Export started` feedback, background-job progress, completion details, and failure visibility. [L2]

## Technical Decisions

1. Update `PeakCsvExportService` as the single output-shape boundary; keep `SettingsScreen`, `peakCsvExportBackgroundRunnerProvider`, and their existing asynchronous job lifecycle unchanged. [L2]
2. Represent the complete current entity schema with the explicit ordered header and row mapping in the export service. The entity has no declared ObjectBox relation fields to export.
3. This intentionally replaces the previous 12-column title-cased header contract; do not retain a compatibility mode or duplicate legacy columns. [L2]

## Testing Strategy

1. Extend the existing `PeakCsvExportService` unit tests first to verify the exact 25-column header order, a fully populated row that covers every field including `id`, and a second row with each nullable field absent that has blank cells at the corresponding column indices. [L1] [L2]
2. Continue parsing exported output with `CsvDecoder` and use the existing in-memory `PeakRepository` plus temporary output directory seam; tests must not write to the macOS production export path.
3. Retain coverage for repository order, escaping, empty header-only overwrite behavior, and progress events.
4. Run the existing Settings widget export journey using its `peakCsvExportBackgroundRunnerProvider` override to confirm unchanged loading, completion, and failure states. No new robot journey is required because the Settings interaction contract does not change.
5. Verify with `flutter test test/services/peak_csv_export_service_test.dart test/widget/peak_csv_export_settings_test.dart` and `flutter analyze`.

## Out of Scope

- Importing the expanded CSV or making it round-trip compatible with another import format.
- Exporting data from related entities such as `PeakList` or tracks.
- Changing the destination path, filename, export UI copy, job labels, retry behavior, or export scheduling.
