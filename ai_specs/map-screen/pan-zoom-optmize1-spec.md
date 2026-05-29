<goal>
Eliminate pan and zoom jank on the map screen by removing redundant controller feedback introduced by rebuild-time camera sync.

This matters because `./lib/screens/map_screen.dart` is the app's primary interaction surface. Users should be able to drag and zoom smoothly while programmatic camera commands from the rest of the app still land on the correct map position.
</goal>

<background>
The confirmed hotspot is in `./lib/screens/map_screen.dart`. `MapScreen.build()` currently schedules a post-frame `_mapController.move(mapState.center, mapState.zoom)` whenever `mapState.syncEnabled` is true, while `onPositionChanged(...)` also writes the latest gesture-driven center and zoom back into `mapProvider`. During a drag or zoom, that creates a feedback loop: gesture updates provider state, provider rebuilds the screen, the rebuild schedules another controller move, and the controller is asked to reapply the same camera.

`./lib/providers/map_provider.dart` currently stores camera state and the broad `syncEnabled` flag. Several non-map-screen entry points rely on provider camera mutation plus later map-screen synchronization, including `centerOnLocation(...)`, `centerOnSelectedLocation(...)`, `showTrack(...)`, actions in `./lib/widgets/map_action_rail.dart`, the track-opening flow in `./lib/widgets/peak_list_peak_dialog.dart`, and the route-to-map flow in `./lib/screens/objectbox_admin_screen.dart`.

The codebase already has a one-shot orchestration pattern for selected map and selected track focus through `selectedMapFocusSerial` and `selectedTrackFocusSerial`. Reuse that style instead of keeping a rebuild-driven boolean sync contract.

`./lib/router.dart` uses `StatefulShellRoute.indexedStack`, so the `/map` branch can remain mounted while offstage. The replacement sync mechanism must therefore work both when the map is visible and when another screen triggers a route-entry camera change before the user returns to `/map`.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/core/constants.dart`
- `./lib/router.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./test/harness/test_map_notifier.dart`
- `./test/widget/map_screen_trackpad_gesture_test.dart`
- relevant `./test/widget/` map-screen sync tests
- relevant `./test/robot/` route-to-map journey tests
</background>

<user_flows>
Primary flow:
1. User opens the map screen.
2. User drags the map or zooms with mouse wheel, trackpad, keyboard, or touch.
3. The camera stays under direct interaction control without snap-back, redundant move calls, or visible jitter.

Alternative flows:
- External recenter: user triggers center-on-location or center-on-marker from the action rail and the map moves once to the requested camera state.
- Route-entry camera change: another screen updates map state, navigates to `/map`, and the map is already at the requested area when the branch becomes visible.
- Peak search focus: user selects a peak from search while already on the map, the camera moves to that peak, and the peak remains the selected peak focus state.
- Explicit fit flow: selected-map and selected-track focus still fit the camera exactly once using their existing serial-gated path.

Error flows:
- If an external camera request arrives while the user is actively dragging or zooming, the request is deferred until the interaction ends instead of interrupting the gesture.
- If multiple external camera requests arrive before the pending request is applied, only the latest still-valid request is applied.
- If an external request resolves to the same camera already shown on screen, it is consumed as a no-op without forcing another controller move.
</user_flows>

<discovery>
Before implementation, confirm the exact list of call sites that currently depend on provider camera mutation plus the generic `syncEnabled` build-time sync.

Specifically verify:
1. Which current flows need an explicit provider-to-screen camera request because they do not already own a direct `MapController` write.
2. Confirm that `centerOnPeak(...)` remains a visible-map-only focus-and-select flow, and stays distinct from plain peak-dialog navigation to a peak.
3. Which existing widget or robot tests already cover route-entry map navigation, selected-map focus, selected-track focus, and trackpad zoom.
4. A reproducible baseline profile scenario on the primary desktop target so before/after performance can be compared consistently.
5. Keep the implementation scope tight. If the feedback-loop removal materially resolves the jank, do not expand this spec into persistence, hover, or geometry caching work.
</discovery>

<requirements>
**Functional:**
1. Remove the generic post-frame `_mapController.move(mapState.center, mapState.zoom)` call from `MapScreen.build()`.
2. Replace rebuild-driven camera sync with one explicit external camera request contract for non-controller callers. Preferred shape: requested center, requested zoom, and a monotonic request serial or equivalent consumed-once token in `MapState`, aligned with the existing focus-serial pattern.
3. Only flows that do not own a `MapController` may create an external camera request. Gesture-driven updates from `onPositionChanged(...)`, `_handleTrackpadPanZoomUpdate(...)`, keyboard scrolling, and other direct controller-owned movement inside `MapScreen` must update provider state without enqueueing a second controller move back to the same camera.
4. If an external request matches the current controller camera within the shared no-op comparison rules, consume it without calling `_mapController.move(...)`.
5. If an external request arrives during an active drag, active trackpad gesture, or held-key scroll, defer it and apply only the latest pending request after the interaction settles.
6. Preserve explicit programmatic camera flows, including `centerOnLocation(...)`, `centerOnSelectedLocation(...)`, goto navigation, selected-map fit, selected-track fit, the `I` key recenter path, the action-rail location button, the action-rail center-on-marker button, peak-dialog navigate-to-peak, the peak-dialog track flow, and the objectbox-admin route-to-map flow.
7. Preserve `centerOnPeak(...)` as a visible-map-only focus-and-select flow. It must remain distinct from plain peak-dialog navigation to a peak: selecting a peak from search may update `selectedPeaks`, while peak-dialog route-entry navigation must remain a plain camera move unless a separate UX change is explicitly requested. `centerOnPeak(...)` must remain non-persisting, must update `selectedPeaks`, and must not set `selectedLocation`.
8. Preserve the existing one-shot selected-map and selected-track focus behavior. No rebuild should cause repeated fit attempts after a serial has been applied.
9. Preserve existing visible side effects that currently travel with camera updates: `currentMgrs`, `selectedLocation`, popup dismissal, hover clearing, and peak-info clearing at the current zoom threshold.
10. Make the fate of `syncEnabled` explicit. Preferred end state: remove it from the generic camera-sync contract entirely. If it remains temporarily, it may only participate in named request creation or route-entry compatibility behavior and must never again trigger unconditional sync from `build()`.
11. Split shared location recenter helpers by caller ownership. `MapScreen` key `C`, `onSecondaryTap`, and any visible-map `centerOnLocation(...)` path such as goto completion must become direct controller-owned camera commands, while non-controller callers such as `MapActionRail` and `ObjectBoxAdminScreen` may continue through the external request path or explicitly named non-controller location APIs.
12. Treat `updatePosition(...)` as a direct controller-owned camera commit API only. Callers that do not own a `MapController` must not use `updatePosition(...)` and must instead use the external request path or a named non-controller request API.

**Error Handling:**
13. If the `/map` branch is mounted and the controller is ready, apply an external camera request immediately even while the branch is offstage. If the controller is not ready, retain only the latest valid external camera request until the screen can safely apply it.
14. If a deferred request is superseded before application, the older request must never apply afterward.
15. If the screen is disposed or the controller is not ready when a deferred request would apply, fail safely without crashing and without replaying the request indefinitely on later rebuilds.

**Edge Cases:**
16. Repeated requests to the same center and zoom must not cause extra controller moves or extra rebuild churn.
17. An external request that arrives mid-gesture must not snap the map away from the user before gesture end.
18. Route-to-map flows from other branches must still land on the requested camera state when `/map` becomes visible again.
19. Existing tested behavior for trackpad zoom, keyboard zoom, keyboard scrolling, selected-map fit, and selected-track fit must remain intact.

**Validation:**
20. Add baseline automated coverage across provider or state logic, widget behavior, and one critical cross-screen journey.
21. Reuse stable app-owned selectors where possible, especially `Key('map-interaction-region')`; add a new key only if a missing selector makes the deferred-sync journey impossible to assert reliably.
</requirements>

<boundaries>
Edge cases:
- Same-camera no-op suppression must use one shared comparison contract. Use exact equality for booleans, enums, ids, and serials, plus `MapConstants.cameraEpsilon` in `./lib/core/constants.dart` for latitude, longitude, and zoom comparisons. Recommended default: `1e-6`.
- Add `MapConstants.defaultMapZoom = 12` as the fallback zoom when selected-map fit cannot yield a usable zoom for goto completion, and use the same constant to replace existing selected-map-fit fallback zoom literals.
- Deferred external camera requests need explicit ownership and consumption rules. `MapScreen` may own temporary pending-until-ready or pending-until-gesture-end state because it owns `MapController`; `MapNotifier` owns state mutation that creates the request.
- Reuse the existing serial-gated pattern for selected-map and selected-track fit flows instead of inventing another unrelated one-shot mechanism.

Error scenarios:
- Because `/map` lives inside an indexed-stack shell, the replacement contract must work when the map branch is mounted but offstage, and it must apply immediately once controller-ready rather than waiting for branch visibility.
- If a pending request is replaced by a newer one, only the newest request may apply.
- If the map becomes ready after a request is created, apply only the latest still-valid request once.

Limits:
- Do not broaden this spec into hover, geometry, tile-loading, or persistence optimization work.
- Do not change the persisted camera schema or route structure.
- Do not replace `flutter_map`.
- Do not add new dependencies unless existing Flutter and Dart primitives are insufficient.
</boundaries>

<implementation>
Expected output paths:
- `./lib/screens/map_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/core/constants.dart`
- `./lib/widgets/map_action_rail.dart` only if its flow must emit the new explicit request shape
- `./lib/widgets/peak_list_peak_dialog.dart` only if its flow depends on the old sync contract
- `./lib/screens/objectbox_admin_screen.dart` only if its route-to-map flow depends on the old sync contract
- focused tests under `./test/widget/`
- `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

Implementation expectations:
1. Keep the change minimal and centered on camera ownership.
2. Introduce one named external camera request seam for non-controller callers instead of relying on `MapState.center` and `MapState.zoom` changes plus `syncEnabled` inside `build()`.
3. Align the new seam with existing `selectedMapFocusSerial` and `selectedTrackFocusSerial` conventions. A monotonic serial or equivalent consumed-once token is preferred over a boolean flag.
4. Separate these responsibilities clearly:
   Direct controller-owned interaction updates: gesture drag or zoom, keyboard movement, `fitCamera`, and immediate screen-owned commands.
   Provider-to-screen external sync requests: commands created by callers that do not own the direct controller interaction path, including off-branch route-entry flows and non-controller map actions.
5. Direct controller-owned interaction updates must continue updating visible provider state immediately, but they must not enqueue a second external sync request back to the same camera.
6. External sync application must be guarded by map readiness, active gesture or active keyboard-scroll state, same-camera no-op suppression, and mounted or disposed safety checks.
7. Preserve and document one clear request-consumption rule. Once an external request has been applied or judged a no-op, it must be marked consumed so rebuilds cannot replay it.
8. Reuse post-frame scheduling only at explicit apply points where controller readiness is required. Do not restore a generic build-time post-frame sync.
9. Inspect and normalize all current camera entry points that rely on the old pattern, including:
   - `MapNotifier.centerOnLocation(...)`
   - `MapNotifier.centerOnSelectedLocation(...)`
   - `MapNotifier.showTrack(...)`
   - `MapScreen._navigateToGridReference(...)`
   - the `MapScreen` `I` key recenter path
   - `MapActionRail` location and center-on-marker actions
   - `PeakListPeakDialog._openTrack(...)`
   - `PeakListPeakDialog._navigateToPeakOnMap(...)`
   - `ObjectBoxAdminScreen._viewPeakOnMainMap(...)`
10. Keep shared location camera helpers split by caller ownership. `MapScreen` key `C`, `onSecondaryTap`, and visible-map goto completion must stop relying on provider-only sync and instead become direct controller-owned camera commands; non-controller `centerOnSelectedLocation(...)` or `centerOnLocation(...)` callers may remain request-driven.
11. Treat `updatePosition(...)` as controller-owned only. Off-controller callers must not use it. In particular, `ObjectBoxAdminScreen._viewPeakOnMainMap(...)` and `PeakListPeakDialog._navigateToPeakOnMap()` must migrate from direct `updatePosition(...)` calls to the non-controller request path.
12. Keep `centerOnPeak(...)` controller-owned and visible-map-only. It should remain the peak-search focus-and-select path, must stay distinct from plain peak-dialog navigation to a peak, and must no longer rely on generic `syncEnabled` replay from `build()`.
13. Keep selected-map and selected-track fit orchestration working as today. If those flows already have explicit controller-driven handling, do not reroute them through the generic external request path unless that simplifies the contract without widening scope.
14. For goto with `selectedMap != null`, selected-map fit may contribute a zoom value only. It must not perform an intermediate visible `_zoomToMapExtent(...)` or any other pre-recenter controller move before the final camera settles on the resolved location.
15. If `syncEnabled` remains in the model for compatibility, constrain it to named request creation or route-entry behavior only.
16. Use a single shared camera-comparison helper or constant set so production code and tests agree on no-op rules.
17. Preferred minimal non-controller request surface: one request API for arbitrary location targets, plus a separate selected-location request API only if selected-location flows require distinct semantics that cannot be expressed through the generic location request.
18. Require explicit camera end-state tables in the implementation notes:

External and off-controller camera flows:

| Flow | Final center and zoom | `selectedLocation` | `selectedPeaks` | Persists | Notes |
| --- | --- | --- | --- | --- | --- |
| ObjectBox admin view peak | peak coordinates, zoom `MapConstants.defaultZoom` | set to the peak location | unchanged | yes | off-controller route-entry flow |
| Peak dialog navigate to peak | peak coordinates, zoom `MapConstants.defaultZoom` | unchanged | unchanged | yes | plain navigation, not focus-and-select |
| Action rail current location | user coordinates, current zoom | set to the user location | unchanged | yes | request may apply offstage if controller-ready |
| Action rail center on marker | current `selectedLocation`, current zoom | unchanged | unchanged | yes | no-op if no selected location |
| Peak dialog open track | fitted track center and zoom | peak location if provided | unchanged | yes when fit succeeds | preserve `selectedTrackFocusSerial` behavior |

Goto flow:

| Condition | Final center and zoom | `selectedMap` | `selectedLocation` | Persists | Notes |
| --- | --- | --- | --- | --- | --- |
| `selectedMap == null` | resolved grid-reference location, zoom `MapConstants.defaultZoom` | unchanged | set to resolved location | yes | goto ends on the requested location |
| `selectedMap != null` | resolved grid-reference location, zoom derived from selected-map fit, else `MapConstants.defaultMapZoom` | remains selected | set to resolved location | yes | selected-map context remains, but goto still finishes centered on the requested location without an intermediate visible fit move |

19. Keep `TestMapNotifier` aligned with the new public contract only where it is still used, but require at least one dedicated production-notifier-compatible lane to exercise real request creation, deferral, consumption, and save behavior.

Avoid:
- replacing one generic rebuild-time sync with another generic diff-guarded sync in `build()`
- widening scope into unrelated map performance work before this feedback loop is removed
- introducing multiple competing one-shot camera request mechanisms for the same class of flow
</implementation>

<validation>
Testing strategy:
- Follow vertical-slice TDD. Add one failing behavior test at a time, implement the smallest passing change, then refactor only on green.
- Prefer tests against public provider and screen behavior rather than private methods.
- Keep deterministic seams minimal. If the new request contract needs a consumed serial or request token, assert it through public state transitions and visible map behavior.

Required automated coverage:
1. Provider or focused state tests:
- non-map camera commands create exactly one external camera request token
- direct interaction updates do not create a second sync request
- same-camera external requests are suppressible under the shared epsilon contract
- `centerOnPeak(...)` remains distinct from plain peak-dialog navigation semantics

2. Widget tests:
- dragging or zooming the map updates state without replaying rebuild-time camera sync
- an external camera request while idle applies once
- an external camera request during an active gesture is deferred until gesture end
- when multiple deferred external requests arrive during one gesture, only the latest applies
- selected-map or selected-track fit serial behavior still applies once
- peak-search selection still behaves as the visible-map focus-and-select flow rather than the generic route-entry request path
- visible-map selected-location recenter via keyboard `C` or `onSecondaryTap` still works through the direct controller-owned path
- non-controller center-on-marker recenter still works through the request-driven path if that path is retained
- visible-map goto or other direct `centerOnLocation(...)` completion still works through the direct controller-owned path
- non-controller `centerOnLocation(...)` callers such as objectbox-admin or action-rail current location still work through the request-driven path

3. Robot-driven journey coverage:
- use `./test/robot/objectbox_admin/objectbox_admin_journey_test.dart` as the preferred critical journey that reaches `/map` from another screen and verifies the requested camera state after navigation
- legacy assertions in that journey about `syncEnabled` are not normative; update the journey to assert the final camera and selection state required by this spec instead
- reuse stable selectors such as `Key('map-interaction-region')` and existing action keys like `Key('goto-map-fab')` when possible
- if a new selector is required, add the smallest app-owned key necessary to assert the route-entry or deferred-sync behavior

Production-compatible lane:
- require at least one focused test path that uses the real `MapNotifier` with fake or injected dependencies, so request creation, deferral, consumption, and persistence are not validated only through `TestMapNotifier`

Profiling requirement:
- Capture a reproducible before and after profile in Flutter profile mode on the primary desktop target using the same scenario for both runs:
1. open `/map`
2. ensure peaks are visible
3. if practical, keep at least one visible track or selected overlay active
4. perform repeated drag and trackpad zoom interactions for 10 to 15 seconds
- Record whether redundant controller moves disappear from the interaction loop and whether frame-time spikes or visible stutter improve.
- If the feedback-loop fix materially removes the jank, stop here and leave broader optimization work for a follow-up spec rather than expanding this one mid-implementation.

Coverage split:
- unit or provider tests own request creation, consumption, and no-op logic
- widget tests own map-ready, gesture deferral, and screen-controller coordination
- robot tests own the critical cross-screen route-entry journey
- residual risk to report explicitly if left untested: behavior when `/map` is mounted offstage, the controller becomes ready after request creation, and an older request is superseded before the latest request applies
</validation>

<done_when>
- `MapScreen.build()` no longer performs generic camera sync from provider state on every rebuild.
- External camera sync is explicit, one-shot, gesture-aware, and protected by no-op guards.
- Pan and zoom interactions no longer feed immediately back into redundant controller moves.
- Existing selected-map, selected-track, goto, and external route-to-map camera flows still work.
- `centerOnPeak(...)` still works as the visible-map focus-and-select flow, and peak-dialog navigation remains a plain route-entry camera move.
- Automated coverage exists for request creation, deferred application, same-camera suppression, and one route-entry journey.
- Before and after profiling shows the rebuild-to-move feedback loop is gone and interaction smoothness is improved enough that no broader optimization is needed in this scope.
</done_when>
