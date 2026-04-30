---
title: Keep existing peaks visible in add dialog
date: 2026-04-29
work_type: bugfix
tags: [flutter, widgets, testing]
confidence: high
references:
  - ai_specs/peak-lists-add-new-peak-plan.md
  - lib/widgets/peak_list_peak_dialog.dart
  - lib/widgets/peak_multi_select_results_list.dart
  - test/widget/peak_list_peak_dialog_test.dart
  - test/widget/peak_multi_select_results_list_test.dart
  - test/robot/peaks/peak_lists_journey_test.dart
---

## Summary

Kept already-added peaks visible in `Add New Peak` search results, with checked read-only checkboxes.
Also split the dialog body into equal-height search and selected panes.

## Reusable Insights

- Separate mutable save selection from read-only membership state.
- Existing peaks can be shown as checked without being addable again, preventing duplicate-save failures.
- Use stable row keys plus checkbox state for widget and robot assertions.
- For two-pane dialog layouts, prefer paired `Expanded` panels over fixed-height constraints when content varies.

## Decisions

- Existing list members stay in the top results list.
- Read-only checked rows are disabled, not merged into the save selection set.
- The selected list remains independently editable for points.

## Validation

- `flutter analyze`
- `flutter test test/widget/peak_multi_select_results_list_test.dart test/widget/peak_list_peak_dialog_test.dart test/robot/peaks/peak_lists_journey_test.dart`

## Pitfalls

- A full `flutter test` run still had unrelated failures elsewhere in the repo, so focused tests were the reliable signal for this change.
