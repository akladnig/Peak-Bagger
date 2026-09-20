---
type: Spec
title: Peak List Details Compact Columns
---

## Problem

The Peak List details table uses verbose headers and a long prose date format, consuming unnecessary horizontal space in its header and rows.

## Proposed Outcome

The Peak List details table presents compact column headers, a short numeric latest-ascent date, and tighter measured columns while preserving existing sorting and prose dates elsewhere.

## User Stories

1. As a peak-list user, I can scan the details table in less horizontal space because compact labels, ascent dates, and measured padding leave more room for peak data.
2. As a peak-list user, I retain the existing sortable columns and readable non-table date prose while the table itself uses concise values.

## Requirements

1. In the Peak List details table header, use `Hgt`, `Date`, `Asc`, `Diff`, and `Time` for the elevation, ascent-date, ascent-count, difficulty, and duration columns. These abbreviations apply only to this table header. [L1]
2. Keep the Ascent Date column's existing sort affordance, key, ordering behavior, and right alignment while changing its visible header text to `Date`. [L3]
3. Add a reusable compact date formatter in `lib/core/date_formatters.dart` that accepts a non-null `DateTime`, converts it to local time before extracting calendar fields, and formats it as `dd/MM/yy`, including leading zeroes. For example, local 11 January 2024 renders as `11/01/24`. [L2]
4. Use the compact formatter only for non-null Ascent Date cells in the Peak List details table. A peak without an ascent date continues to render an empty cell. [L2]
5. Do not change readable date formats in prose or other screens, including peak-list summary sentences that say when an ascent was climbed. [L2]
6. Retain text-scale-aware width measurement, header sort-control allowance, existing column caps, row overflow behavior, and column gaps. Use one `UiConstants.columnCellHorizontalPadding` contribution for details-table widths rather than two. [L3]
7. Measure the Rating column with one-pixel gaps between its five stars, measure peak names against `Boggy Marsh sugarloaf`, and measure difficulty against `Medium`. [L3]

## Technical Decisions

1. Keep the established Peak elevation domain term and existing data/model names unchanged; `Hgt`, `Date`, `Asc`, `Diff`, and `Time` are presentation-only table-header abbreviations. [L1]
2. Replace the details-row use of the private prose date helper with the new shared compact formatter. The formatter owns conversion of the persisted UTC ascent date to local time; leave the private helper in place for existing prose call sites. [L2]
3. Update the table-width header measurements to match the new compact header strings. Apply a single horizontal-padding contribution consistently, with the manual Rating, peak-name, and difficulty measurement baselines. [L1] [L3]
4. Add the stable date-cell key `peak-lists-details-ascent-date-$peakId` so the existing widget harness can assert both populated and empty cell values without ambiguous text finders. [L2]

## Testing Strategy

1. Add focused unit tests in `test/core/date_formatters_test.dart` for the compact formatter's leading-zero `dd/MM/yy` output, including a single-digit day and month. Verify that formatting a UTC input produces the same result as formatting its `toLocal()` equivalent. [L2]
2. Update the existing `test/widget/peak_lists_screen_test.dart` details-table contract to assert `Hgt`, `Date`, `Asc`, `Diff`, and `Time`, and verify the keyed populated and empty Ascent Date cells render `dd/MM/yy` and `''` respectively. [L1] [L2] [L3]
3. Extend the existing header-width widget test to prove the elevation width is measured from `Hgt`, the unchanged sort-control allowance, and one `UiConstants.columnCellHorizontalPadding` contribution at the active text scale. [L1] [L3]
4. Retain the existing widget-test harness and its in-memory peak, peak-list, and ascent repositories. No network call, API key, persistence migration, new Test Seam, robot journey, or screenshot test is required because this change is synchronous, table-local presentation. [L2] [L3]

## Out of Scope

- Renaming Peak elevation or other domain terminology.
- Changing labels in import/export CSV schemas, map peak information, administration screens, filters, or other tables.
- Changing ascent-date storage, sorting semantics, timezone handling, null behavior, navigation, state management, or persistence.
- Changing prose date formats outside the Peak List details table.
