---
title: Peak list GPX navigation and dialog placement
date: 2026-04-24
work_type: bugfix
tags: [flutter, riverpod, map, testing]
confidence: high
references: [ai_specs/011-pl-add-edit-spec.md, ai_specs/011-pl-add-edit-plan.md, lib/widgets/peak_list_peak_dialog.dart, lib/providers/map_provider.dart, lib/screens/map_screen.dart, lib/screens/peak_lists_screen.dart, test/widget/peak_list_peak_dialog_test.dart, test/widget/tasmap_map_screen_test.dart]
---

## Summary
This session fixed GPX-link navigation from the peak dialog so it works on repeated clicks, not just the first one, and moved the dialog to a draggable bottom-right surface so it covers the mini-map less. The map now carries the peak marker, selects the track, and retargets correctly even when `MapScreen` stays alive inside the shell's indexed stack.

## Reusable Insights
- When a screen lives inside `StatefulShellRoute.indexedStack`, it may stay mounted but offstage. A navigation side effect that depends on the screen being active can be consumed too early and then never re-run when the branch becomes visible again.
- For repeated navigation actions, keep an explicit focus serial and only treat a request as applied after the viewport update really happened. A pending/applied split prevents stale retries from winning.
- Put the UX-critical fallback in the provider, not only in the widget. In this case `showTrack(...)` needed to move state immediately so the right track and peak marker were already in place before `MapScreen` reactivated.
- Preserve the selected peak location when navigating to a track link. That keeps the peak marker visible while the track selection changes.
- A shell/branch regression test is more valuable here than a plain widget test. The failure only showed up when the real router lifecycle was exercised.
- If a dialog must avoid covering part of the app, prefer an explicit positioned surface over a stock centered dialog. `AlertDialog` still centers itself even when wrapped, so the fix was to render a custom `Material` surface anchored bottom-right and expose a drag handle on the title bar.
- For placement tests, assert the actual painted surface and first-frame position. Measuring the wrapper or only checking the settled state can hide a centered entrance.

## Validation
- `flutter test test/widget/peak_list_peak_dialog_test.dart test/widget/tasmap_map_screen_test.dart test/gpx_track_test.dart`
- `flutter test test/widget/peak_list_peak_dialog_test.dart`

## Notes
- Main implementation files: `lib/widgets/peak_list_peak_dialog.dart`, `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`.
- The most useful regressions were `test/widget/tasmap_map_screen_test.dart`, which switches away from the map branch and back to reproduce the stale-track behavior, and `test/widget/peak_list_peak_dialog_test.dart`, which checks bottom-right placement plus drag.
