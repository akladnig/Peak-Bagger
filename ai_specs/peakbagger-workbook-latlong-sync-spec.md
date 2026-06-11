<goal>
Build a repeatable maintenance pipeline that reads peak rows from `./peak-bagger-peak-data.csv`, fetches PeakBagger latitude/longitude and metadata, writes the CSV back in place, and upserts ObjectBox `Peak` rows from the same CSV data.

This is for future bulk peak additions and corrections. It must be a repository-local tool/workflow, not a runtime app feature.
</goal>

<background>
The CSV already contains regional rows with a `Url` column pointing at PeakBagger peak pages, and `State/Prov` acts as the region key. Composite `State/Prov` values must be written back as comma-separated values.
The current `Peak` model is OSM-centric (`osmId` is unique, `sourceOfTruth` only knows `OSM` and `HWC`), so PeakBagger data needs its own provenance instead of being forced into OSM semantics. PeakBagger source-of-truth rows use `peakbagger.com`.
`peakbagger-cli` already exposes JSON output, rate limiting, and Cloudflare handling, so use it as the scraping backend for the maintenance tool rather than re-implementing PeakBagger scraping inside the Flutter runtime. The default command is `uvx peakbagger peak show <pid> --format json`.

Files to examine:
- `./peak-bagger-peak-data.csv`
- `./lib/models/peak.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/services/peak_csv_export_service.dart`
- `./tool/*.dart`
- `./test/services/peak_repository_test.dart`
- `./test/services/peak_admin_editor_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/tool/*.dart`
</background>

<discovery>
Before implementation, inspect a representative sample of CSV rows and confirm:
- the PeakBagger URL shape is consistent enough to parse `pid`
- the CSV header already contains the columns needed for round-trip writes, or the importer can add them defensively
- `State/Prov` can be used as the region key, including composite values that should be preserved as comma-separated text
- `peakbagger-cli peak show <pid> --format json` returns the fields needed for latitude, longitude, elevation, prominence, and location metadata
- the existing peak correlation logic in `./lib/services/peak_list_import_service.dart` and `./lib/services/track_peak_correlation_service.dart` can inform the peak-to-peak matching rules without being reused blindly
</discovery>

<requirements>
**Functional:**
1. Add a reusable PeakBagger CSV sync service under `./lib/services/` that can read `./peak-bagger-peak-data.csv`, normalize rows, fetch PeakBagger details, and return canonical peak records.
2. Add a repository-local sync tool under `./tool/` that updates `./peak-bagger-peak-data.csv` in place and writes a machine-readable sync report to `./peak-bagger-peak-data.sync-report.json`.
3. Parse the canonical PeakBagger identity from the CSV `Url` column and store it as a stable `peakbaggerPid` on each row.
4. Add CSV columns for `PeakBagger PID`, `Latitude`, `Longitude`, `note`, and `osmId` if they are not already present; on sync, only those columns are mutated and the existing `Url` plus all other data cells remain unchanged.
5. The `note` column must contain only the current discrepancy summary for that row; overwrite it on each sync run and clear it when no current discrepancy remains.
6. Extend `Peak` with PeakBagger-specific persisted data needed by the app: `peakbaggerPid`, `prominence`, `country`, `county`, `range`, and `sourceOfTruth = 'peakbagger.com'` for PeakBagger-origin rows.
7. For PeakBagger-origin peaks, allocate a stable negative synthetic `osmId` and persist it in the CSV `osmId` column so the identity remains permanent until a genuine OSM id replaces it.
8. When a genuine OSM id is later discovered for an existing PeakBagger peak, update the existing row in place via the existing `PeakRepository.saveDetailed()` path so PeakList and PeaksBagged references are rewritten automatically; do not create a new Peak row.
9. Correlate CSV rows to existing ObjectBox peaks primarily by latitude/longitude within 50m and elevation within 10m, then by normalized peak name when coordinates disagree; use the existing correlation patterns as inspiration, but keep the implementation explicit and peak-specific.
10. If exactly one existing peak is within the 50m/10m correlation window, accept that match.
11. If multiple existing peaks are within the 50m/10m correlation window, choose the closest location match and record that tie-break in both the `note` column and `import.log`.
12. If the closest-location comparison is still effectively tied, do not auto-match; record the ambiguity in both the `note` column and `import.log`.
13. If no existing peak is within the 50m/10m correlation window, allow a strong normalized-name fallback only when there is exactly one qualifying name match across either `Peak.name` or `Peak.altName`, and record that fallback decision in both the `note` column and `import.log`. A strong normalized-name match uses the same normalization contract as `./lib/services/peak_list_import_service.dart`: exact normalized match, or Levenshtein distance `<= 2` when both names are length `>= 6`.
14. If there is no confident spatial or strong-name match, do not auto-match; record the unresolved outcome in both the `note` column and `import.log`.
15. When a CSV row matches an existing OSM-derived peak, update that stored peak in place with PeakBagger truth, preserve local-only fields such as `id`, `altName`, `verified`, and existing peak-list references, replace OSM-derived elevation with PeakBagger elevation when they differ, set `region` from the CSV region key value, and update `sourceOfTruth` to `peakbagger.com`.
16. If the CSV row remains unresolved after the full decision tree, create a new PeakBagger-origin row only when the sync tool is invoked with an explicit CLI flag to create unmatched peaks; otherwise leave the row unmatched and logged for manual review.
17. Treat the CSV as the source of truth for future PeakBagger additions: new rows appended later should sync without changing the import contract or requiring app code changes.
18. Reuse `peakbagger-cli` JSON output as the scraping contract via a small adapter seam; do not embed a new PeakBagger scraper directly in the Flutter runtime.
19. Update `./lib/services/objectbox_admin_repository.dart` and the ObjectBox schema guard so `peakbaggerPid`, `prominence`, `country`, `county`, `range`, `osmId`, `region`, and `sourceOfTruth` are exposed in admin flows. For this spec, those PeakBagger fields may remain read-only in admin; no Tasmania-admin redesign is required. Do not introduce or reference removed fields such as `peakbaggerUrl` or `state` in the Peak model, admin mapping, or schema guard.

**Error Handling:**
20. If a PeakBagger fetch fails for a row, leave the CSV row unchanged, record the failure in the sync report, and continue.
21. If a row lacks a usable PeakBagger URL or pid, skip it deterministically and report it as skipped.
22. If `uvx` or `peakbagger` is unavailable locally, fail fast before mutating either the CSV or ObjectBox, append a single timestamped error to `./logs/import.log`, and return a clear sync error explaining that `uvx peakbagger` is required.
23. If CSV write-back fails, do not replace the original file with partial output.
24. Append every discrepancy to `./logs/import.log` using one timestamped text line per event in ISO-8601 UTC format. Each line must include `row`, `peakbaggerPid`, `osmId`, `action`, and `detail`, and must cover closest-location tie-breaks, unresolved closest-location ties, strong-name fallback matches, unresolved no-match outcomes, coordinate/name mismatches, skipped rows, fetch failures, and PeakBagger/Osm promotions.

**Edge Cases:**
25. Handle duplicate URLs/pids across rows by updating one canonical peak record, not creating duplicates.
26. Preserve existing non-PeakBagger peaks in ObjectBox; the sync must not clear the database.
27. Handle repeated runs idempotently: rows that already contain current values should not trigger unnecessary CSV or ObjectBox churn.

**Validation:**
28. Add tests for URL/pid parsing, row normalization, scraper adapter behavior, correlation matching, CSV update behavior, ObjectBox upsert behavior, `import.log` appends, `note` column generation, and report generation.
29. Validate that new PeakBagger fields are reflected in the ObjectBox admin mapping and schema generation.
30. Add tests proving that a correlated OSM peak flips to PeakBagger source-of-truth when the PeakBagger record wins.
</requirements>

<boundaries>
- No runtime UI for launching the sync.
- No direct PeakBagger scraping in app startup or map refresh paths.
- No deletion of pre-existing ObjectBox peaks outside the matched PeakBagger upsert set.
- Respect PeakBagger rate limiting; batch behavior should be sequential or explicitly throttled.
</boundaries>

<implementation>
Create a small sync stack instead of adding ad hoc CSV logic in the app UI.

Recommended file targets:
- `./lib/models/peak.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/services/objectbox_schema_guard.dart`
- `./lib/services/peakbagger_scraper.dart`
- `./lib/services/peakbagger_csv_import_service.dart`
- `./lib/services/peakbagger_csv_sync_service.dart`
- `./lib/services/peakbagger_peak_correlation_service.dart`
- `./tool/sync_peakbagger_csv.dart`
- `./test/services/peakbagger_csv_import_service_test.dart`
- `./test/services/peakbagger_csv_sync_service_test.dart`
- `./test/services/peakbagger_peak_correlation_service_test.dart`
- `./test/services/peak_model_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/services/objectbox_schema_guard_test.dart`
- `./test/tool/sync_peakbagger_csv_test.dart`

Use injected seams for:
- PeakBagger command execution (`uvx peakbagger peak show <pid> --format json` by default)
- CSV read/write
- repository persistence
- report output
- correlation matcher thresholds and tie-breaking
- import.log writer/path resolution

Keep the parser and row model independent of the CSV writer so future CSV additions only touch one path.
Do not use the runtime app as the operator entry point; this is maintenance tooling plus repository import logic.
</implementation>

<validation>
Use vertical-slice TDD:
- First test the smallest parser failure and make it red.
- Add one passing slice at a time for pid parsing, detail mapping, CSV mutation, and ObjectBox upsert.
- Keep CSV I/O behind seams so tests can use fixtures and in-memory storage.

Baseline automated coverage outcomes:
- Logic/business rules: URL parsing, row normalization, duplicate handling, idempotence, synthetic id assignment, report counts.
- Data integrity: unchanged untouched rows, preserved CSV header/column layout, `note` column generation.
- Persistence: ObjectBox upsert preserves existing local fields and writes new PeakBagger fields.

Required test cases:
- CSV row with valid URL parses pid and updates lat/long from a fixture PeakBagger response
- duplicate pid across rows maps to one canonical peak update
- missing/invalid URL is skipped
- fetch failure is reported and does not corrupt the CSV
- discrepancies are appended to `import.log`
- note column captures discrepancy details
- re-run against an already synced CSV is a no-op
- existing OSM peaks remain after import
- admin repository exposes new PeakBagger fields
- correlation chooses the existing peak when lat/lon are within 50m and elevation is within 10m, then falls back to name when coordinates disagree
- multiple matching peaks choose the closest location and log the tie-break
- correlated existing peaks are updated with PeakBagger values and `sourceOfTruth` changes to the PeakBagger value
</validation>

<done_when>
- The CSV can be enriched in place from PeakBagger URLs.
- The same CSV data can be imported into ObjectBox deterministically.
- PeakBagger rows have stable provenance and do not overload OSM identity.
- Existing OSM peaks can be correlated to PeakBagger rows and promoted to PeakBagger source-of-truth when PeakBagger data is better.
- New PeakBagger additions can be synced later with the same contract.
- Tests cover the parser, scraper adapter, CSV writer, ObjectBox merge path, and failure reporting.
</done_when>
