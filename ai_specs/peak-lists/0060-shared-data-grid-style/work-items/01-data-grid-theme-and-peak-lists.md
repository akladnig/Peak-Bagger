---
type: Work Item
title: Add Data Grid Theme and Refactor Peak List Grids
parent: ../spec.md
---

## What to build

Add the `DataGridTheme` extension and install its specified light and dark values in `MyTheme`. Refactor the Peak List summary and details grids as the reference implementation of the shared Data grid style without changing their data, columns, labels, sorting, ratings, selection, or deletion behavior.

## Required context

- `lib/theme.dart` contains existing `ThemeExtension` conventions, the `darken` helper, and `MyTheme` construction.
- `lib/screens/peak_lists_screen.dart` contains `_SummaryRowCard`, `_PeakDetailsTableCard`, `_PeakDetailsTableRow`, and existing measured table widths.
- `test/theme_test.dart` and `test/widget/peak_lists_screen_test.dart` contain the existing theme and Peak List widget harnesses.
- Keep `RowHoverTheme` for dashboard consumers outside this Work Item's grid scope.

## Acceptance criteria

- [x] `DataGridTheme` exposes every token named in Spec Technical Decision 1, provides compatible `copyWith` and `lerp`, and is installed by both `MyTheme` variants.
- [x] `DataGridTheme.fromColorScheme` uses the exact Spec formulas for default and non-default seed, dynamic-scheme-variant, and contrast-level configurations.
- [x] Peak List summary and details headers and rows use the shared padding, row text, direct complete header text style, column gaps, hover feedback, selected decoration, and dividers between adjacent data rows.
- [x] Selected Peak List rows retain their selected background and top/bottom borders while hovered or pressed; unselected interactive rows use the shared hover treatment.
- [x] Existing measured Peak List column widths, horizontal scrolling, sortable-header behavior, semantic labels, keyboard activation, ratings, formatting, selection, and deletion remain unchanged.
- [x] Theme and Peak List widget coverage uses a `1280 x 800` viewport at `TextScaler.linear(2.0)`, verifies no framework exception, and retains sortable-header semantics and keyboard activation.
- [x] `flutter test test/theme_test.dart test/widget/peak_lists_screen_test.dart` passes.

## Covers

- User Stories: 1, 4
- Requirements: 1, 2, 6, 7, 8
- Technical Decisions: 1, 2, 3
- Testing Strategy: 1, 2
- Interview Ledger: L2, L3, L4, L5, L6, L7

## Blocked by

None - ready to start
