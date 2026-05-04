---
title: Desktop Trackpad Map Zoom Controls
date: 2026-05-04
work_type: feature
tags: [flutter_map, trackpad, map-gestures]
confidence: high
references:
  [
    ai_specs/map-control-updates-spec.md,
    ai_specs/map-control-updates-plan.md,
    lib/screens/map_screen.dart,
    lib/services/map_trackpad_gesture_classifier.dart,
    test/widget/map_screen_trackpad_gesture_test.dart,
    test/widget/gpx_tracks_recovery_test.dart,
    test/robot/gpx_tracks/gpx_tracks_robot.dart,
    test/robot/gpx_tracks/selection_journey_test.dart,
  ]
---

## Summary

Added desktop trackpad-specific map controls for `MapScreen`:

- vertical two-finger movement zooms
- horizontal two-finger movement is forced to no-op
- pinch still zooms
- rotation is disabled

The implementation stayed inside `MapScreen`, with one small pure helper for gesture classification and focused widget plus robot regression coverage.

## Reusable Insights

1. `flutter_map` flags were not enough on their own.

`InteractionOptions` can disable built-in rotate and multi-finger behaviors, but it does not express "vertical trackpad motion zooms, horizontal motion no-op" directly. The stable pattern was:

- disable conflicting built-in multi-finger behavior with `InteractiveFlag`
- layer raw trackpad handling with `Listener.onPointerPanZoomStart/Update/End`
- keep map-state sync flowing through the existing notifier path

2. Use raw `PointerPanZoomUpdateEvent.pan`, not transformed pan, for classifier inputs.

The widget tests drive `panZoomUpdate(... pan: ...)` directly. Using `event.pan` matched those tests and avoided coordinate-space surprises that showed up when using `localPan`.

3. Horizontal no-op needed active enforcement, not passive ignoring.

Trackpad gestures can still produce small zoom drift. The reliable behavior was to restore the gesture-start center and zoom when classification returned `none`, rather than merely skipping custom handling.

4. A small pure classifier made edge-case testing cheap.

`lib/services/map_trackpad_gesture_classifier.dart` isolates:

- pinch precedence over translation
- vertical-dominant detection
- dead-zone handling
- zoom delta scaling

That kept `MapScreen` thinner and made threshold tuning safer.

5. Trackpad tests needed tolerance for noisy scale signals.

Pure horizontal trackpad updates can still surface slight scale noise. The classifier used a relatively wide `scaleEpsilon` (`0.25`) so horizontal no-op tests stayed deterministic while explicit pinch coverage still passed.

6. Regressions lived in test helpers too, not just production code.

This change required updating stale assumptions in:

- `test/widget/gpx_tracks_recovery_test.dart`
- `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `test/robot/gpx_tracks/selection_journey_test.dart`

If a helper name encodes old behavior, rename it early so future tests do not preserve the wrong mental model.

## Decisions

- Kept gesture ownership in `lib/screens/map_screen.dart`
- Did not change `MapNotifier.updatePosition()` contract
- Added one pure helper instead of pushing gesture math into the provider
- Preferred repo conventions: Riverpod notifier state sync, key-first widget/robot selectors, focused widget tests before broader suite validation

## Pitfalls

- Pointer wrappers like `AbsorbPointer` or `IgnorePointer` can break pan/zoom event delivery in surprising ways; avoid them unless you have a verified event-flow reason.
- Changing `flutter_map` interaction flags without focused trackpad tests makes it easy to regress pinch or preserve hidden pan behavior.
- A successful happy-path zoom test is not enough; horizontal no-op and diagonal behavior exposed the real conflicts.

## Validation

High confidence came from layered checks:

- focused widget tests: `test/widget/map_screen_trackpad_gesture_test.dart`
- existing regression widget tests: `test/widget/gpx_tracks_recovery_test.dart`
- robot journey coverage: `test/robot/gpx_tracks/selection_journey_test.dart`
- full project validation: `flutter analyze` and `flutter test`

## Follow-ups

- If runtime behavior on real macOS trackpads diverges from widget-test simulation, revisit classifier thresholds first.
- If more trackpad gesture rules arrive, keep the classifier pure and add cases there before widening `MapScreen` logic.
