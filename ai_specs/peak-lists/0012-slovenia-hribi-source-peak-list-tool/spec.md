---
type: Spec
title: Slovenia Hribi Source Peak List Tool
---

## Problem

Peak Bagger has repository-local tools for ranking, validating, syncing, and importing peak data, but it does not yet have a repeatable way to crawl the Slovenia mountain-range listings on `hribi.net` and turn them into a versioned raw `Hribi source peak list` artifact for later review or downstream use. The current manual workflow is slow, inconsistent about cross-border naming, and offers no repair-only rerun path when a subset of source pages fail. [L1] [L4] [L7] [L8] [L9]

## Proposed Outcome

Add a standalone Dart CLI under `tool/` that crawls the locked current 10 Slovenia range pages from `hribi.net`, confirms peak rows from `hribi.net` detail pages, enriches names from `monti.uno` using the approved country-sensitive fallback rules, normalizes `Country` and `Mountain Range` into the agreed English output contract, and writes versioned CSV, repair, and state artifacts under `assets/peaks/`. The tool must support partial-output runs, repair-only reruns, and reusable on-disk HTTP caching without mutating app/ObjectBox data or adding `osmId`. [L1] [L2] [L3] [L4] [L5] [L7] [L8] [L9] [L10] [L11] [L12]

## User Stories

1. As a repo maintainer, I can run one standalone CLI and generate a versioned raw Slovenia `Hribi source peak list` CSV without touching runtime app data or inventing `osmId` values. [L1] [L3] [L10]
2. As a maintainer reviewing Slovenia source coverage, I can crawl the current 10 configured Slovenia ranges in one pass, keep cross-border peaks that belong to those ranges, and get stable ordering between versions. [L4] [L5] [L7]
3. As a maintainer dealing with flaky upstream pages, I can keep partial output from a normal run, inspect a repair list of failed range or peak pages, and rerun only the unresolved subset with `--repair-list` rather than recrawling everything. [L8] [L9] [L10] [L11] [L12]
4. As a maintainer comparing names across languages, I can rely on the approved country-sensitive `Name` and `Alt Name` rules and the normalized `Country` and `Mountain Range` columns to produce a stable review artifact. [L4] [L5] [L6]

## Requirements

1. Add a standalone repo-local Dart CLI under `tool/`, in the same general style as existing scripts such as `tool/rank_fvg_peaks.dart`, that produces a raw `Hribi source peak list` artifact. The tool must not add `osmId`, match rows to existing `Peak` records, or modify ObjectBox/app runtime data. [L1]
2. The first version is locked to the current 10 `hribi.net` range pages listed under `Gorovja - Slovenija` and frozen in `Appendix A: Locked Slovenia Range Configuration`. Treat those 10 configured ranges as explicit app-owned scope, not as a live-discovered list that silently changes when the site changes. A normal run still targets all 10 configured ranges in the listed order. [L7] [L13]
3. Merge all configured ranges into one main CSV. Include every confirmed peak listed on those configured range pages even when the detail page country is `Italy` or multiple countries. Do not de-duplicate across ranges in the first version. [L7]
4. The main CSV header must be exactly `Name,Alt Name,Country,Mountain Range,Altitude,Latitude,Longitude,Popularity,Type`. Do not add `osmId`, source URLs, ranking fields, or other extra columns to the visible CSV. [L3] [L11]
5. Only write a row to the main CSV after the `hribi.net` detail page confirms a peak by including `vrh` in the source type. Export `Type` as exactly `Peak` for every main CSV row. Non-peak entries must stay out of the main CSV even if they appear on a source range page. [L2] [L8]
6. `Name` and `Alt Name` must follow the approved country-sensitive source matrix:
   1. For `Slovenia`-only peaks with a usable `monti.uno` page, `Name` comes from `hribi.net` and `Alt Name` comes from `monti.uno`.
   2. For `Slovenia`-only peaks where the `monti.uno` page is missing or unusable, keep the confirmed `hribi.net` name as `Name`, leave `Alt Name` blank, and keep the peak in the repair list with the missing enrichment metadata.
   3. For `Italy`-only peaks or multi-country peaks with a usable `monti.uno` page, `Name` comes from `monti.uno` and `Alt Name` comes from `hribi.net`.
   4. For `Italy`-only peaks or multi-country peaks where the required `monti.uno` page is missing or unusable, fall back to the confirmed `hribi.net` name as `Name`, leave `Alt Name` blank, and keep the peak in the repair list with the missing enrichment metadata.
   5. If `Alt Name` would duplicate `Name` after trimming whitespace, leave `Alt Name` blank. [L4]
7. Normalize `Country` to an English comma-separated list using a tool-owned mapping from `hribi.net` country text. Preserve the source order from `hribi.net` for multi-country peaks and de-duplicate repeated country names if the source repeats one. At minimum, the mapping must cover `Slovenija -> Slovenia`, `Italija -> Italy`, `Hrvaška -> Croatia`, and `Avstrija -> Austria`, and the implementation must remain app-owned rather than fetched live from a sister site. [L5]
8. `Mountain Range` must use the exact English sister-site label from `hike.uno` for the configured Slovenia range that produced the row. Do not further translate, ASCII-normalize, or dynamically fetch a different display label at runtime. [L5]
9. Normalize numeric output values as follows:
   1. `Altitude` is integer meters only.
   2. `Latitude` and `Longitude` are decimal degrees with `.` decimal separators.
   3. `Popularity` is integer percent only.
   4. Strip units, degree markers, percent signs, ranking text, and locale commas from the stored CSV values. [L6]
10. Normal runs must allow partial output rather than failing the whole command for missing upstream pages. If a configured range page fails, write an error summary and a repair entry for that range. If a peak detail page fails before type confirmation, keep the item out of the main CSV and write a repair entry with the peak name and any available context. [L8]
11. If a confirmed peak detail page is missing or cannot parse one or more non-type fields such as `Country`, `Altitude`, `Latitude`, `Longitude`, `Popularity`, or the secondary-name enrichment, still write the main CSV row with blanks for the missing values and also keep that peak in the repair list with the missing-field metadata. [L8]
12. Add a repair-only workflow triggered by `--repair-list`. The repair sidecar must have columns `Kind,RangeUrl,DetailUrl,Name,MissingFields,LastError`, with `Kind=range` for failed range pages and `Kind=peak` for failed peak detail pages. [L9]
13. `--repair-list` must read the latest prior versioned artifact set and retry only those unresolved range and peak URLs rather than falling back to a full crawl. The repair run baseline is the latest prior main CSV, repair CSV, and state JSON that share a version number. If the latest repair file does not exist, print `No repair file found. Run a normal crawl first.` and exit non-zero without creating a new versioned artifact set. [L9]
14. When a repaired `Kind=range` entry succeeds, process that recovered range end-to-end in the same repair run using the same confirmation, normalization, and enrichment rules as a normal run. Clear the original range repair entry once the range page itself is successfully processed, and keep only any still-failing peaks from that recovered range in the next repair file. [L9]
15. Every meaningful run writes a new versioned artifact set under `assets/peaks/` using the stable base name `slovenia-hribi-source-peaks`, for example `slovenia-hribi-source-peaks-V1.csv`, `slovenia-hribi-source-peaks-V1.repair.csv`, and `slovenia-hribi-source-peaks-V1.state.json`. `--repair-list` must read the latest prior version and write a new version instead of overwriting the old one. [L10]
16. If a run has no data changes and no repair-file changes, do not create a new version. Otherwise, rewrite the full current main CSV, repair CSV, and state JSON as the next versioned snapshot rather than appending new rows to an older CSV in place. Change detection must compare the logical rewritten main CSV and repair CSV contents after normalization and deterministic ordering, not incidental state-file metadata. [L10]
17. Keep the visible CSV limited to the agreed 9 columns and store machine-owned row identity in the versioned state JSON. The state artifact must store at least `RangeUrl`, `HribiDetailUrl`, and `MontiDetailUrl` when known so repair and rewrite logic can update the correct logical row without adding URL columns to the main CSV. [L11]
18. The merged CSV ordering must be deterministic and source-first: use the configured `Gorovja - Slovenija` range order, then preserve the in-range row order from the source range page. Repair runs that rewrite the full CSV must preserve that same ordering and place repaired rows back into their original logical positions when possible. [L7]
19. Cache successful `hribi.net` and `monti.uno` page fetches on disk and reuse them by default on later normal and repair runs. Keep that raw HTTP cache separate from `assets/peaks/`, and add `--refresh-cache` to ignore cached content and refetch the targeted URLs for the current run. [L12]
20. Keep this first version Slovenia-only. Do not add Croatia or Italy crawling, do not add a multi-country selector flag, and do not broaden the configured range scope beyond the current 10 Slovenia ranges in this slice. [L13]

## Technical Decisions

1. Implement the feature as a small standalone CLI plus pure/service-style crawl and transformation seams rather than a monolithic script body. The CLI should own argument parsing and user-facing summaries, while crawl, parse, normalization, versioning, and repair logic stay directly testable without spawning a process. This follows the repo pattern already used by `tool/peak_prominence_csv.dart` and its callable `run...Tool` seam. [L1] [L9] [L12]
2. Treat the 10 Slovenia ranges as app-owned configuration and hard-code the related source metadata needed for deterministic output exactly as listed in `Appendix A: Locked Slovenia Range Configuration`: the locked `hribi.net` range URLs, the exact `hike.uno` English range labels, and the corresponding sister-site translated range references needed to resolve Italian names. Do not rely on live page discovery for scope, live translations for `Country`, or a second free-form translation layer beyond the approved sister-site labels. [L5] [L7] [L13]
3. Keep the main CSV intentionally human-facing and source-agnostic while pairing it with versioned repair and state artifacts. The machine-owned state file is the source-identity seam that lets repair runs and later versions rewrite rows accurately without changing the visible CSV contract. [L3] [L10] [L11]
4. Build the network and storage behavior around injectable seams: HTTP fetchers, cache readers/writers, filesystem writers, version allocators, and clock or timestamp providers where needed for deterministic repair metadata. Prefer fakes and fixtures in tests over real upstream calls. [L8] [L9] [L10] [L12]
5. Store successful upstream responses as reusable raw cache artifacts under a separate cache directory such as `.cache/hribi-source-peaks/`. Repair runs and normal runs should reparse cached pages rather than depending on a hidden structured database or app runtime state. [L12]
6. The later Croatia/Italy expansion should be a separate slice that adds an explicit country flag plus separate configured source ranges, naming rules, and output base names. This spec intentionally does not generalize the first CLI into a multi-country contract yet. [L13]

## Repair Snapshot Semantics

1. A `--repair-list` run must load the latest prior `slovenia-hribi-source-peaks-Vn.csv`, matching `slovenia-hribi-source-peaks-Vn.repair.csv`, and matching `slovenia-hribi-source-peaks-Vn.state.json` as one baseline snapshot before retrying unresolved work.
2. The baseline main CSV and state JSON are the last-known-good visible dataset for rows that were already written in the prior version. A repair run must start from that baseline and replace only the rows whose source data is newly recovered or improved in the current run.
3. If a previously exported confirmed peak still fails during a repair run, preserve its last-known-good main CSV row from the prior version, keep the unresolved row in the new repair CSV, and update only deterministic repair metadata needed for the next rerun.
4. If a recovered `Kind=range` entry succeeds, rebuild that range using the same confirmation, normalization, enrichment, and ordering rules as a normal run, then replace the corresponding baseline rows from that configured range in the new snapshot.
5. The newly written repair CSV must contain only entries that remain unresolved after the current run. Successfully repaired range or peak entries must not remain in the next repair CSV.
6. Version suppression must compare the logical contents of the rewritten main CSV and rewritten repair CSV after deterministic ordering and normalization. Incidental state-file metadata must not force a new version when the visible CSV data and unresolved repair set are unchanged.
7. The state JSON may store deterministic row identity, source linkage, configured range order/index information, and deterministic repair metadata needed to rewrite or compare rows. Do not store timestamps, debug-only fields, or other nondeterministic values that would create meaningless version churn.

## Testing Strategy

1. Use behavior-first TDD for the crawl parsing, peak confirmation, normalization, repair-list, and versioning logic.
2. Add focused unit or service coverage for HTML extraction and transformation rules, including:
   1. source range parsing for the locked 10-range configuration
   2. `vrh`-based peak confirmation on `hribi.net` detail pages
   3. non-peak exclusion from the main CSV
   4. `Name` / `Alt Name` swap behavior for `Slovenia`-only, `Italy`-only, and multi-country peaks
   5. blank `Alt Name` behavior when the secondary page is missing or duplicates `Name`
   6. `Country` normalization and ordering
   7. exact `Mountain Range` label mapping from the sister-site labels
   8. numeric normalization for `Altitude`, `Latitude`, `Longitude`, and `Popularity` [L2] [L4] [L5] [L6] [L7]
3. Add service coverage for partial-output and repair behavior, including:
   1. failed range pages producing summary/repair entries
   2. failed peak detail pages staying out of the main CSV before type confirmation
   3. confirmed peaks with missing non-type fields writing blank values plus repair entries
   4. recovered `Kind=range` repairs recrawling that range end-to-end
   5. `--repair-list` non-zero behavior when no prior repair file exists [L8] [L9]
4. Add tool-level tests under `test/tool/` for CLI invocation behavior, including:
   1. normal run over configured ranges
   2. `--repair-list`
   3. `--refresh-cache`
   4. versioned artifact naming
   5. no-new-version behavior when both dataset and repair file are unchanged
   6. human-readable stdout/stderr summaries for partial and repair runs [L9] [L10] [L12]
5. Prefer fake HTTP clients/loaders, fixture HTML pages, fake cache/file writers, and deterministic version allocators over real network calls. Automated tests must not hit live `hribi.net`, `monti.uno`, or `hike.uno`, and must not require API keys or Flutter runtime app state.
6. Widget and robot coverage are not required for this slice because the feature is a standalone repo-local CLI rather than a Flutter UI journey. Keep testing effort focused on unit, service, and tool layers.
7. Add representative fixtures that cover at least one `Slovenia`-only peak, one `Italy`-only peak, one multi-country peak, one non-peak detail page, one failed range page, and one failed peak detail page so the country-sensitive naming and repair contracts stay regression-safe. [L2] [L4] [L8] [L9]

## Out of Scope

1. Importing the generated CSV into existing app peak-list flows, matching rows to existing peaks, or adding `osmId`. [L1]
2. Any ObjectBox, runtime Flutter UI, provider, or app-route changes. [L1]
3. Croatia and Italy crawling support, including an explicit country selector flag or country-specific source-range configuration. [L13]
4. Dynamic live expansion or reordering of the locked 10 Slovenia ranges based on future upstream website changes. [L7] [L13]
5. Cross-range de-duplication, canonical peak identity reconciliation across ranges, or merge-time suppression of repeated peaks. [L7]

## Follow-Ups

1. Add a later multi-country CLI slice for Croatia and Italy with an explicit country flag, separate configured ranges, and per-country output base names. [L13]
2. If future sister-site structure diverges, add a stronger cross-site identity strategy than assuming display-name parity; do not widen the first-version CSV contract to expose source URLs just to compensate.

## Notes

1. Relevant implementation patterns already in the repo include `tool/rank_fvg_peaks.dart` for standalone crawl-oriented CLI structure, `tool/peak_prominence_csv.dart` for callable tool seams, and `test/tool/peak_prominence_csv_test.dart` for tool-level argument and summary coverage. [L1] [L9] [L12]
2. Relevant project terminology is already captured in `GLOSSARY.md` under `Hribi source peak list` and `Repair list`. [L1] [L9]
3. Current source inspection confirmed that the Julian Alps sibling range pages on `hribi.net` and `monti.uno` expose the same count, ordering, and numeric detail IDs even though the visible names differ. The implementation may use that parity as supporting evidence, but it should not rely on slug text equality alone.

## Appendix A: Locked Slovenia Range Configuration

| Order | `hribi.net` configured range URL | Exact `hike.uno` `Mountain Range` label | Frozen translated range references |
| --- | --- | --- | --- |
| 1 | `https://www.hribi.net/gorovje/gorisko_notranjsko_in_sneznisko_hribovje/26` | `Goriško, Notranjsko and Snežniško hribovje` | `https://www.hike.uno/mountain_range/gorisko_notranjsko_and_sneznisko_hribovje/26`, `https://www.monti.uno/catena_montuosa/gorisko_notranjsko_e_sneznisko_hribovje/26` |
| 2 | `https://www.hribi.net/gorovje/julijske_alpe/1` | `Julian Alps` | `https://www.hike.uno/mountain_range/julian_alps/1`, `https://www.monti.uno/catena_montuosa/alpi_giulie/1` |
| 3 | `https://www.hribi.net/gorovje/kamnisko_savinjske_alpe/3` | `Kamnik Savinja Alps` | `https://www.hike.uno/mountain_range/kamnik_savinja_alps/3`, `https://www.monti.uno/catena_montuosa/alpi_di_kamnik-savinja/3` |
| 4 | `https://www.hribi.net/gorovje/karavanke/11` | `Karawanks` | `https://www.hike.uno/mountain_range/karawanks/11`, `https://www.monti.uno/catena_montuosa/caravanche/11` |
| 5 | `https://www.hribi.net/gorovje/pohorje_dravinjske_gorice_in_haloze/4` | `Pohorje, Dravinjske gorice and Haloze` | `https://www.hike.uno/mountain_range/pohorje_dravinjske_gorice_and_haloze/4`, `https://www.monti.uno/catena_montuosa/pohorje_dravinjske_gorice_e_haloze/4` |
| 6 | `https://www.hribi.net/gorovje/polhograjsko_hribovje_in_ljubljana/5` | `Polhograjsko hribovje and Ljubljana` | `https://www.hike.uno/mountain_range/polhograjsko_hribovje_and_ljubljana/5`, `https://www.monti.uno/catena_montuosa/polhograjsko_hribovje_e_lubiana/5` |
| 7 | `https://www.hribi.net/gorovje/posavsko_hribovje_in_dolenjska/25` | `Posavsko hribovje and Dolenjska` | `https://www.hike.uno/mountain_range/posavsko_hribovje_and_dolenjska/25`, `https://www.monti.uno/catena_montuosa/posavsko_hribovje_e_dolenjska/25` |
| 8 | `https://www.hribi.net/gorovje/prekmurje/163` | `Prekmurje` | `https://www.hike.uno/mountain_range/prekmurje/163`, `https://www.monti.uno/catena_montuosa/prekmurje/163` |
| 9 | `https://www.hribi.net/gorovje/skofjelosko_cerkljansko_hribovje_in_jelovica/21` | `Škofjeloško, Cerkljansko hribovje and Jelovica` | `https://www.hike.uno/mountain_range/skofjelosko_cerkljansko_hribovje_and_jelovica/21`, `https://www.monti.uno/catena_montuosa/skofjelosko_cerkljansko_hribovje_e_jelovica/21` |
| 10 | `https://www.hribi.net/gorovje/strojna_kosenjak_kozjak_in_slovenske_gorice/162` | `Strojna, Košenjak, Kozjak and Slovenske gorice` | `https://www.hike.uno/mountain_range/strojna_kosenjak_kozjak_and_slovenske_gorice/162`, `https://www.monti.uno/catena_montuosa/strojna_kosenjak_kozjak_e_slovenske_gorice/162` |
