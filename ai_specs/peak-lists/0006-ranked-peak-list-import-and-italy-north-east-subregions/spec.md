---
type: Spec
title: Ranked Peak List CSV Import and Italy North East Subregions
---

## Problem

Peak Bagger's current peak-list import flow is built around an HWC-style scoring CSV and cannot faithfully import the generated region ranking files produced by tools such as `tool/rank_fvg_peaks.dart`. Those ranked files carry a different schema, identify peaks by `osmId`, and include shared peak metadata that the current `Peak` model does not fully store. At the same time, the app's northeast region model is too coarse for the user's current workflow: `italy-nord-est` is the only stored/filterable region key, so the Search popup cannot isolate FVG and Veneto results, and there is no agreed path yet for Trentino Alto Adige and Emilia Romagna subregion filtering. [L1] [L2] [L3] [L12] [L14]

## Proposed Outcome

Extend the existing `Import Peak List` flow so it auto-detects two CSV contracts: the current HWC peak-list CSV and a new `ranked peak list CSV`. Ranked imports must use the existing dialog-entered list name, match rows to existing peaks by `osmId`, never create peaks, strictly validate generated-file invariants before writing, and enrich matched peaks with new ranked metadata fields plus region-specific `sourceOfTruth` labels. In the same slice, introduce Italy North East subregion keys for stored peaks and peak-search filtering while keeping peak lists on the broader existing manifest region model, and expose those subregions through the existing Search popup filter menu so peak results can be narrowed to `FVG`, `Veneto`, `Trentino Alto Adige`, or `Emilia Romagna` without requiring a full top-level manifest split or a new parent-region hierarchy model. [L1] [L2] [L3] [L7] [L8] [L9] [L12] [L13] [L14] [L15]

## User Stories

1. As a user on the Peak Lists screen, I can import a generated ranked region file through the same `Import Peak List` dialog, type the list name I want, and reuse the current duplicate-name update flow. [L1] [L7]
2. As a user importing a ranked file, I get an all-or-nothing result: valid rows update the list and shared peak metadata, but tool-invariant problems such as missing, unknown, or duplicate `osmId` values fail the import before any peaks or lists are changed. [L4] [L5] [L6] [L8] [L9] [L11]
3. As a user maintaining non-Tasmanian ranked lists, I can enrich existing peaks with region ranking metadata, region-specific `sourceOfTruth` values, and Northeast subregion keys without the importer inventing new peaks or changing peak lists away from their broader manifest region. [L1] [L3] [L8] [L10] [L12] [L15]
4. As a user searching for peaks, I can keep using the existing Search popup `Filter` control while selecting `FVG`, `Veneto`, `Trentino Alto Adige`, or `Emilia Romagna` to narrow peak results by stored subregion. [L12] [L13] [L14]

## Requirements

1. Keep the existing HWC peak-list importer behavior and add a second header-detected `ranked peak list CSV` path; do not replace the current HWC flow or introduce a separate dataset-sync workflow. [L1] [L2]
2. Ranked imports must enter through the current `Import Peak List` dialog and use the user-entered list name. Do not derive ranked list names from file names such as `fvg-top-peaks.csv` or `lesser_fvg_peaks.csv`. Existing cancel, duplicate-name confirmation, and success/failure dialog flows should remain the user-facing shell around the new ranked import path. [L7]
3. Detect a ranked peak list CSV only when its header row matches this exact case-sensitive set of columns in this exact spelling: `name`, `osmId`, `rating`, `elevation`, `prominence`, `latitude`, `longitude`, `country`, `region`, `range`, `county`, `difficulty`, `viaFerrata`, `notes`. If the file matches neither the ranked header contract nor the existing HWC import contract, fail the import. [L9]
4. Ranked imports must match rows to existing peaks by `osmId` only and must never create a new `Peak`. [L1]
5. Every ranked-imported `PeakListItem` must be stored with `points: 1`. Do not derive `points` from `rating`, row order, or region identity. [L4]
6. Ranked-import validation must be atomic. If any ranked row is missing `osmId`, references an unknown `osmId`, or duplicates an earlier `osmId` in the same file, fail the entire import without updating any `Peak` rows or the target `PeakList`. The row-specific error messages must preserve these shapes:
   1. `row N is missing osmId (Peak Name)`
   2. `row N references unknown osmId 123456789 (Peak Name)`
   3. `duplicate osmId 123456789 on row N` [L6]
7. Ranked imports must validate the ranked-region contract from the CSV `region` column rather than from the typed list name or file name. For this slice, supported mappings are:
   1. `Friuli Venezia Giulia` -> `Peak.region = fvg`, `PeakList.region = italy-nord-est`, `Peak.sourceOfTruth = FVG`
   2. `Veneto` -> `Peak.region = veneto`, `PeakList.region = italy-nord-est`, `Peak.sourceOfTruth = VENETO`
   Every imported row in one file must resolve to the same supported mapping. If a row uses an unsupported ranked-import region or a file mixes supported ranked-import regions, fail the entire import with these message shapes:
   1. `unsupported region "Slovenia" on row N`
   2. `mixed ranked-import regions in one file` [L8]
8. Extend `Peak` to store ranked metadata fields that are not in the current schema: `rating`, `difficulty`, `viaFerrata`, and `notes`. `rating` must be stored as a single-decimal `double?` constrained to `0.0` through `5.0`; `difficulty`, `viaFerrata`, and `notes` must preserve the raw ranked CSV labels as strings rather than normalizing `viaFerrata` to a boolean. [L3]
9. Ranked imports must continue to update existing shared `Peak` fields when the ranked CSV provides non-blank values: `name`, `elevation`, `prominence`, `latitude`, `longitude`, `country`, `region`, `range`, and `county`, in addition to the new ranked fields. Blank ranked CSV values mean "no update" and must not clear an existing stored value. [L3] [L5]
10. Ranked imports must accept valid `rating` values with more than one decimal place, round them to one decimal place before saving, and reject the import only when a non-blank `rating` is non-numeric or outside `0.0` through `5.0`. Example normalization must follow standard rounding, including `4.33` -> `4.3` and `4.35` -> `4.4`. [L3] [L11]
11. Ranked imports must treat malformed non-blank persisted numeric fields as generated-file invariant failures and reject the entire import before any peaks or lists are changed. This strict atomic validation applies to `rating`, `elevation`, `prominence`, `latitude`, and `longitude`. Blank values for those fields still mean "no update". Required message shapes are:
   1. `invalid rating "VALUE" on row N (Peak Name)`
   2. `invalid elevation "VALUE" on row N (Peak Name)`
   3. `invalid prominence "VALUE" on row N (Peak Name)`
   4. `invalid latitude "VALUE" on row N (Peak Name)`
   5. `invalid longitude "VALUE" on row N (Peak Name)` [L5] [L11]
12. Ranked imports for supported non-Tasmanian regions must overwrite matched peaks regardless of their current `sourceOfTruth`, including peaks currently marked `HWC`, then set `sourceOfTruth` to the ranked-import region label for that file. The Tasmania-specific HWC importer behavior remains unchanged. [L8] [L15]
13. Once a ranked import updates a peak and sets `sourceOfTruth` to `FVG` or `VENETO`, that peak must remain non-`OSM` refresh-protected under the app's current refresh-eligibility rules. [L10]
14. Introduce these stored/search Italy North East subregion keys under the existing broader `italy-nord-est` umbrella: `fvg`, `veneto`, `trentino-alto-adige`, and `emilia-romagna`. In this slice those keys apply to stored `Peak.region` values and peak-search filtering only; `PeakList.region` remains on the broader manifest region model such as `italy-nord-est`. This spec does not require turning those subregions into full top-level manifest regions or introducing a reusable parent-region hierarchy. [L12]
15. Do not back-classify existing `italy-nord-est` peaks as part of this slice. The new subregion behavior applies only to peaks explicitly stored with the new subregion keys. Existing peak lists remain on the broader existing region key in this slice. [L13]
16. Keep one Search popup `Filter` menu. Add these exact user-facing options to that existing menu: `FVG`, `Veneto`, `Trentino Alto Adige`, and `Emilia Romagna`. Keep broader existing region options such as `Italy North East` in the same menu. When a subregion is selected, the filter button label must show that exact subregion label. `None` must continue to clear the filter. [L14]
17. The new northeast subregion filters are a peak-focused feature in this slice. In `Peaks` search mode, a selected subregion must filter peak results by stored `Peak.region`. In `All` search mode, a selected subregion must narrow peak results by stored `Peak.region` while non-peak results continue to follow the broader existing region model. Tracks, routes, maps, and current peak-list visibility/pinning behavior must not be required to resolve into the new subregions in this spec. [L13] [L14]
18. Search popup subregion options must be available even when current results are empty so users can narrow peak searches before typing. Keep the existing single-control popup layout rather than adding a second region selector. [L14]
19. Ranked-import loading, success, and failure remain local UI states within the existing peak-list import flow. While a ranked import is running, the current disabled-controls behavior should remain in place. On failure, the app should continue to surface the existing `Peak List Import Failed` dialog title with the ranked validation message in the dialog body. Because ranked import is local file and local database work, this slice does not require separate offline or slow-network states.
20. Search popup layout must remain usable on desktop and narrower/mobile widths by preserving the current horizontally scrollable control row. The new subregion choices must work with current text scaling without introducing a second filter control or hiding the active filter label.

## Technical Decisions

1. Implement ranked import as a distinct parser/validator branch inside `PeakListImportService`, keyed by exact header detection, rather than weakening the existing HWC importer into one permissive mixed-format parser. This preserves the current HWC contract and lets ranked validation remain strict and atomic. [L1] [L9]
2. Extend the `Peak` ObjectBox schema and supporting copy/update paths for `rating`, `difficulty`, `viaFerrata`, and `notes`, then thread those fields through ranked import updates without inventing a second shared-peak store. Regenerate `lib/objectbox.g.dart` and `lib/objectbox-model.json` as part of this schema change; do not hand-edit generated ObjectBox artifacts. [L3]
3. Reuse the existing peak-list import seams where possible: `PeakListCsvLoader`, `PeakListImportRootLoader`, `PeakListLogWriter`, in-memory `PeakRepository` and `PeakListRepository` storage, provider-overridden `PeakListImportRunner`, and the existing file-picker and duplicate-name seams. This slice should not require real filesystem dialogs, live network calls, or new external services in automated tests. [L1]
4. Treat ranked-region mapping as an app-owned import/search layer rather than a top-level manifest split in this slice. `Peak.region` should store subregion keys such as `fvg` and `veneto`, while `PeakList.region` remains on the broader manifest region key such as `italy-nord-est`. This slice does not introduce a reusable parent-region hierarchy for peak lists. [L8] [L12] [L13]
5. Extend the Search popup filter source to compose app-owned northeast subregion options with the existing manifest-driven region options. The popup must not depend on those subregions already existing as top-level `regionManifestCatalog` entries. [L12] [L14]

## Testing Strategy

1. Use behavior-first TDD for the ranked import detection/validation logic and the peak-search subregion filtering behavior.
2. Add focused service coverage for `PeakListImportService` covering:
   1. exact ranked-header detection versus the existing HWC path
   2. `osmId`-only matching with no peak creation
   3. atomic failure on missing, unknown, and duplicate `osmId`
   4. supported ranked-region mapping, unsupported-region failure, and mixed-region failure
   5. `points: 1` list membership output
   6. new `Peak` field updates and blank-value no-clear behavior
   7. `rating` range validation and one-decimal rounding
   8. atomic failure on malformed non-blank `elevation`, `prominence`, `latitude`, and `longitude`
   9. overwrite behavior when the existing peak currently has `sourceOfTruth = HWC`
   10. `sourceOfTruth` updates to `FVG` and `VENETO`, persisted `Peak.region` updates to `fvg` and `veneto`, and `PeakList.region` remaining `italy-nord-est` [L1] [L3] [L4] [L5] [L6] [L8] [L9] [L10] [L11] [L15]
3. Add service coverage for `MapSearchService` covering the new subregion keys, including peak-only filtering behavior in `Peaks` mode, peak-only narrowing in `All` mode, preservation of broader non-peak region behavior, and the decision not to back-classify existing `italy-nord-est` peak data in this slice. [L12] [L13] [L14]
4. Add widget coverage for the existing peak-list import UI and Search popup UI covering:
   1. ranked import using the typed list name through the current dialog shell
   2. ranked import failure presentation through `Peak List Import Failed`
   3. duplicate-name update flow remaining intact for ranked imports
   4. Search popup filter menu entries for `FVG`, `Veneto`, `Trentino Alto Adige`, and `Emilia Romagna`
   5. filter button label updates to the selected subregion label
   6. subregion filter availability even when results are empty [L7] [L14]
5. Extend the existing peak-list robot or journey coverage for the import dialog to include at least one successful ranked-import path using deterministic fake CSV input, stable app-owned selectors, and provider overrides. Search popup changes may remain at unit/widget scope in this slice unless a broader search journey already exists and can be extended cheaply. [L7] [L14]
6. Prefer fake repositories, in-memory ObjectBox seams, fake CSV loaders, and provider overrides over live disk/network behavior. Automated tests must not require real network calls, live Overpass refreshes, or API keys.
7. Extend schema-surface verification for the new persisted `Peak` fields, including `test/services/objectbox_schema_guard_test.dart` or equivalent coverage that proves the regenerated ObjectBox model exposes `rating`, `difficulty`, `viaFerrata`, and `notes`.

## Out of Scope

1. Creating new peaks from ranked peak list CSV rows. [L1]
2. Adding ranked-import source mappings for Slovenia before its `sourceOfTruth` label and region key are decided. [L16]
3. Back-classifying existing `italy-nord-est` peaks or peak lists into northeast subregions. [L13]
4. Turning `fvg`, `veneto`, `trentino-alto-adige`, or `emilia-romagna` into new top-level manifest regions with new polygon assets or basemap/catalog splits in this slice. [L12]
5. Requiring tracks, routes, or maps to adopt the new northeast subregions. [L13]

## Open Questions

1. What exact ranked-import `sourceOfTruth` label and region mapping should be used for Slovenia once ranked Slovenia lists are brought into scope? [L16]
2. Should a later data-migration slice classify existing `italy-nord-est` peaks and peak lists into the new northeast subregions once the desired boundaries and migration rules are finalized? [L13]

## Follow-Ups

1. When ranked imports expand beyond FVG and Veneto, add the next supported ranked-region mappings explicitly rather than inferring them from display names or file names.
2. If peak search subregions later need map-aware visibility or non-peak filtering, plan a separate manifest/polygon slice instead of extending this import-focused change ad hoc.

## Notes

1. Relevant implementation files include `lib/models/peak.dart`, `lib/models/peak_list.dart`, `lib/services/peak_list_import_service.dart`, `lib/providers/peak_list_provider.dart`, `lib/widgets/peak_list_import_dialog.dart`, `lib/services/peak_refresh_service.dart`, `lib/services/map_search_service.dart`, `lib/widgets/map_search_popup.dart`, and `lib/services/peak_list_visibility.dart`. [L1] [L3] [L8] [L12] [L14]
2. Relevant automated coverage starting points include `test/services/peak_list_import_service_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/robot/peaks/peak_lists_journey_test.dart`, and `test/services/map_search_service_test.dart`. [L1] [L7] [L14]
3. `GLOSSARY.md` now defines `Ranked peak list CSV` and `Italy North East subregion` as the canonical project terminology for this feature. [L2] [L12]
4. Relevant schema-managed files and verification surfaces also include `lib/objectbox.g.dart`, `lib/objectbox-model.json`, and `test/services/objectbox_schema_guard_test.dart` because this slice adds persisted `Peak` fields.
