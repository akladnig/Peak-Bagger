---
type: Spec
title: Slovenia Ranked Peak List Correlation Tool
---

## Problem

The first Slovenia CLI slice currently produces a raw `Hribi source peak list` artifact, but the next workflow step needs a canonical CSV shaped like the existing `Ranked peak list CSV` contract: `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes`. The current Slovenia tool does not correlate rows to existing ObjectBox `Peak` records, so it cannot populate `osmId`, and it does not yet split crawl failures from correlation failures into separate artifacts. At the same time, this slice must remain a read-only CSV generator and must not update or create ObjectBox data. [L1] [L2] [L3] [L4] [L7]

## Proposed Outcome

Extend the existing Slovenia CLI so its primary output becomes a `Slovenia ranked peak list` in the canonical ranked CSV column order, populated by correlating successfully crawled Hribi rows against existing ObjectBox `Peak` records. Rows that correlate confidently write to the canonical CSV with matched `osmId` values. Rows that crawl successfully but remain unresolved or ambiguous write to a separate `Correlation review CSV` that uses the same canonical columns, forces `osmId = 0`, and appends `correlationReason` as a trailing column. Keep the existing `Repair list` workflow for upstream crawl or missing-source-field failures, and keep the entire slice read-only with respect to ObjectBox. [L1] [L2] [L3] [L4] [L5] [L6] [L7]

## User Stories

1. As a repo maintainer, I can run the Slovenia CLI and get a canonical `Slovenia ranked peak list` CSV that downstream ranked-import flows can recognize structurally, without hand-editing columns or `osmId` values. [L1] [L4] [L5]
2. As a maintainer reviewing difficult matches, I can inspect a separate `Correlation review CSV` for unresolved or ambiguous rows, with canonical columns plus a correlation reason, instead of having the tool guess wrong `osmId` values. [L2] [L3] [L6]
3. As a maintainer handling flaky upstream pages, I can keep using the existing `Repair list` retry workflow for crawl or source-field failures, separate from correlation review. [L3] [L7]
4. As a maintainer protecting app data, I can generate both Slovenia CSV artifacts using existing ObjectBox `Peak` rows as read-only correlation input, without creating or updating any ObjectBox records. [L2]

## Requirements

1. Change the primary Slovenia output contract from the raw `Hribi source peak list` visible header to the canonical ranked CSV header `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes`. The primary output of this slice is now a `Slovenia ranked peak list`. [L1]
2. Populate canonical rows by correlating successfully crawled Slovenia source rows against existing ObjectBox `Peak` records. The pipeline may read existing `Peak` rows for correlation and field backfill, but it must not create, update, or otherwise mutate ObjectBox data. [L1] [L2]
3. Do not invent synthetic `osmId` values. A row may appear in the canonical CSV only when the tool has a confident correlation to exactly one existing ObjectBox `Peak`, in which case the row must use that matched `Peak.osmId`. [L1] [L2] [L6]
4. When a successfully crawled row cannot be confidently matched to exactly one existing ObjectBox `Peak`, write it to a separate `Correlation review CSV` instead of the canonical CSV. The review CSV must:
   1. use the same canonical columns and ordering as the main ranked CSV
   2. force `osmId` to `0`
   3. append `correlationReason` as the final column [L2] [L3]
5. Keep the existing `Repair list` dedicated to crawl or source-data failures such as failed range pages, failed detail pages, or missing upstream fields that require a retry path. Do not collapse repair rows into the `Correlation review CSV`. A single run may emit the canonical CSV, the `Correlation review CSV`, and the `Repair list`. [L3] [L7]
6. Build canonical row values using this field-precedence contract for confidently matched rows:
   1. `name`: the resolved Hribi-based row name from the existing Slovenia naming rules
   2. `osmId`: matched `Peak.osmId`, or `0` in the `Correlation review CSV`
   3. `rating`: derived from Hribi popularity
   4. `elevation`: Hribi value when present, otherwise matched `Peak.elevation`
   5. `prominence`: matched `Peak.prominence`
   6. `latitude` and `longitude`: Hribi values when present, otherwise matched `Peak.latitude` and `Peak.longitude`
   7. `country`: Hribi value when present, otherwise matched `Peak.country`
   8. `region`, `county`, `difficulty`, `viaFerrata`, and `notes`: matched `Peak` values
   9. `range`: Hribi mountain-range label when present, otherwise matched `Peak.range` [L4]
7. Build `Correlation review CSV` row values using this conservative contract:
   1. `name`: the resolved Hribi-based row name from the existing Slovenia naming rules
   2. `osmId`: always `0`
   3. `rating`: derived from Hribi popularity
   4. `elevation`: Hribi value when present, otherwise blank
   5. `prominence`: blank
   6. `latitude` and `longitude`: Hribi values when present, otherwise blank
   7. `country`: Hribi value when present, otherwise blank
   8. `region`: exactly `Slovenia`
   9. `range`: Hribi mountain-range label when present, otherwise blank
   10. `county`, `difficulty`, `viaFerrata`, and `notes`: blank
   11. `correlationReason`: a deterministic reason code from the approved review-reason vocabulary
   Review rows must not copy field values from a non-confident candidate `Peak` just for reviewer convenience. [L2] [L4] [L5] [L6]
8. Write `region` as exactly `Slovenia` in both the canonical CSV and the `Correlation review CSV`. Do not use the internal storage key `slovenia` in the visible CSV contract. [L5]
9. Use a conservative confidence policy for correlation:
   1. Start with distance-based candidates within 150m and prefer the nearest peak.
   2. For any selected candidate beyond 50m, require strong name confirmation against either `Peak.name` or `Peak.altName`.
   3. In this slice, strong name confirmation means normalized exact matching only: trim whitespace, case-fold, and ignore diacritic and punctuation differences before comparing the Hribi-derived row name against `Peak.name` or `Peak.altName`.
   4. Do not use fuzzy or Levenshtein-style name matching in this slice.
   5. If multiple candidates pass the confidence rules and their distances differ by no more than the configured tie window in meters, treat the row as unresolved and write it to the `Correlation review CSV`.
   6. If no candidate passes the distance and name checks, treat the row as unresolved and write it to the `Correlation review CSV`. [L6]
10. Treat `Peak.altName` as a valid name target during correlation, not just `Peak.name`, so cross-language or alternate-name peaks can still resolve without mutating stored data. [L6]
11. Expose the tie window as a CLI flag in meters. The flag must default to `10`, may be set to `0`, and affects only tie handling. It must not change the 50m strong-name threshold or the 150m candidate search radius. Record the chosen tie-window value in run state or run summaries so differing outputs remain explainable. [L6]
12. Preserve the existing Slovenia-source naming, country normalization, range-label normalization, crawl confirmation, caching, partial-output, and repair semantics from the first Slovenia slice unless the canonical ranked CSV contract above explicitly supersedes the visible raw CSV format or the artifact-family requirements below replace the old raw-output snapshot contract. [L1] [L4] [L7]

## Technical Decisions

1. Implement this as an extension of the existing Slovenia CLI and service seams rather than as a Flutter UI flow or an ObjectBox data-migration path. The tool remains repo-local, service-testable, and read-only against app storage. [L1] [L2]
2. Reuse existing read-only data seams where possible: the current Slovenia crawl/parsing/versioning services for source acquisition, the existing ObjectBox-backed `PeakRepository` or equivalent storage seam for loading current `Peak` rows, and existing correlation patterns from other repo-local CSV correlation tools where applicable. Prefer extracting a dedicated Slovenia correlation service only if the existing service contracts do not fit without broad coupling. [L1] [L2] [L6]
3. Treat artifact separation as a first-class design boundary:
   1. canonical ranked CSV = confidently matched rows only
   2. `Correlation review CSV` = crawled but unresolved or ambiguous rows
   3. `Repair list` = crawl or source-data retry rows [L2] [L3] [L7]
4. Keep the canonical CSV user-facing and deterministic. Keep machine-owned source identity, repair metadata, and any correlation bookkeeping in state or auxiliary artifacts rather than adding extra hidden columns to the canonical CSV. The only allowed visible review-only column addition is trailing `correlationReason` in the `Correlation review CSV`. [L2] [L3]
5. Do not change ObjectBox records during correlation, even when Hribi data or matched ranked fields differ from stored `Peak` values. This slice uses ObjectBox only as a source for lookup and field backfill. [L2] [L4]
6. Treat ranked-import support for visible CSV `region = Slovenia` as a separate follow-up. This slice is responsible only for generating the CSVs, not for extending the ranked importer to accept them. [L5]
 7. This slice replaces the prior `slovenia-hribi-source-peaks` artifact family entirely. The old raw-output snapshots are not valid repair baselines for this slice, and backward compatibility with that artifact family is out of scope. [L1] [L3] [L7]
 8. Each meaningful run must write one shared-version Slovenia correlation snapshot that includes the canonical ranked CSV, the `Correlation review CSV`, the `Repair list`, and the state JSON. `--repair-list` must read only the latest prior snapshot from this new correlated artifact family. [L1] [L2] [L3] [L7]
 9. Suppress a new version only when the logical contents of all visible CSV artifacts in the correlated snapshot are unchanged after deterministic ordering and normalization. A change in the canonical CSV, `Correlation review CSV`, or `Repair list` must create a new version. [L1] [L2] [L3] [L7]
 10. Replacing the old artifact family does not invalidate the existing raw HTTP cache. The tool may reuse previously cached successful `hribi.net` and `monti.uno` page responses when building the new correlated snapshot because the cache is separate from versioned output snapshots. `--refresh-cache` continues to bypass cached responses for the targeted run. [L7]
 11. Use a deterministic `correlationReason` code in the visible `Correlation review CSV`. In this slice, allowed codes are `missing_hribi_coordinates`, `no_candidate_within_150m`, `name_mismatch_beyond_50m`, `multiple_tied_candidates`, `multiple_name_confirmed_candidates`, and `insufficient_source_data_for_correlation`. Do not write free-form review-only prose into `correlationReason` in this slice. Any richer diagnostic detail may appear in state or run summaries instead of the visible CSV contract. [L2] [L3] [L6]

## Testing Strategy

1. Use behavior-first TDD for the new correlation and canonical-row-shaping logic.
2. Add focused service coverage for confident-match resolution, including:
   1. nearest-candidate selection within 150m
   2. strong-name confirmation against `Peak.name` and `Peak.altName`
   3. beyond-50m matches requiring strong name confirmation
   4. tied candidates falling into `Correlation review CSV`
   5. no-confident-match rows falling into `Correlation review CSV` [L6]
3. Add service coverage for canonical field precedence, proving the generator mixes Hribi and matched `Peak` values exactly as specified for `rating`, `elevation`, `prominence`, coordinates, `country`, `region`, `county`, `difficulty`, `viaFerrata`, `notes`, and `range`. [L4] [L5]
4. Add service or tool-level coverage for artifact separation, proving that one run can emit:
   1. canonical ranked rows with matched `osmId`
   2. `Correlation review CSV` rows with `osmId = 0` and `correlationReason`
   3. `Repair list` rows for crawl or missing-source failures [L2] [L3] [L7]
5. Add regression coverage that no ObjectBox rows are created or updated during a run, including when a row matches confidently, when a row lands in the `Correlation review CSV`, and when crawl failures produce repair entries. Prefer in-memory or fake storage seams over real app data mutation. [L2]
6. Keep automated testing focused on unit, service, and tool layers. Widget and robot coverage are not required for this slice because the feature remains a standalone repo-local CLI rather than a Flutter UI journey.
7. Prefer fake repositories, fixture crawled rows, and deterministic correlation inputs over live network or live ObjectBox state. Automated tests must not hit upstream sites or require app runtime side effects.
 8. Add coverage proving `Correlation review CSV` rows leave matched-peak-dependent fields blank rather than copying values from non-confident candidates.
 9. Add focused coverage for strong-name confirmation normalization, tie-window handling, and the CLI flag boundaries, including `0`, the default value, and the guarantee that the flag does not change the 50m or 150m thresholds.
 10. Add focused coverage for the allowed `correlationReason` code vocabulary so each review path emits the expected deterministic code rather than free-form prose.
 11. Add regression coverage for the new correlated snapshot versioning rules, including reuse of the existing raw HTTP cache, rejection of old raw-only artifact snapshots as repair baselines, and no-new-version behavior only when all visible CSV artifacts are unchanged.

## Out of Scope

1. Creating or updating ObjectBox `Peak` rows during Slovenia CSV generation. [L2]
2. Extending the ranked importer to accept `region = Slovenia` in this same slice. [L5]
3. Replacing or merging the existing `Repair list` with unresolved-correlation output. [L3] [L7]
4. Broadening the Slovenia tool into a general-purpose multi-region correlation framework in this slice.

## Follow-Ups

1. Extend `PeakListImportService` ranked-region mappings when the app should import `Slovenia ranked peak list` files directly, including the agreed visible `region = Slovenia` contract. [L5]
2. If correlation rules need reuse across multiple non-Tasmanian generators, extract a shared read-only peak-correlation service once the second consumer proves the abstraction.

## Notes

1. Relevant existing context includes `ai_specs/peak-lists/0012-slovenia-hribi-source-peak-list-tool/spec.md` for the first raw-source slice and `ai_specs/peak-lists/0006-ranked-peak-list-import-and-italy-north-east-subregions/spec.md` for the canonical ranked CSV importer contract and the current unsupported-region behavior for `Slovenia`. [L1] [L5]
2. `GLOSSARY.md` now defines `Slovenia ranked peak list` and `Correlation review CSV` as canonical terms for this slice. [L1] [L3]
