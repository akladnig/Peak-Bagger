---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should this work produce an import-ready peak list or a standalone raw source extract tool?

Answer: For this initial version extract to csv only... do not add osmId.

Decision: Build a standalone Dart CLI under `tool/`, similar in style to `tool/rank_fvg_peaks.dart`, that outputs a raw `Hribi source peak list` CSV and does not add `osmId` or mutate app/ObjectBox data.

Constraints:
- Output is CSV-only in this first version.
- Do not modify app runtime data.
- Do not match rows to existing app peaks.

### L2

Status: current

Question: Which listed items count as peaks, and what should the exported `Type` value be?

Recommended Answer:
- Output only summit/peak entries.
- Use the detail-page type field to confirm that the source item is a peak.
- Write `Type` as exactly `Peak` in the CSV.

Answer: agreed. Use the "Type" field with the setting of Peak ... agreed

Decision: Only include rows whose `hribi.net` detail page confirms a peak by including `vrh` in the source type, and write the CSV `Type` value as exactly `Peak`.

Negative Requirements:
- Do not include huts, lakes, waterfalls, churches, caves, viewpoints, or other non-peak POIs in the main CSV.
- Do not write an unconfirmed item to the main CSV if the detail page failed before type confirmation.

### L3

Status: current

Question: What exact columns should the CSV export contain?

Answer: extract to csv only, with the following columns which are extracted from the details page ... `Name, Country, Mountain Range, Altitude, Latitude, Longitude, Popularity, Type`. do not add osmId ... Add a new column Alt Name, which is the name of the peak from monti.uno

Decision: The main CSV header must be exactly `Name,Alt Name,Country,Mountain Range,Altitude,Latitude,Longitude,Popularity,Type`.

Negative Requirements:
- Do not add `osmId`.
- Do not add source URL columns to the visible CSV.

### L4

Status: current

Question: How should `Name` and `Alt Name` be sourced across Slovenian, Italian, and multi-country peaks?

Answer: use hribi.net as the base url, and monti.uno as the secondary ... if the peak in question is actually in Italy, then Name should come from monti.uno and alt name from hribi.net ... In the case where a peak resides in multiple countries, use Name from monti.uno and Alt Name from hribi.net ... agreed

Decision: Use `hribi.net` as the primary Slovenian source and `monti.uno` as the secondary Italian source. For `Slovenia`-only peaks, `Name` comes from `hribi.net` and `Alt Name` comes from `monti.uno`. For `Italy` or multi-country peaks, `Name` comes from `monti.uno` and `Alt Name` comes from `hribi.net`.

Constraints:
- If the secondary page is missing or unusable, keep the primary name and leave `Alt Name` blank.
- If `Alt Name` would duplicate `Name` after trimming whitespace, leave `Alt Name` blank.

### L5

Status: current

Question: How should `Country` and `Mountain Range` values be normalized in the output CSV?

Recommended Answer:
- Normalize `Country` to an English comma-separated list using a tool-owned mapping.
- Normalize `Mountain Range` to the English sister-site label from `hike.uno`.
- Preserve the exact `hike.uno` wording rather than translating it again.

Answer: the country names should become an english normalised comma separated list e.g. Italy, Slovenia, Croatia etc. ... yes use the english names from the sister site hike.uno ... agreed ... preserve the exact `hike.uno` range labels as the canonical `Mountain Range` values.

Decision: Normalize `Country` to an English comma-separated list using a tool-owned mapping from `hribi.net` country text, while `Mountain Range` must use the exact `hike.uno` English sister-site labels for the locked Slovenia ranges.

Constraints:
- Preserve `hribi.net` country order for multi-country peaks.
- De-duplicate repeated country names if the source repeats them.
- Do not further translate or ASCII-normalize the chosen `hike.uno` range labels.

### L6

Status: current

Question: What exact formatting rules should the exported numeric fields use?

Recommended Answer:
- `Altitude`: integer meters only.
- `Latitude` and `Longitude`: decimal degrees with `.` separators.
- `Popularity`: integer percent only.

Answer: agreed

Decision: Export `Altitude` as integer meters, `Latitude` and `Longitude` as decimal degrees with `.` separators, and `Popularity` as integer percent values.

Constraints:
- Strip units, degree markers, percent signs, ranking text, and locale commas from the stored CSV values.

### L7

Status: current

Question: What source ranges are in scope, and how should the tool order and merge them?

Recommended Answer:
- Merge the configured ranges into one CSV.
- Preserve deterministic source-first order.
- Do not de-duplicate across ranges in the first version.

Answer: agreed. In fact include all 10 ranges in Slovenia as shown under the heading `Gorovja - Slovenija` ... agreed ... lock the first version to the current 10 Slovenia range URLs.

Decision: The first version is locked to the current 10 `hribi.net` ranges under `Gorovja - Slovenija`, merged into one CSV, ordered by the source range order and then the in-range listing order, without cross-range de-duplication.

Answer History:
- Initial answer: use the two example Slovenia ranges only.
- Final answer: include all 10 current Slovenia ranges shown under `Gorovja - Slovenija`.

Constraints:
- Include every confirmed peak listed on those 10 range pages, even if the peak country is `Italy` or multiple countries.
- A normal full run still targets all 10 configured ranges.

### L8

Status: current

Question: What should happen when pages or fields are missing during a crawl?

Answer: Do not fail. write partial data. if a range page is missing write an error summary, if a peak detail page fails to load, write the peak name and any available details ... agreed ... If a confirmed peak detail page lists missing fields, keep the row with blanks and also add it to the repair list.

Decision: Normal runs must allow partial output. Missing range pages produce an error summary and repair entries. Failed peak detail pages produce repair entries with any available context. Confirmed peak pages with missing non-type fields still write a main CSV row with blanks and also remain in the repair list.

Constraints:
- Only write a row to the main CSV after the `hribi.net` detail page has confirmed `vrh`.
- If type confirmation never happened, keep the item out of the main CSV and only in repair artifacts.
- Missing or unparsable `Country`, `Altitude`, `Latitude`, `Longitude`, `Popularity`, or `Alt Name` do not block a confirmed peak row from the main CSV.

### L9

Status: current

Question: What repair workflow should exist for missing data?

Recommended Answer:
- Add a repair-only flag that retries unresolved items from a sidecar repair file.
- Use explicit repair rows for failed ranges and peaks.

Answer: Allow a subsequent run of the tool with a flag like `repair-list` to re-run and only load missing data ... agreed ... On `--repair-list`, read only that repair file and retry just those missing range/detail URLs ... When a range row from the repair list is retried successfully, immediately crawl the recovered range end-to-end.

Decision: Add a `--repair-list` workflow that reads the latest repair file and retries only unresolved range and peak sources. If a repaired range page succeeds, process that range end-to-end in the same repair run.

Constraints:
- The repair sidecar must have columns `Kind,RangeUrl,DetailUrl,Name,MissingFields,LastError`.
- Use `Kind=range` for failed range pages and `Kind=peak` for failed peak detail pages.
- If `--repair-list` is invoked with no prior repair file, print `No repair file found. Run a normal crawl first.` and exit non-zero without creating a new version.

### L10

Status: current

Question: How should versioned output files be written and stored?

Recommended Answer:
- Write a new versioned CSV, repair file, and state file for each meaningful run.
- Save them beside each other under `assets/peaks/`.

Answer: save as a new version by appending for example V1 to the file name ... save to assets/peaks/ ... agreed

Decision: Save versioned run artifacts under `assets/peaks/` using the stable base name `slovenia-hribi-source-peaks`, for example `slovenia-hribi-source-peaks-V1.csv`, `slovenia-hribi-source-peaks-V1.repair.csv`, and `slovenia-hribi-source-peaks-V1.state.json`.

Constraints:
- `--repair-list` reads the latest prior version and writes a new versioned artifact set instead of overwriting the earlier files.
- If a run has no data changes and no repair-file changes, do not create a new version.

### L11

Status: current

Question: Should source URLs appear in the visible CSV, or live in a separate state artifact?

Recommended Answer:
- Keep the visible CSV limited to the agreed 9 columns.
- Store row identity and source URLs in a separate machine-owned state file.

Answer: agreed

Decision: Keep the main CSV limited to the 9 visible columns and store source identity in a versioned state JSON file.

Constraints:
- The state file must store at least `RangeUrl`, `HribiDetailUrl`, and `MontiDetailUrl` when known.
- Repair and rewrite logic must use the state file rather than adding URL columns to the main CSV.

### L12

Status: current

Question: Should successful source pages be cached and reused on later runs?

Recommended Answer:
- Cache successful pages on disk.
- Reuse them by default.
- Add a refresh flag to bypass cached pages.

Answer: agreed

Decision: Cache successful `hribi.net` and `monti.uno` fetches on disk, reuse them by default on later normal and repair runs, and add `--refresh-cache` to refetch targeted URLs.

Constraints:
- Keep the raw HTTP cache separate from the versioned CSV, repair file, and state file.

### L13

Status: current

Question: Should this first version expand now into Croatia and Italy support, or stay Slovenia-only?

Recommended Answer:
- Keep this first version Slovenia-only.
- Add Croatia and Italy in the next version with an explicit country flag and separate configured source ranges.

Answer: agreed

Decision: Keep the first version locked to Slovenia. Croatia and Italy support move to a later version that introduces an explicit country flag and separate configured range sets.

Negative Requirements:
- Do not expand this first version into a multi-country crawler.
- Do not add a country selector in this slice.
