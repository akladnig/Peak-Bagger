---
title: Peak List enhancements - dialogs, search, and defaults
date: 2026-04-24
work_type: feature
tags: [flutter, peak-list, dialogs, search-widget, draggable-ui]
confidence: high
references: [lib/widgets/peak_list_peak_dialog.dart, lib/screens/map_screen_panels.dart, lib/widgets/peak_search_results_list.dart, test/widget/peak_list_peak_dialog_test.dart]
---

## Summary

Delivered five incremental enhancements to the Peak List feature: fixed a repeat-click GPX navigation bug, implemented bottom-right draggable dialog placement, added autofocus and map name display to the add-peak search, extracted a shared search results widget, and changed the default sort order to ascent date descending.

## Reusable Insights

### Dialog Positioning
- `AlertDialog` auto-centers itself regardless of parent - use a custom `Material` surface widget to enable bottom-right placement
- `showGeneralDialog` with `transitionBuilder: (context, animation, secondaryAnimation, child) => FadeTransition(...)` gives immediate appearance at the placed position (no pop-in animation)
- Combine with ` Rect.fromLTRB(...) ` for absolute offset calculations

### Repeat-Click Navigation Bug
- Root cause: async callback fires after dialog closes, focus serial no longer matches
- Fix: use `ref.read(peakListNavigationProvider.notifier).navigateToGpxPath` as the callback directly (no async wrapper) and validate `PeakListNavigationState.pathIdToNavigate` in `build()` via `WidgetsBinding.instance.addPostFrameCallback`

### Shared Widget Extraction
- Extract `PeakSearchResultsList` into `lib/widgets/` to reuse in both `PeakDialog` and `MapScreenPanels`
- Pattern: stateless if parent passes all data, keeps testability high

### Default Sort Order
- `_PeakDetailsTableCardState` already resets sort on list change - just change `defaultSortedColumn` and `defaultSortAscending` in `_PeakDetailsTableCardState.initState`

### Testing New Behaviors
- Use `flinger()` + `await tester.pumpAndSettle()` for drag tests
- `testWidgets('repeat navigation does not fire when dialog is closed', ...)` covers the key regression
- `testWidgets('map name displayed in add-peak search results', ...)` covers the new label
- Test both the widget tests and integration-style tests in `test/widget/` - they run fast and catch regressions

## Decisions

- Chose `showGeneralDialog` over `showDialog` specifically for the transition control needed for bottom-right placement
- Kept `PeakSearchResultsList` stateless since both callers already handle query building

## Pitfalls

- Wrapping `AlertDialog` in a `Positioned` does nothing - the dialog re-centers itself; use a bare `Material` widget instead
- `showGeneralDialog` default transition is scale+fade from center, which looks odd when placed at bottom-right; override with a simple fade transition

## Validation

All new widget tests pass. The behaviors are covered by:
- `peak_list_peak_dialog_test.dart` - draggable dialog, repeat-click GPX
- `map_screen_peak_search_test.dart` - search results widget
- `peak_lists_screen_test.dart` - default sort order

## Follow-ups

- Consider extracting the draggable dialog into a reusable `DraggableDialog` widget if used elsewhere
- Explore whether the map name label can be moved into the `PeakSearchResultsList` widget itself rather than passed as a parameter