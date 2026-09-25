---
type: Work Item
title: Apply Data Grid Style to Peak Multi-Select Results
parent: ../spec.md
---

## What to build

Apply the shared Data grid style to `PeakMultiSelectResultsList`, including consistent column gaps, row padding, dividers, hover feedback, and selected-row decoration. Preserve the list's existing selection semantics and lazy rendering.

## Required context

- `lib/widgets/peak_multi_select_results_list.dart` owns the checkbox selection and row layout.
- `test/widget/peak_multi_select_results_list_test.dart` provides a stateful widget harness and stable row/checkbox keys.
- Use the `DataGridTheme` from Work Item 01; keep the green checked-checkbox indicator as the checkbox-state signal.

## Acceptance criteria

- [x] Each multi-select row uses shared row padding, row text styling, `columnGap` between checkbox, peak name, elevation, and map columns, and a shared divider only between adjacent results.
- [x] Selected rows use the shared selected background and borders and retain that treatment while hovered or pressed; unselected interactive rows use shared hover feedback.
- [x] Checked checkbox indicator colour remains green, and read-only selected peaks remain checked and disabled.
- [x] Existing selection limit, row and checkbox keys, alphabetical ordering, lazy vertical list behavior, peak fields, and callback behavior remain unchanged.
- [x] Widget coverage uses `MyTheme`, a `1280 x 800` viewport, and `TextScaler.linear(2.0)` to verify long-name layout, no framework exception, checkbox semantics, and keyboard activation.
- [x] `flutter test test/widget/peak_multi_select_results_list_test.dart` passes.

## Covers

- User Stories: 1
- Requirements: 3, 6, 7, 8
- Technical Decisions: 4, 5
- Testing Strategy: 3
- Interview Ledger: L1, L3, L4, L5, L7

## Blocked by

- `01-data-grid-theme-and-peak-lists.md`
