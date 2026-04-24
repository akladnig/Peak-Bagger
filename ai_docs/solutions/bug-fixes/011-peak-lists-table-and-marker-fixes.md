---
title: Peak Lists table and marker fixes
date: 2026-04-22
work_type: bugfix
tags: [flutter, ui, testing]
confidence: high
references: [ai_specs/011-pl-ui-updates-spec.md, ai_specs/011-pl-ui-updates-plan.md, lib/screens/peak_lists_screen.dart, lib/screens/map_screen_layers.dart, test/widget/peak_lists_screen_test.dart, test/widget/tasmap_map_screen_test.dart]
---

## Summary
This session finished a set of Peak Lists UI fixes around the right-side peak table and the shared peak-marker helper. The details table now sorts correctly, keeps column headers legible, aligns numeric/date columns as intended, and preserves blank ascent dates after real dates. Climb markers also render above unclimbed markers by ordering the marker list.

## Reusable Insights
- For scrollable table headers, width math must include both the label and the sort affordance. If the icon/gap is omitted, the header can clip even when the cell text itself fits.
- Keep header and row spacing identical. The Peak Lists table needed the same 12px gaps in both the header row and each data row to preserve alignment.
- When a sort column has blanks, handle the blank partition explicitly instead of relying on generic comparator null behavior. Here, valid ascent dates sort first and blank dates are appended after them in both directions.
- Use `TextAlign.right` for right-aligned columns in both header cells and data cells. Aligning only the rows leaves headers visually inconsistent.
- Marker draw order is paint order in Flutter map layers. If climbed peaks must sit above unclimbed peaks, emit unclimbed markers first and climbed markers last, or split them into separate layers.
- Add focused widget assertions for the failure mode you just fixed: header width, blank-date ordering, and marker ordering are all easy to regress without a targeted test.

## Validation
- `flutter test test/widget/peak_lists_screen_test.dart`
- `flutter test test/widget/tasmap_map_screen_test.dart`
- `flutter analyze`

## Notes
- The Peak Lists work built on `ai_specs/011-pl-ui-updates-spec.md` and `ai_specs/011-pl-ui-updates-plan.md`.
- Main implementation files were `lib/screens/peak_lists_screen.dart` and `lib/screens/map_screen_layers.dart`.
