---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the ranked CSV `region` contract stay as a special ranked-import mapping with northeast exceptions, or should the project treat specific Italian regions such as FVG and Veneto as the real stored regions?

Recommended Answer:
- Use manifest region labels as the default ranked-import contract for top-level regions.
- Import `Slovenia` as `Peak.region = slovenia` and `PeakList.region = slovenia`.
- Keep `Friuli Venezia Giulia` and `Veneto` as explicit `Italy North East subregion` exceptions.

Answer: I don't like the exceptions. I think the regions should be set at the fvg and veneto level. Italy-nord-est and italy-nord-ovest are unions of the underlying 15 real regions as per https://en.wikipedia.org/wiki/ISO_3166-2:IT.

Decision: Treat specific Italian administrative regions such as FVG and Veneto as the real stored/search regions, and treat `italy-nord-est` and `italy-nord-ovest` as aggregate union regions rather than exception-backed primary regions.

Answer History:
- Initial recommendation: keep FVG and Veneto as exceptions under broader manifest-backed regions.
- Revised and final answer: reject exceptions and make specific Italian regions the real canonical regions.

Reason: The aggregate Italy north-east and north-west keys represent unions, not the durable region identity the project should store for ranked peaks.

### L2

Status: current

Question: Should the manifest model every ISO 3166-2:IT first-level Italian subdivision now, or only the Italian regions currently needed by the app?

Recommended Answer:
- Model the currently needed Italian administrative regions as real manifest regions now.
- Keep `italy-nord-est` and `italy-nord-ovest` as aggregate regions only when the app needs broad grouping.
- Store imported ranked peaks and ranked peak lists against the specific Italy administrative region, never the aggregate.
- Do not add all 20 ISO 3166-2:IT first-level subdivisions until there are polygons/assets or user-visible flows for them.

Answer: agreed

Decision: Add only the currently needed Italian administrative regions now, while keeping the aggregate Italy north-east and north-west regions for grouping only.

Constraints:
- Do not model all ISO 3166-2:IT first-level subdivisions yet.
- Use specific Italian administrative regions for stored ranked peak data.

### L3

Status: current

Question: Once ranked import becomes manifest-driven, should the CSV `region` column use display names, internal keys, or both?

Recommended Answer:
- The CSV `region` column should use exact manifest display names, not internal keys.
- Examples: `Slovenia`, `Friuli Venezia Giulia`, `Veneto`, `Trentino-Alto Adige`, `Emilia-Romagna`.
- Internal keys such as `slovenia`, `fvg`, `veneto`, or `italy-nord-est` should not be accepted in CSV files.

Answer: agreed

Decision: Ranked CSV files use exact manifest display names for `region`, and do not accept internal region keys.

### L4

Status: current

Question: Should the manifest-driven region change migrate existing stored `Peak.region` and `PeakList.region` values, or apply only to new and updated imports?

Recommended Answer:
- Apply the new model to new and updated imports going forward.
- Keep existing stored values unchanged unless a separate migration is explicitly defined later.
- Do not silently rewrite old `italy-nord-est` or `italy-nord-ovest` records.
- Handle compatibility through lookup or alias logic rather than immediate migration.

Answer: agreed

Decision: Apply the new region model only to new and updated ranked imports, with no silent migration of existing stored data in this slice.

Negative Requirements:
- Do not rewrite existing stored region values in this slice.

### L5

Status: current

Question: Should one `Ranked peak list CSV` still be limited to a single region, or can one file mix rows from multiple regions?

Recommended Answer:
- Keep one ranked CSV file limited to a single manifest region.
- If a file mixes regions such as `Friuli Venezia Giulia` and `Veneto`, fail the entire import atomically.

Answer: it should allow mixed regions as some peaks straddle regions and countries - unless there is a better way to handle this?

Decision: Ranked CSV files may contain rows from multiple canonical regions, including border-related cases.

Reason: Some peaks straddle region and country boundaries, so region diversity alone must not invalidate an import file.

### L6

Status: current

Question: For peaks on a region or country boundary, should the app store multiple countries or regions per peak, or keep one canonical stored country and region?

Recommended Answer:
- Keep exactly one canonical stored `Peak.region` and one canonical stored `Peak.country` in this slice.
- Let ranked CSV files contain mixed regions.
- Trust the row's canonical `country` and `region` values for storage.
- Do not add multi-region or multi-country membership in this slice.

Answer: agreed

Decision: Keep one canonical stored `country` and one canonical stored `region` per peak even when ranked files may mix border-related rows.

Negative Requirements:
- Do not add multi-country or multi-region stored peak membership in this slice.

### L7

Status: current

Question: How should a row like `Monte Nachnoi ... Italy, Slovenia ... Italy, Slovenia ...` be handled or modified for the canonical ranked CSV?

Recommended Answer:
- The ranked CSV must emit exactly one `country` and one `region` per row.
- Comma-separated values like `Italy, Slovenia` are not valid in the canonical import CSV.
- The generator should resolve the canonical `country` and `region` from the peak coordinates against manifest polygons before writing the CSV.
- If the point falls in more than one country or region polygon, the generator should still choose one canonical pair and append the border fact to `notes`.
- The importer should reject rows whose `country` or `region` cells contain multiple comma-separated values.

Answer: agreed. That means that the tool tool/slovenia_hribi_source_peak_list.dart will need to be modified to save a single country and region, with an updated notes field as per above plus if the shared country is Italy, then the country and region need to be updated to Italy, not Slovenia.

Decision: Canonical ranked rows must have exactly one country and one region, and the Slovenia tool must rewrite border rows accordingly and append border context to `notes`.

Examples:
- Comma-separated `country` or `region` cells are not valid canonical ranked-import values.

### L8

Status: current

Question: When a shared border peak canonicalizes to the Italian side, should the ranked row use the broad `Italy` region label or the specific Italian administrative-region name?

Recommended Answer:
- Use `country = Italy`.
- Use the specific Italian administrative-region display name in `region`, not `Italy`.
- For `Monte Nachnoi`, if the canonical Italian side is FVG, write `region = Friuli Venezia Giulia` and append `Border peak with Slovenia` to `notes`.

Answer: agreed

Decision: Italy-border peaks canonicalize to `country = Italy` plus a specific Italian administrative-region display name, never to a broad `Italy` region label.

### L9

Status: current

Question: When a ranked-imported `PeakList` contains peaks from multiple canonical regions, how should that list behave in the Flutter UI?

Recommended Answer:
- A mixed-region peak list should appear in every visible region where at least one member peak belongs.
- List visibility, pinning, and selection should be derived from the member peaks' canonical regions, not from one single `PeakList.region` value.
- `PeakList.region` should no longer be treated as the sole source of truth for ranked-imported lists.
- For non-ranked legacy lists, keep the existing single-region behavior unless a later migration changes them.

Answer: agreed

Decision: Mixed-region ranked lists appear in every visible region where they have member peaks, and their UI visibility derives from member peaks rather than a single stored region field.

### L10

Status: current

Question: What stored `PeakList.region` value should a mixed-region ranked import use, given that the current `PeakList` entity still requires one string?

Recommended Answer:
- Introduce a dedicated internal sentinel key such as `mixed`.
- Use `PeakList.region = mixed` for ranked-imported lists that contain peaks from more than one canonical region.
- Keep single-region ranked imports storing their one canonical region key as before.
- `mixed` is not a manifest region and should not be shown as a user-facing region label.

Answer: agreed

Decision: Use `mixed` as the persisted sentinel `PeakList.region` value for mixed-region ranked imports.

### L11

Status: current

Question: Should ranked provenance continue to be inferred from `region`, or should the producing tool supply an explicit source-of-truth value?

Recommended Answer:
- Change `Peak.sourceOfTruth` to reflect the producing ranked dataset or tool, not the canonical stored region.
- Rows from `tool/slovenia_hribi_source_peak_list.dart` could import with a dedicated provenance label such as `SLOVENIA`, even when a border peak canonicalizes to Italy.

Answer: i think a better way to go is to add a mandatory flag to the tool which specifies the sOT - in this instance it would be HRIBI. lowercase text would need to be uppercased

Decision: Ranked provenance must be supplied explicitly by the producing tool via a source-of-truth flag and normalized to uppercase rather than inferred from the stored region.

Constraints:
- Lowercase input must be uppercased.

### L12

Status: current

Question: How should the tool flag and CSV contract interact for `sourceOfTruth`?

Recommended Answer:
- Add a required `sourceOfTruth` column to the ranked CSV header.
- Add a mandatory tool flag such as `--source-of-truth hribi`.
- The tool must uppercase and trim that value before writing.
- The importer must read `sourceOfTruth` from the CSV, not infer it from `region`.

Answer: change the tool so that it can be run as a shell script and add a tool flag. If an optional sourceOfTruth column is provided in the csv file use that, otherwise mandate the flag. If a flag is set override the sourceOfTruth column if it exists. The tool must uppercase and trim that value before writing, so hribi becomes HRIBI. if a sourceOfTruth column is provided Every row in one ranked CSV file must carry the same non-blank sourceOfTruth value. If a file has mixed, blank, or invalid sourceOfTruth values, fail the import atomically.

Decision: Add a shell-script entrypoint and a source-of-truth tool flag, with CSV column support that is overridden by the flag when present; all row values must normalize to one shared non-blank uppercase provenance label.

Constraints:
- If the CSV lacks a `sourceOfTruth` column, the flag is mandatory.
- If the flag is provided, it overrides the CSV column.
- Mixed, blank, or invalid `sourceOfTruth` values fail atomically.

### L13

Status: current

Question: During the transition, should the ranked importer accept both the old ranked header and a new header that includes `sourceOfTruth`?

Recommended Answer:
- Support both exact ranked CSV headers.
- When the `sourceOfTruth` column exists, all non-blank rows must carry the same normalized value.
- The importer must not depend on any external CLI flag at import time.

Answer: agreed

Decision: Support both the legacy ranked header and the extended ranked header with `sourceOfTruth`, with the importer reading provenance from the CSV itself when the extended header is used.

Negative Requirements:
- The app importer must not require a CLI flag at import time.

### L14

Status: current

Question: For legacy ranked CSV files that use the old header without `sourceOfTruth`, what should the importer persist to `Peak.sourceOfTruth`?

Recommended Answer:
- Keep backward compatibility for legacy 14-column ranked CSV files only.
- Derive `sourceOfTruth` from the existing legacy region contract exactly as today for supported old inputs:
  - `Friuli Venezia Giulia` -> `FVG`
  - `Veneto` -> `VENETO`
- For manifest-driven regions such as `Slovenia`, `Trentino-Alto Adige`, or `Emilia-Romagna`, require the explicit `sourceOfTruth` column and do not infer provenance from `region`.

Answer: agreed

Decision: Preserve legacy region-derived provenance only for old FVG and Veneto ranked files, and require explicit `sourceOfTruth` for newer manifest-driven regions.

Reason: This keeps backward compatibility for already-supported files without silently guessing provenance for newer regions.
