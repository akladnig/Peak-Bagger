<goal>
Create a repository-local peak-prominence import tool for `./assets/all-peaks-sorted-p100.csv` so matched `Peak` rows can have `prominence` populated in ObjectBox without mutating the raw source.

This matters because the file is large, headerless, and prominence-sorted for a different purpose than peak lookup; the tool needs a stable parse contract, a deterministic correlation pass, a safe persistence path, and a reviewable dry-run export.
</goal>

<background>
Andrew Kirmse's 2023 prominence update says the CSV export is a list of peaks with at least 100 feet of prominence, sorted by decreasing prominence, and the values are in floating-point meters.

The bundled asset `./assets/all-peaks-sorted-p100.csv` has six comma-separated columns and no header row:
`latitude,longitude,elevation,key saddle latitude,key saddle longitude,prominence`.
In this file, `0,0` in the key-saddle columns means the peak is the high point of a land mass.

`Peak.prominence` already exists on the ObjectBox entity, and `PeakRepository.saveDetailed()` already provides the persistence path that preserves identity and dependent references.

The repo already uses small repository-local tools under `./tool/` plus focused service/test seams. This work should follow that pattern instead of adding runtime app behavior.

Files to examine:
- `./assets/all-peaks-sorted-p100.csv`
- `./lib/models/peak.dart`
- `./lib/services/peak_repository.dart`
- `./lib/services/peakbagger_peak_correlation_service.dart`
- `./tool/*.dart`
- `./test/tool/*.dart`
- `./lib/services/*.dart`
</background>

<discovery>
Before implementation, confirm:
- whether a transient in-memory index is sufficient or whether a derived lookup CSV is only justified after a measured performance or memory problem
- whether the full CSV can be streamed once while holding only the lookup/index structures needed for correlation and reporting
- whether the dry-run CSV is simpler to generate from an in-memory projected snapshot or by overlaying proposed prominence values while iterating all ObjectBox peaks in `id` order
</discovery>

<user_flows>
Primary flow:
1. Developer runs the peak-prominence tool against `./assets/all-peaks-sorted-p100.csv`.
2. The tool parses the six headerless columns into typed records.
3. The tool builds a lookup structure in memory or from a secondary lookup file if needed for efficient correlation.
4. The tool correlates each prominence row to an existing `Peak` record.
5. The tool persists matched `prominence` values back into ObjectBox.
6. The tool prints a summary of matched rows, unresolved CSV rows, unmatched ObjectBox peaks, and skipped rows.

Alternative flows:
- Dry run: the tool validates and correlates rows, then writes a review CSV snapshot from ObjectBox without mutating it.
- Repeated runs: the same correlation rules should yield idempotent `Peak.prominence` updates.
- Lookup-heavy run: if the implementation chooses a derived lookup artifact, the import can reuse it on later runs.

Error flows:
- Missing asset file: fail fast with a clear path error.
- Malformed row: report the 1-based line number and the bad row shape.
- Non-numeric field: report the line and field name, then stop the current run.
- Unexpected sort order: report the first out-of-order pair and fail validation.
- Unresolved CSV row: leave the stored peak unchanged and record the row for manual review.
- Unmatched ObjectBox peak: leave the peak unchanged and record it for manual review after the full correlation pass.
</user_flows>

<requirements>
**Functional:**
1. Add a small reusable prominence CSV service under `./lib/services/` that reads `./assets/all-peaks-sorted-p100.csv` and exposes typed records for latitude, longitude, elevation, key-saddle latitude, key-saddle longitude, and prominence.
2. Treat the CSV as headerless and enforce the exact six-column contract in the source article and asset.
3. Preserve numeric precision as parsed doubles; do not convert the raw values back to feet.
4. Preserve source ordering and expose the file's decreasing-prominence sort as an invariant.
5. Interpret `0,0` in the key-saddle columns as the land-mass high-point sentinel, not as a real saddle location.
6. Add a peak correlation service under `./lib/services/` that matches prominence rows to existing `Peak` rows using deterministic coordinate-first matching: lat/lon within 30m, elevation within 10m, and lat/lon-only fallback when `Peak.elevation` is missing. If multiple peaks fall inside the 30m window, sort the qualifying candidates by ascending `Peak.id`, take the first match, skip the rest, and log an error for each skipped duplicate candidate.
7. Add a repository-local CLI under `./tool/` that can validate the file, run the import, and support a dry-run mode.
8. Dry run must emit a CSV snapshot of all ObjectBox peaks after correlation, sorted by `id`, with columns `id,region,name,latitude,longitude,elevation,prominence`.
9. Persist matched rows by updating the existing `Peak` record through `PeakRepository.saveDetailed()` or an equivalent repository update path so `prominence` lands on the same ObjectBox entity identity.
10. Keep the raw asset read-only; the tool may build a transient in-memory index or a secondary lookup file if needed, but it must not rewrite `./assets/all-peaks-sorted-p100.csv`.
11. Write the dry-run CSV snapshot to `./tool/peak-prominence-objectbox-preview.csv`. If a derived lookup file is needed for speed, put it under a dedicated path in `./tool/` and make that path explicit in tool help and tests.

**Error Handling:**
12. If the CSV has fewer or more than six columns on any row, fail validation with the line number and row content summary.
13. If any field fails numeric parsing, fail with the offending line and column name.
14. If the file is not sorted by decreasing prominence, fail validation at the first out-of-order pair.
15. If a CSV row cannot be correlated confidently, leave the matching `Peak` unchanged and record the row as unresolved instead of guessing.
16. If persistence fails for a matched row, continue best-effort with later rows, report the failure deterministically, and do not silently drop the update.
17. If a CSV row cannot be correlated, append one timestamped error entry per unresolved CSV row per run to `./logs/prominence-unresolved-csv.log`.
18. After the full correlation pass, append one timestamped informational entry per unmatched ObjectBox `Peak` entity per run to `./logs/prominence-not-found-in-dataset.log` with `action=not-found-in-dataset`.

**Edge Cases:**
19. Handle peaks whose key saddle is the `0,0` sentinel without treating them as invalid.
20. Preserve duplicate coordinate rows if they exist; do not deduplicate unless the CSV contract explicitly requires it.
21. Avoid rounding on ingest; formatting should happen only at the CLI presentation layer.
22. If `Peak.elevation` is missing, fall back to lat/lon-only correlation instead of requiring elevation to match.
23. If the raw prominence order is not useful for matching, create a lookup-friendly index without changing the raw CSV contract.

**Validation:**
24. Add tests for the six-column parse contract, sentinel handling, sort-order validation, correlation behavior, persistence to `Peak.prominence`, unresolved CSV-row logging, unmatched ObjectBox-peak logging, and dry-run CSV export.
25. Baseline automated coverage must include logic/business rules, repository update behavior, dry-run export behavior, and CLI behavior.
26. Use deterministic fixtures or small synthetic CSV samples in tests; do not depend on the full asset file for unit coverage.
</requirements>

<boundaries>
Edge cases:
- The source CSV is headerless; do not infer column names from the first row.
- The file is large enough that streaming parsing should be preferred if the implementation needs to run over the full asset repeatedly.
- Do not assume the key-saddle coordinates are always real land coordinates; the `0,0` sentinel is valid.
- Do not create new `Peak` rows by default when no correlation is found.
- When multiple peaks fall within the match window, prefer the qualifying candidate with the smallest `Peak.id` and log the additional candidates.
- Treat `action=not-found-in-dataset` as an informational outcome for unmatched ObjectBox peaks, not as proof of a bad correlation.

Error scenarios:
- Missing file, malformed line, non-numeric cell, or sort-order failure should make the validation command exit non-zero.
- Lookup or import commands should fail closed for invalid input rather than falling back to partial matches.
- A partial import should be visible in the run report if a later row fails persistence.
- Unresolved CSV rows and unmatched ObjectBox peaks should be logged and should not abort the rest of the run.
- If any persistence failure occurs, the command should exit non-zero after completing the best-effort pass.

Limits:
- No network fetching from Andrew Kirmse's site at runtime.
- No UI changes in the Flutter app for this task.
- No database writes outside the explicit import path.
- No unit conversion back to feet in stored values.
</boundaries>

<implementation>
Files to create or modify:
- `./lib/services/peak_prominence_csv_service.dart`
- `./lib/services/peak_prominence_correlation_service.dart`
- `./lib/services/peak_prominence_import_service.dart`
- `./tool/peak_prominence_csv.dart`
- `./test/services/peak_prominence_csv_service_test.dart`
- `./test/services/peak_prominence_correlation_service_test.dart`
- `./test/services/peak_prominence_import_service_test.dart`
- `./test/tool/peak_prominence_csv_test.dart`

Implementation expectations:
- Keep parsing logic isolated from CLI argument handling.
- Use a small record model with explicit field names instead of a loosely typed list of doubles.
- Make validation available as a pure function or service method so tests can cover it without spawning a process.
- Keep correlation behavior narrow and deterministic: coordinate-first matching, a 150m/100m window, lat/lon-only fallback when `Peak.elevation` is missing, and ascending-`Peak.id` tie resolution for accidental multi-hit windows.
- Preserve the raw CSV as the single source of truth.
- Prefer a transient in-memory index first; only add a derived lookup artifact if the in-memory path is too slow or too memory-heavy.
- Use the existing `PeakRepository.saveDetailed()` flow for matched rows so the update remains on the existing ObjectBox entity identity.
- For dry run, export all ObjectBox peaks using the same field order in the spec so reviewers can compare before/after without opening the app; matched rows should reflect the proposed prominence value, unmatched peaks should retain their current stored prominence value unchanged, and output should be sorted by `id`.
- Write `./logs/prominence-unresolved-csv.log` using one line per unresolved CSV row in the format `<iso8601-utc> latitude=<lat> longitude=<lon> elevation=<elev-or-empty> action=unresolved-csv-row detail=<detail>`.
- Write `./logs/prominence-not-found-in-dataset.log` using one line per unmatched ObjectBox peak in the format `<iso8601-utc> peakId=<id> name=<name> action=<action> detail=<detail>`.
- The run report should include at least `matchedCount`, `updatedCount`, `unresolvedCsvRowCount`, `unmatchedPeakCount`, and `writeFailureCount`.

Avoid:
- Avoid loading the full file into app startup paths or map rendering flows.
- Avoid reserializing the data unless a dedicated export mode is added later.
- Avoid guessing missing values or silently coercing malformed rows.
- Avoid creating duplicate peaks just to satisfy unresolved rows.
</implementation>

<stages>
Phase 1: Parse and validate
- Add the record model and parser.
- Verify the six-column contract, numeric parsing, and sentinel handling.

Phase 2: Add correlation and persistence
- Add the peak correlation service and persistence path.
- Verify matched rows update `Peak.prominence` and unresolved rows stay unchanged.

Phase 3: Add CLI behavior and harden
- Add validation, dry-run CSV export, and import modes.
- Verify the CLI exits cleanly for valid input and fails deterministically for malformed input.
- Update tool help or inline usage text to document the column contract and any derived lookup path.
</stages>

<validation>
Use vertical-slice TDD:
- Start with a failing test for the six-column parse contract.
- Add one behavior at a time: sentinel handling, sort validation, correlation, persistence, then CLI wiring.
- Keep the parser and validator callable without spawning a subprocess.

Required coverage split:
- `unit` or logic: parse contract, numeric parsing, `0,0` sentinel interpretation, sort-order validation, coordinate-first correlation, and fallback behavior.
- `service`: repository update behavior proving matched rows persist `prominence` on the existing `Peak` row.
- `tool`: CLI argument handling, dry-run export path, import path, non-zero exit paths, and success output formatting.

Required assertions:
- The parser maps the six raw columns to explicit fields in the documented order.
- The validator rejects malformed rows and unsorted input.
- The correlation path chooses the correct existing `Peak`, prefers the smallest `Peak.id` on accidental multi-hit windows, or leaves the row unresolved.
- The import path updates `Peak.prominence` on the same stored entity identity.
- The dry-run path writes a CSV preview of all ObjectBox peaks, sorted by `id`, with `id,region,name,latitude,longitude,elevation,prominence`, and unmatched peaks retain their current stored prominence value unchanged.
- The unresolved log path writes one line per unresolved CSV row per run and one line per unmatched ObjectBox peak per run using the documented token format.
- The import continues best-effort after write failures, reports `writeFailureCount`, and exits non-zero if any write fails.
- The tool does not depend on network access or app runtime state.
</validation>

<done_when>
The spec is complete when the repo has a documented, test-covered parser, correlation service, and CLI for `./assets/all-peaks-sorted-p100.csv`, the six columns are treated as a stable contract, `0,0` key-saddle sentinels are handled correctly, matched peaks persist `prominence` to ObjectBox, unmatched peaks are reported as `not-found-in-dataset`, best-effort write failures are counted and surfaced with a non-zero exit, and the raw asset remains untouched.
</done_when>
