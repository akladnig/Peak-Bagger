---
type: Work Item
title: Expanded App-Owned Export CSV Contract And Coverage
parent: ../spec.md
---

## What to build

Replace the previous app-owned export contract in `PeakListCsvExportService` with this exact case-sensitive ordered header only:

```text
name,altName,elevation,prominence,rating,difficulty,duration,viaFerrata,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,peakbaggerPid,country,region,county,range,notes,verified,sourceOfTruth
```

Update export row generation to round-trip the expanded app-owned metadata surface needed for full peak maintenance, while keeping the existing export entry surfaces, preserving stored `PeakListItem` row order and duplicate memberships exactly, and deriving MGRS fields from stored latitude/longitude whenever stored grid-reference fields are blank or invalid.

## Required context

- `lib/services/peak_list_csv_export_service.dart` is the only app-owned export seam. Keep its existing output-directory, file-writer, and background-job integration points instead of adding a second export path.
- Reuse shared duration logic from `lib/services/peak_metadata_rules.dart` for canonical fallback duration text when `durationLabel` is blank.
- Reuse existing MGRS conversion support in `lib/services/peak_mgrs_converter.dart` so derived `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` match current app formatting rules.
- `PeakListCsvExportService.csvHeaders` is already reused by service, widget, and robot helpers. Update that shared seam once and keep downstream tests deterministic.
- Existing export-facing coverage starts in `test/services/peak_list_csv_export_service_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, and `test/robot/peaks/peak_list_export_journey_test.dart`. Keep stable selectors and fake file seams unchanged.

## Acceptance criteria

- [x] `PeakListCsvExportService` writes the exact case-sensitive ordered header `name,altName,elevation,prominence,rating,difficulty,duration,viaFerrata,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,peakbaggerPid,country,region,county,range,notes,verified,sourceOfTruth` and no longer writes the previous app-owned header or the older `Points` column spelling.
- [x] Each exported row writes `points` and `osmId` for every row from stored `PeakListItem` membership data and matching `Peak` identity data, preserving duplicate rows and stored row order exactly as persisted.
- [x] Export includes the added app-owned metadata fields `prominence`, `rating`, `difficulty`, `duration`, `viaFerrata`, `peakbaggerPid`, `notes`, and `verified` in the exact contract positions without adding any new export flow, route, or dialog step.
- [x] Export writes `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` for every row, deriving those values from stored latitude/longitude when the stored grid-reference fields are blank or invalid.
- [x] Export writes `duration` as the exact stored `durationLabel` when that label is non-blank, derives parser-safe `H:MM` output for sub-day `durationMinutes` when the label is blank, derives `1 day` or `<int> days` for exact whole-day `durationMinutes` when the label is blank, and writes blank only when both stored duration fields are absent or blank.
- [x] Export writes `rating` with exactly one decimal place when present, such as `4.0` or `4.4`, and writes blank when absent.
- [x] Export writes `verified` as exact lowercase `true` or `false`, `peakbaggerPid` as a plain integer string when present and blank when absent, and `sourceOfTruth` as the exact stored value.
- [x] Existing export widget, settings, and journey coverage that asserts app-owned CSV content is updated to the new exact contract while keeping the current background-job UI, selectors, and deterministic fake file seams unchanged.
- [x] Behavior-first TDD extends focused export service coverage before export call-site assertions are updated, including the exact new header, exact field ordering, added metadata columns, one-decimal `rating` output, canonical derived `duration` output, duplicate-row preservation, row-order preservation, and derived grid-reference output.

## Covers

- User Stories: 1, 3
- Requirements: 2, 5-7, 9, 13, 16-21
- Technical Decisions: 1, 3-4
- Testing Strategy: 1, 4, 6-7
- Interview Ledger: L1, L3, L4, L6-L10

## Blocked by

- `01-shared-peak-duration-exact-day-parsing-and-admin-validation.md`
