---
type: Work Item
title: My Peak Lists Rating Difficulty Duration Table Contract
parent: ../spec.md
---

## What to build

Update the `My Peak Lists` peak-details table so it remains sort-only in this iteration while adding the exact additional columns `Rating`, `Difficulty`, and `Duration`. The table must use this exact column order: `Rating`, `Peak Name`, `Height`, `Ascent Date`, `Ascents`, `Difficulty`, `Duration`. The new headers must use the same tap-to-toggle sort behavior as the existing sortable columns, with `Rating` rendered as a five-star row using full, half, and empty stars, `Difficulty` shown as stored `Peak difficulty` text with region-aware sorting behavior, and `Duration` shown as `durationLabel` or a derived formatted duration fallback.

## Required context

- `lib/screens/peak_lists_screen.dart` already owns the details table widths, sort enum/state, header cells, row rendering, and blank-last sort conventions. Keep this slice vertical inside that existing screen boundary unless a very small shared helper is clearly needed.
- Existing sort/header selectors are in `peak-lists-details-sort-${column.name}` and `peak-lists-details-sort-icon-${column.name}`. Add stable selectors for the new rating, difficulty, and duration cells if current keys are insufficient for deterministic assertions.
- `test/widget/peak_lists_screen_test.dart` already covers row ordering by tapped headers, blank-last conventions, and deterministic widget behavior through fake repositories and local test seams.
- Reuse the shared metadata logic from `01-peak-duration-persistence-and-shared-metadata-rules.md` for nearest-half `Rating` display, region-aware `Peak difficulty` ordering, and formatted duration fallback instead of duplicating those rules inside the widget.

## Acceptance criteria

- [ ] `My Peak Lists` remains sort-only for this feature and does not add peak metadata filtering controls.
- [ ] The peak-details table shows columns in this exact order: `Rating`, `Peak Name`, `Height`, `Ascent Date`, `Ascents`, `Difficulty`, `Duration`.
- [ ] The `Rating`, `Difficulty`, and `Duration` headers use the same tap-to-toggle sorting pattern already used by the other sortable columns.
- [ ] The `Rating` column renders a five-star row using full, half, and empty stars and does not show decimal text in the same cell.
- [ ] When a peak has no rating, the `Rating` cell is blank.
- [ ] `Rating` star rendering rounds the stored numeric rating to the nearest half star for display only, while sorting uses the existing numeric 0-5 rating value.
- [ ] The `Difficulty` column shows the stored `Peak difficulty` text.
- [ ] `Difficulty` sorting uses Tasmania `Easy < Medium < Hard < Very Hard`, Italy administrative regions `T < E < EE < EEA < EAI`, and `slovenia` and `croatia` `T1 < T2 < T3 < T4 < T5 < T6`, with alphabetical fallback for regions without a configured ladder.
- [ ] If one visible table contains multiple regions, `Difficulty` sorting orders by region first, then by that region's difficulty order, then by peak name.
- [ ] The `Duration` column shows `durationLabel` when it is present.
- [ ] If no label is present but a numeric duration exists, the `Duration` column shows a formatted duration string derived from `durationMinutes`.
- [ ] `Duration` sorting uses `durationMinutes`.
- [ ] For the new `Rating`, `Difficulty`, and `Duration` columns, rows with missing values render blank and sort after rows with values following the screen's existing blank-value sort conventions.
- [ ] Deterministic widget coverage in `test/widget/peak_lists_screen_test.dart` verifies the exact column order, nearest-half star rendering in `Rating`, sortable `Rating` / `Difficulty` / `Duration` headers, numeric-versus-text sort behavior, configured difficulty-ladder ordering, formatted duration display fallback, and blank-value ordering rules.

## Covers

- User Stories: 1, 3
- Requirements: 4-10
- Technical Decisions: 1-3
- Testing Strategy: 3
- Interview Ledger: L1, L3-L4, L6

## Blocked by

- `01-peak-duration-persistence-and-shared-metadata-rules.md`
