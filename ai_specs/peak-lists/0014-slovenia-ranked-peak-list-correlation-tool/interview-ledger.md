---
type: Interview Ledger
parent: spec.md
---

## Records

### L1

Status: current

Question: Should the Slovenia pipeline continue producing a raw `Hribi source peak list`, or should it now produce the canonical import-ready format?

Recommended Answer:
- Make the Slovenia output a `Ranked peak list CSV`.
- Require correlation against existing ObjectBox `Peak` rows to populate `osmId`.
- Keep the current raw or unmatched data only as an internal review or repair artifact, not as the primary exported CSV.
- Do not invent synthetic `osmId` values in this pipeline.

Answer: agreed

Decision: Replace the primary Slovenia output with a `Slovenia ranked peak list` that uses correlation against existing ObjectBox `Peak` rows to populate canonical `osmId` values, without inventing synthetic ids.

Constraints:
- The primary output is no longer a raw `Hribi source peak list`.
- The pipeline must correlate against existing ObjectBox `Peak` rows.
- The pipeline must not invent synthetic `osmId` values.

### L2

Status: current

Question: What should happen when a Hribi row cannot be confidently matched to exactly one existing ObjectBox `Peak`?

Recommended Answer:
- Write only confidently correlated rows to the primary `Slovenia ranked peak list` CSV.
- Send unresolved or ambiguous rows to a separate review artifact with the raw source fields plus a correlation reason.
- Do not leave `osmId` blank in the canonical CSV.
- Do not auto-create new `Peak` records in ObjectBox as part of this pipeline.

Answer: Send unresolved or ambiguous rows to a separate review artifact with the same headers as the canonical header with osmId = 0. And add a new column at the end as the correlation reason. And do not update or create any objectBox entries. This is purely a csv file generation tool

Decision: Write confidently correlated rows to the canonical CSV, and write unresolved or ambiguous rows to a separate `Correlation review CSV` that uses the canonical header, forces `osmId = 0`, and appends a trailing `correlationReason` column.

Constraints:
- Do not leave `osmId` blank in either artifact.
- Do not create ObjectBox `Peak` rows.
- Do not update ObjectBox `Peak` rows.
- This slice is a CSV generation tool only.

Negative Requirements:
- Do not mutate ObjectBox data.

### L3

Status: current

Question: What canonical term should this Spec use for the unresolved-correlation file?

Recommended Answer:
- Use `Correlation review CSV`.
- Keep `Repair list` only for source-page crawl failures and missing upstream fields.
- Define `Correlation review CSV` as the read-only review output for unresolved or ambiguous peak-to-ObjectBox matches.

Answer: agreed

Decision: Use `Correlation review CSV` as the canonical term for the unresolved-or-ambiguous correlation output.

Reason: The project already uses `Repair list` for crawl and retry failures, so unresolved matching needs a separate durable term.

### L4

Status: current

Question: For canonical columns that Hribi does not fully own, should the output use Hribi values, matched ObjectBox `Peak` values, or a mix?

Recommended Answer:
- Use a mix with explicit precedence.
- `name`: Hribi-correlated row name
- `osmId`: matched ObjectBox `Peak.osmId`, or `0` in `Correlation review CSV`
- `rating`: derived from Hribi popularity
- `elevation`: Hribi value when present, else matched `Peak.elevation`
- `prominence`: matched `Peak.prominence`
- `latitude`, `longitude`: Hribi value when present, else matched `Peak` coordinates
- `country`: Hribi value when present, else matched `Peak.country`
- `region`, `county`, `difficulty`, `viaFerrata`, `notes`: matched ObjectBox `Peak`
- `range`: Hribi mountain-range label when present, else matched `Peak.range`
- For `Correlation review CSV`, use the same field rules, but with `osmId = 0` and append `correlationReason` as the last column.

Answer: agreed

Decision: Use a mixed-source canonical row contract with explicit field precedence between the crawled Hribi row and the matched ObjectBox `Peak`.

Constraints:
- `rating` is derived from Hribi popularity.
- `prominence` comes from the matched `Peak`.
- `region`, `county`, `difficulty`, `viaFerrata`, and `notes` come from the matched `Peak`.
- The review CSV uses the same field rules, with `osmId = 0` plus `correlationReason`.

### L5

Status: current

Question: What exact `region` value should the Slovenia canonical CSV write?

Recommended Answer:
- Write `region` as `Slovenia` in both the `Slovenia ranked peak list` and `Correlation review CSV`.
- Treat this as a new ranked-import region alongside the existing FVG and Veneto values.
- Keep the CSV generator read-only; any importer support for `Slovenia` is a separate follow-up if needed.

Answer: agreed

Decision: Write `region` as exactly `Slovenia` in both Slovenia output CSVs.

Constraints:
- Do not use the internal key `slovenia` in the canonical CSV.
- Any ranked-import support for `Slovenia` is outside this slice.

### L6

Status: current

Question: What should count as a confident match between a Hribi row and an existing ObjectBox `Peak` when generating `osmId`?

Recommended Answer:
- Match in this order:
- 1. Exact coordinate match within 150m, preferring the nearest peak.
- 2. Require a strong name confirmation against `Peak.name` or `Peak.altName` for any candidate beyond 50m.
- 3. If multiple candidates remain effectively tied, send the row to `Correlation review CSV`.
- 4. If no candidate passes the distance and name checks, send the row to `Correlation review CSV`.
- 5. Use matched `Peak.altName` as a valid name target during correlation, not just `Peak.name`.

Answer: agreed

Decision: Use a conservative read-only correlation policy based on distance-first matching, stronger name confirmation beyond close-range matches, and review-file fallback for ties or non-confident results.

Constraints:
- Prefer the nearest peak within 150m.
- For candidates beyond 50m, require strong confirmation against `Peak.name` or `Peak.altName`.
- Ties and non-confident results go to `Correlation review CSV`.

### L7

Status: current

Question: Should source-crawl failures remain separate from correlation failures?

Recommended Answer:
- Keep them separate.
- Use `Repair list` only for upstream crawl or retry problems.
- Use `Correlation review CSV` only for rows that were crawled successfully but could not be confidently matched.
- A run can produce all three outputs: canonical CSV, correlation review CSV, and repair list.

Answer: agreed

Decision: Keep crawl and source-data failures in the `Repair list`, and keep unresolved correlations in the `Correlation review CSV`.

Constraints:
- A single run may emit the canonical CSV, `Correlation review CSV`, and `Repair list` together.
