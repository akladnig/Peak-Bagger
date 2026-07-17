---
type: Work Item
title: Expanded App-Owned Import Contract Through Existing Dialog
parent: ../spec.md
---

## What to build

Update the app-owned branch in `PeakListImportService` so the existing `Import Peak List` workflow accepts only this exact case-sensitive ordered app-owned header:

```text
name,altName,elevation,prominence,rating,difficulty,duration,viaFerrata,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,peakbaggerPid,country,region,county,range,notes,verified,sourceOfTruth
```

Keep the existing HWC and ranked peak-list import paths unchanged, keep the current import dialog shell and failure presentation unchanged, and apply the expanded app-owned create/update contract atomically before any peak or list writes occur.

## Required context

- `lib/services/peak_list_import_service.dart` already owns exact-header detection, CSV decoding, repository writes, and row-level validation. Keep the app-owned path as a distinct exact-header branch instead of weakening the HWC or ranked importers into a permissive mixed parser.
- `lib/providers/peak_list_provider.dart`, `lib/widgets/peak_list_import_dialog.dart`, and `lib/screens/peak_lists_screen.dart` already provide the existing `Import Peak List` shell, loading state, retry path, and current import error surface. Preserve those navigation boundaries and stable selectors.
- Reuse the shared duration rules from `lib/services/peak_metadata_rules.dart`, existing MGRS conversion support in `lib/services/peak_mgrs_converter.dart`, current repository test doubles, and existing one-decimal rating normalization seam instead of duplicating import-only logic.
- Existing focused coverage starts in `test/services/peak_list_import_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/robot/peaks/peak_lists_journey_test.dart`. Keep deterministic fake CSV input, in-memory repositories, provider overrides, stable selectors, and fake file-picker seams unchanged.

## Acceptance criteria

- [x] `PeakListImportService` keeps the existing HWC import path and the existing ranked peak-list CSV import path, and the app-owned branch triggers only when the header row exactly matches `name,altName,elevation,prominence,rating,difficulty,duration,viaFerrata,gridZoneDesignator,mgrs100kId,easting,northing,points,osmId,peakbaggerPid,country,region,county,range,notes,verified,sourceOfTruth`.
- [x] The previous app-owned export header is rejected by the app-owned importer, and the importer does not accept aliases such as `Points`, partial subsets, reordered columns, or mixed old/new app-owned shapes.
- [x] App-owned import still enters through the existing `Import Peak List` dialog and current import error shell, and this change adds no new route, second dialog step, separate picker flow, or new robot selector contract.
- [x] App-owned import validates the full file before the first write and fails atomically on wrong headers, invalid required identifiers, invalid grid references, invalid booleans, invalid numeric fields, invalid `duration`, invalid `rating`, invalid `peakbaggerPid`, blank created-peak `name`, or created-peak rows with both blank `region` and blank `country`.
- [x] App-owned import still matches existing peaks by `osmId`, including stored synthetic negative `osmId` values, updates an existing `Peak` when the imported `osmId` exists, and creates a new `Peak` from the row data plus derived coordinates when the imported `osmId` is unknown.
- [x] Blank app-owned cells preserve the existing stored value for existing peaks, while newly created peaks use normal model defaults for blank fields unless the Spec defines a stricter create-path rule.
- [x] `points` and `osmId` remain required row identity and list-membership fields. Blank or invalid values fail the import atomically, and duplicate rows plus file order are preserved exactly in the saved `PeakList`.
- [x] For newly created peaks, blank `name` fails import atomically, blank `region` falls back to the row's `country`, and rows with both blank `region` and blank `country` fail import atomically before any writes occur.
- [x] Nullable numeric app-owned columns `elevation`, `prominence`, `rating`, and `peakbaggerPid` use non-blank validated overrides, preserve existing stored values on blank cells for existing peaks, and fall back to normal model defaults on newly created peaks.
- [x] `rating` accepts only numeric values from `0` through `5` inclusive when non-blank, normalizes to one decimal place before save, preserves the existing stored rating on blank cells for existing peaks, leaves newly created peaks unrated on blank cells, and fails invalid or out-of-range values atomically with a clear row-level validation error.
- [x] `difficulty`, `viaFerrata`, `country`, `region`, `county`, `range`, `notes`, `name`, and `altName` round-trip as trimmed string data, non-blank values replace stored values after trimming, blank values preserve existing stored values for existing peaks, and this change adds no new global allowlist validator for `difficulty`.
- [x] `duration` round-trips through the shared `Peak duration` parsing logic, preserves the existing stored `durationLabel` and `durationMinutes` for existing peaks when blank, leaves newly created peaks with blank duration fields when blank, accepts only the parser-supported forms from the Spec when non-blank, and fails unsupported non-blank values atomically with a clear row-level validation error.
- [x] `verified` accepts only `true`, `false`, or blank on import, exports no alternate boolean spellings through the import path, preserves the existing stored value for existing peaks when blank, leaves newly created peaks at the model default `false` when blank, and fails any other non-blank value atomically.
- [x] `sourceOfTruth` preserves the existing stored value for existing peaks when blank, leaves newly created peaks at the model default `OSM` when blank, trims and stores non-blank values exactly as provided, and adds no new global allowlist validator.
- [x] `peakbaggerPid` accepts only blank or positive integer data, preserves the existing stored value for existing peaks when blank, leaves newly created peaks `null` when blank, and fails `0`, negative integers, and non-integer text atomically.
- [x] Existing list-level behavior remains intact outside this contract change: app-owned import still uses the user-entered list name, still preserves the existing `PeakList.region` on update, still uses the default region on create, and still surfaces failures through the current import error shell.
- [x] Behavior-first TDD starts with focused service and shared-rule coverage before widget or robot wiring updates, and the updated service, widget, and robot tests keep stable selectors plus deterministic fake file seams while covering exact header detection, rejection of the previous app-owned header, create and update flows with the expanded field set, blank-preserves-existing semantics, default behavior for newly created peaks, row-order and duplicate preservation, and exact failure presentation through the existing dialog shell.

## Covers

- User Stories: 1-3
- Requirements: 1, 3-15, 17-23
- Technical Decisions: 1-6
- Testing Strategy: 1, 5-7
- Interview Ledger: L1-L11

## Blocked by

- `01-shared-peak-duration-exact-day-parsing-and-admin-validation.md`
- `02-expanded-app-owned-export-csv-contract-and-coverage.md`
