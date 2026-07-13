---
type: Spec
title: Peak List Export CSV Round-Trip Import
---

## Problem

Peak Bagger currently exports peak lists in an app-owned CSV shape that the import flow cannot read back. The current export header also omits `country`, `region`, `county`, `range`, and `sourceOfTruth`, so exported files are not sufficient to recreate missing `Peak` rows safely when the current single-instance, single-user app does not already contain the referenced `osmId` values. That breaks the user's requested round-trip workflow of exporting a peak list file and importing the same format back through the existing peak-list import flow. [L1] [L2] [L3]

## Proposed Outcome

Adopt one shared app-owned peak-list export/import CSV contract for exported peak-list files. Update peak-list export to write the new exact header row and matching peak field values, and add a third header-detected import path in `PeakListImportService` that reads that same format through the existing `Import Peak List` dialog. The new import path must recreate missing peaks from row data, update existing peaks by `osmId`, preserve exported list row order and duplicate memberships, keep the current dialog shell and local loading/error behavior, and use the existing-on-update/default-on-create rule for `PeakList.region`. For this slice, the round-trip contract is defined for the current single-instance, single-user app workflow, including existing local synthetic negative `osmId` values. [L1] [L2] [L3] [L4]

## User Stories

1. As a user on the Peak Lists screen, I can export a peak list and later import that same exported file through `Import Peak List` without manually converting headers or row data first. [L1] [L3]
2. As a user importing an exported peak-list file into an app instance that does not yet contain every listed peak, I can recreate the missing `Peak` rows from the CSV itself so the list still imports successfully. [L2] [L3]
3. As a user updating an existing list from an exported file, I keep the current duplicate-name confirmation, loading spinner, success/failure dialogs, and existing `PeakList.region` value while the list membership and peak metadata are refreshed from the file. [L4]

## Requirements

1. Keep the existing HWC peak-list import path and the existing ranked peak list CSV import path. Add a third header-detected import path for the app-owned peak-list export CSV format; do not replace the other two formats. [L1]
2. Update `PeakListCsvExportService` so the exported header row is exactly this case-sensitive ordered set of CSV columns and the new import path only detects this format when that exact ordered header row is present: [L3]

```text
name,altName,elevation,gridZoneDesignator,mgrs100kId,easting,northing,Points,osmId,country,region,county,range,sourceOfTruth
```

3. The importer must not support the previous 9-column peak-list export header. Files written by the older export contract must fail import rather than being silently treated as the new export format. [L3]
4. Export and import must treat the shared header contract as the source of truth for the fields they exchange. Export must write each column from the matching stored row data, except that it may derive `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` from stored `latitude` and `longitude` when the stored grid-reference fields are blank or invalid. Import must map those same columns back into `Peak` and `PeakListItem` data without introducing a second app-export schema. [L1] [L3]
5. The new export-format import must continue to enter through the current `Import Peak List` dialog and use the user-entered list name. Existing entry, cancel, back-dismiss, duplicate-name confirmation, loading, success, and failure shells must remain intact, including the current dialog titles `Import Peak List`, `Peak List Created`, `Peak List Updated`, and `Peak List Import Failed`. Because this is local file and local database work, no separate offline or slow-network UI is required.
6. While the new import path is running, the current disabled-controls behavior must remain in place: file selection, name entry, cancel, and submit stay disabled and the existing `peak-list-import-progress` loading indicator remains the in-dialog progress state.
7. For each imported row in the new export format, match existing peaks by `osmId`, including current synthetic negative `osmId` values already stored in this single-instance app. If the `osmId` already exists, update that `Peak` from the imported row fields covered by the shared contract. If the `osmId` does not exist, create a new `Peak` from the imported row fields instead of failing or skipping the row. [L2] [L3]
8. When creating a missing peak from the new export format, derive `latitude` and `longitude` from the imported `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` values, because the shared export/import contract does not carry separate lat/lng columns. Fields not present in the shared contract, such as `prominence`, `difficulty`, `viaFerrata`, `notes`, `verified`, and `peakbaggerPid`, must keep current model defaults on newly created peaks.
9. When updating an existing peak from the new export format, align the stored values for `name`, `altName`, `elevation`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `country`, `region`, `county`, `range`, and `sourceOfTruth` to the imported row and recompute `latitude` and `longitude` from the imported grid reference. Peak fields not represented in the shared export/import contract must remain unchanged on existing peaks.
10. The `Points` column in the new shared contract must round-trip exact `PeakListItem.points` values. Import must not normalize those values to ranked-import `points: 1`, must not deduplicate duplicate `osmId` rows, and must preserve row order exactly as exported.
11. Export must continue to preserve the stored order of `PeakListItem` rows inside each file, and the new import path must persist list membership in that same row order. If the exported file contains duplicate memberships for the same `osmId`, import must store them as separate `PeakListItem` rows in file order.
12. When importing the new export format into an existing list name, preserve that existing list's `PeakList.region`. When importing into a new list name, create the list using the current default region. Do not try to infer `PeakList.region` from the imported peak rows. [L4]
13. Export must write `country`, `region`, `county`, `range`, and `sourceOfTruth` columns for every row using stored `Peak` data so the new import path has the data it needs to recreate missing peaks. Blank stored values may still export as blank cells where the underlying model permits them. If a row's stored `gridZoneDesignator`, `mgrs100kId`, `easting`, or `northing` values are blank or invalid, export must derive those four columns from the stored `latitude` and `longitude` before writing the row.
14. Validation for the new export format must be atomic at the file-validation stage. If the header is wrong, a required parse needed to resolve `osmId`, `Points`, or the grid reference fails, or a row cannot be converted into a valid `Peak`/`PeakListItem`, fail the import before any peak or list changes are persisted. The importer must complete full-file validation and build the import plan before the first peak or peak-list write begins.
15. On validation failure for the new export format, continue to surface the existing `Peak List Import Failed` dialog title and show the exact validation message in the dialog body, following the same current behavior used by ranked-import failures.
16. After a failed new-format import, the user must be able to retry through the existing import flow without restarting the app or switching to a different screen.
17. The new export header names are now a durable user-visible file contract. Update any export-focused tests, docs, and status expectations that currently assert the older names such as `Name`, `Alt Name`, `Zone`, `Easting`, and `Northing` so they instead assert the new exact shared contract. [L3]
18. This slice is desktop-only. The new format must not add a second dialog step, a new route, or a separate picker flow.

## Technical Decisions

1. Implement the new export-format importer as a distinct parser/validator branch inside `PeakListImportService`, keyed by exact header detection, rather than weakening the HWC or ranked importers into one permissive mixed parser. [L1] [L3]
2. Treat the shared export/import contract as a coordinated change across `PeakListCsvExportService` and `PeakListImportService`. The new import format is not a standalone parser for the old export files; the export contract itself changes in this slice. [L1] [L3]
3. Reuse existing seams where possible: `PeakListCsvLoader`, `PeakListImportRootLoader`, `PeakListLogWriter`, injectable export file-writer/output-directory seams, in-memory `PeakRepository` and `PeakListRepository` storage, provider-overridden import/export runners, and the existing file-picker and duplicate-name seams. Automated tests should not require real filesystem dialogs, live network calls, or API keys.
4. Use the current MGRS/UTM conversion support already present in the codebase to derive `latitude` and `longitude` for created or updated peaks from the imported grid-reference columns, and to derive export grid-reference columns from stored lat/lng when stored grid fields are blank or invalid, instead of expanding the shared export contract to also carry lat/lng.
5. For this slice, treat existing local synthetic negative `osmId` values as stable identifiers within the current single-instance, single-user app workflow. A future multi-instance design may require a separate stable app-owned identifier or hash.
6. Keep `PeakList.region` as list-owned state rather than deriving it from row-level `Peak.region` values during this import path. Existing list region is preserved on update; default region is used on create. [L4]

## Testing Strategy

1. Use behavior-first TDD for the import/export service logic in vertical slices, starting with service tests before UI wiring.
2. Add focused service coverage for `PeakListCsvExportService` covering:
   1. the new exact shared header row and updated row value mapping
   2. preservation of stored list row order
   3. preservation of duplicate memberships in exported files
   4. export of `country`, `region`, `county`, `range`, and `sourceOfTruth`
   5. derivation of `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` from stored lat/lng when stored grid fields are blank or invalid
3. Add focused service coverage for `PeakListImportService` covering:
   1. exact detection of the new shared export/import header versus the existing HWC and ranked paths [L1] [L3]
   2. updating an existing peak by `osmId`
   3. creating a missing peak from imported row data and derived lat/lng [L2]
   4. atomic failure on old export headers and malformed new-format rows [L3]
   5. exact round-tripping of `Points`, duplicate rows, and row order
   6. full-file validation completes before the first write for the new export format
   7. preserving `PeakList.region` on update and using the default region on create [L4]
4. Extend widget coverage for the existing import dialog and settings/export UI covering:
   1. new-format import through the current dialog shell
   2. existing loading state while a new-format import is in progress
   3. failure presentation through `Peak List Import Failed` for a rejected old-format export file
   4. updated export service assertions that depend on the new shared header contract
5. Extend the existing peak-list robot or journey coverage with at least one successful import of the new export-matching format through the current desktop dialog, using deterministic fake CSV input and the existing stable app-owned selectors. Because journey coverage is in scope, keep selectors stable rather than introducing text-only test targeting.
6. Prefer fake repositories, fake CSV loaders, fake file writers, and provider overrides over live disk or network behavior. Automated tests must not require real file pickers, live filesystem dialogs, network access, or API keys.
7. Expected default split: service tests for parsing/export logic and atomic validation, widget tests for dialog/status behavior, and robot coverage for the critical import journey.

## Out of Scope

1. Supporting the previous 9-column peak-list export header in the new import path. [L3]
2. Changing the existing HWC or ranked peak list CSV contracts beyond adding this third import format. [L1]
3. Expanding the shared export/import contract to include additional `Peak` fields not named in the resolved header, such as `prominence`, `difficulty`, `viaFerrata`, `notes`, `verified`, or `peakbaggerPid`.
4. Adding a new route, wizard, background sync workflow, or alternate file picker just for this format.
5. Supporting multi-instance or multi-user peak identity beyond the current single-instance, single-user workflow.

## Notes

1. Relevant implementation files include `lib/services/peak_list_import_service.dart`, `lib/services/peak_list_csv_export_service.dart`, `lib/providers/peak_list_provider.dart`, `lib/providers/peak_list_csv_export_provider.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/screens/peak_lists_screen.dart`, and `lib/screens/settings_screen.dart`. [L1] [L3] [L4]
2. Relevant automated coverage starting points include `test/services/peak_list_import_service_test.dart`, `test/services/peak_list_csv_export_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/widget/peak_list_csv_export_settings_test.dart`, `test/robot/peaks/peak_lists_journey_test.dart`, and `test/robot/peaks/peak_list_export_journey_test.dart`. [L1] [L2] [L3]
