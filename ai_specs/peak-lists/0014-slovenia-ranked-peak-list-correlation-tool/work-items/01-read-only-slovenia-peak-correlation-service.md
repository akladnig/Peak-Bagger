---
type: Work Item
title: Read-Only Slovenia Peak Correlation Service
parent: ../spec.md
---

## What to build
Add a pure read-only correlation service that takes successfully crawled Slovenia source rows plus existing ObjectBox `Peak` records and deterministically splits them into confidently matched canonical ranked rows and `Correlation review CSV` rows. This slice owns the conservative confidence policy, normalized exact name confirmation against `Peak.name` and `Peak.altName`, tie-window behavior, deterministic `correlationReason` codes, and the canonical versus review field-precedence contracts.

## Required context
- Reuse the smallest existing read-only peak seam possible, especially `lib/services/peak_source.dart`, and avoid any create or update path through ObjectBox.
- Follow the correlation expectations in `spec.md` exactly; do not broaden matching to fuzzy or Levenshtein-style name logic from other tools.
- Review nearby correlation patterns in `lib/services/peak_prominence_correlation_service.dart` and `lib/services/peakbagger_peak_correlation_service.dart`, but keep this slice's exact 150m radius, 50m strong-name threshold, and normalized exact matching rules.
- Keep glossary terminology from `GLOSSARY.md`, especially `Slovenia ranked peak list`, `Correlation review CSV`, and `Repair list`.
- Prefer fake repositories or fixture peaks in tests rather than live ObjectBox state or network-driven inputs.

## Acceptance criteria
- [x] A directly testable read-only service accepts crawled Slovenia rows plus existing `Peak` records and returns separate outputs for confidently matched canonical rows and unresolved `Correlation review CSV` rows.
- [x] Confident matching uses the exact Spec policy: candidate search within 150m, nearest-candidate preference, strong normalized exact-name confirmation against `Peak.name` or `Peak.altName` beyond 50m, and review fallback for ties or non-confident results.
- [x] The tie window is an explicit service input in meters, supports `0`, and affects only tie handling rather than the 50m or 150m thresholds.
- [x] Canonical matched rows use the exact ranked CSV column order and the approved mixed-source field precedence, including matched `Peak.osmId`, matched `Peak.prominence`, matched `Peak` backfill fields, Hribi-first `elevation` and coordinates when present, and visible `region` written as exactly `Slovenia`.
- [x] Review rows use the same canonical column order, force `osmId` to `0`, append `correlationReason`, leave matched-peak-dependent fields blank when confidence is insufficient, and never copy values from a non-confident candidate for reviewer convenience.
- [x] Review rows emit only the approved deterministic `correlationReason` codes: `missing_hribi_coordinates`, `no_candidate_within_150m`, `name_mismatch_beyond_50m`, `multiple_tied_candidates`, `multiple_name_confirmed_candidates`, and `insufficient_source_data_for_correlation`.
- [x] Unit or service tests cover nearest-match selection, alt-name confirmation, beyond-50m name requirements, tie-window behavior, no-confident-match review fallback, canonical field precedence, review-row blank-field behavior, and the allowed reason-code vocabulary without hitting live upstream services or mutating ObjectBox data.

## Covers
- User Stories: 1, 2, 4
- Requirements: 2, 3, 4, 6, 7, 8, 9, 10, 11
- Technical Decisions: 2, 4, 5, 11
- Testing Strategy: 1, 2, 3, 5, 7, 8, 9, 10
- Interview Ledger: L1, L2, L4, L5, L6

## Blocked by
None - ready to start
