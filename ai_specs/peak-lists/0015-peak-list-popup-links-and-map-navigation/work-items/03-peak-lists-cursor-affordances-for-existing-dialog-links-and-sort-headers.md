---
type: Work Item
title: Peak Lists Cursor Affordances For Existing Dialog Links And Sort Headers
parent: ../spec.md
---

## What to build

Apply the pointing-finger cursor to the remaining existing Peak Lists interactive surfaces covered by this Spec but not introduced by the first two slices: links in the peak-list edit/details popup, Peak Lists summary-table sort headers, and Peak Lists detail-table sort headers. Keep disabled or non-interactive text free of the pointing-finger cursor, and extend focused widget coverage so these cursor affordances stay deterministic across desktop-style pointer interaction.

## Required context

- `lib/screens/peak_lists_screen.dart` already owns the Peak Lists summary-table and detail-table sort-header widgets and existing pointer affordance patterns for other interactive rows.
- `lib/widgets/peak_list_peak_dialog.dart` owns the peak-list edit/details popup links that are explicitly called out by the Spec and Interview Ledger.
- `test/widget/peak_lists_screen_test.dart` already covers row hover and cursor behavior on Peak Lists and should be extended for summary-table and detail-table sort headers.
- `test/widget/peak_list_peak_dialog_test.dart` is the focused dialog test surface for verifying link cursor behavior in the peak-list edit/details popup.

## Acceptance criteria

- [x] Every enabled Peak Lists summary-table sort header touched by this Spec uses the pointing-finger cursor when interactive.
- [x] Every enabled Peak Lists detail-table sort header touched by this Spec uses the pointing-finger cursor when interactive.
- [x] Links in the peak-list edit/details popup touched by this Spec use the pointing-finger cursor when interactive.
- [x] Disabled or non-interactive text in these surfaces does not use the pointing-finger cursor.
- [x] Widget coverage in `test/widget/peak_lists_screen_test.dart` verifies both summary-table and detail-table sort headers use the pointing-finger cursor when interactive.
- [x] Widget coverage in `test/widget/peak_list_peak_dialog_test.dart` verifies the relevant peak-list edit/details popup links use the pointing-finger cursor when interactive and do not regress existing dialog behavior.

## Covers

- User Stories: 3
- Requirements: 10
- Testing Strategy: 2, 4
- Interview Ledger: L5-L6

## Blocked by

None - ready to start
