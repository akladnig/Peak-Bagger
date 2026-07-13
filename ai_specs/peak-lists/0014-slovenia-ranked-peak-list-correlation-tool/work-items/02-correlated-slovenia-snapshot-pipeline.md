---
type: Work Item
title: Correlated Slovenia Snapshot Pipeline
parent: ../spec.md
---

## What to build
Rework the existing Slovenia crawl/export service around the new correlated artifact family. Replace the old raw `Hribi source peak list` output with a shared-version correlated snapshot that writes the canonical `Slovenia ranked peak list`, the `Correlation review CSV`, the `Repair list`, and the state JSON together while preserving the existing crawl, naming, normalization, caching, partial-output, and repair semantics unless the new visible CSV contracts explicitly supersede them.

## Required context
- Build directly on the current Slovenia service in `lib/services/slovenia_hribi_source_peak_list_service.dart` and preserve the first slice's crawl and repair behavior unless `spec.md` explicitly replaces it.
- This slice replaces the prior `slovenia-hribi-source-peaks` artifact family entirely; old raw-output snapshots are not valid repair baselines for the new correlated run family.
- Keep artifact separation strict: canonical ranked CSV for confident matches only, `Correlation review CSV` for crawled but unresolved or ambiguous rows only, and `Repair list` for crawl or missing-source-field retry rows only.
- Record machine-owned correlation bookkeeping, artifact identity, and the chosen tie-window value in state or run summaries rather than adding visible columns beyond the required trailing `correlationReason` column in the review CSV.
- Reuse the existing raw HTTP cache when available; cache behavior remains separate from versioned snapshot artifacts.

## Acceptance criteria
- [x] The Slovenia service writes a correlated snapshot with four coordinated artifacts: canonical ranked CSV, `Correlation review CSV`, `Repair list`, and state JSON.
- [x] The main visible CSV header is exactly `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes`, and the review CSV uses the same columns plus trailing `correlationReason`.
- [x] Confidently matched rows appear only in the canonical CSV, crawled unresolved or ambiguous rows appear only in the `Correlation review CSV`, and crawl or source-data retry rows remain only in the `Repair list`.
- [x] Both visible CSVs write `region` as exactly `Slovenia`, and the pipeline does not attempt to extend ranked-import support for that region in this slice.
- [x] The old raw-output artifact family is replaced by the new correlated family, `--repair-list` reads only the latest prior correlated snapshot as its baseline, and raw-only historical snapshots are rejected as repair baselines.
- [x] Version suppression occurs only when the logical contents of all visible CSV artifacts in the correlated snapshot are unchanged after deterministic ordering and normalization; any change in the canonical CSV, review CSV, or repair CSV creates a new version.
- [x] State or run-summary output records the chosen tie-window value and enough correlation bookkeeping to explain later outputs without adding hidden machine columns to the visible CSV contracts.
- [x] Service tests cover one-run emission of canonical rows, review rows, and repair rows together; preservation of repair-only semantics for crawl failures; correlated snapshot rewrite/versioning rules; reuse of the existing raw HTTP cache; and rejection of old raw-only repair baselines.

## Covers
- User Stories: 1, 2, 3, 4
- Requirements: 1, 4, 5, 8, 12
- Technical Decisions: 3, 4, 7, 8, 9, 10, 11
- Testing Strategy: 4, 5, 11
- Interview Ledger: L1, L2, L3, L5, L7

## Blocked by
- `01-read-only-slovenia-peak-correlation-service.md`
