---
type: Work Item
title: Export-Matching Peak List Import Through Existing Dialog
parent: ../spec.md
---

## What to build

Extend the existing `Import Peak List` flow so the app keeps the current HWC and ranked peak-list importers and adds a third exact-header-detected app-owned export CSV branch inside `PeakListImportService`. The new branch must validate the full file and build the import plan before any writes begin, match existing peaks by `osmId` including current synthetic negative `osmId` values already stored in this single-instance app, create missing peaks from imported row data, update existing peaks from the shared contract, preserve duplicate memberships and exported row order exactly, preserve the existing `PeakList.region` rule of existing-on-update and default-on-create, and keep the current duplicate-name, loading, success, retry, and `Peak List Import Failed` dialog behavior through the existing desktop dialog shell.

## Required context

- `lib/services/peak_list_import_service.dart` already owns CSV decoding, header detection, import validation, repository writes, and the `PeakListCsvLoader`, `PeakListImportRootLoader`, and `PeakListLogWriter` seams. Add the new parser as a distinct exact-header branch instead of weakening the HWC or ranked importers into a mixed parser.
- `lib/providers/peak_list_provider.dart`, `lib/widgets/peak_list_import_dialog.dart`, and `lib/screens/peak_lists_screen.dart` already provide the typed-name import shell, duplicate-name confirmation flow, disabled-controls loading state, result dialogs, failure dialog title, and list-selection refresh behavior that this item must preserve.
- Reuse existing conversion support in `lib/services/peak_mgrs_converter.dart` for imported grid-reference parsing and lat/lng derivation. New-format imports must not add lat/lng columns to the shared contract.
- `lib/models/peak.dart` and `lib/models/peak_list.dart` define current defaults and list item encoding. This item must preserve current defaults for fields not present in the shared contract and must keep duplicate `PeakListItem` rows instead of deduplicating by `osmId`.
- Existing focused coverage starts in `test/services/peak_list_import_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/robot/peaks/peak_lists_journey_test.dart`. Reuse deterministic fake CSV input, in-memory repositories, provider overrides, and stable app-owned selectors rather than live file dialogs, network calls, or API keys.

## Acceptance criteria

- [ ] `PeakListImportService` keeps the existing HWC and ranked peak-list import behavior and adds a third exact-header-detected app-owned export CSV parser branch that triggers only when the header row exactly matches `name,altName,elevation,gridZoneDesignator,mgrs100kId,easting,northing,Points,osmId,country,region,county,range,sourceOfTruth`.
- [ ] Files written by the previous 9-column peak-list export header are not supported by the new branch and fail import rather than being silently treated as the new export format.
- [ ] New-format import enters through the existing `Import Peak List` dialog, uses the user-entered list name, keeps the existing cancel and duplicate-name confirmation flow, keeps file selection, name entry, cancel, and submit disabled while importing, shows the existing `peak-list-import-progress` loading indicator, and preserves the existing dialog titles `Import Peak List`, `Peak List Created`, `Peak List Updated`, and `Peak List Import Failed`.
- [ ] New-format import validates the full file and builds the full import plan before the first `Peak` or `PeakList` write begins. Wrong header order, invalid or unparseable `osmId`, invalid or unparseable `Points`, invalid or unparseable grid-reference fields, or any row that cannot be converted into a valid `Peak` and `PeakListItem` fail the import before any changes are persisted.
- [ ] For each imported row in the new format, existing peaks are matched by `osmId`, including current synthetic negative `osmId` values already stored locally in this single-instance app. If the `osmId` exists, import updates that `Peak`; if it does not exist, import creates a new `Peak` from the row data instead of failing or skipping the row.
- [ ] New-format imports create missing peaks by deriving `latitude` and `longitude` from imported `gridZoneDesignator`, `mgrs100kId`, `easting`, and `northing`, and leave fields not present in the shared contract at current model defaults on newly created peaks.
- [ ] New-format imports update existing peaks so `name`, `altName`, `elevation`, `gridZoneDesignator`, `mgrs100kId`, `easting`, `northing`, `country`, `region`, `county`, `range`, and `sourceOfTruth` align to the imported row, and recompute stored `latitude` and `longitude` from the imported grid reference while leaving fields not represented in the shared contract unchanged.
- [ ] New-format imports round-trip exact `PeakListItem.points` values from the `Points` column, do not normalize those values to ranked-import `points: 1`, do not deduplicate duplicate `osmId` rows, and persist list membership in exported row order exactly.
- [ ] When importing into an existing list name, import preserves that list's current `PeakList.region`; when importing into a new list name, import uses the current default region and does not infer `PeakList.region` from imported peak rows.
- [ ] On validation failure for the new format, import keeps using the existing `Peak List Import Failed` dialog title, shows the exact validation message in the dialog body, and allows the user to retry through the existing flow without restarting the app or leaving the screen.
- [ ] Behavior-first TDD drives this item. Focused service tests cover exact new-header detection versus the existing HWC and ranked paths, update-by-`osmId`, creation of missing peaks, atomic full-file validation before writes, rejection of the old export header, exact `Points` round-trip, duplicate-row preservation, row-order preservation, and `PeakList.region` preservation/default behavior.
- [ ] Widget tests cover new-format import through the existing dialog shell, the unchanged duplicate-name update flow, the existing loading-state disable behavior, and failure presentation through `Peak List Import Failed` for rejected old-export files and malformed new-format files.
- [ ] Robot or journey coverage extends the existing peak-list import flow with at least one successful import of the new export-matching format using deterministic fake CSV input, provider overrides, and stable app-owned selectors; it does not require real filesystem dialogs, live network access, or API keys.

## Covers

- User Stories: 1-3
- Requirements: 1, 3-16, 18
- Technical Decisions: 1-6
- Testing Strategy: 1, 3-7
- Interview Ledger: L1-L4

## Blocked by

- `01-shared-peak-list-export-csv-contract.md`
