---
type: Spec
title: App-Owned Export CSV Metadata Expansion
---

## Problem

The current app-owned export/import CSV contract is too narrow for full round-trip peak maintenance. It omits `prominence`, `rating`, `difficulty`, `duration`, `viaFerrata`, `notes`, `verified`, and `peakbaggerPid`, still uses the older `Points` column spelling, and does not define field-specific blank-value override rules for a full source-of-truth reimport workflow. That leaves the export format unable to act as the single deterministic maintenance file for the peak metadata the project now stores and uses. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10]

## Proposed Outcome

Replace the previous app-owned export/import CSV contract with one expanded exact header that round-trips the app-owned peak metadata needed for full peak-list maintenance. Update the existing app-owned export path to write that exact contract, update the existing app-owned import path to detect only that exact contract, and align import validation, blank-preserves-existing behavior for existing peaks, rating normalization, and shared duration parsing with the new file contract. This remains an update to the existing peak-list export/import workflow rather than a new UI flow or a new independent importer. This Spec supersedes the app-owned export/import CSV contract defined in `ai_specs/peak-lists/0010-peak-list-export-csv-round-trip-import/spec.md`. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10]

## User Stories

1. As a user maintaining peak-list files through Peak Bagger's existing export/import flow, I can export an app-owned peak-list CSV and later re-import that same file as the full source of truth for the peak metadata the file carries. [L1] [L2] [L6]
2. As a user correcting peak metadata through an app-owned export CSV, I can leave cells blank without accidentally clearing existing stored peak metadata during re-import. [L2] [L3] [L7] [L8] [L9]
3. As a user round-tripping richer peak metadata, I can export and re-import `prominence`, `rating`, `difficulty`, `duration`, `viaFerrata`, `notes`, `verified`, and `peakbaggerPid` without switching to a separate admin-only maintenance path. [L3] [L4] [L5] [L6] [L7] [L8] [L9]

## Requirements

1. Keep the existing HWC peak-list import path and the existing ranked peak-list CSV import path. Continue using a distinct header-detected app-owned import path, but update that app-owned path to support only the new expanded app-owned contract. [L1]
2. The app-owned export/import CSV header must be matched exactly, case-sensitively, and in this exact ordered sequence: [L1]

```text
name,altName,elevation,prominence,rating,difficulty,duration,viaFerrata,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,peakbaggerPid,country,region,county,range,notes,verified,sourceOfTruth
```

3. The previous app-owned export header must no longer be accepted by the app-owned importer. The importer must not accept aliases such as `Points`, partial subsets, reordered columns, or mixed old/new app-owned shapes. [L1]
4. The app-owned export/import CSV is authoritative for the non-blank values it carries. During app-owned import, blank values preserve the existing stored value for existing peaks, while newly created peaks still use normal model defaults for fields left blank in the CSV. [L2]
5. `points` and `osmId` remain required row identity/list-membership fields in the app-owned contract. App-owned export must always write them, and app-owned import must fail atomically on blank or invalid values rather than inventing clear/default semantics for those fields. [L10]
6. App-owned export and import must continue to enter through the existing peak-list export surfaces and the existing `Import Peak List` dialog. This change must not add a new route, a second dialog step, or a separate picker flow.
7. App-owned export must continue to preserve `PeakListItem` row order and duplicate memberships exactly as stored, and app-owned import must continue to preserve duplicate rows and file order exactly as written in the CSV.
8. App-owned import must still match existing peaks by `osmId`, including synthetic negative `osmId` values already used locally. If a row references an existing `osmId`, update that peak from the app-owned row data. If a row references an unknown `osmId`, create a new `Peak` from the row data and the derived coordinates.
9. App-owned export must continue to write `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing` for every row, deriving those values from stored latitude/longitude when the stored grid-reference fields are blank or invalid. App-owned import must continue to derive `latitude` and `longitude` from the imported grid-reference fields for created or updated peaks.
10. For newly created peaks in the app-owned import path, `name` is required. If a row that would create a new peak has a blank `name`, fail the import atomically before any peak or list writes occur. [L11]
11. For newly created peaks in the app-owned import path, blank `region` must fall back to the row's `country` value. If both `region` and `country` are blank on a row that would create a new peak, fail the import atomically before any peak or list writes occur. [L11]
12. For nullable numeric columns in the app-owned contract, non-blank cells override the stored value after validation, while blank cells preserve the existing stored value for existing peaks and fall back to normal model defaults on newly created peaks. This includes `elevation`, `prominence`, `rating`, and `peakbaggerPid`, subject to each field's additional validation rules. [L2] [L4] [L6] [L9]
13. `rating` must accept only numeric values from `0` through `5` inclusive when non-blank, must normalize to one decimal place before save, and must export with exactly one decimal place when present, such as `4.0` or `4.4`. Blank `rating` preserves the existing stored value for existing peaks and leaves newly created peaks unrated. Invalid or out-of-range non-blank values must fail the import atomically with a clear row-level validation error. [L4]
14. `difficulty`, `viaFerrata`, `country`, `region`, `county`, `range`, `notes`, `name`, and `altName` must round-trip as trimmed string data. Non-blank values replace the stored value after trimming. Blank values preserve the existing stored value for existing peaks and fall back to normal model defaults on newly created peaks, except for the explicit created-peak `name` and `region` rules above. App-owned import must not add a new allowlist validator for `difficulty` in this change. [L2] [L5] [L6] [L11]
15. `duration` must round-trip through the shared `Peak duration` parsing logic. Blank `duration` preserves the existing stored `durationLabel` and `durationMinutes` for existing peaks and leaves newly created peaks with blank duration fields. Non-blank `duration` must accept these parser-supported forms: `H:MM`, `<int>-<int> hour(s)`, `<int>-<int> day(s)`, `<int> day`, and `<int> days`. Unsupported non-blank values must fail import atomically with a clear row-level validation error. The shared parser expansion in this Spec also applies to the dedicated ObjectBox Admin peak editor because it already reuses the same `Peak duration` parsing logic. [L2] [L3]
16. App-owned export must write `duration` as the exact stored `durationLabel` when that label is non-blank. When `durationLabel` is blank but `durationMinutes` is present, export must derive a parser-safe canonical value: `H:MM` for sub-day durations and `<int> day` or `<int> days` for exact whole-day durations. Export must write blank `duration` only when both stored duration fields are absent/blank. [L3]
17. `verified` must export as exact lowercase `true` or `false`. App-owned import must accept only `true`, `false`, or blank for `verified`. Blank preserves the existing stored value for existing peaks and leaves newly created peaks at the model default `false`. Any other non-blank value must fail import atomically. [L7]
18. `sourceOfTruth` must export as the exact stored value. During app-owned import, blank `sourceOfTruth` preserves the existing stored value for existing peaks and leaves newly created peaks at the model default `OSM`. Non-blank values must be trimmed and stored exactly as provided. This change must not add a new global allowlist validator for app-owned `sourceOfTruth` values. [L8]
19. `peakbaggerPid` must export as a plain integer string when present and blank when absent. During app-owned import, blank preserves the existing stored `peakbaggerPid` for existing peaks and leaves newly created peaks with `null`. The only valid non-blank values are positive integers. `0`, negative integers, and non-integer text must fail import atomically. [L9]
20. `prominence` must participate in the app-owned round-trip contract as nullable numeric data. Blank `prominence` preserves the existing stored value for existing peaks and leaves newly created peaks with `null`, and invalid non-blank numeric text must fail import atomically. [L2] [L6]
21. The app-owned contract now includes `viaFerrata`, `notes`, `verified`, and `peakbaggerPid`, so app-owned import must update those fields when the CSV provides explicit non-blank replacement values rather than preserving them unconditionally as out-of-contract metadata. [L2] [L6] [L7] [L9]
22. App-owned import must still validate the full file before the first write. Wrong headers, invalid required identifiers, invalid grid references, invalid booleans, invalid numeric fields, invalid `duration`, invalid `rating`, invalid `peakbaggerPid`, blank created-peak `name`, or a created-peak row with both blank `region` and blank `country` must all fail the import atomically before any peak or list rows are persisted. [L11]
23. Existing list-level behavior outside this contract change must remain intact: app-owned import still uses the user-entered list name, still preserves the existing `PeakList.region` on update, still uses the default region on create, and still surfaces failures through the current import error shell.

## Technical Decisions

1. Treat this change as a coordinated contract update across `PeakListCsvExportService`, the app-owned branch in `PeakListImportService`, and the shared duration parsing/formatting logic in `peak_metadata_rules.dart`. [L1] [L3] [L4]
2. Keep app-owned import as an exact-header parser branch rather than weakening the HWC or ranked importers into a permissive mixed-header parser. [L1]
3. Reuse the project's existing shared normalization seams where possible: one-decimal `rating` normalization in import logic, the shared `Peak duration` parser/formatter, current MGRS conversion support, repository test doubles, and the existing import/export dialog/provider seams. [L3] [L4]
4. The app-owned contract is a deterministic maintenance format for explicit row values, but blank app-owned cells preserve existing stored values for existing peaks rather than clearing them. Newly created peaks still use normal model defaults for omitted values. [L2]
5. Keep `Peak difficulty` as stored region-specific text. This change updates the app-owned transport contract for `difficulty` but does not add a new global difficulty validation layer. [L5]
6. For newly created peaks only, treat blank `region` as a fallback-to-`country` case rather than a preserve-existing or default-region case, because there is no existing peak row to preserve and the user explicitly chose import failure when both fields are blank. [L11]

## Testing Strategy

1. Use behavior-first TDD for the non-UI contract changes, starting with service and shared-rule tests before wiring export/import call sites.
2. Extend `test/services/peak_metadata_rules_test.dart` to cover the expanded shared duration parser contract, including exact single-day forms such as `1 day` and `2 days`, retained support for existing clock/range forms, and rejection of still-unsupported forms such as `4 hours`. [L3]
3. Extend `test/services/peak_admin_editor_test.dart` to cover the dedicated admin editor's use of the expanded shared duration parser, including exact-day acceptance and updated invalid-duration validation messaging. [L3]
4. Extend `test/services/peak_list_csv_export_service_test.dart` to cover:
   1. the new exact header row and exact field ordering [L1]
   2. export of the added fields `prominence`, `rating`, `difficulty`, `duration`, `viaFerrata`, `peakbaggerPid`, `notes`, `verified`, and `sourceOfTruth` [L4] [L6] [L7] [L8] [L9]
   3. one-decimal `rating` export text such as `4.0` and `4.4` [L4]
   4. derived export of parser-safe `duration` values when only `durationMinutes` is stored [L3]
5. Extend `test/services/peak_list_import_service_test.dart` to cover:
   1. exact detection of the expanded app-owned header and rejection of the previous app-owned header [L1]
   2. update and create flows with the expanded field set [L6]
   3. blank-preserves-existing semantics for carried nullable/string fields on existing peaks, plus model defaults for newly created peaks [L2]
   4. one-decimal `rating` normalization and invalid rating failure [L4]
   5. free-text `difficulty` import without new validation [L5]
   6. duration preserve-on-blank behavior, valid exact-day import, and invalid duration failure [L3]
   7. `verified` blank/true/false handling and invalid boolean failure [L7]
   8. `sourceOfTruth` blank-preserves-existing behavior plus default-`OSM` behavior for newly created peaks [L8]
   9. `peakbaggerPid` blank/positive handling and invalid `0`/negative/non-integer failures [L9]
   10. required integer `points` behavior and atomic failure on blank/invalid `points` [L10]
   11. created-peak blank-name failure, created-peak blank-region fallback to `country`, and created-peak blank-region-plus-blank-country atomic failure [L11]
   12. full-file validation before the first write for malformed expanded app-owned rows
6. Update existing widget and journey coverage that asserts or constructs app-owned export/import CSV content so those tests use the new exact header and field contract, while keeping the current dialog shell, selectors, and deterministic fake file seams unchanged.
7. Prefer in-memory repositories, fake CSV loaders/writers, and provider overrides over live file pickers, live filesystem dialogs, or network access.

## Out of Scope

1. Supporting the previous app-owned export header alongside the new one. [L1]
2. Adding exact whole-hour duration syntax such as `4 hours`. [L3]
3. Adding a new global validation allowlist for app-owned `difficulty` or `sourceOfTruth` values. [L5] [L8]
4. Changing the HWC or ranked peak-list CSV contracts beyond reusing the shared duration parser behavior where they already depend on it.
5. Adding a new route, wizard, or separate import/export UI specifically for the app-owned contract update.

## Notes

1. Relevant implementation files include `lib/services/peak_list_csv_export_service.dart`, `lib/services/peak_list_import_service.dart`, `lib/services/peak_metadata_rules.dart`, `lib/models/peak.dart`, and the existing peak-list import/export widget/provider surfaces.
2. Relevant automated coverage starting points include `test/services/peak_list_csv_export_service_test.dart`, `test/services/peak_list_import_service_test.dart`, `test/services/peak_metadata_rules_test.dart`, and any existing widget or robot coverage that imports app-owned export CSV files.
