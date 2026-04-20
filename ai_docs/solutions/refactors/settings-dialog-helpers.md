---
title: Shared dialog helpers in widgets folder
date: 2026-04-20
work_type: refactor
tags: [flutter, dialogs, refactor]
confidence: high
references: [lib/screens/settings_screen.dart, lib/widgets/dialog_helpers.dart, lib/widgets/peak_list_import_dialog.dart, test/widget/peak_refresh_settings_test.dart, test/widget/gpx_tracks_summary_test.dart, test/widget/tasmap_refactor_test.dart]
---

## Summary

Refactored repeated confirmation/result/failure dialogs in `settings_screen.dart` into small shared helpers in `lib/widgets/dialog_helpers.dart`, then reused the same helpers from `peak_list_import_dialog.dart`.
Kept the action-specific async logic separate so each flow still owns its own success/failure behavior.

## Reusable Insights

- Prefer composable dialog helpers over inheritance for UI reuse when the shared part is only structure, not behavior.
- Split helpers by dialog shape, not by screen: confirm dialog, single-action result dialog, single-action error dialog.
- Keep workflow-specific logic outside the helper: async operation, loading flags, status text, result payload, error handling.
- Preserve stable dialog keys in the helper API so widget/robot tests do not drift when copy changes.
- If dialogs are already shaped differently, a single mega-helper becomes harder to read and harder to test.

## Decisions

- `showDangerConfirmDialog(...)` for destructive confirmations.
- `showSingleActionDialog(...)` for result/failure dialogs with one close action.
- No subclass hierarchy; helper functions only.

## Pitfalls

- Similar dialog copy can hide meaningful behavior differences, especially where one flow updates state and another just shows a result.
- Reusing the wrong abstraction level can make future dialogs inconsistent instead of consistent.

## Validation

- `flutter test test/widget/peak_refresh_settings_test.dart test/widget/gpx_tracks_summary_test.dart test/widget/tasmap_refactor_test.dart`
- `flutter analyze`

## Follow-ups

- If another screen needs the same dialog shapes, keep them in the shared widgets utility and extend by helper shape, not by screen.
- Keep action-specific result formatting in the caller so helper reuse does not flatten important messaging.
- Peak list import coverage (`test/widget/peak_lists_screen_test.dart`) proved the shared helper fit the existing dialog keys and didn't disturb import flow behavior.
