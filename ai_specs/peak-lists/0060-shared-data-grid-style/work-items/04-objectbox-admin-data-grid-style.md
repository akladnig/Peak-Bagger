---
type: Work Item
title: Apply Data Grid Style to ObjectBox Admin Grids
parent: ../spec.md
---

## What to build

Apply the shared Data grid style through the generic ObjectBox Admin grid, header, row, and cell widgets. Keep all entity-specific fields and the linked scrolling architecture intact while replacing direct seed-colour selection styling.

## Required context

- `lib/screens/objectbox_admin_screen_table.dart` contains `ObjectBoxAdminDataGrid`, `ObjectBoxAdminDataHeaderRow`, `ObjectBoxAdminDataRowTile`, and `ObjectBoxAdminCell`.
- `test/widget/objectbox_admin_browser_test.dart` and `test/widget/objectbox_admin_waypoints_test.dart` cover generic grid behavior, deletion, sorting, and linked scrolling.
- Use the `DataGridTheme` from Work Item 01. Apply header/row padding once per logical header/row, not once per cell.

## Acceptance criteria

- [x] Every ObjectBox Admin entity grid uses shared direct header typography, header/row padding, row text styling, `columnGap`, row dividers, and hover treatment.
- [x] `columnGap` separates the primary, scrollable, and action columns and individual scrollable data cells while retaining defined column widths and linked scroll-controller behavior.
- [x] Selected rows use the shared selected background and borders across the complete row; the former separate primary-cell seed-colour treatment is removed.
- [x] Selected rows retain shared selected decoration while hovered or pressed, and unselected rows use shared hover feedback.
- [x] Entity fields, primary-column rules, sorting, deletion controls and confirmation flow, loading-more row, row keys, horizontal/vertical scrolling, semantics, and keyboard activation remain unchanged.
- [x] Widget coverage uses a `1280 x 800` viewport and `TextScaler.linear(2.0)` to verify fixed primary columns, horizontally scrollable cells, no framework exception, sort semantics/keyboard activation, selectable-row semantics, and delete-control semantics/keyboard activation.
- [x] `flutter test test/widget/objectbox_admin_browser_test.dart test/widget/objectbox_admin_waypoints_test.dart` passes.
- [x] `flutter analyze` and the full `flutter test` suite pass, or any unrelated baseline failures are reported separately from this Work Item's targeted results.

## Covers

- User Stories: 3
- Requirements: 5, 6, 7, 8
- Technical Decisions: 4, 5
- Testing Strategy: 5, 6
- Interview Ledger: L1, L3, L4, L5, L7

## Blocked by

- `01-data-grid-theme-and-peak-lists.md`
