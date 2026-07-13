---
type: Work Item
title: Shared Peak List Export CSV Contract
parent: ../spec.md
---

## What to build

Update `PeakListCsvExportService` and the existing export-facing test and settings surfaces so peak-list exports use the new exact app-owned CSV contract `name,altName,elevation,gridZoneDesignator,mgrs100kId,easting,northing,Points,osmId,country,region,county,range,sourceOfTruth`. Keep stored `PeakListItem` row order and duplicate memberships unchanged in exported files, export the additional `Peak` metadata needed for round-trip import, and derive `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` from stored `latitude` and `longitude` when stored grid-reference fields are blank or invalid.

## Required context

- `lib/services/peak_list_csv_export_service.dart` is the export seam that currently writes the old header and row shape. Keep the existing output-directory and file-writer seams instead of introducing a second export path.
- Reuse the existing MGRS conversion behavior already present in `lib/services/peak_mgrs_converter.dart` and the lat/lng-to-grid update path in `lib/services/peak_admin_editor.dart` so export derivation follows existing formatting semantics rather than inventing a parallel formatter.
- `lib/models/peak.dart` allows stored peaks with blank `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing`, so this item must cover the export-side derivation rule explicitly.
- Existing export-facing coverage starts in `test/services/peak_list_csv_export_service_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, and `test/robot/peaks/peak_list_export_journey_test.dart`. Keep deterministic fake file writers and stable app-owned selectors; do not require live filesystem dialogs or network access.

## Acceptance criteria

- [ ] `PeakListCsvExportService` writes the exact case-sensitive ordered header `name,altName,elevation,gridZoneDesignator,mgrs100kId,easting,northing,Points,osmId,country,region,county,range,sourceOfTruth` and no longer writes the previous export header names such as `Name`, `Alt Name`, `Zone`, `Easting`, or `Northing`.
- [ ] Each exported row writes `name`, `altName`, `elevation`, `Points`, `osmId`, `country`, `region`, `county`, `range`, and `sourceOfTruth` from the matching stored `Peak` and `PeakListItem` data using the shared contract as the only app-owned export schema for this flow.
- [ ] Export preserves the stored order of `PeakListItem` rows in each file and preserves duplicate memberships for the same `osmId` as separate exported rows in file order.
- [ ] When a row's stored `gridZoneDesignator`, `mgrs100kId`, `easting`, or `northing` are blank or invalid, export derives those four values from the stored `latitude` and `longitude` using the existing MGRS conversion support already used elsewhere in the app.
- [ ] Export-focused tests, docs, and status expectations that currently assert the older export header contract are updated to assert the new exact shared contract instead.
- [ ] Focused service tests cover the exact new header row, row value mapping for the added columns, preservation of stored row order, preservation of duplicate memberships, and derivation of grid-reference columns from stored lat/lng when stored grid fields are blank or invalid.
- [ ] Existing export widget and robot coverage stays deterministic and continues to use provider overrides, fake file-writing seams, and stable app-owned selectors while updating assertions that depend on the export contract.

## Covers

- User Stories: 1-2
- Requirements: 2, 4, 10-11, 13, 17
- Technical Decisions: 2-4
- Testing Strategy: 1-2, 4.4, 6-7
- Interview Ledger: L3

## Blocked by

None - ready to start
