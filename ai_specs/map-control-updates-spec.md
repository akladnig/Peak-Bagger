<goal>
Update the map interaction model so desktop trackpad two-finger gestures behave predictably on the map screen. Pinch zoom must continue to work as it does today, two-finger rotation must be disabled, vertical two-finger movement should change zoom around the map centre, and horizontal two-finger movement should do nothing.
This matters for desktop users on multi-touch trackpads who currently get accidental pan or rotation while trying to zoom.
</goal>

<background>
The map screen lives in `./lib/screens/map_screen.dart`; map state and zoom persistence live in `./lib/providers/map_provider.dart`. The app uses `flutter_map` `8.2.2` from `./pubspec.yaml` and already routes map movement through `MapOptions.onPositionChanged`.
This change is for desktop trackpad input only; do not broaden scope to unsupported mobile touch behavior.
Existing gesture-heavy coverage lives in `./test/widget/map_screen_peak_info_test.dart`, `./test/widget/tasmap_map_screen_test.dart`, and robot journeys under `./test/robot/**`.
Research the `flutter_map` interaction API first. `InteractionOptions` can disable rotation and other built-in gestures, but the requested vertical-only two-finger zoom may require a narrow custom gesture layer if the package cannot express it directly.
Files to examine: `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, `./test/widget/map_screen_peak_info_test.dart`, `./test/widget/tasmap_map_screen_test.dart`, `./test/robot/**`, `./pubspec.yaml`
</background>

<discovery>
Confirm whether `flutter_map` can satisfy the requested behavior using only `InteractionOptions`.
Verify the behavior on desktop trackpad multi-touch input, not just mouse drag.
Identify the smallest place to intercept or reinterpret two-finger movement without regressing hover, tap, keyboard zoom, wheel zoom, or fit-to-extent logic.
</discovery>

<user_flows>
Primary flow:
1. User performs a two-finger gesture on a desktop trackpad.
2. Vertical movement changes zoom.
3. Pinch in/out still zooms normally.
4. Horizontal two-finger movement does not pan or rotate the map.
5. The gesture ends cleanly with the map centred and in the new zoom state.

Alternative flows:
- Single-finger or mouse drag: continues to pan as today.
- Desktop mouse wheel or keyboard shortcuts: continue to zoom as today.
- Returning to the map after the gesture: no stale gesture state or unwanted jump.

Error flows:
- If the gesture cannot be classified confidently, prefer no movement over unintended pan or rotation.
- If the map reaches min or max zoom, clamp cleanly instead of overshooting or bouncing.
</user_flows>

<requirements>
**Functional:**
1. Disable two-finger rotation for desktop trackpad gestures on the map screen.
2. Preserve existing pinch zoom behavior on the desktop trackpad path.
3. Convert two-finger vertical trackpad motion into zoom changes around the map centre.
4. Treat two-finger horizontal-only trackpad motion as a no-op.
5. Preserve existing single-finger drag, hover, click, keyboard zoom, and mouse wheel behavior.

**Error Handling:**
6. Gesture ambiguity must fail safe by avoiding unintended pan or rotate changes.
7. Zoom updates must clamp to the existing map zoom bounds and keep map state synchronized with `MapNotifier`.

**Edge Cases:**
8. Diagonal two-finger trackpad gestures should zoom based on the vertical component and keep the map centre stable.
9. Rapid finger lift or re-contact should not leave the map in a stuck interaction state.
10. Existing selected-map and selected-track zoom and fit-to-extent behavior must still apply after gesture-driven zoom changes.

**Validation:**
11. Add deterministic tests for the gesture translation path if any custom logic is introduced.
12. Cover the critical map gesture journey with robot-driven or widget-level tests using stable selectors such as `Key('map-interaction-region')`.
13. Verify baseline automated coverage across business or state logic, UI behavior, and the critical gesture journey.
</requirements>

<boundaries>
Edge cases:
- Mixed vertical and horizontal movement: zoom should follow the vertical delta and keep the map centred; horizontal drift should not move the camera.
- Multi-touch cancellation: the map should recover to normal interaction mode immediately.
- Min or max zoom: clamp rather than animate past limits.

Error scenarios:
- Unsupported desktop trackpad hardware or platform quirks: keep the map usable and avoid regressions in existing controls.
- Ambiguous gesture arena outcomes: prefer deterministic no-op over unintended motion.

Limits:
- Do not change persisted map state schema or unrelated selection or hover logic.
- Do not remove existing mouse, keyboard, or wheel affordances while adjusting desktop trackpad gestures.
- Do not broaden scope to unsupported mobile touch behavior.
</boundaries>

<implementation>
Research the `flutter_map` interaction model first and decide whether the requested behavior can be expressed with package configuration alone.
If built-in interaction flags are enough only for part of the behavior, apply the smallest possible change in `./lib/screens/map_screen.dart` and keep the `MapNotifier` sync path in `./lib/providers/map_provider.dart` unchanged unless a narrow seam is required.
If `flutter_map` cannot express vertical-only two-finger zoom directly, add a small custom gesture interpreter near the map widget and isolate its translation logic in a pure helper or small service under `./lib/screens/` or `./lib/services/` so it is easy to test.
Update or add tests in `./test/widget/map_screen_peak_info_test.dart`, `./test/widget/tasmap_map_screen_test.dart`, or a focused map gesture test file; add a robot journey under `./test/robot/**` if the critical flow spans multiple interaction steps.
Audit and update existing tests and helpers that currently assume trackpad pan moves the camera, including `./test/widget/gpx_tracks_recovery_test.dart` and `GpxTracksRobot.panMap()` in `./test/robot/gpx_tracks/gpx_tracks_robot.dart`.
Rename or replace outdated test helpers when their old names encode the previous trackpad-pan behavior.

Avoid:
- Forking or vendoring `flutter_map` unless the package API proves insufficient and no narrower workaround exists.
- Touching unrelated tile, overlay, peak, or track rendering logic.
</implementation>

<stages>
Phase 1: Research and decision
- Read the `flutter_map` interaction docs and the current map screen gesture code.
- Decide whether the behavior can be expressed with package configuration alone.
- Verify the decision against existing tests and platform expectations.

Phase 2: Implement gesture behavior
- Apply the minimal map interaction change in `./lib/screens/map_screen.dart` or a narrow helper.
- Keep pinch zoom and non-touch controls intact.
- Verify map state updates still flow through `MapNotifier`.

Phase 3: Test and stabilize
- Add focused widget or robot coverage for vertical zoom, horizontal no-op, and rotate-disabled behavior.
- Run the relevant map test suite and fix any regressions.
</stages>

<illustrations>
Desired:
- Two fingers move up or down and the map zooms.
- Two fingers pinch in or out and the map zooms as it does today.
- Two fingers twist and the map does not rotate.

Undesired:
- Two fingers dragging left or right pan the map.
- Two fingers twisting change map bearing.
- Gesture handling leaves the map stuck in a down or dragging state after one finger lifts.
</illustrations>

<validation>
Use TDD-style slices for any new gesture logic: start with the most critical behavior, then add the no-op and edge-case coverage one test at a time.
Prefer a pure helper or small seam for any gesture translation so unit tests can cover it deterministically.
For user journeys, add robot coverage for the critical desktop trackpad two-finger zoom path and widget coverage for edge cases such as cancellation, clamp behavior, and horizontal no-op.
Keep selectors key-first and app-owned; `Key('map-interaction-region')` is the preferred anchor for gesture tests.
Verify existing map gesture tests still pass, especially hover, click, and fit-to-extent cases.
Required automated coverage outcome:
- `unit` or logic: any custom gesture math or classification.
- `widget`: map control edge cases and regression states.
- `robot`: the critical two-finger user journey on the map screen.

At least one test must exercise `PointerDeviceKind.trackpad` for the happy-path vertical zoom behavior.
</validation>

<done_when>
The spec is complete when the recommended gesture approach is identified, implemented, and covered by tests; desktop trackpad two-finger rotation no longer occurs; vertical two-finger movement zooms the map around the map centre; horizontal two-finger movement does nothing; pinch zoom and existing controls remain intact; and the map screen’s existing state synchronization continues to work.
</done_when>
