---
type: Work Item
title: Manifest-Driven Ranked Import and Provenance Through Import Peak List
parent: ../spec.md
---

## What to build
Rework the ranked branch of the existing Flutter `Import Peak List` flow so ranked imports resolve `region` from manifest-backed display names, accept mixed-region files, persist one canonical `country` and one canonical `region` per imported `Peak`, store `PeakList.region = mixed` only when one ranked file spans multiple canonical regions, and consume explicit ranked `sourceOfTruth` provenance from the CSV contract instead of inferring it from region labels. Preserve the narrow legacy FVG and Veneto compatibility path for the old ranked header without extending that fallback to newer manifest-backed regions.

## Required context
- `lib/services/peak_list_import_service.dart` is the authoritative ranked-import seam. Replace hard-coded ranked region logic there instead of building a second ranked import path.
- `lib/widgets/peak_list_import_dialog.dart`, `lib/screens/peak_lists_screen.dart`, `test/widget/peak_lists_screen_test.dart`, and `test/robot/peaks/peak_lists_journey_test.dart` already cover the existing `Import Peak List` UI shell, failure presentation, and journey wiring. Preserve that shell and extend it with deterministic fake CSV input and stable existing selectors.
- `lib/models/peak.dart`, `lib/models/peak_list.dart`, `lib/services/peak_list_derived_data.dart`, and `lib/services/peak_list_repository.dart` define the current single-region storage model and the existing `mixed` sentinel behavior that this item must preserve for storage while changing ranked-import production rules.
- Follow `GLOSSARY.md`, especially `Ranked peak list CSV` and `Mixed-region peak list`.
- Relevant prior behavior and regression surfaces already live in `test/services/peak_list_import_service_test.dart`. Reuse existing fake CSV loaders and repository seams. Do not introduce real filesystem, network, or external CLI dependencies into import tests.

## Acceptance criteria
- [x] The ranked importer stops using `_rankedRegionMappings` as its primary source of truth and instead resolves ranked CSV `region` values from exact manifest display names after surrounding-whitespace trimming plus the newly modeled `Italy administrative region` entries from this slice.
- [x] Ranked CSV imports support exactly these two case-sensitive header variants during the transition: `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes` and `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth`.
- [x] When the extended ranked header is used, every non-blank row in one file carries the same non-blank `sourceOfTruth` value after trim-and-uppercase normalization; mixed, blank, comma-separated, or format-invalid values fail the import atomically before saving any peaks or peak lists.
- [x] A valid ranked `sourceOfTruth` value remains non-blank after trimming and uppercasing, contains at least one ASCII letter or digit, contains only uppercase ASCII letters, digits, spaces, periods, hyphens, or underscores after normalization, and does not contain commas or other multi-valued separators.
- [x] Legacy 14-column ranked CSV files preserve backward compatibility only for `Friuli Venezia Giulia -> Peak.sourceOfTruth = FVG` and `Veneto -> Peak.sourceOfTruth = VENETO`. Newer manifest-backed regions such as `Slovenia`, `Trentino-Alto Adige`, or `Emilia-Romagna` fail under the legacy-header path and require the extended header with explicit `sourceOfTruth`.
- [x] Ranked imports may contain rows from multiple canonical regions in one file. The importer no longer fails a ranked import solely because rows resolve to different canonical regions.
- [x] Each successfully imported ranked `Peak` still stores exactly one canonical `country` and one canonical `region`; the ranked importer still matches by `osmId`, still never creates a new `Peak`, still keeps atomic validation semantics, and still updates ranked metadata fields and shared peak metadata for successful rows.
- [x] Single-region ranked imports continue storing their one canonical region key on `PeakList.region`. Ranked imports whose rows span more than one canonical region persist `PeakList.region = mixed`. This slice does not migrate or silently rewrite existing stored `Peak.region` or `PeakList.region` values.
- [x] The Flutter `Import Peak List` flow continues to detect ranked headers through the existing dialog path, keeps the existing typed-name, duplicate-name, loading, success, and atomic-failure behavior, and surfaces new region or provenance validation failures through the existing import-failure presentation.
- [x] Behavior-first TDD drives this item. Focused service coverage proves manifest-backed region resolution, rejection of internal region keys, mixed-region ranked file acceptance, canonical `Peak.region` persistence to specific Italy administrative-region keys and other manifest-backed region keys, `PeakList.region = mixed` for mixed-region ranked imports, extended-header provenance validation and normalization, and the narrow FVG and Veneto legacy path. Focused widget or robot coverage proves the `Import Peak List` dialog still detects ranked headers correctly and surfaces success or atomic failure with deterministic fake CSV input and stable selectors.

## Covers
- User Stories: 1, 4, 5
- Requirements: 1-10, 19, 21-26
- Technical Decisions: 2, 4, 5, 8-11
- Testing Strategy: 1, 2, 5, 9, 10
- Interview Ledger: L1-L6, L10-L14

## Blocked by
- `01-manifest-backed-italy-administrative-regions-and-priority-metadata.md`
