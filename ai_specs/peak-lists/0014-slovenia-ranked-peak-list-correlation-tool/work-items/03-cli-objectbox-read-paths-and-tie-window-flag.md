---
type: Work Item
title: CLI ObjectBox Read Paths and Tie-Window Flag
parent: ../spec.md
---

## What to build
Update the existing Slovenia CLI entrypoint so it opens the existing peak repository for read-only correlation input, passes the chosen tie-window setting into the correlated Slovenia pipeline, and exposes the new canonical outputs through the existing callable tool seam and command-line flow without creating or updating any ObjectBox records.

## Required context
- Follow the existing CLI shape in `tool/slovenia_hribi_source_peak_list.dart` and the ObjectBox bootstrap patterns already used by other repo-local tools such as `tool/peak_prominence_csv.dart`.
- Keep the CLI and tool seam read-only with respect to ObjectBox; this slice may load current `Peak` rows for correlation but must not persist changes even when source and stored values differ.
- Preserve existing CLI behaviors such as `--repair-list`, `--refresh-cache`, and output-directory handling unless the Spec explicitly changes them.
- Tool-level tests in `test/tool/` should call the Dart seam directly and use fake storage or temp directories rather than shelling out to live app state.

## Acceptance criteria
- [x] The Slovenia CLI opens the existing peak repository through a read-only path, loads current `Peak` rows for correlation, and passes them into the service without creating or updating ObjectBox data.
- [x] The CLI exposes a tie-window flag in meters that defaults to `10`, accepts `0`, affects only tie handling, and is carried through to state or run-summary output so different runs remain explainable.
- [x] Existing supported flags such as `--repair-list`, `--refresh-cache`, and `--output-dir` continue to work with the new correlated artifact family.
- [x] A missing correlated repair baseline still fails cleanly without writing a new versioned artifact set.
- [x] Tool-level coverage verifies read-only ObjectBox usage, tie-window flag defaults and boundary values, repair-list behavior against the new correlated snapshot family, and successful end-to-end emission of the canonical ranked CSV, `Correlation review CSV`, and `Repair list` through the callable tool seam.

## Covers
- User Stories: 1, 3, 4
- Requirements: 2, 5, 11, 12
- Technical Decisions: 1, 2, 5
- Testing Strategy: 4, 5, 7, 9
- Interview Ledger: L1, L2, L6, L7

## Blocked by
- `02-correlated-slovenia-snapshot-pipeline.md`
