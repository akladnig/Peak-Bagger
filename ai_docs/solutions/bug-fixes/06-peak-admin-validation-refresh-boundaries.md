---
title: Peak admin validation and refresh boundaries
date: 2026-04-23
work_type: bugfix
tags: [flutter, objectbox, peak-admin]
confidence: high
references:
  - ai_specs/06-objectbox-peak-admin-spec.md
  - ai_specs/003-peaks-to-mgrs-spec.md
  - lib/services/peak_admin_editor.dart
  - lib/providers/map_provider.dart
  - lib/screens/objectbox_admin_screen.dart
  - lib/screens/objectbox_admin_screen_details.dart
  - test/services/peak_admin_editor_test.dart
  - test/widget/objectbox_admin_shell_test.dart
  - test/robot/objectbox_admin/objectbox_admin_journey_test.dart
---

## Summary
Two separate bugs surfaced in the Peak admin flow: live form validation could throw on malformed complete MGRS input, and peak marker reloads were accidentally using the network-backed refresh path.
The fix was to keep validation pure and defensive in `PeakAdminEditor.validateAndBuild()`, and to split local marker reloads (`reloadPeakMarkers()`) from the Overpass-backed `refreshPeaks()` flow.

## Reusable Insights
- Anything called from `TextFormField.onChanged` must never throw. Convert parse failures into validation errors inside the editor/helper layer.
- Keep MGRS parsing and coordinate derivation in one domain helper. UI code should only display the returned errors, not interpret parse exceptions.
- Reserve `refreshPeaks()` for the explicit Settings `Refresh Peak Data` action. Screen-entry reloads for `MapScreen`, `PeakListsScreen`, and admin save flows should use a local repository-backed reload path.
- If a save flow needs to update map markers, use the local `PeakRepository` state already in memory. Do not hit Overpass just to repaint markers.
- When a create flow should leave the new row selected, assert that selection directly in tests. The refresh + select sequence can look correct visually while still dropping selection state.

## Decisions
- Complete MGRS validation now catches conversion failures and returns field errors instead of bubbling a `FormatException` through Flutter callbacks.
- `reloadPeakMarkers()` became the shared screen-entry marker refresh seam so admin saves and in-app navigation stay offline and deterministic.

## Pitfalls
- A defensive validation catch is still needed even after regex checks, because `PeakMgrsConverter.fromForwardString()` can reject syntactically valid-looking input.
- Reusing `refreshPeaks()` for local UI refreshes can silently trigger Overpass and fail with unrelated HTTP errors.

## Validation
- `flutter test test/services/peak_admin_editor_test.dart`
- `flutter test test/widget/objectbox_admin_shell_test.dart`
- `flutter test test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
- `flutter analyze`
