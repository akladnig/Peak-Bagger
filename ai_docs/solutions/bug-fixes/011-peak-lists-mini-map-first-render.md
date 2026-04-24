---
title: Peak Lists mini-map first-render fix
date: 2026-04-22
work_type: bugfix
tags: [flutter, flutter_map, peak-lists]
confidence: high
references: [ai_specs/011-pl-ui-updates-plan.md, ai_specs/011-pl-ui-updates-spec.md, lib/screens/peak_lists_screen.dart, test/widget/peak_lists_screen_test.dart, test/robot/peaks/peak_lists_journey_test.dart]
---

## Summary
Peak Lists had a blank mini-map on first entry until a list was selected. The fix was to stop driving the initial camera through a controller/post-frame path and instead render the map with `initialCameraFit`, remounting the map per selected list so the first frame has a valid visible viewport.

## Reusable Insights
- For `flutter_map`, prefer `initialCameraFit` when the visible region is known at build time. It avoids controller timing races that can produce a blank first frame.
- If a map must re-center when selection changes, key the map subtree by selection identity so the widget rebuilds with fresh initial camera state.
- Keep stable test selectors on the wrapper, not the map internals. We preserved `peak-lists-mini-map` on a `KeyedSubtree` while remounting the `FlutterMap` itself.
- When adding visual spacing in fixed-width headers, count that spacing in the width resolver. Otherwise the label will truncate to make room for the icon.

## Pitfalls
- A post-frame `MapController.fitCamera` path can appear to work after later rebuilds while still leaving the initial render blank.
- A small spacing tweak in a sort header can silently shrink the measured text width unless the column width calculation is updated.

## Validation
- `flutter test test/widget/peak_lists_screen_test.dart`
- `flutter test test/robot/peaks/peak_lists_journey_test.dart`
