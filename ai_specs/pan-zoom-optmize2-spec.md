<goal>
Reduce pan and zoom jank on the map screen by removing `SharedPreferences` writes from the camera interaction hot path and replacing them with an explicit deferred camera-persistence contract.

This matters because the map screen is a primary interaction surface. Users should be able to drag, zoom, scroll, and recenter the map smoothly without persistence work running on gesture frames, while still getting the expected saved map position when they return later.
</goal>

<background>
The source brief identifies one confirmed hotspot: `MapNotifier.updatePosition(...)` in `./lib/providers/map_provider.dart` immediately calls `savePosition()`, and `savePosition()` performs `SharedPreferences.getInstance()` plus multiple preference writes. That hot path is reached from gesture-driven and interaction-driven map flows in `./lib/screens/map_screen.dart`, including `onPositionChanged`, custom trackpad pan or zoom handling, keyboard-driven scrolling or zooming, and some direct camera commands that currently call `updatePosition(...)` after moving the controller.

Current code also couples camera persistence with unrelated preference persistence. `savePosition()` writes both camera keys and peak-list selection keys, so a naive debounce would accidentally delay non-camera preference saves too.

The current test harness matters here as well. `./test/harness/test_map_notifier.dart` overrides `updatePosition(...)` and bypasses real persistence, so the implementation must introduce a deterministic seam that focused provider or widget tests can exercise with the production notifier path.

Preserve current persisted preference keys and startup loading behavior:
- `map_position_lat`
- `map_position_lng`
- `map_zoom`
- `peak_list_selection_mode`
- `peak_list_id`

Files to examine:
- `./ai_specs/pan-zoom-optmize2.md`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/core/constants.dart`
- `./lib/providers/peak_list_selection_provider.dart`
- `./test/harness/test_map_notifier.dart`
- `./test/providers/map_peak_list_selection_persistence_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/map_screen_trackpad_gesture_test.dart`
- `./test/widget/map_screen_camera_request_test.dart`
- `./test/robot/**`
</background>

<user_flows>
Primary flow:
1. User opens the map screen.
2. User drags or zooms the map with touch, mouse wheel, or standard map gestures.
3. The visible camera updates immediately with no persistence work on each intermediate frame.
4. After movement settles, the final camera state is persisted once through the new deferred save seam.

Alternative flows:
- Desktop trackpad gesture: the map updates during `PointerPanZoomUpdate`, then persists once from `PointerPanZoomEnd` or the same explicit settle seam for that path.
- Keyboard interaction: zoom shortcuts and held-key scrolling update the camera immediately, then persist once when the key-driven movement completes.
- Programmatic camera move that already persists today: the map still ends with the same visible camera and same persisted or non-persisted behavior as before, but any persisting flow saves only once from the final settled camera state.

Error flows:
- Deferred camera persistence fails: keep in-memory map state correct, swallow the persistence failure, and continue without user-visible interruption.
- A pending deferred save becomes stale because a newer camera update occurs: cancel or replace the older pending save so only the latest intended final camera is committed.
</user_flows>

<discovery>
Before implementation, document the current camera mutation and persistence ownership matrix.

At minimum, identify:
1. Every current `savePosition()` caller in `./lib/providers/map_provider.dart`.
2. Every current camera-mutating entry point, including persisting and non-persisting paths in both `MapScreen` and `MapNotifier`.
3. Every `MapScreen` path that calls `updatePosition(...)` after a controller move.
4. Which flows should remain persisting versus remain transient in the desired end state.
5. Whether any existing `flutter_map` move-end event is reliable enough for a given path, or whether the simpler recommended seam is a short debounce for drag or wheel plus explicit command-end commits for trackpad, keyboard, and direct commands.
6. Which route-entry handoff mechanism each off-screen camera flow uses today, including `cameraRequest*`, `selectedMapFocusSerial`, and `selectedTrackFocusSerial`, plus which non-camera payload fields must survive that handoff.
7. How each off-screen handoff behaves in both real route-entry modes used by this app shell: cold map creation versus an already-mounted but hidden `/map` branch.

Document discovery results in two separate inventories:
- camera-mutation and camera-persistence flows
- non-camera preference-save flows that currently share `savePosition()`

The discovery output must explicitly classify every live current `savePosition()` caller as deferred, immediate, or duplicate-save cleanup. Dead code proven unused may be removed from the matrix instead of preserved.

Do not broaden this task into controller-feedback, rebuild-isolation, or geometry-cache work unless implementation proves the persistence-only change is inseparable from a small required ownership cleanup.
</discovery>

<requirements>
**Functional:**
1. Remove the direct `savePosition()` call from `MapNotifier.updatePosition(...)` so gesture-driven camera updates no longer write preferences on every intermediate update.
2. Split camera state mutation from camera persistence by introducing a named API boundary for transient camera updates versus final persisted camera commits.
3. Keep visible camera state immediate for drag, wheel, trackpad, keyboard, and direct command flows; the optimization must defer only storage writes, not visible movement.
4. Use an explicit split persistence ownership model:
   - `MapScreen` owns gesture or command completion detection and any pending deferred-save scheduling for in-screen interactive paths it directly controls.
   - `MapNotifier` owns the final persisted camera commit API and storage writes.
   - provider-owned or off-screen route-entry requests that already represent a final desired camera may commit immediately through the provider instead of waiting for a screen-owned settle seam, but they must still preserve or replace the existing route-entry visible-camera handoff so the user sees the requested camera correctly in both cold-start and already-mounted hidden-branch cases.
   - the route-entry contract must cover all current handoff styles: `cameraRequest*` request consumption, `selectedMapFocusSerial` selected-map fit orchestration, and `selectedTrackFocusSerial` selected-track fit orchestration.
5. For drag or wheel interaction, use a concrete debounce constant owned in `./lib/core/constants.dart`. Default first pass to `150ms` unless the audit proves another value within a documented acceptable range is required. The debounce must be fakeable in tests.
6. For custom trackpad gestures, persist once from `PointerPanZoomEnd` or an equivalent explicit settle seam for that path.
7. For keyboard scrolling, persist once from `_stopScrolling()`. For discrete keyboard zoom shortcuts, commit once per handled keydown because that path is already a one-shot final camera change rather than a continuous movement stream.
8. For programmatic camera flows that already persist today, preserve whether each flow persists or not, but normalize persisting flows so they commit only once from the final settled camera state.
9. Define the desired camera persistence contract explicitly for every current camera-mutating entry point. The matrix must be exhaustive, and at minimum it must include these current paths:
   - `MapScreen.onPositionChanged(...)`
   - `MapScreen._handleTrackpadPanZoomUpdate(...)`
   - `MapScreen` keyboard zoom shortcuts
   - `MapScreen._moveMap(...)` and `_stopScrolling()`
   - `MapScreen._focusPeakDirect(...)`
   - `MapScreen._navigateToGridReference(...)` and any direct camera helper it uses
   - `MapScreen._zoomToMapExtent(...)`
   - `MapScreen._zoomToTrackExtent(...)`
    - any direct `MapController.move(...)` plus `updatePosition(...)` path that currently exists in `MapScreen`
    - `MapNotifier.requestCameraMove(...)`
    - `MapNotifier.selectMap(...)`
    - `MapNotifier.centerOnLocation(...)`
    - `MapNotifier.centerOnSelectedLocation(...)`
    - `MapNotifier.centerOnPeak(...)`
    - `MapNotifier.showTrack(...)`
    - `MapNotifier.selectAllSearchResults(...)`
    Each listed path must be classified as deferred final camera commit, immediate final camera commit, or intentionally non-persisting.
    For off-screen or route-entry paths, the matrix must also record which handoff mechanism applies (`cameraRequest*`, `selectedMapFocusSerial`, `selectedTrackFocusSerial`, or an explicit replacement), how that path behaves in both cold-start and hidden-branch cases, and which payload state must survive until the requested camera is visible to the user.
    For `requestCameraMove(...)` flows, explicitly classify preservation of `selectedLocation`, `selectedPeaks`, `clearGotoMgrs`, `clearHoveredPeakId`, and `clearHoveredTrackId` rather than collapsing them into generic flow-specific state.
    For `selectMap(...)`, explicitly preserve or deliberately reclassify `selectedMap`, `tasmapDisplayMode`, `clearSelectedLocation`, `mapSuggestions`, and `mapSearchQuery`.
    For `showTrack(...)`, explicitly preserve or deliberately reclassify `tracks`, `selectedTrackId`, `selectedLocation`, `showTracks`, `clearHoveredTrackId`, and `clearGotoMgrs`.
10. Preserve the current one-shot serial-gating behavior for selected-map and selected-track handoffs. Any retained or replacement mechanism must suppress stale or repeated fit work equivalently to the current pending or applied serial checks.
11. Define a separate immediate non-camera preference contract for `MapNotifier.selectPeakList(...)` and `MapNotifier._resetToAllPeaks()`. These flows must remain provider-owned and immediate, and must not route through the deferred camera-save seam.
12. Split camera persistence from unrelated preference persistence. Peak-list selection mode and selected peak-list id must persist through a dedicated non-camera save path so those settings do not inherit gesture debounce timing.
13. Preserve existing persisted key names, stored value formats, and startup restoration behavior for both camera and peak-list preferences.
14. If a debouncer, scheduler, or save callback seam is introduced, make it deterministic and testable from production-notifier tests without relying on `TestMapNotifier` overrides.
15. Keep current non-camera interaction side effects from transient camera updates unless the code audit proves a specific side effect should move elsewhere. This includes current MGRS update behavior and current hover or popup clearing behavior that already happens as part of `updatePosition(...)`.
16. Keep `isFirstLaunch` owned by camera load or successful camera commit behavior only. Peak-list-only preference saves must not change `isFirstLaunch`.
17. Add explicit no-op suppression for final persistence commits so identical final camera states do not schedule or write redundant saves. Reuse `MapConstants.cameraEpsilon` for camera equality unless the audit proves a different threshold is necessary.

**Error Handling:**
18. Failed deferred camera persistence must not revert visible camera state or crash the map screen.
19. Pending deferred save work must be replaced while newer camera updates are arriving, so only the latest intended final camera remains pending.
20. `MapScreen` must observe app lifecycle changes for the pending interactive save owner seam, such as `WidgetsBindingObserver`, and flush the latest pending camera save exactly once before suspension when the app pauses or backgrounds.
21. On real deferred-save owner disposal, flush the latest pending camera save exactly once before teardown if a final camera exists. Do not treat indexed-shell branch switches as disposal events when the map branch remains alive.
22. Any successful pause flush or disposal flush must consume the pending deferred-save state so later lifecycle events do not re-flush the same final camera unless a newer camera becomes pending afterward.
23. If a chosen completion seam is unreliable for a specific path, fall back to the simpler explicit debounce or command-end seam rather than restoring per-frame persistence.

**Edge Cases:**
24. Rapid sequences of drag, zoom, and keyboard or trackpad input must persist only the most recent settled camera state.
25. Non-camera preference saves such as peak-list selection must remain immediate even while camera persistence is deferred.
26. Programmatic flows that currently do not persist, such as flows intentionally treated as transient after the code audit, must remain non-persisting.
27. `showTrack(...)` must not persist a pre-fit intermediate camera if the selected-track fit path will later produce the true final camera. The spec must normalize selected-track focus to one final persisted camera owner.

**Validation:**
28. Add baseline automated coverage across logic or state behavior, widget interaction behavior, and at least one critical user journey that exercises deferred camera persistence or explicitly document why persistence proof remains outside the robot lane.
29. Follow vertical-slice TDD during implementation: write one failing test at a time, implement the smallest production change to pass it, then refactor only after green.
30. Behavior-first TDD slices must cover this order:
   - transient camera updates no longer write preferences immediately
   - final camera state is saved once after drag or wheel settles
   - trackpad gesture end commits exactly one final save
   - keyboard movement or zoom commits exactly one final save on completion
   - peak-list selection persistence remains immediate and independent of camera debounce
   - failure, disposal, and stale-pending-save behavior remain safe
31. Testability seams must allow deterministic control of deferred work, such as constructor injection of a save scheduler, debouncer abstraction, or equivalent fakeable timing boundary.
32. Prefer fakes over mocks for deferred-save scheduling and preference writes; mock only true external boundaries if a fake is impractical.
33. Keep a robot-driven journey covering one critical map interaction happy path with stable app-owned selectors. Reuse `Key('map-interaction-region')` as the primary gesture anchor unless a narrower stable key is required.
34. Robot coverage is required for gesture wiring and user-visible map behavior. End-to-end persistence proof is required in robot tests only if the test harness uses the real `MapNotifier` path; otherwise persistence proof must live in provider or widget tests using the production notifier.
35. Default test split:
   - unit or provider tests for persistence ownership, debounce, stale-save replacement, and peak-list persistence separation
   - widget tests for trackpad, keyboard, and map-screen completion seams
   - robot journey coverage for a critical user-visible movement path and gesture behavior
   - provider or widget persistence assertions for final saved camera state unless a real-`MapNotifier` robot harness is deliberately introduced
36. Report any justified testing gap explicitly if a specific `flutter_map` completion signal cannot be driven deterministically in tests.
</requirements>

<boundaries>
Edge cases:
- Do not change user-visible map behavior beyond removing hot-path persistence work.
- Keep current camera restoration schema and preference keys unchanged.
- Preserve current persist-versus-transient behavior per flow unless the code audit shows a duplicated or accidental persistence path that this spec explicitly normalizes.
- Treat peak-list selection persistence as a separate immediate preference concern, not as a deferred camera-persistence flow.
- Use `MapConstants.cameraEpsilon` for final camera no-op suppression unless the audit proves it is insufficient.
- Removing dead code from the matrix is allowed only when the code path is proven unused; otherwise current persistence behavior must be preserved or explicitly normalized.
- Off-screen camera flows must remain correct in both cold-start and already-mounted hidden-branch shell states.

Error scenarios:
- If `SharedPreferences` access fails, continue with correct in-memory camera state and no crash.
- If the app pauses or backgrounds while a final camera is pending, `MapScreen` must flush that final camera once before suspension through its lifecycle observer seam.
- If the real deferred-save owner is disposed with a pending final camera, flush that pending final camera once before teardown.
- After a successful lifecycle or disposal flush, the pending final camera must be consumed so the same camera is not flushed again without a newer pending update.
- If multiple settle signals occur for one movement sequence, the implementation must still commit at most one final save for the resulting final camera state.

Limits:
- Do not redesign the map UI.
- Do not replace `flutter_map`.
- Do not introduce new persistence dependencies.
- Do not broaden this task into profiling-driven geometry or rebuild optimization work.
- Do not change the startup load contract for existing saved camera or peak-list preferences.
</boundaries>

<implementation>
Expected output paths:
- Update `./lib/providers/map_provider.dart` to separate transient camera updates from persisted camera commits and to split camera persistence from peak-list preference persistence.
- Update `./lib/screens/map_screen.dart` to own movement completion detection for the interaction paths it controls, observe app lifecycle for pause flushing, and call the new final camera-commit seam only at safe completion points.
- Update `./lib/core/constants.dart` to add the shared debounce duration constant for camera persistence behavior.
- Update `./test/harness/test_map_notifier.dart` only as needed to stay aligned with the new notifier API shape; do not let the test harness remain the only covered path.
- Add or update focused tests under `./test/providers/` and `./test/widget/`, including `./test/providers/map_peak_list_selection_persistence_test.dart` and `./test/widget/map_screen_camera_request_test.dart` for real-notifier persistence assertions, plus `./test/widget/map_screen_keyboard_test.dart` and `./test/widget/map_screen_trackpad_gesture_test.dart` for gesture behavior where appropriate.
- Keep the current `TestMapNotifier` keyboard and trackpad widget files gesture-focused unless they are deliberately converted to a real-notifier harness; final persistence assertions for those paths must live in real-notifier widget tests.
- Add new focused real-notifier widget tests if needed for selected-map and selected-track hidden-branch replay or serial-gating coverage beyond the listed files above.
- Add or update one robot journey under `./test/robot/` for gesture wiring and user-visible behavior. Do not require the robot lane to prove persistence unless it uses the real `MapNotifier` path.

Implementation expectations:
1. Keep the change as small as possible while making persistence ownership explicit.
2. Prefer a named transient-update method plus a named persisted-commit method over boolean flags whose ownership is hard to reason about.
3. Keep first-pass completion seams simple: `150ms` shared debounce for drag or wheel, explicit end events for trackpad, immediate commit for discrete keyboard zoom, `_stopScrolling()` commit for held-key panning, app-pause flush for pending final camera state, and explicit final-commit points for programmatic flows that persist today.
4. Only use `flutter_map` move-end or event-stream completion if it is demonstrably more reliable for a specific path than the simpler seam above.
5. Move peak-list preference writes behind a dedicated immediate save method so startup reconciliation and selection changes keep working independently of camera persistence.
6. Keep `isFirstLaunch` transitions coupled to camera load or camera commit behavior only; splitting persistence must not let a peak-list-only save clear first-launch state.
7. Document the final persistence matrix in code comments or tests so future camera-entry paths have one clear contract to follow.
8. Avoid hidden duplicate-save behavior. If a flow currently saves both during an intermediate provider mutation and again after a final controller fit, normalize that to one final save.
9. Normalize selected-track focus explicitly: `showTrack(...)` must not own a pre-fit persisted camera when `_zoomToTrackExtent(...)` or its successor is responsible for the final fit-owned camera.
10. Keep deferred interactive scheduling in `MapScreen` for drag, wheel, trackpad, and held-key movement. `MapNotifier` should expose the final commit API and own storage writes, but it should not become the owner of interactive debounce timing in the first pass.
11. Make `MapScreen` the concrete lifecycle observer for pending interactive save work, flush the latest pending final camera on app pause or background, and also flush it in widget disposal. Do not rely on branch switches as a disposal signal.
12. Off-screen or provider-owned route-entry camera requests that already represent a final desired camera may persist immediately through the provider, but they must still preserve or replace the existing `cameraRequest*`, `selectedMapFocusSerial`, and `selectedTrackFocusSerial` visible-camera handoff mechanisms in both cold-start and hidden-branch cases.
13. Preserve one-shot serial gating for selected-map and selected-track fit handoffs, including stale-request suppression equivalent to the current pending or applied serial checks.
14. Route-entry preservation must include carried payload state, not only visible camera. For `requestCameraMove(...)` flows, preserve or explicitly reclassify `selectedLocation`, `selectedPeaks`, `clearGotoMgrs`, `clearHoveredPeakId`, and `clearHoveredTrackId`.
15. Preserve the current `currentMgrs`, hover-clearing, and popup-clearing semantics owned by transient camera updates unless a specific side effect is intentionally reassigned and covered by tests.
16. Keep non-camera preference persistence immediate and isolated from camera commit timing.

Avoid:
- Reintroducing per-frame persistence through another helper or callback.
- Folding unrelated optimization work into the same change.
- Depending only on `TestMapNotifier` behavior to verify the new contract.
</implementation>

<stages>
Phase 1: Audit current persistence ownership.
- Enumerate current persisting and non-persisting camera flows.
- Define the desired final persistence matrix before code changes.

Phase 2: Introduce the persistence seam.
- Remove hot-path camera saves from transient updates.
- Split camera persistence from peak-list persistence.
- Add deterministic deferred-save ownership.

Phase 3: Route interaction paths through the seam.
- Wire drag or wheel, trackpad, keyboard, and programmatic persisting flows to commit once from their final settle points.

Phase 4: Validate behavior.
- Add focused provider and widget coverage.
- Add or confirm one robot journey for gesture wiring and user-visible behavior.
- Verify no regressions in startup restoration and peak-list persistence.
- Verify provider or widget coverage proves final persistence unless a real-`MapNotifier` robot harness is introduced.
- Verify app-pause or lifecycle-flush behavior.
- Verify route-entry handoff coverage for `cameraRequest*`, `selectedMapFocusSerial`, and `selectedTrackFocusSerial` paths where persistence behavior is touched.
- Verify route-entry correctness separately for cold-start and already-mounted hidden-branch cases.
</stages>

<illustrations>
Desired:
- Dragging the map updates the camera smoothly and does not trigger repeated preference writes during the drag.
- A held keyboard pan persists once when movement stops, not once per timer tick.
- Choosing a peak-list filter still persists immediately even if the user is actively moving the map.

Undesired:
- Moving `savePosition()` behind a debounce without splitting peak-list preference writes, causing list-selection persistence to lag.
- Letting both a debounce and an explicit end callback save the same final camera.
- Preserving smooth interaction but losing the final camera because pending deferred work has no disposal contract.
</illustrations>

<validation>
Run focused automated coverage and confirm the intended contract rather than only smoke-testing manually.

Required outcomes:
1. Provider or unit tests prove transient camera updates do not write preferences immediately.
2. Provider or unit tests prove the final camera commit writes the same persisted keys and values as before.
3. Provider or unit tests prove peak-list selection persistence remains immediate and independent from camera debounce.
4. Widget tests prove keyboard and trackpad paths commit exactly one final save at the intended settle seam.
5. Widget or provider tests prove stale pending saves are canceled or replaced deterministically.
6. Widget or provider tests prove disposal behavior flushes the latest pending final camera once at real owner teardown.
7. Widget or provider tests prove app-pause or lifecycle flush behavior.
8. One robot-driven journey covers a critical map interaction path using stable selectors and verifies gesture wiring and user-visible behavior. End-to-end persistence assertions belong in robot tests only if that lane uses the real `MapNotifier`; otherwise they must be proven in provider or widget tests.
9. Real-notifier widget tests prove final persistence for keyboard and trackpad paths; the existing `TestMapNotifier` keyboard and trackpad widget files may remain gesture-only unless they are intentionally converted.
10. Provider or widget coverage proves route-entry behavior for both cold-start and hidden-branch cases, and proves one-shot serial gating for selected-map and selected-track handoffs.

TDD expectations:
- Execute one failing test at a time.
- Keep each slice vertical: one behavior, minimal implementation, then refactor.
- Test through public notifier and widget interfaces, not private helpers.

Robot expectations:
- Use app-owned stable keys only.
- Prefer existing map interaction selectors before adding new ones.
- Add only the smallest selector or seam needed for deterministic completion and persistence assertions.
</validation>

<done_when>
1. `updatePosition(...)` no longer performs per-frame persistence.
2. Camera persistence has one explicit deferred contract with clear ownership and cleanup behavior.
3. Peak-list preference persistence is separated from camera persistence and remains immediate.
4. Every current persisting camera path saves at most once from its final settled camera state.
5. Existing persisted key names and startup restore behavior are unchanged.
6. Automated tests cover the deferred persistence contract across provider or unit, widget, and robot or justified residual-risk levels.
</done_when>
