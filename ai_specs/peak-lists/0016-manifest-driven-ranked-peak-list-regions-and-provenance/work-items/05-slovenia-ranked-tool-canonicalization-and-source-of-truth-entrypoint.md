---
type: Work Item
title: Slovenia Ranked Tool Canonicalization and Source-of-Truth Entrypoint
parent: ../spec.md
---

## What to build
Extend the Slovenia ranked generator path so the repo-local shell entrypoint and underlying Dart tool produce canonical ranked rows with one `country`, one `region`, and explicit uppercase `sourceOfTruth` provenance. Replace the current broad-`Slovenia` defaulting with polygon-based canonicalization that can choose an Italy administrative side when appropriate, compares manifest priorities numerically, appends border context to `notes`, and fails tied winning matches into deterministic review output instead of guessing.

## Required context
- `tool/slovenia_hribi_source_peak_list.dart`, `lib/services/slovenia_hribi_source_peak_list_service.dart`, and `lib/services/slovenia_peak_correlation_service.dart` are the current generator seams. Keep the existing crawl, cache, and artifact pipeline unless `spec.md` explicitly changes it.
- Root shell wrappers such as `sync_peakbagger_csv.sh` and `peak_prominence_csv.sh` show the repo's existing shell-entrypoint pattern. Follow that pattern for the new Slovenia ranked entrypoint and forward CLI flags through to the Dart tool.
- Reuse manifest and polygon helpers rather than ad hoc geometry code. `lib/services/region_manifest_catalog.dart`, `lib/services/polygon_geometry.dart`, and the manifest priority utilities from `01-manifest-backed-italy-administrative-regions-and-priority-metadata.md` are the intended canonicalization sources.
- Existing tests live in `test/tool/slovenia_hribi_source_peak_list_tool_test.dart`, `test/services/slovenia_hribi_source_peak_list_service_test.dart`, and `test/services/slovenia_peak_correlation_service_test.dart`. Keep tests deterministic with fixtures and fake loaders; do not depend on live upstream Slovenia pages or real network requests.
- Follow `GLOSSARY.md`, especially `Slovenia ranked peak list`, `Correlation review CSV`, `Repair list`, `Italy administrative region`, and `Manifest priority`.

## Acceptance criteria
- [x] A repo-root shell script entrypoint for the Slovenia ranked tool follows the project's existing `.sh` wrapper pattern and forwards CLI flags to `tool/slovenia_hribi_source_peak_list.dart`.
- [x] The tool adds a mandatory `--source-of-truth` flag path for ranked provenance. If the input CSV pipeline does not provide a `sourceOfTruth` column, the flag is required. If the flag is provided, it overrides any existing per-row `sourceOfTruth` values before output is written.
- [x] If an optional input `sourceOfTruth` column is present, every row in one file normalizes to the same non-blank uppercase value after trimming and uppercasing. Mixed, blank, comma-separated, or format-invalid values fail the tool run atomically.
- [x] The generated ranked CSV writes the exact extended header `name,osmId,rating,elevation,prominence,latitude,longitude,country,region,range,county,difficulty,viaFerrata,notes,sourceOfTruth` and writes the resolved uppercase `sourceOfTruth` value into every canonical output row.
- [x] Canonical ranked CSV rows contain exactly one `country` value and one `region` value. Multi-valued cells such as `Italy, Slovenia` are not valid canonical output.
- [x] The tool no longer writes broad `Slovenia` region values for canonical rows by default. For each confident row, it resolves one canonical country-region pair from peak coordinates against manifest polygons, including canonicalization onto the Italian side when that side wins.
- [x] When canonicalization has multiple polygon matches, the tool compares manifest `priority` values segment by segment numerically, treats a longer prefix-sharing path as more specific than its parent, and never lets aggregate regions such as `italy`, `italy-nord-est`, or `italy-nord-ovest` outrank a matching more specific child solely because of manifest order.
- [x] If multiple matching regions remain tied after priority comparison, the tool fails that row into deterministic review output rather than guessing.
- [x] When the canonical side of a shared peak is Italy, the canonical row writes `country = Italy`, writes the specific `Italy administrative region` display name in `region`, and appends border context such as `Border peak with Slovenia` to `notes` instead of emitting a broad `Italy` label or a comma-separated country or region cell.
- [x] Behavior-first TDD drives this item. Focused service or tool coverage proves shell flag forwarding, required-flag behavior when the input lacks `sourceOfTruth`, flag override of an existing `sourceOfTruth` column, uppercase provenance output, border-row canonicalization to one country and one region, Italy-side border-note behavior, numeric `priority` ordering, and deterministic review output for tied winning priorities.

## Covers
- User Stories: 3
- Requirements: 8-15, 27-30
- Technical Decisions: 4, 7, 9, 10
- Testing Strategy: 1, 4, 6, 7, 10
- Interview Ledger: L6-L8, L11-L13

## Blocked by
- `01-manifest-backed-italy-administrative-regions-and-priority-metadata.md`
