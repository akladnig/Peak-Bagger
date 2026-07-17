---
type: Spec
title: Manifest-Driven Ranked Peak List Regions and Provenance
---

## Problem

The current `Ranked peak list CSV` importer uses a hard-coded region mapping that only accepts `Friuli Venezia Giulia` and `Veneto`, so ranked files such as Slovenia exports fail with `unsupported region` even though the app already has a broader region manifest. At the same time, the current Italy model treats `italy-nord-est` and `italy-nord-ovest` as stored regions even though they are app-owned aggregate unions rather than Italian administrative regions, the ranked importer assumes one region per file and one region per `PeakList`, and ranked provenance is still inferred from region labels instead of being carried explicitly in the CSV contract. The Slovenia ranked generator also currently writes broad `Slovenia` region values for canonical rows and cannot yet canonicalize border peaks down to one stored country and one stored region with explicit border context. [L1] [L2] [L3] [L5] [L6] [L7] [L8] [L9] [L10] [L11] [L12] [L13] [L14]

## Proposed Outcome

Make ranked import manifest-driven, with explicit Italian administrative-region support, mixed-region ranked-list support, and explicit `sourceOfTruth` provenance in the ranked CSV contract. Extend the Slovenia ranked CSV generator and its shell entrypoint so it produces canonical single-country, single-region rows, can canonicalize shared Italy/Slovenia peaks onto the Italian side when appropriate, and writes or overrides `sourceOfTruth` deterministically from a required CLI flag or a validated CSV column. Preserve legacy FVG and Veneto ranked CSV imports through an explicit compatibility path rather than through ongoing hard-coded region logic. [L1] [L2] [L3] [L4] [L5] [L6] [L7] [L8] [L9] [L10] [L11] [L12] [L13] [L14]

## User Stories

1. As a maintainer importing ranked CSV files through the existing Flutter `Import Peak List` flow, I can import manifest-backed regions such as `Slovenia` and specific Italian administrative regions without maintaining a growing hard-coded region allowlist. [L1] [L2] [L3] [L4] [L12] [L13] [L14]
2. As a maintainer working with Italy data, I can store ranked peaks against specific Italian administrative regions such as `Friuli Venezia Giulia` or `Veneto`, while treating `italy-nord-est` and `italy-nord-ovest` only as aggregate grouping regions. [L1] [L2] [L3] [L4]
3. As a maintainer generating Slovenia ranked CSVs, I can run a repo-local shell script or the underlying Dart tool with an explicit source-of-truth flag and get canonical single-country, single-region ranked rows suitable for import. [L6] [L7] [L8] [L11] [L12] [L13]
4. As a user viewing imported peak lists in the app, a mixed-region ranked list appears in every visible region where it has member peaks instead of disappearing because the list was forced into one fake region. [L5] [L9] [L10]
5. As a maintainer preserving older ranked datasets, I can still import legacy FVG and Veneto ranked CSV files that do not yet include a `sourceOfTruth` column, without extending that legacy fallback to newer manifest-backed regions. [L12] [L13] [L14]

## Requirements

1. Ranked import region validation must stop using the current hard-coded `_rankedRegionMappings` table as the primary source of truth. Instead, the importer must resolve ranked CSV `region` values from manifest-backed display names plus the explicitly modeled Italian administrative regions in this slice. [L1] [L2] [L3]
2. Treat `fvg`, `veneto`, `trentino-alto-adige`, `emilia-romagna`, and any north-west administrative-region peers added in this slice as real Italian administrative-region keys. Treat `italy-nord-est` and `italy-nord-ovest` as app-owned aggregate regions only, not as the canonical stored `Peak.region` for ranked imports. [L1] [L2]
3. In this slice, add only the Italian administrative regions currently needed by the app's data, polygon, or ranked-import flows. Do not model all ISO 3166-2:IT first-level subdivisions until the app has assets or user-visible flows that need them. These newly added Italian administrative manifest regions are manifest-backed for search, import, and canonicalization in this slice, but they must not trigger startup peak-region asset seeding unless a later slice explicitly adds the required seed assets and startup-import behavior. [L2]
4. Ranked CSV `region` cells must use exact manifest display names after surrounding-whitespace trimming. Internal keys such as `slovenia`, `fvg`, `veneto`, or `italy-nord-est` are not valid ranked CSV region values. [L3]
5. Search popup region options, compact labels, and aggregate-region filter matching must come from manifest-backed region metadata rather than from hard-coded app lists. For this slice, option inclusion must come from `showInPeakList`, compact labels must come from `shortName` when present and otherwise from the manifest display name, and aggregate-to-child or alias matching must come from `peakListFilterAliases` or equivalent manifest-backed roll-up metadata. This slice must remove the current hard-coded northeast search-region layer in favor of that manifest-driven contract. [L1] [L2] [L3]
6. Apply the new manifest-driven region model to new or updated ranked imports going forward. Do not silently migrate or rewrite existing stored `Peak.region` or `PeakList.region` values in this slice. [L4]
7. Ranked imports may contain rows from multiple canonical regions in one file. The importer must not fail a ranked import solely because rows resolve to different canonical regions. The old `mixed ranked-import regions in one file` failure path no longer applies to manifest-driven ranked imports. [L5]
8. Even when a ranked file mixes regions or countries, each imported `Peak` must continue to store exactly one canonical `country` and one canonical `region`. Do not add multi-country or multi-region peak membership in this slice. [L6]
9. Canonical ranked CSV rows must contain exactly one `country` value and one `region` value. Multi-valued cells such as `Italy, Slovenia` are not valid canonical ranked-import values. [L6] [L7]
10. For border or shared peaks, the CSV generator must resolve the canonical `country` and `region` from the peak coordinates against manifest polygons before writing the importable row. If the point is shared across border-relevant polygons, the generator must still choose one canonical country-region pair and append the border fact to `notes`. [L7]
11. Manifest-backed regions that participate in canonicalization must define a required `priority` field in segmented numeric form using 1 to 3 dot-separated integer segments such as `2`, `2.1`, or `2.1.3`. The app and tool must parse those segments numerically rather than lexically, validate the format before use, and reject invalid or missing `priority` values rather than silently falling back to manifest file order. [L7] [L8]
12. When canonicalization has multiple polygon matches, compare manifest `priority` segment-by-segment numerically. If one priority path is a strict prefix of another, the longer path is more specific and must win. Example: `2.1` outranks `2`, and `2.1.3` outranks `2.1`. [L7] [L8]
13. Aggregate regions such as `italy`, `italy-nord-est`, and `italy-nord-ovest` must never outrank a matching more specific child region solely because of manifest order. If multiple matching regions remain tied after priority comparison, the generator must fail that row into deterministic review output rather than guess. [L7] [L8]
14. When the canonical side of a shared peak is Italy, the canonical ranked row must use `country = Italy` and the specific Italian administrative-region display name in `region`, not the broad `Italy` region label. Example: an Italy/FVG border peak writes `country = Italy`, `region = Friuli Venezia Giulia`, and appends border context such as `Border peak with Slovenia` to `notes`. [L8]
15. Extend the Slovenia ranked generator so it no longer writes broad `Slovenia` region values for every canonical row by default. It must canonicalize each confident row to one country and one region using the rule above, including canonicalization onto the Italian side when the chosen canonical country is Italy. [L7] [L8]
16. Any persisted `PeakList.region = mixed` list must appear in every visible region where at least one member peak belongs. Visibility and selection for those lists must derive from member-peak canonical regions rather than from one stored `PeakList.region` value alone. Ranked import is the first producer of `mixed` in this slice, but the app behavior applies to the `mixed` classification itself. [L5] [L9] [L10]
17. Pinning a persisted `mixed` list must persist that pin for every canonical member region represented by peaks in the list. Unpinning a persisted `mixed` list must remove the pin for every canonical member region represented by peaks in the list. The UI should still present one selectable and pinnable list entry rather than duplicating the list per region. [L9] [L10]
18. Keep existing single-region behavior for lists whose persisted region is not `mixed` unless a later migration explicitly changes them. [L9]
19. Because `PeakList.region` remains a required stored string, ranked imports that contain peaks from more than one canonical region must persist `PeakList.region = mixed`. Single-region ranked imports must continue storing their one canonical region key. [L10]
20. `mixed` is an internal sentinel key, not a manifest region and not a user-facing region label. Mixed-list visibility and pinning must come from member peaks rather than by treating `mixed` as a visible region choice. [L10]
21. Ranked provenance must no longer be inferred from `region` for new manifest-driven imports. Introduce an explicit `sourceOfTruth` contract that the importer reads from the ranked CSV data. [L11] [L12]
22. Support two exact ranked CSV header variants during the transition:
   1. Legacy header: `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes`
   2. Extended header: `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth` [L12] [L13]
23. When the extended ranked CSV header is used, every non-blank row in one file must carry the same non-blank `sourceOfTruth` value after trimming and uppercasing. If the file has mixed, blank, or invalid `sourceOfTruth` values, fail the import atomically before saving any peaks or lists. [L11] [L12] [L13]
24. For this slice, a valid ranked `sourceOfTruth` value is a single explicit provenance label that remains non-blank after trimming and uppercasing, contains at least one ASCII letter or digit, contains only uppercase ASCII letters, digits, spaces, periods, hyphens, or underscores after normalization, and does not contain commas or other multi-valued separators. The importer and tool must normalize lowercase or padded values such as ` hribi ` to `HRIBI` before comparison or persistence. [L11] [L12]
25. For legacy ranked CSV files that use the old 14-column header without `sourceOfTruth`, preserve backward compatibility only for the current legacy mappings:
   1. `Friuli Venezia Giulia` -> `Peak.sourceOfTruth = FVG`
   2. `Veneto` -> `Peak.sourceOfTruth = VENETO`
   Do not invent new legacy region-to-provenance inference rules for newer manifest-backed regions such as `Slovenia`, `Trentino-Alto Adige`, or `Emilia-Romagna`. Those regions require the extended header with explicit `sourceOfTruth`. [L14]
26. Update the ranked importer so it still matches peaks by `osmId`, still never creates new peaks in the ranked path, still keeps atomic failure semantics for row validation, and still updates ranked metadata fields and shared peak metadata for successful rows. This slice changes region and provenance rules, not the core ranked-import persistence model. [L4] [L5] [L6] [L12] [L13] [L14]
27. Extend `tool/slovenia_hribi_source_peak_list.dart` so it can also be run through a repo-root shell script entrypoint that follows the project's existing script pattern. The script must forward CLI flags to the Dart tool. [L11] [L12]
28. Add a mandatory tool flag for ranked provenance, such as `--source-of-truth`, to the Slovenia ranked tool path. If the input CSV does not provide a `sourceOfTruth` column, the flag is required. If the flag is provided, it overrides any existing `sourceOfTruth` column values before output is written. [L11] [L12]
29. If an optional `sourceOfTruth` column is provided to the tool's input pipeline, every row in one file must carry the same non-blank value after trim-and-uppercase normalization. Mixed, blank, or invalid per-row values must fail the tool run atomically rather than letting inconsistent provenance reach the importable output. [L11] [L12]
30. The tool must write the resolved uppercase `sourceOfTruth` into the output ranked CSV when generating the extended header variant, so the importer can consume provenance from the CSV itself rather than from external flags at import time. [L11] [L12] [L13]

## Technical Decisions

1. Use the updated glossary terminology in code-adjacent artifacts: `Italy administrative region` for real first-level Italian stored/search regions, and `Italy aggregate region` for app-owned unions such as `italy-nord-est` and `italy-nord-ovest`. [L1] [L2]
2. Keep manifest display names as the user-facing and CSV-facing contract, while internal storage continues to use normalized keys. Region resolution should happen through manifest-backed name lookup rather than through ad hoc importer conditionals. [L1] [L3]
3. Replace hard-coded search-region lists and special-case northeast matching with manifest-backed search metadata. For this slice, `showInPeakList`, `shortName`, and `peakListFilterAliases` are the intended manifest-backed search metadata contract unless an equivalent manifest-backed shape is introduced without changing the required behavior. [L1] [L2] [L3]
4. Do not expand the data model to support multiple stored regions or countries per `Peak`. Border handling stays a row-shaping and note-enrichment rule in this slice. [L6] [L7] [L8]
5. Use `mixed` as a dedicated persisted sentinel for mixed-region peak lists rather than misusing `Peak.defaultRegion` or forcing an arbitrary real region. Ranked import is the first producer in this slice, but the sentinel semantics are producer-agnostic. [L10]
6. Rework mixed-list visibility through existing region-visibility seams such as `peak_list_visibility.dart`, `peak_list_selection_provider.dart`, and ranked list member lookup, instead of introducing a new top-level Flutter feature surface. [L9] [L10]
7. Treat manifest `priority` as explicit canonicalization metadata rather than incidental JSON ordering. Parse it as 1 to 3 numeric segments, compare shared segments numerically, and treat a longer prefix-sharing path as more specific than its parent. [L7] [L8]
8. Preserve current storage for existing legacy data. If broader data migration becomes desirable later, handle it as a separate spec with explicit backfill rules and user-visible compatibility expectations. [L4]
9. Treat `sourceOfTruth` as dataset provenance, not geographic identity. The Slovenia tool's explicit flag or the extended ranked CSV column is the authoritative source for new imports; legacy region-derived provenance survives only as a narrow compatibility path for older FVG and Veneto files. [L11] [L12] [L13] [L14]
10. Keep the importer independent of external CLI flags at import time. Any tool-level flag must be resolved into the CSV artifact before the file reaches the app import flow. [L12] [L13]
11. Preserve ranked-import backward compatibility by supporting both exact ranked headers instead of mutating old files in place. The extended header is the forward path for all newly generated manifest-driven ranked datasets. [L13] [L14]

## Testing Strategy

1. Use behavior-first TDD for the ranked importer, mixed-region visibility logic, and Slovenia tool row-shaping/provenance changes.
2. Add focused service-level coverage for ranked importer region resolution, proving:
   1. exact manifest display-name matching after trim
   2. rejection of internal keys in CSV `region`
   3. acceptance of mixed-region ranked files
   4. persistence of `Peak.region` to specific Italian administrative-region keys and other manifest-backed region keys
   5. `PeakList.region = mixed` for mixed-region ranked imports [L1] [L3] [L5] [L10]
3. Add focused service or widget coverage for manifest-driven Search popup/filter behavior, proving:
   1. region options come from manifest-backed metadata rather than hard-coded app lists
   2. compact labels come from manifest-backed label metadata
   3. aggregate-region filters include matching child administrative regions through manifest-backed roll-up metadata
   4. hard-coded northeast-only special cases are no longer required for Search behavior [L1] [L2] [L3]
4. Add focused service coverage for manifest `priority` parsing and canonicalization ordering, proving:
   1. valid 1 to 3 segment priorities such as `2`, `2.1`, and `2.1.3` parse successfully
   2. malformed priorities fail deterministically before canonicalization proceeds
   3. numeric comparison is used instead of lexical comparison
   4. a longer prefix-sharing path outranks its parent, such as `2.1` over `2`
   5. tied winning priorities fail into deterministic review output instead of falling back to manifest file order [L7] [L8]
5. Add focused service coverage for ranked provenance validation, proving:
   1. extended-header import reads `sourceOfTruth` from the CSV
   2. trim-and-uppercase normalization
   3. mixed, blank, comma-separated, and format-invalid `sourceOfTruth` values fail atomically
   4. legacy 14-column files still map `Friuli Venezia Giulia -> FVG` and `Veneto -> VENETO`
   5. newer manifest-backed regions without `sourceOfTruth` fail under the legacy header path [L11] [L12] [L13] [L14]
6. Add focused service or tool-level coverage for the Slovenia generator and shell entrypoint, proving:
   1. the shell script forwards flags correctly
   2. `--source-of-truth` is mandatory when no input `sourceOfTruth` column exists
   3. a provided flag overrides an existing `sourceOfTruth` column
   4. output rows write uppercase resolved provenance
   5. border rows canonicalize to one country and one region and append border context to `notes` [L7] [L8] [L11] [L12]
7. Add focused service coverage for border-row canonicalization, including an Italy/Slovenia shared-peak example that canonicalizes to `country = Italy`, a specific Italian administrative-region display name, and a border note instead of a comma-separated country or region cell. [L6] [L7] [L8]
8. Add provider or widget coverage for mixed-region peak-list visibility, selection, and pinning so a persisted `mixed` list appears in each visible region where it has member peaks, pins across all canonical member regions, and still renders as a single list entry. Prefer existing fake repositories and state seams over broad UI rewrites. [L9] [L10]
9. Extend existing ranked-import Flutter flow coverage with a focused widget or robot regression for the `Import Peak List` dialog so the app still detects ranked headers correctly and surfaces success or atomic failure under the new region and provenance rules. Reuse existing fake CSV loaders and avoid real external services. [L12] [L13] [L14]
10. Automated tests for this slice must not depend on live network requests, real upstream Slovenia pages, or a real UI import filesystem path. Prefer fake peak repositories, fixture CSV rows, and deterministic manifest or polygon fixtures.

## Out of Scope

1. Modeling all ISO 3166-2:IT first-level Italian subdivisions immediately. [L2]
2. Adding multi-country or multi-region stored membership to `Peak`. [L6]
3. Migrating existing stored `Peak.region` or `PeakList.region` values. [L4]
4. Replacing all legacy ranked CSV files with the extended `sourceOfTruth` header in this slice. [L13] [L14]
5. Redesigning the broader peak-list UI beyond the behavior required for persisted mixed-region list visibility, selection, and pinning. [L9] [L10]

## Follow-Ups

1. Expand manifest-backed Italian administrative-region coverage beyond the currently needed subset once polygons, datasets, user-facing flows, and any required startup seed assets exist for the remaining ISO 3166-2:IT regions. [L2]
2. Consider a separate migration spec if the repo later wants old `italy-nord-est` or `italy-nord-ovest` stored data rewritten to specific Italian administrative-region keys. [L4]
3. If future features need true multi-country or multi-region peak identity rather than canonical single-value storage, define that as a separate schema, search, and UI slice. [L6]

## Notes

1. Relevant prior context includes `ai_specs/peak-lists/0006-ranked-peak-list-import-and-italy-north-east-subregions/spec.md` for the original ranked importer contract and `ai_specs/peak-lists/0014-slovenia-ranked-peak-list-correlation-tool/spec.md` for the existing Slovenia ranked generator contract that this slice revises. [L1] [L5] [L11] [L12] [L13] [L14]
2. `GLOSSARY.md` now defines `Italy administrative region`, `Italy aggregate region`, `Mixed-region peak list`, and `Manifest priority` as canonical project terminology for this area. [L1] [L2] [L7] [L8] [L9] [L10]
