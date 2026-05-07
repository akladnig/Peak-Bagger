<goal>
Reduce pan and zoom jank on the map screen by removing full-screen and full-provider churn from continuous camera movement.
This change matters for users actively dragging, pinching, scrolling, or keyboard-panning the map, because interaction should stay smooth while zoom and MGRS readouts remain live.
</goal>

<background>
The map screen lives in `./lib/screens/map_screen.dart`; canonical map state, persistence, and camera-related side effects live in `./lib/providers/map_provider.dart`; peak filtering currently depends on the full map provider in `./lib/providers/peak_list_selection_provider.dart`; heavy layer construction lives in `./lib/screens/map_screen_layers.dart`.
Today, continuous camera paths call `MapNotifier.updatePosition()` on every movement tick from `MapOptions.onPositionChanged`, custom trackpad zoom handling, mouse-wheel zoom, and keyboard scrolling. `MapScreen` also watches the full `mapProvider`, so camera motion rebuilds the whole screen and re-evaluates unrelated providers and layer builders. `InteractiveFlag.pinchMove` and `InteractiveFlag.pinchZoom` are currently disabled; this spec preserves the existing custom desktop trackpad pinch path and does not broaden scope to new touch-pinch support.
Existing interaction and persistence coverage already exists in `./test/widget/map_screen_trackpad_gesture_test.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/widget/map_screen_persistence_test.dart`, and related map widget tests under `./test/widget/`.
Map-route widgets that currently watch `mapProvider` and may need dependency narrowing include `./lib/widgets/map_action_rail.dart`, `./lib/widgets/map_peak_lists_drawer.dart`, `./lib/widgets/map_basemaps_drawer.dart`, and the map-specific snackbar host in `./lib/router.dart`.
The existing debounce source of truth is `MapConstants.cameraSaveDebounce` in `./lib/core/constants.dart`.
Files to examine: `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, `./lib/providers/peak_list_selection_provider.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/widgets/map_action_rail.dart`, `./lib/widgets/map_peak_lists_drawer.dart`, `./lib/widgets/map_basemaps_drawer.dart`, `./lib/router.dart`, `./lib/core/constants.dart`, `./test/widget/map_screen_trackpad_gesture_test.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/widget/map_screen_persistence_test.dart`
</background>

<discovery>
Identify the smallest architecture change that prevents continuous camera movement from rebuilding unrelated map UI.
Decide whether the live camera should be held in local widget state, a narrow camera-specific notifier, or another minimal seam; prefer the option that minimizes churn without broad provider rewrites.
Audit every camera movement entry point and classify it as continuous interaction or discrete camera move before changing behavior.
Verify the intended UX for the existing custom trackpad pinch path so the live-camera model remains coherent across drag, trackpad zoom, and held-key pan.
</discovery>

<user_flows>
Primary flow:
1. User pans or zooms the map with drag, mouse-wheel zoom, trackpad zoom gestures, or held-key movement.
2. The visible map updates smoothly during motion.
3. Zoom and MGRS readouts remain live during motion.
4. The existing custom trackpad pinch zoom path behaves coherently with the rest of the live-camera policy while rotation remains disabled.
5. The hot path and at least one explicitly instrumented visible non-camera consumer do not rebuild just because the camera is moving.
6. When motion ends, canonical app camera state and persistence catch up cleanly.

Alternative flows:
- Discrete zoom or move actions: keyboard single-step zoom, goto, selected-map focus, selected-track focus, peak-search focus, my-location recenter, camera requests, and explicit recenter actions may commit immediately, but must still avoid duplicate feedback loops.
- Returning to the map after a restored or programmatic camera move: the visible camera, canonical provider state, and persisted state remain aligned.
- Long drag or long held-key pan: canonical state sync behavior must follow the explicit per-input policy below, without reverting to frame-by-frame provider writes.

Error flows:
- If persistence fails, the visible map movement still succeeds and the failure does not block further interaction.
- If a new explicit camera request arrives during a continuous interaction, the final applied camera must be deterministic and must not jump back to stale transient state.
</user_flows>

<requirements>
**Functional:**
1. Continuous camera movement must no longer use full `MapState` updates as its per-frame transport.
2. The implementation must preserve live visible camera updates during continuous interaction.
3. Zoom and MGRS readouts must remain live during continuous interaction without requiring full `MapScreen` rebuilds.
4. Preserve the existing custom desktop trackpad pinch zoom behavior. Touch pinch remains out of scope for this optimization, and rotation stays disabled.
5. `MapScreen` must no longer watch full `mapProvider` for the full route subtree during continuous camera interaction; split the screen into narrower consumers or local live-camera subtrees so continuous motion does not rebuild unrelated UI.
6. `filteredPeaksProvider` must stop watching full `MapState` and depend only on the peak and peak-list-selection inputs it actually needs.
7. Canonical camera state in `MapNotifier` must synchronize according to an explicit per-input policy rather than a general per-frame update rule.
8. All camera input paths must be reviewed and placed into one of two buckets with explicit behavior.
9. Continuous paths: mouse drag, mouse-wheel zoom, desktop trackpad zoom handling, and held-key scrolling must use the live-camera path and the policy defined in this spec for end-sync and mid-interaction debounce behavior.
10. Discrete paths: single-step keyboard zoom, goto navigation, selected-map or selected-track focus, peak-search focus, direct recenter, my-location recenter, secondary-tap selected-location recenter, and camera requests may commit immediately, but must not duplicate local-live updates or trigger stale camera echoes.
11. Existing user-visible behavior for popup dismissal, selected location, hover clearing, zoom clamping, and camera persistence must be preserved unless a narrower and clearly equivalent timing change is required to eliminate per-frame state writes.
12. Heavy whole-screen and unrelated-provider rebuild churn must be removed in the hot path and in the explicitly instrumented visible non-camera consumer, but a minimal isolated live-camera subtree is allowed to update during continuous motion if that subtree is necessary for visually coherent map interaction.
13. All camera writes must participate in one deterministic ownership rule across continuous live state, direct controller moves, and provider-issued camera requests. The newest accepted camera intent must win, and a delayed continuous flush must never overwrite a newer direct goto, focus, recenter, or `requestCameraMove()` action.
14. Every camera intent must register through one acceptance seam in the chosen ownership model. An intent is accepted only when the map controller has the final visible camera for that intent. Only accepted intents may update canonical provider camera state or persist camera preferences.
15. This acceptance seam must cover direct `move(...)` paths, provider-requested moves consumed later, and `fitCamera(...)` paths whose final visible zoom or center is only known after controller application or a post-frame callback.
16. Hidden-route camera state must follow this contract:
- `MapState.center`, `MapState.zoom`, and camera-derived `currentMgrs` represent the last accepted visible camera.
- Pending off-route camera intents must live in a single `pending camera request object` until the map route mounts and the controller accepts them.
- The `pending camera request object` must carry camera state plus request payload state including `selectedLocation`, `selectedPeaks`, request-owned clear flags, and the request serial or token until acceptance rather than mutating accepted visible-camera fields early.
- Only one `pending camera request object` may exist at a time. A newer pending camera request replaces any older pending request and its payload unless the spec explicitly states otherwise for a specific flow.
- Off-route request creation must not overwrite the accepted camera fields merely to stage a future move.
- Route-entry and camera-request flows must consume the pending request on map mount, then update canonical accepted camera state only after visible application succeeds.
- The `pending camera request object` replaces the current scattered `cameraRequest*` representation in the target design.
- Off-route readers must use the `pending camera request object` for pending intent and accepted camera fields only for the last visible accepted camera.

17. The `pending camera request object` schema must include these minimum fields:
- required accepted-at-apply inputs: `center`, `zoom`, request serial or token
- selection payload semantics for `selectedLocation`: preserve, replace with a provided location, or clear
- selection payload semantics for `selectedPeaks`: preserve, replace with a provided list, or clear-to-empty
- request-owned behavior flags: whether to clear goto MGRS, hovered peak, hovered track, or other request-scoped state as part of accepted apply
- persistence control: whether the accepted request writes persisted camera state after visible application

The schema may include additional fields only if they are required to preserve current route-entry or request-driven behavior.
18. The sync policy for continuous inputs must be implemented exactly as follows:

| Input path | Category | Mid-interaction canonical sync | End sync | Dedupe rule |
| --- | --- | --- | --- | --- |
| Mouse drag via `onPositionChanged` | Continuous | Required on `MapConstants.cameraSaveDebounce` | Required | Do not commit again at end if the latest canonical state already matches the live camera |
| Mouse-wheel zoom via `onPositionChanged` | Continuous | Required on `MapConstants.cameraSaveDebounce` | Not required | Debounce commit is sufficient; do not require a separate end-sync hook |
| Desktop trackpad zoom custom handling | Continuous | Optional; may remain end-only if that keeps the implementation smaller | Required | Do not commit again at end if no live-camera change remains unsynced |
| Held-key scrolling | Continuous | Optional; may remain end-only if that keeps the implementation smaller | Required on key-stop | Do not commit again if the final live camera already matches the latest canonical commit |
| Single-step keyboard zoom | Discrete | Not applicable | Immediate | One immediate canonical commit per accepted discrete action |
| Keyboard `I` selected-location recenter plus info popup | Discrete | Not applicable | Immediate | Preserve current popup timing behavior after accepted visible application |
| Goto, focus-to-extent, peak-search focus, my-location recenter, secondary-tap selected-location recenter, direct recenter, provider camera request-object apply | Discrete | Not applicable | Immediate | These moves supersede any older pending continuous commit |

19. If a shared debounce interval is introduced or retained, keep `MapConstants.cameraSaveDebounce` as the source of truth unless a test-backed reason to change it is discovered during implementation.
20. Any current or future camera entry point omitted from the explicit table above must follow this default rule until explicitly specialized: if it directly moves the map controller and immediately syncs canonical provider state, it is a discrete move and must follow the discrete policy.
21. For discrete camera intents, persistence must happen only after the visible camera application has been accepted as the latest winning intent. Superseded or un-applied intents must not write final persisted camera state. The component that owns the final accepted camera application must own that persistence write.

**Error Handling:**
22. Canonical sync or persistence failures must not interrupt visible camera interaction.
23. For this task, preserve the current non-user-facing failure behavior for persistence and camera sync. Do not introduce new snackbars, dialogs, or other user-visible error surfaces as part of this optimization.
24. Pending camera state must still flush on lifecycle pause, hide, detach, or dispose so transient movement is not silently lost.

**Edge Cases:**
25. Min and max zoom clamping must remain correct for both continuous and discrete paths.
26. A continuous interaction ending after a newer explicit camera request must not overwrite the newer request with stale center or zoom values.
27. Readouts must not flicker, freeze, or temporarily display mismatched center and zoom data while the canonical provider catches up.
28. The implementation must distinguish between live-camera subscribers and non-subscribers during continuous motion:
- Must follow live camera: visible map viewport, zoom readout, MGRS readout, existing custom trackpad pinch behavior, and interaction-driven popup dismissal behavior.
- Must not subscribe to live camera updates: map-route drawers, snackbar hosts, search panels, goto panels, action rail state that does not depend on camera movement, and other non-camera route chrome.
- Non-camera widgets may continue to observe canonical provider state only for their own non-camera behavior.
29. Preserve current MGRS readout precedence during and after the refactor by extending it for live camera motion as `cursorMgrs ?? gotoMgrs ?? liveCameraMgrs ?? currentMgrs`.
30. During continuous camera motion, the extracted hot-path seam must provide a transient `liveCameraMgrs` value derived from the live camera. `currentMgrs` remains the canonical accepted-camera MGRS and updates only at canonical sync points.
31. Tapping the map to select a location must continue to show the tapped location's MGRS in the readout until hover or camera motion overrides it.
32. Preserve current `showInfoPopup` dismissal timing during continuous gesture motion; the refactor must not accidentally leave the map info popup visible while gesture-driven camera movement is in progress.
33. The implementation must use the following live-vs-canonical matrix for zoom-sensitive map content and interaction logic during continuous motion:

| Layer or behavior | Rendering source | Visibility threshold source | Hit-testing source |
| --- | --- | --- | --- |
| Peak markers | Canonical sync | Canonical sync | Canonical sync |
| Track polylines | Canonical sync | Canonical sync | Canonical sync |
| Selected-location marker | Live camera subtree | Live camera subtree | N/A |
| Selected-peaks circles | Canonical sync | Canonical sync | N/A |
| Selected-map rectangle | Canonical sync | Canonical sync | N/A |
| All-map overlay polygons | Canonical sync | Canonical sync | N/A |
| Selected-map labels | Canonical sync | Canonical sync | N/A |
| Overlay labels | Canonical sync | Canonical sync | N/A |
| Peak hover | N/A | Canonical sync | Canonical sync |
| Track hover | N/A | Canonical sync | Canonical sync |

This lag for peak markers, track polylines, selected-peaks circles, all-map overlay polygons, selected-map labels, overlay labels, and related hover behavior is intentional and acceptable for this optimization in exchange for reducing hot-path churn.
Selected-map labels and overlay labels intentionally share the same canonical-sync behavior.
These layers must refresh together on canonical sync so rendered geometry, visibility thresholds, and hover targets stay aligned after each accepted debounce or end-sync update.
Selected-map rectangle and selected-map labels together form the selected-map visual feature and intentionally share the same canonical-sync cadence.
By default, no escalation from canonical sync to a narrower live subtree occurs unless the user explicitly requests a revision after reviewing the implemented behavior.
Content within one visible layer must not mix live and canonical sources inconsistently; for example, a layer's threshold logic and rendered geometry must use the same source.
34. Movement side effects currently bundled inside `updatePosition()` must be reassigned explicitly rather than lost implicitly:
- Must happen during live continuous motion: hover invalidation tied to camera movement, cursor MGRS clearing if the current interaction should suppress stale pointer location, and peak-info dismissal when live zoom crosses the existing clear threshold.
- Must happen at canonical sync points: canonical center and zoom update, persisted current MGRS update, and any provider state whose correctness does not require per-frame churn.
- Discrete camera moves must preserve their current immediate side effects unless a test-backed simplification proves equivalent.
35. Use the following timing contract for side effects and camera-adjacent state fields:

| Field or side effect | Live motion | Accepted discrete apply | Canonical sync | Superseded intent |
| --- | --- | --- | --- | --- |
| `selectedLocation` | No change unless the live-motion path explicitly owns it | Update only when the accepted discrete intent owns selected-location behavior | Do not mutate opportunistically | Must not overwrite newer selected location |
| `selectedPeaks` | No change | Update only when the accepted discrete intent owns selected-peaks behavior | Do not mutate opportunistically | Must not overwrite newer selected peaks |
| `cursorMgrs` | Clear when motion invalidates pointer-derived readout | Preserve tapped-location behavior and other accepted-intent behavior as currently visible to the user | Do not recreate stale cursor-derived values | Must not restore stale cursor MGRS |
| `liveCameraMgrs` | Derived from the live camera during continuous motion and used in readout precedence ahead of `currentMgrs` | Not used once a discrete intent has been accepted | Clear when canonical sync catches up or the interaction ends | Must not outlive the superseded live interaction |
| `currentMgrs` | No direct live write required | May remain unchanged until canonical sync unless the accepted discrete intent already depends on immediate canonical write | Update from the accepted camera state | Must not write stale camera-derived MGRS |
| `hoveredPeakId` | Clear on live camera motion | Preserve existing accepted discrete behavior unless motion semantics require clearing | May remain cleared | Must not restore stale hover state |
| `hoveredTrackId` | Clear on live camera motion | Preserve existing accepted discrete behavior unless motion semantics require clearing | May remain cleared | Must not restore stale hover state |
| `peakInfo` | Clear when live zoom crosses the existing clear threshold | Preserve or clear according to the accepted discrete intent's existing behavior | May remain cleared | Must not restore stale popup content |
| `showInfoPopup` | Dismiss on live gesture motion using current behavior timing | Preserve existing accepted discrete behavior unless that intent intentionally dismisses it | Do not re-open implicitly | Must not re-show stale popup state |
| Persistence | Never per frame | Write only after the accepted winning visible camera | Commit the accepted final camera state | Must never persist stale superseded state |

35. The current integer-rounded zoom readout is acceptable for the existing custom trackpad pinch path; the spec does not require fractional zoom text in the readout.
36. Trackpad scope is limited to the current custom zoom-only behavior. Custom desktop trackpad panning remains out of scope for this optimization.

**Validation:**
37. Add deterministic coverage for the synchronization policy so tests can prove continuous paths no longer persist or commit on every frame.
38. Add coverage that distinguishes continuous-path debounce or end-sync behavior from discrete-path immediate commit behavior.
39. Verify baseline automated coverage across camera-sync logic, screen behavior, and the critical pan or zoom journey.
40. Continuous-path tests must stop using `mapProvider.center` or `mapProvider.zoom` as the live-camera oracle. Migrate those tests to assert against live readouts, visible UI behavior, or a dedicated live-camera seam; reserve provider assertions for canonical sync points only.
41. `MapMgrsReadout` and `MapZoomReadout` must expose stable app-owned selectors unless equivalent app-owned selectors already exist.
42. Add deterministic validation that proves the hot path and one explicitly instrumented visible non-camera consumer no longer rebuild during continuous camera motion at both of these minimum seams:
- the primary `MapScreen` route-root split or equivalent hot-path consumer boundary
- at least one secondary non-camera consumer such as `MapActionRail`
43. Rebuild-proof validation must use an explicit instrumentation seam. Acceptable proof mechanisms are a tiny test-only build-counter widget, a debug callback on an extracted subtree, or another deterministic app-owned rebuild counter boundary suitable for widget tests.
44. The `MapScreen` root must be split into at least one extracted hot-path boundary or equivalent consumer seam suitable for rebuild instrumentation before rebuild-proof validation is attempted.
45. Additional map-route consumers that currently watch full `mapProvider`, such as `MapPeakListsDrawer`, `MapBasemapsDrawer`, and the route snackbar consumer, only require narrowing if instrumentation shows camera churn still reaches them in the interaction states where they are present; the spec only claims optimization of the hot path and the explicitly instrumented visible non-camera consumer unless that additional proof exists.
</requirements>

<boundaries>
Edge cases:
- Very short gestures: they should still commit once at end, not be dropped.
- Long continuous motion: debounce-based canonical sync may happen during movement, but must be meaningfully less frequent than frame-by-frame updates.
- Mixed input sequences: a user can drag, then use keyboard zoom, then trigger goto; camera ownership must stay deterministic.

Error scenarios:
- Persistence or preference writes fail: keep the visible map interactive and keep the in-memory canonical state correct.
- Widget disposal during a pending debounce: flush pending canonical state once and avoid duplicate commits.

Limits:
- Do not change the persisted preference keys or the stored camera schema.
- Do not broaden scope to track cache decoding, hover-hit-test optimization, or overlay geometry caching in this spec.
- Do not rewrite unrelated selection, search, drawer, or tile-loading behavior except where dependency narrowing is required to stop camera-driven rebuild churn.
- Keep optimization scope focused on the map route and its direct dependents. Settings-screen `mapProvider` consumption is out of scope unless a discovered regression makes it impossible to preserve map-route behavior without touching it.
- Do not add new trackpad pan behavior as part of this optimization.
- Do not broaden scope to new touch-pinch support as part of this optimization.
- Do not allow discrete camera intents to persist stale final camera values after they have been superseded.
- Legacy camera paths that bypass controller-owned application, such as provider-level camera mutations discovered during implementation, must either be migrated into the chosen acceptance model or be explicitly called out as out of scope with justification.
- The implementation audit must grep for every `state.copyWith(center:`, `state.copyWith(zoom:`, `updatePosition(`, `requestCameraMove(`, `.move(`, and `fitCamera(` call. Each match must be migrated into the request-object acceptance model, covered by the continuous/discrete policy, or explicitly marked out of scope with justification.
- The camera-entry inventory below is a seed list, not a claim of completeness. The grep audit must append a discovered-writers appendix before refactor implementation tasks begin.
</boundaries>

<implementation>
Refactor the map camera flow so continuous interaction uses a narrow live-camera state instead of repeated `MapNotifier.updatePosition()` calls.
The preferred shape is the smallest one that satisfies the requirements: either local `MapScreen` state or a small dedicated camera-state seam. Avoid broadening `MapState` further if a narrower seam is sufficient.

Implementation expectations:
- No refactor implementation work begins until the discovered-writers appendix is complete and every discovered writer is mapped to the request-object acceptance model or explicitly left out of scope with justification.
- Keep canonical persisted camera state in `./lib/providers/map_provider.dart`, but stop using it as the per-frame source of truth for continuous interaction.
- Preserve the existing custom desktop trackpad pinch path while keeping touch pinch disabled and rotation disabled.
- Introduce an explicit distinction between continuous sync and discrete commit behavior. If useful, replace `updatePosition()` with clearer APIs whose names encode their responsibility.
- Make camera ownership explicit. The chosen seam must carry enough version or token information that pending continuous commits can be ignored once a newer discrete move or provider-issued request has been accepted.
- Use a single request object for pending off-route and provider-issued camera intents rather than retaining the scattered `cameraRequest*` representation.
- Reuse existing focus serial mechanisms where practical. Do not require a full replacement of `selectedMapFocusSerial` or `selectedTrackFocusSerial` if a smaller addition, such as one continuous-interaction token or coordinator, can enforce the latest-wins rule across all camera intents.
- Fix or migrate legacy discrete camera paths that currently mutate provider camera state without going through controller-owned acceptance, including `selectAllSearchResults()`, `centerOnPeak()`, and `centerOnLocationWithZoom()`, unless a specific path is explicitly excluded from scope with justification.
- Follow the hidden-route contract above for off-route reader behavior.
- Keep live readout data close to the live camera seam so `MapMgrsReadout` and `MapZoomReadout` can update cheaply during motion.
- Drag end-sync may be implemented via pointer-up or another explicit end-of-interaction seam, as long as the latest-wins and dedupe rules hold.
- Custom trackpad pinch end-sync may be implemented via `PointerPanZoomEndEvent` or another explicit end-of-interaction seam that preserves the latest-wins and dedupe rules.
- Split `MapScreen` into narrower consumers or local live-camera subtrees as a primary requirement, not optional cleanup.
- Narrow `filteredPeaksProvider` so it no longer watches full `MapState`.
- Narrow provider dependencies in `./lib/widgets/map_action_rail.dart`, `./lib/widgets/map_peak_lists_drawer.dart`, `./lib/widgets/map_basemaps_drawer.dart`, and the map-route `Consumer` in `./lib/router.dart` only if rebuild instrumentation shows camera churn still reaches them after the main hot path is fixed.
- Isolate any live-updating map-content churn to the smallest possible subtree; do not reintroduce whole-screen rebuilds in order to keep zoom-sensitive layers live.
- Preserve the current debounce and flush semantics for persistence by keeping `MapConstants.cameraSaveDebounce` as the default debounce source, but apply it to canonical camera sync points rather than every frame.
- Add stable app-owned selectors to `MapMgrsReadout` and `MapZoomReadout` unless equivalent app-owned selectors already exist.
- Treat widget tests as the default integration seam for this task. Add robot coverage only if the current harness can drive the chosen behavior deterministically without significant new test infrastructure.
- Prioritize the hot path first. Primary likely edits are `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, and `./lib/providers/peak_list_selection_provider.dart`. Treat `./lib/widgets/map_action_rail.dart`, `./lib/widgets/map_peak_lists_drawer.dart`, `./lib/widgets/map_basemaps_drawer.dart`, and `./lib/router.dart` as secondary dependency-narrowing candidates only if instrumentation shows camera churn still reaches them after the hot path is fixed.
- Migrate existing continuous-path widget tests away from immediate `mapProvider` camera assertions and toward live-camera observables.

Primary likely changes (provisional until the discovered-writers appendix is complete):
- `./lib/screens/map_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/providers/peak_list_selection_provider.dart`

Secondary likely changes if dependency narrowing is still needed after the hot path fix (also provisional until the discovered-writers appendix is complete):
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/map_peak_lists_drawer.dart`
- `./lib/widgets/map_basemaps_drawer.dart`
- `./lib/router.dart`

Test files likely to change:
- Focused files under `./test/widget/`, with optional robot coverage under `./test/robot/` only if the existing harness is already a good fit

Avoid:
- Rebuilding the entire optimization around a large new architecture or generalized state framework.
- Changing overlay rendering algorithms, track simplification, hover math, or persistence format as part of this task.
- Introducing backward-compatibility branches unless a concrete behavior break is discovered.
</implementation>

<camera_entry_points>
Current concrete camera entry points below are a seed list that must be audited and mapped to the policy table above.

Continuous paths:
- `MapOptions.onPositionChanged` drag path
- `MapOptions.onPositionChanged` mouse-wheel zoom path
- `_handleTrackpadPanZoomUpdate()` zoom path
- `_startScrolling()` / `_moveMap()` held-key pan path

Discrete paths:
- `_focusPeakDirect()`
- `MapNotifier.selectAllSearchResults()` extent focus path
- `centerOnLocationWithZoom()` direct provider camera mutation path
- action-rail `centerOnSelectedLocation()` path
- keyboard discrete zoom shortcut handler (`=`, `.`, `+`, `-`, `,`, `<`, `>`) in `MapScreen`
- keyboard `I` selected-location recenter plus info popup path
- `_moveVisibleMapToLocation()`
- `_centerOnSelectedLocationDirect()`
- `_zoomToMapExtent()`
- `_zoomToTrackExtent()`
- `MapNotifier.requestCameraMove()` consumption and apply path
- selected-map focus serial path
- selected-track focus serial path
- action-rail my-location recenter via `centerOnLocation()`
- secondary-tap selected-location recenter handler

Any additional direct controller move or provider-driven camera request discovered during implementation must be added to this inventory and mapped before the refactor is considered complete.
</camera_entry_points>

<discovered_writers>
Before any refactor implementation tasks begin, append the results of the required camera-writer grep audit here or in an equivalent implementation note. For each discovered writer, record whether it was migrated into the acceptance model, covered by the continuous/discrete policy unchanged, or explicitly left out of scope with justification.
</discovered_writers>

<stages>
Phase 1: Classify camera paths and choose the seam
- Audit all current camera update entry points.
- Audit all current camera writer sites, including provider-level `center`/`zoom` mutations and controller-owned move/apply paths.
- Complete and append the discovered-writers audit before any refactor implementation tasks begin. This is a Phase 1 exit gate.
- Mark each one continuous or discrete.
- Encode the accepted per-input sync policy from this spec before changing production code.
- Choose the smallest live-camera seam that can keep readouts live without whole-screen rebuilds.

Phase 2: Refactor sync behavior
- Move continuous camera motion to the live-camera path.
- Keep canonical provider sync at end or debounce points.
- Add the shared latest-wins protection across continuous commits, direct controller moves, and provider camera requests.
- Preserve immediate commits for discrete camera actions where required.
- Make discrete persistence happen only after the winning visible camera application.
- Establish and implement the single acceptance seam for all camera intents, including `fitCamera` and legacy provider-mutated discrete paths.

Phase 3: Narrow rebuild scope
- Remove broad `mapProvider` watches in the map route subtree that cause unrelated recomputation on camera changes.
- Keep non-camera UI insulated from transient motion updates.
- Reassign `updatePosition()` side effects deliberately so hover, cursor, and popup behavior remain correct under the new live-camera path.
- Isolate any necessary live map-content subtree so it is smaller than the full route subtree.

Phase 4: Validate and stabilize
- Add and update tests for continuous versus discrete camera behavior, readout liveness, persistence timing, test-migration expectations, and lifecycle flushes.
- Add and update tests that prove the hot path and the explicitly instrumented visible non-camera consumer no longer rebuild during continuous camera motion at the required validation seams.
- Run the relevant map test suite and fix regressions.
</stages>

<illustrations>
Desired:
- Dragging the map feels smooth while the zoom or MGRS readouts keep changing.
- The existing custom trackpad pinch zoom path works and follows the same live-camera rules without re-enabling rotation.
- A long held-key pan does not trigger provider writes on every timer tick, but still ends with the correct saved camera.
- Goto or focus-to-extent still moves immediately and ends with canonical state aligned.

Undesired:
- Every drag or zoom tick rebuilds the full `MapScreen` and its heavy layers.
- Live readouts stop updating until the gesture ends.
- A stale pending gesture commit overwrites a newer explicit camera move.
- A superseded discrete camera intent still writes stale persisted camera coordinates.
</illustrations>

<validation>
Use strict vertical-slice TDD where practical: write one failing test for the most important camera-sync behavior, implement the minimum code to pass it, then add the next behavior slice.
Prefer test seams that exercise public behavior. If a debounce or sync coordinator is extracted, keep it small and deterministic so unit tests can verify timing and stale-update protection without mocking internals.

Required coverage split:
- `unit` or logic: any extracted camera-sync coordinator, continuous-versus-discrete classification, debounce policy, stale-commit protection, and winning-intent persistence timing.
- `widget`: drag, mouse-wheel zoom, trackpad, keyboard, lifecycle flush, and live-readout behavior on `MapScreen`.
- `robot`: optional only. Add one critical happy-path map journey only if the existing robot harness can drive it deterministically with stable selectors and without substantial new harness work; otherwise document the justified omission and keep coverage at widget level.

Required assertions:
- Continuous gesture movement changes the visible map and live readouts before canonical provider sync.
- Continuous gesture movement does not cause immediate persistence on every frame.
- After `N` continuous motion updates in one interaction, canonical camera sync count is measurably less than `N`; use a counting fake or equivalent seam at the canonical camera-sync boundary rather than inferring this only from persisted preference writes.
- Mouse-wheel zoom commits canonical state on debounce without requiring a separate end-sync hook.
- Continuous gesture end commits canonical camera state exactly once unless a debounce already committed the latest identical state.
- Held-key pan follows the continuous path semantics.
- The existing custom trackpad pinch path remains functional and follows the continuous-path sync policy without re-enabling rotation.
- Discrete keyboard zoom and explicit camera requests still commit immediately.
- Discrete camera persistence occurs only after the winning visible camera application and does not write stale superseded values.
- Lifecycle pause or dispose flushes the latest pending canonical camera state once.
- Non-camera route UI does not rebuild during continuous camera motion at the chosen validation seam.

Selector and seam expectations:
- Keep selectors key-first and app-owned; reuse `Key('map-interaction-region')`.
- `MapMgrsReadout` and `MapZoomReadout` must expose stable app-owned selectors unless equivalent app-owned selectors already exist.
- Prefer fakes or test notifiers at true boundaries such as persistence counting or canonical camera-sync counting; avoid mocking widget internals.
- Migrate existing continuous-path tests away from immediate `mapProvider` camera assertions; use live UI/readouts or a dedicated live-camera seam for in-motion assertions, and reserve provider assertions for canonical sync points.
</validation>

<done_when>
The spec is complete when continuous map pan and zoom no longer depend on per-frame full `MapState` updates, the existing custom trackpad pinch path remains functional, live readouts remain responsive during movement, canonical camera state synchronizes on end or debounce points, discrete camera actions still behave immediately, discrete persistence only writes the winning visible camera, persistence and lifecycle flush behavior remain correct, and automated tests prove the new continuous-versus-discrete camera policy without broad regressions.
</done_when>
