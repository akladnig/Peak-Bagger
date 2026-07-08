---
type: Work Item
title: Ranked Peak List CSV Import Through Existing Dialog
parent: ../spec.md
---

## What to build
Extend the existing `Import Peak List` flow so the app keeps the current HWC importer and adds a second exact-header-detected `ranked peak list CSV` path inside `PeakListImportService`. The ranked path must use the typed dialog list name, validate the generated-file invariants atomically before writing, match rows to existing peaks by `osmId` only, never create peaks, store every ranked-imported `PeakListItem` with `points: 1`, update the required shared `Peak` fields and new ranked metadata fields, set `Peak.region` and `Peak.sourceOfTruth` from the CSV `region` contract, keep `PeakList.region` on the broader existing manifest region such as `italy-nord-est`, preserve the existing duplicate-name, loading, success, and `Peak List Import Failed` dialog shell, and extend the existing service, schema, widget, and robot coverage for this flow.

## Required context
- `lib/services/peak_list_import_service.dart` currently implements the HWC-only importer and already owns the `PeakListCsvLoader`, `PeakListImportRootLoader`, `PeakListLogWriter`, and repository seams that this item should reuse for the ranked branch rather than introducing a separate workflow.
- `lib/models/peak.dart`, `lib/objectbox.g.dart`, `lib/objectbox-model.json`, and `test/services/objectbox_schema_guard_test.dart` are the schema surfaces that must reflect the new persisted `Peak` fields `rating`, `difficulty`, `viaFerrata`, and `notes`. Regenerate ObjectBox artifacts; do not hand-edit generated files.
- `lib/providers/peak_list_provider.dart`, `lib/widgets/peak_list_import_dialog.dart`, and `lib/screens/peak_lists_screen.dart` already provide the typed-name import shell, disabled-controls behavior, duplicate-name confirmation, and `Peak List Import Failed` presentation that this item must preserve while routing ranked imports through the same UI.
- Follow canonical terminology from `GLOSSARY.md`, especially `Ranked peak list CSV`.
- Existing test seams and starting points are in `test/services/peak_list_import_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/robot/peaks/peak_lists_journey_test.dart`. Reuse deterministic fake CSV input, provider overrides, and stable app-owned selectors instead of live file dialogs, network calls, or API keys.
- `lib/services/peak_refresh_service.dart` contains the current refresh-eligibility behavior for non-`OSM` peaks. This item must preserve the protection behavior once ranked imports set `sourceOfTruth` to `FVG` or `VENETO`.

## Acceptance criteria
- [ ] `PeakListImportService` keeps the existing HWC importer behavior and adds a distinct ranked parser and validator branch that triggers only when the header row exactly matches this case-sensitive column set: `name`, `osmId`, `rating`, `elevation`, `prominence`, `latitude`, `longitude`, `country`, `region`, `range`, `county`, `difficulty`, `viaFerrata`, `notes`; files matching neither known contract fail the import.
- [ ] Ranked imports enter through the existing `Import Peak List` dialog, use the user-entered list name exactly as today, keep the existing cancel and duplicate-name confirmation flow, keep ranked-import loading state local to the current dialog shell with the current disabled-controls behavior, and surface ranked failures through the existing `Peak List Import Failed` dialog title.
- [ ] Ranked imports validate atomically before writing any `Peak` rows or `PeakList` changes: missing `osmId`, unknown `osmId`, duplicate `osmId` in one file, unsupported ranked-import region, mixed ranked-import regions, invalid non-blank `rating`, `elevation`, `prominence`, `latitude`, or `longitude`, or any other malformed generated-file invariant fail the entire import with the exact required message shapes from the Spec.
- [ ] Ranked imports match rows to existing peaks by `osmId` only and never create a new `Peak`.
- [ ] Every ranked-imported `PeakListItem` is stored with `points: 1`; the importer does not derive points from `rating`, row order, or region identity.
- [ ] Ranked imports support only these CSV `region` mappings in this slice and derive them from the CSV `region` column rather than the typed list name or file name: `Friuli Venezia Giulia` -> `Peak.region = fvg`, `PeakList.region = italy-nord-est`, `Peak.sourceOfTruth = FVG`; `Veneto` -> `Peak.region = veneto`, `PeakList.region = italy-nord-est`, `Peak.sourceOfTruth = VENETO`.
- [ ] `Peak` persists the new ranked metadata fields `rating`, `difficulty`, `viaFerrata`, and `notes`; `rating` is stored as a single-decimal `double?` constrained to `0.0` through `5.0`, valid values with extra precision are rounded before save using standard rounding such as `4.33` -> `4.3` and `4.35` -> `4.4`, and `difficulty`, `viaFerrata`, and `notes` preserve the raw ranked CSV labels as strings.
- [ ] Ranked imports continue to update existing shared `Peak` fields when the ranked CSV provides non-blank values for `name`, `elevation`, `prominence`, `latitude`, `longitude`, `country`, `region`, `range`, and `county`, plus the new ranked fields; blank values mean no update and do not clear stored values.
- [ ] Ranked imports overwrite matched supported non-Tasmanian peaks regardless of current `sourceOfTruth`, including peaks currently marked `HWC`, then set `sourceOfTruth` to `FVG` or `VENETO`; Tasmania-specific HWC importer behavior remains unchanged, and peaks updated by ranked imports remain non-`OSM` refresh-protected under the app’s current refresh rules.
- [ ] Behavior-first TDD drives this item. Focused service coverage proves exact ranked-header detection versus the HWC path, `osmId`-only matching, no peak creation, atomic failure cases, supported region mapping, `points: 1`, new `Peak` field updates, blank-value no-clear behavior, rating validation and rounding, overwrite behavior for existing `HWC` peaks, `Peak.region` and `PeakList.region` persistence, and `sourceOfTruth` updates to `FVG` and `VENETO`.
- [ ] Widget coverage proves ranked import uses the typed list name through the existing dialog shell, keeps the duplicate-name update flow intact, and shows ranked validation failures through `Peak List Import Failed`.
- [ ] Robot or journey coverage extends the existing peak-list import flow with at least one successful ranked import using deterministic fake CSV input, provider overrides, and stable app-owned selectors; it does not require real filesystem dialogs, live Overpass refreshes, or network calls.

## Covers
- User Stories: 1-3
- Requirements: 1-13, 15, 19
- Technical Decisions: 1-4
- Testing Strategy: 1-2, 4.1-4.3, 5-7
- Interview Ledger: L1-L13, L15

## Blocked by
None - ready to start
