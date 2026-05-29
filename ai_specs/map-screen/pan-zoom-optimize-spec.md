<goal>
Reduce pan and zoom jank on the map screen by removing avoidable work from the interaction hot path, narrowing rebuild scope, and caching expensive geometry work without changing user-visible map behavior.

This matters because the map screen is the app's primary interaction surface. Desktop and mobile users should be able to drag, zoom, hover, and inspect map content smoothly even when peaks, tracks, and overlays are visible.
</goal>

<background>
The current map interaction flow lives mainly in `./lib/screens/map_screen.dart`, with camera state and transient hover/cursor state stored in `./lib/providers/map_provider.dart`. Track display geometry is exposed by `./lib/models/gpx_track.dart`, and layer construction happens in `./lib/screens/map_screen_layers.dart`.

The existing review identified four main jank risks:
- camera sync feedback from `MapScreen.build` post-frame callbacks,
- `SharedPreferences` writes on the gesture hot path,
- whole-screen rebuilds caused by transient hover/cursor updates,
- repeated geometry decode and projection work during hover and redraw.

The current test harness also matters here: many widget and robot tests use `TestMapNotifier` from `./test/harness/test_map_notifier.dart`, which overrides `updatePosition()` without exercising real preference persistence. Any deferred-persistence change must therefore introduce an explicit seam that can be tested deterministically with the real notifier path when needed.

The harness mismatch is broader than persistence alone. `TestMapNotifier` currently diverges from production camera side effects and uses hard-coded zoom behavior instead of sharing the same source-of-truth constants and rules as production. Any related cleanup must prefer shared constants in `./lib/core/constants.dart` or introduce a new shared map-behavior constant there instead of duplicating literals in test harness code. One concrete mismatch to eliminate is the peak-popup clear threshold: production currently clears at `zoom < 8`, while `TestMapNotifier` clears at `zoom < 9`.

Track simplification by zoom already exists via `TrackDisplayCacheBuilder.buildJson(...)`; this spec is not asking for a new simplification algorithm. The optimization target is repeated JSON decode and repeated projection or hover-candidate rebuild work on top of the existing simplified data.

Preserve current user-visible behavior for map drag, pinch/trackpad zoom, selected-map fit, selected-track fit, peak popup placement, hover affordances, keyboard controls, and existing widget keys unless a new stable key is required for deterministic tests.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/providers/peak_list_selection_provider.dart`
- `./lib/models/gpx_track.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/services/peak_hover_detector.dart`
- `./lib/services/track_hover_detector.dart`
- `./lib/services/gpx_track_geometry.dart`
- `./lib/services/map_trackpad_gesture_classifier.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/peak_list_peak_dialog.dart`
- `./lib/screens/objectbox_admin_screen.dart`
- `./test/harness/test_map_notifier.dart`
- `./test/harness/test_tasmap_map_notifier.dart`
- `./test/widget/map_screen_trackpad_gesture_test.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/gpx_tracks_recovery_test.dart`
- `./test/widget/tasmap_map_screen_test.dart`
- `./test/robot/**`
</background>

<user_flows>
Primary flow:
1. User opens the map screen with peaks, tracks, or Tasmap overlays visible.
2. User pans the map or zooms with mouse wheel, keyboard, touch, or desktop trackpad.
3. The camera updates smoothly without visible stutter, snapping, or redundant repositioning.
4. Hover, popup dismissal, and selection behavior remain correct during and after movement.

Alternative flows:
- Track-heavy map: user pans or zooms with one or more GPX tracks visible and performance remains acceptable.
- Peak-dense map: user hovers peaks while stationary or after movement without causing full-screen jank.
- Programmatic camera move: selected-map fit, selected-track fit, goto navigation, and center-on-location still move the camera correctly.

Error flows:
- If camera updates are received from multiple sources, no feedback loop or oscillation should occur.
- If geometry cache data is missing or malformed for one track, that track should be skipped or yield empty decoded geometry while the rest of the map remains usable.
</user_flows>

<discovery>
Before implementation, profile the current map screen with Flutter DevTools or equivalent instrumentation to confirm where frame time is being spent.

Specifically verify:
0. Use one fixed profiling scenario for both baseline and post-change checks: map screen open with visible peaks enabled and at least one visible GPX track.
0b. Use the same scenario for deciding whether later hover-cache or cross-instance geometry-cache phases are necessary at all; if controller feedback removal and deferred persistence eliminate the measured jank, keep later caching work minimal.
0c. Only proceed into later geometry or hover-caching work if the fixed scenario still shows decode or projection work among the top remaining timeline costs after controller-feedback and persistence fixes, or if frame work in that scenario still exceeds the 16 ms budget.
1. Rebuild frequency for `MapScreen` and its child layers while dragging and zooming.
2. Whether `SharedPreferences` writes appear during drag or zoom frames.
3. CPU time spent in `GpxTrack.getSegmentsForZoom()`, JSON decode, peak hover candidate building, and track hover candidate projection.
4. Prefer the simplest completion seam that matches the path. Default first pass to explicit command-end commits and one debounced gesture-save path; consider `MapController.mapEventStream` and `MapEventMoveEnd` only if that simpler model proves insufficient for native gesture completion.
5. Which existing robot or widget tests already cover movement followed by hover or selection, especially under `./test/widget/gpx_tracks_recovery_test.dart` and `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`.
6. Which current camera-mutating flows also change side-effect fields such as `syncEnabled`, `selectedLocation`, `gotoMgrs`, `selectedMapFocusSerial`, and `selectedTrackFocusSerial`, including camera entry points outside `MapScreen`.
7. If profiling evidence is inconclusive or multiple hotspots tie, continue in the listed phase order and optimize controller feedback removal and per-frame persistence first.
8. Which existing tests depend on `Key('map-interaction-region')` being attached specifically to the outer `MouseRegion`, not merely any descendant widget.
</discovery>

<requirements>
**Functional:**
1. Remove redundant camera sync work from the map interaction loop so camera updates caused by map gestures do not trigger immediate controller writes back to the same camera state.
2. Keep programmatic camera changes working for selected-map fit, selected-track fit, goto navigation, and center-on-location.
3. Preserve simple route-entry center or zoom behavior in both cold-map and hidden-branch cases. For cold map creation, provider state plus `initialCenter` or `initialZoom` is sufficient. For an already-mounted but hidden `/map` branch, define a named provider-to-screen handoff for off-screen camera updates once generic build-time controller sync is removed. Use explicit controller-dependent handoff only for flows that require map-ready sizing, `fitCamera`, or controller readback.
4. Define one exact desired end state for every route-entry camera flow, including final visible camera, `selectedLocation`, `selectedPeaks`, popup state, `syncEnabled`, and persistence behavior.
5. Move map position persistence off the per-frame interaction path for flows that already persist today; camera position must persist only at a safe lower-frequency seam such as gesture end, move end, app lifecycle pause, or a short debounce.
6. Prevent transient hover and cursor updates from rebuilding the full map screen tree more than necessary.
7. If profiling justifies it after first-pass fixes, cache decoded track display geometry so repeated calls during drawing or hit testing do not repeatedly JSON-decode the same track data.
8. If profiling justifies it after first-pass fixes, reduce repeated hover projection work so peak and track hover candidate recomputation occurs only when camera or source data changes, not on every pointer move.
9. Preserve existing pan, zoom, hover, peak popup, track selection, selected-map label, selected-track fit, and trackpad gesture behavior unless a deliberate optimization-safe adjustment is required.
10. Define and implement a single desired persistence ownership model for each camera mutation path so it is always clear which seam commits the final saved camera state. Use current behavior only as input context, and explicitly normalize duplicate-save or intermediate-save artifacts into one final contract per path; existing duplicate-save behavior is not normative.
11. Split deferred camera persistence from unrelated preference persistence so peak-list selection and other non-camera settings do not accidentally inherit gesture-driven save timing.
12. Define exact no-op suppression rules for camera, hover, and cursor updates so guards and tests are deterministic.

**Error Handling:**
12. If a deferred persistence write fails, keep the in-memory map state correct and continue without interrupting interaction.
13. If cached geometry cannot be decoded, fail safely by returning empty geometry rather than crashing the screen.
14. If hover caches become stale after camera or dataset changes, invalidate and rebuild them deterministically before use.

**Edge Cases:**
15. Rapid sequences of drag, zoom, hover, and popup dismissal must not leave stale hover state, stale cached projections, or stuck gesture state.
16. No-op state updates must not notify listeners when center, zoom, hover, or cursor values are effectively unchanged.
17. Optimization changes must not regress low-zoom peak suppression, selected-track highlighting, or selected-map/overlay label visibility rules.
18. Desktop trackpad vertical zoom behavior covered by existing tests must remain intact.

**Validation:**
19. Add or update automated coverage for deferred persistence timing, no-op state suppression, and cached geometry behavior.
20. Keep a critical map interaction journey covered with stable app-owned selectors, using `Key('map-interaction-region')` as the primary gesture anchor unless a narrower new key is justified.
21. Verify baseline coverage across logic/state, widget behavior, and user-journey interaction paths.
</requirements>

<boundaries>
Edge cases:
- Hovering while stationary should still update cursor and hover affordances promptly, but without forcing heavy layer rebuilds.
- Programmatic camera moves should still update visible readouts correctly even if gesture-driven persistence is deferred, and they should preserve current persisted or non-persisted behavior unless the spec is later updated to authorize a behavior change.
- Geometry caches must be invalidated when the underlying track content changes, not only when zoom changes.
- Peak hover cache invalidation must consider a concrete derived camera key and not an undefined abstract revision. Acceptable keys include center, zoom, and non-rotated size, or an explicit revision counter added deliberately for this purpose.
- Track hover cache invalidation must also use a concrete derived camera key or explicit revision counter, plus rounded display zoom, visible tracks, and track visibility or recovery-state flags.
- No-op suppression must use explicit comparison rules: exact equality for hovered ids and formatted MGRS strings, exact equality for booleans and enum-like fields, and a named epsilon constant in `./lib/core/constants.dart` for `LatLng` center and `zoom` comparisons if floating-point tolerance is required.

Error scenarios:
- If no reliable move-end callback exists, use a short debounce rather than restoring per-frame persistence.
- Prefer `flutter_map`'s event-based move-end seam over debounce only for paths where the built-in event semantics actually fire, and do not assume controller-driven `move` or `fitCamera` paths will emit the same completion event.
- If a cache optimization risks stale or incorrect hit testing, correctness wins over maximum caching; rebuild deterministically at the nearest safe seam.
- If a deferred-save seam is introduced, it must define ownership, cancellation, flush, and disposal behavior explicitly so stale timers or late writes cannot outlive the notifier or screen.
- If the map branch remains alive offstage in the shell, define whether pending deferred-save work is flushed, canceled, or intentionally allowed to complete when the user leaves the map branch.

Limits:
- Do not change the persisted map position schema.
- Do not redesign map UI, change route structure, or replace `flutter_map`.
- Do not broaden this task into tile-loading, network, or basemap-server optimization unless profiling proves they are the dominant source of jank.
- Any decoded geometry cache stored on `GpxTrack` must remain in-memory only and must not alter ObjectBox persistence, `toMap()`, or serialized payload shape.
- If lifecycle-based save flushing is used, explicitly define whether it is owned by `MapScreen` or a higher app-level seam; otherwise keep first-pass scope to move-end or debounce-based flushing only.
</boundaries>

<implementation>
Modify the interaction hot path with the smallest correct changes first.

Expected output paths:
- Update `./lib/screens/map_screen.dart` to remove controller feedback from `build`, move any required sync into narrower controller-driven seams, and keep gesture behavior intact.
- Update `./lib/providers/map_provider.dart` to separate transient interaction updates from persisted camera updates, add no-op guards, and avoid per-frame persistence.
- Update `./lib/providers/peak_list_selection_provider.dart` if needed so derived peak filtering stops depending on hover or cursor-only state.
- Update `./lib/models/gpx_track.dart` to cache decoded `displayTrackPointsByZoom` data in a cache ownership model that works across all readers of the same serialized track data, not only a single entity instance.
- Update `./lib/screens/map_screen_layers.dart` and/or adjacent map-screen support code only as needed to consume cached geometry or narrower rebuild inputs.
- Update non-map-screen camera callers only as needed to route through the same final camera-commit contract, including `./lib/widgets/map_action_rail.dart`, `./lib/widgets/peak_list_peak_dialog.dart`, and `./lib/screens/objectbox_admin_screen.dart`.
- Add focused tests under `./test/widget/`, `./test/robot/`, and focused provider or model test files under `./test/` where they validate changed behavior.

Implementation expectations:
1. Eliminate the generic post-frame `_mapController.move(mapState.center, mapState.zoom)` pattern from `build` entirely. Do not replace it with a generic diff-guarded build-time sync; remaining controller writes must live only in explicit event or command seams such as gesture handlers, selected-map fit, selected-track fit, goto, and direct commands.
2. Split the provider API so gesture-driven camera updates can update visible state without immediately writing preferences.
3. Introduce a concrete persistence seam that is testable outside `TestMapNotifier`, such as an injected save callback, save scheduler, debouncer abstraction, or an explicit split between transient camera updates and persisted camera commits.
4. Use one explicit deferred-persistence owner boundary: `MapScreen` owns movement completion detection because it owns `MapController` and the gesture or command end points; `MapNotifier` owns the single persisted commit API and storage writes. Do not duplicate completion ownership across screen and provider.
5. Decide the end-state of `syncEnabled` explicitly. Either remove it entirely and replace it with named route-entry or map-command handoffs, or keep it only as a narrow route-entry or command flag with no generic build-time controller-sync behavior.
6. Split camera persistence from non-camera preference persistence. Peak-list selection mode or id and other unrelated preferences that are currently saved through `savePosition()` must either stay immediate through a separate save path or move to a dedicated non-camera persistence method.
7. Any camera-behavior threshold or rule shared between production and test harnesses must come from `./lib/core/constants.dart`, or from a newly added shared map-behavior constant there, rather than duplicated hard-coded literals in production or `TestMapNotifier`.
8. Define the camera ownership and persistence matrix explicitly in code and tests as the desired end-state contract, and allow cleanup of current duplicate-save or intermediate-save behavior where needed. Existing duplicate-save behavior is not normative.
   Required matrix columns:
   - actual call site
   - controller write owner
   - in-memory state owner
   - final persistence owner
   - whether the flow persists at all
   - cold-start behavior
   - hidden-branch behavior
   At minimum include these current call sites:
   - `MapScreen.onPositionChanged(...)`
   - `MapScreen._handleTrackpadPanZoomUpdate(...)`
   - `MapScreen._moveMap(...)`
   - `MapScreen._navigateToGridReference(...)`
   - `MapScreen._zoomToMapExtent(...)`
   - `MapScreen._zoomToTrackExtent(...)`
   - `MapScreen` `keyI` recenter path
   - `MapNotifier.centerOnLocation(...)`
   - `MapNotifier.centerOnSelectedLocation(...)`
   - `MapNotifier.centerOnPeak(...)`
   - `MapNotifier.selectAllSearchResults(...)`
   - `MapNotifier.showTrack(...)`
   - `PeakListPeakDialog._openMap(...)`
   - `PeakListPeakDialog._navigateToPeakOnMap(...)`
   - `PeakListPeakDialog._openTrack(...)`
   - `ObjectBoxAdminScreen._viewPeakOnMainMap(...)`
   - any action-rail camera-entry path that mutates map state
   For these flows:
   - `flutter_map` gesture drag or wheel zoom via `onPositionChanged`: update visible camera state immediately; this is a currently persisting path, so keep it persisting, but defer the save to move-end or a short debounce instead of every frame.
   - custom trackpad pan or zoom path: update visible camera state immediately and commit exactly once from `PointerPanZoomEnd` or the same explicit settle seam used for that path.
   - keyboard scrolling or zoom shortcuts: update visible camera state immediately and commit exactly once from `_stopScrolling()` or an equivalent explicit settle seam for held-key movement.
   - programmatic goto, center-on-location, selected-map fit, selected-track fit, the `I` key recenter path, and `showTrack` plus its follow-up selected-track fit flow: define one explicit desired end-state per flow, including final visible camera and final persistence behavior, and commit exactly once from the final settled camera state rather than from both an intermediate provider mutation and a later screen-owned fit readback.
   - route-entry camera mutations performed before `/map` becomes active: allow simple center or zoom state to hydrate through `initialCenter` or `initialZoom` only for cold creation. For an already-mounted but hidden map branch, reuse the existing `selectedMapFocusSerial` or `selectedTrackFocusSerial` style offstage-fit mechanism where it already fits, and use an explicit provider-to-screen handoff only where no such mechanism exists.
   - `centerOnPeak` and `selectAllSearchResults`: keep their current non-persisting behavior unless the user explicitly approves a persistence behavior change.
   - `centerOnLocationWithZoom`: treat as currently unused or dead code unless a separate change intentionally revives it; do not let it drive the main ownership model.
   - non-map-screen camera callers such as dialogs, admin tools, or action-rail commands: either route them through the same final commit contract as equivalent map-screen commands or explicitly mark them out of scope and leave them unchanged.
   - app lifecycle pause or equivalent shutdown seam: optional for the first pass unless a move-end or debounce seam leaves a realistic data-loss gap; if added, explicitly name its owner.
   Add a dedicated route-entry end-state table for off-map callers that states, per caller, the final visible camera, whether `selectedLocation` is set, whether `selectedPeaks` changes, whether popups are cleared or preserved, whether `syncEnabled` changes, and whether the flow persists.
9. Add a complete camera mutation side-effects contract. For each current camera-mutating flow, preserve behavior for `currentMgrs`, `cursorMgrs`, `hoveredPeakId`, `hoveredTrackId`, `peakInfo`, `showInfoPopup`, `syncEnabled`, `selectedLocation`, `gotoMgrs`, `selectedMapFocusSerial`, `selectedTrackFocusSerial`, popup dismissal, and any zoom-threshold-driven peak-info clearing that currently happens alongside camera updates.
10. Separate transient camera-update side effects from deferred persistence commits explicitly. The transient camera update seam continues to own in-memory behavior such as `currentMgrs`, cursor clearing, hover clearing, popup dismissal, and peak-info clearing; the deferred commit seam owns storage writes only unless a named flow explicitly says otherwise.
11. For screen-owned `fitCamera` flows such as selected-map fit and selected-track fit, define completion explicitly. Default to explicit command-end or post-frame controller-readback commits; use `MapEventMoveEnd` only if a native gesture path actually benefits from it.
12. Preserve the one-shot focus-serial gating behavior for selected-map and selected-track fits, including pending or applied serial checks that prevent stale or repeated fit work.
13. Keep peak-list preference persistence immediate through a dedicated non-camera persistence method. Startup reconciliation must continue reading the same peak-list keys independently of deferred camera saves. This split is required first-pass work, not optional cleanup.
14. Add equality or explicit early-return guards so provider methods do not publish redundant state objects. At minimum define exact comparison behavior for hovered ids and formatted MGRS strings, plus exact or epsilon-based comparison rules for `LatLng` center and `zoom`.
15. Avoid duplicate cursor updates per hover event. In particular, do not keep both `_handleMapHover()` and `_handleTrackHover()` writing the same cursor state if one write can cover the event.
16. Narrow rebuild scope by explicitly isolating these transient concerns from the root full-screen `mapProvider` watch path: `MouseRegion.cursor`, the MGRS readout surface, hovered peak marker presentation, and any other UI that depends only on `cursorMgrs`, `hoveredPeakId`, or `hoveredTrackId`. The minimum success boundary is that `cursorMgrs` and `hoveredTrackId` updates must not rebuild the broad `FlutterMap` subtree or recompute layer collections. `hoveredPeakId` may rebuild only the peak-marker presentation path unless that affordance is moved to an overlay outside `FlutterMap`.
17. Achieve rebuild isolation with selector-based subwidgets around readout, cursor, marker, or map subtrees while keeping screen-owned fit orchestration, focus management, popup anchoring, hit testing, and local pointer bookkeeping in `MapScreen`.
18. Narrow derived-provider dependencies as well as widget boundaries. `filteredPeaksProvider` must stop watching the entire `MapState` and instead select only peak-list-related inputs so transient pointer updates do not trigger unrelated filtering or broad rebuild pressure.
19. Add a deterministic rebuild-isolation test seam, such as a rebuild counter wrapper around the `FlutterMap` subtree or equivalent test-only probe, so provider-driven hover or cursor-only updates can be proven not to rebuild that subtree. Exclude local pointer-down or focus-management rebuilds from this assertion.
20. Only implement cross-instance decoded-geometry caching if profiling on the fixed scenario still shows decode or projection work among the top remaining timeline costs after controller-feedback and persistence fixes, or if frame work still exceeds the 16 ms budget.
21. If geometry caching remains necessary, use one preferred ownership model: a shared runtime-only cache keyed by the current `displayTrackPointsByZoom` payload or a hash derived from it, with optional per-instance memoization layered on top if useful.
22. If geometry caching remains necessary, ensure any decoded track geometry cache is deterministic, invalidates when source JSON or relevant content hash changes, and does not leak across unrelated track instances.
23. If geometry caching remains necessary, the decoded geometry cache must be shared by all `GpxTrack` segment readers that consume the same serialized data, including redraw, hover hit testing, validation helpers, and extent-fit callers, not just hover-specific paths. Do not rely on per-instance-only caching if selected-map or repository flows can materialize fresh `GpxTrack` objects.
24. If geometry caching remains necessary, use a canonical cross-instance geometry cache key based on the current `displayTrackPointsByZoom` payload or a hash derived from that payload. If a track id is reused with new geometry, the old decoded cache entry must not be reused.
25. If geometry caching remains necessary, treat decoded geometry caching as transient runtime state only. If cache state is stored on `GpxTrack`, it must be private, excluded from persistence and serialization, and keyed to the current geometry payload or a hash derived from the current `displayTrackPointsByZoom` payload; `contentHash` alone is not sufficient when display geometry can be recalculated independently.
26. If geometry caching remains necessary, any cross-instance geometry cache must define a bounded in-memory lifetime or cleanup policy so it cannot grow without limit during normal repository churn. A first pass may use a payload-keyed runtime cache with explicit cleanup behavior if a more formal eviction policy is unnecessary.
27. Reuse hover candidates or projected geometry per concrete camera cache key where practical; avoid recomputing them on every pointer move when the camera and source datasets are unchanged.
28. Define cache invalidation separately for each hover path:
    - peak hover cache invalidates on a structural key composed from the concrete camera cache key plus ordered visible peak ids, relevant peak-list revision or filtering revision, and `correlatedPeakIds`, while preserving the current unticked-before-ticked candidate ordering used by hover hit testing.
    - track hover cache invalidates on a structural key composed from the concrete camera cache key including viewport size or `nonRotatedSize`, plus rounded display zoom, ordered visible track ids, geometry-payload cache keys, and `showTracks` or `hasTrackRecoveryIssue` flags.
28. Safe degradation for malformed geometry must be enforced in the `GpxTrack` decode layer itself, with caller-level catches remaining as an additional per-track fail-safe rather than the primary protection.
29. Once decode safety is enforced in `GpxTrack`, narrow or remove broad caller-level `catch` blocks so malformed geometry degrades safely without hiding unrelated projection or layer-construction bugs.
30. If a debounced or deferred save seam is introduced, define who owns pending work, when it is cancelled, when it is flushed, and how cleanup occurs on notifier disposal, route teardown, or shell-branch offstage transitions.
31. If `mapEventStream` or any other stream-based completion seam is used, define subscription ownership and disposal explicitly, including whether the subscription lives in `MapScreen` or another owner.
32. Focus-management post-frame callbacks are out of scope for the first pass unless profiling shows they materially contribute to jank; do not broaden the task into focus orchestration cleanup without evidence.
33. If shared map or test harness logic still duplicates `_trackFocus` threshold behavior, extract that behavior behind shared constants or shared logic rather than preserving duplicated hard-coded branches.

Avoid:
- Large architectural rewrites before the smallest hot-path fixes are applied.
- New dependencies for memoization or persistence.
- Background isolates unless profiling shows JSON decode remains a hotspot after in-memory caching.
</implementation>

<stages>
Phase 1: Measure and confirm hotspots.
- Profile map pan and zoom behavior.
- Confirm the contribution of controller feedback, persistence writes, rebuild churn, and geometry decode/projection.

Phase 2: Remove the highest-cost hot-path work.
- Remove controller feedback from `build`.
- Move persistence off the gesture frame path.
- Add no-op state guards.

Phase 3: Narrow rebuild scope.
- Separate transient hover/cursor concerns from whole-screen state watching.
- Keep readouts and hover affordances updating correctly.

Phase 4: Cache geometry and hover work.
- Cache decoded track geometry.
- Reuse or invalidate hover candidates based on camera/data changes.

Phase 5: Validate and tune.
- Re-run profiling.
- Compare rebuild counts and frame timing before and after.
- Fix any behavior regressions exposed by tests or profiling.
</stages>

<illustrations>
Desired:
- Dragging the map does not trigger visible snap-back or micro-stutter.
- Zooming with trackpad, wheel, or programmatic fit feels smooth while visible map content remains correct.
- Hovering a peak or track after movement updates affordances without heavy redraw churn.

Undesired:
- A map drag causes repeated provider updates that immediately drive a redundant controller move.
- Camera persistence writes occur continuously during movement.
- Hovering the map causes full `MapScreen` rebuilds and repeated geometry decode work.
</illustrations>

<validation>
Use behavior-first TDD slices for any new helper or provider seam. Add one focused failing test at a time, implement the smallest change to pass it, then refactor.

Required testability seams:
- A deterministic seam for camera-state persistence timing, such as an injected save callback, a fakeable scheduler or debouncer abstraction, or a testable notifier method split between transient updates and persisted updates.
- A deterministic seam for geometry caching so tests can verify decode-once or invalidation behavior without relying on frame timing.
- Do not rely only on `TestMapNotifier` for persistence assertions; at least the persistence-timing coverage must exercise the real notifier path through the injected seam.
- Treat `TestMapNotifier` widget and robot tests as UI-regression coverage only unless the harness is explicitly brought back into semantic alignment with production. If the harness remains in use for semantics-sensitive assertions, align `updatePosition()` side effects with production for all in-memory behavior except persistence; otherwise move those assertions into provider-level tests using the real `MapNotifier` pattern.

Required automated coverage outcome:
- `unit` or logic: no-op state suppression, deferred persistence behavior, and, if Phase 4 is justified by profiling, track geometry cache behavior and any extracted hover-cache invalidation logic.
- `widget`: gesture-driven map updates, popup/hover regression behavior after movement, and any screen-level rebuild-sensitive behavior that can be asserted deterministically.
- `robot`: at least one critical map-heavy GPX or peak journey that exercises movement plus a follow-up hover, selection, or popup-dismissal assertion if that path is materially affected.
- `provider`: dependency-narrowing and recomputation behavior for derived providers such as `filteredPeaksProvider`, proving hover or cursor-only state changes no longer trigger unrelated recomputation.

Validation split:
- Always required after Phases 1-3: persistence timing, no-op suppression, route-entry correctness, provider dependency narrowing, popup or hover regressions, and keyboard or trackpad interaction coverage.
- Required only if Phase 4 is entered: geometry-cache correctness, hover-cache invalidation coverage, decode or projection reduction evidence, and any additional cache-owner cleanup tests.

Selector policy:
- Prefer existing app-owned keys.
- Reuse `Key('map-interaction-region')` for gesture tests, and preserve that key on the outer `MouseRegion` unless tests are intentionally updated together with the selector contract.
- Add new keys only if needed to observe a newly isolated readout or interaction surface deterministically.
- If rebuild-isolation coverage needs a direct map-subtree probe, add a stable key or wrapper specifically for the `FlutterMap` subtree rather than overloading `map-interaction-region`.
- Any new rebuild-probe or map-subtree key must be additive only and must not move, rename, or repurpose `map-interaction-region` from the outer `MouseRegion`.

Minimum regression floor:
- Keep `PointerDeviceKind.trackpad` coverage for vertical zoom behavior.
- Add coverage proving repeated gesture updates do not trigger immediate persistence writes on every frame.
- Add coverage proving redundant provider updates are suppressed when camera state is unchanged.
- If Phase 4 is entered, add coverage proving cached track geometry is reused and invalidated correctly when the source track changes.
- Add one regression that exercises movement followed by hover or selection using the GPX or peak map surface rather than only Tasmap navigation flows.
- Add at least one real-`MapNotifier` provider-level persistence test using the existing harness pattern from `test/providers/map_peak_list_selection_persistence_test.dart`, with injected repositories and startup loaders disabled where needed.
- If Phase 4 is entered, add explicit unit coverage for malformed `displayTrackPointsByZoom` input so the decode layer returns empty geometry instead of throwing.
- If the test harness is kept for widget or robot tests, align any shared zoom-threshold behavior with production through constants in `./lib/core/constants.dart` rather than duplicated literals.
- If the test harness is kept for widget or robot tests, align duplicated `_trackFocus` or other shared zoom-ladder behavior with production through constants or shared logic rather than preserving divergent branches.
- Include regression coverage for popup dismissal, hover clearing, and keyboard settle behavior from the existing map-screen keyboard and peak-info surfaces.
- If event-stream completion is used, include deterministic coverage for subscription lifecycle and for paths that do not emit `MapEventMoveEnd`, so controller-driven moves still commit exactly once.
- Add provider-level coverage proving `filteredPeaksProvider` or its replacement does not recompute for hover or cursor-only state changes.
- Add coverage proving duplicate cursor writes per hover event have been eliminated or no-op suppressed.
- If non-map-screen camera callers are kept in scope, add at least one regression proving they route through the same final commit contract or are intentionally non-persisting.
- If objectbox-admin route-entry behavior remains in scope, add at least one explicit regression for that caller; otherwise mark it out of scope in the implementation notes.
- Add coverage proving route-entry camera mutations made before `/map` activation still produce the intended camera result when the map screen becomes ready.
- Use real-`MapNotifier` provider tests for persistence timing and no-op suppression.
- Keep widget or robot tests harness-based for UI regressions unless they assert semantics that diverge from production; when they do, either align `TestMapNotifier` with production in-memory side effects or migrate those assertions to real-`MapNotifier` tests.

Recommended verification commands:
- `flutter test test/widget/map_screen_trackpad_gesture_test.dart` - trackpad gesture regression surface
- `flutter test test/widget/gpx_tracks_recovery_test.dart` - hover or track interaction regression surface
- `flutter test test/widget/map_screen_keyboard_test.dart` - keyboard movement and settle regression surface
- `flutter test test/widget/map_screen_peak_info_test.dart` - popup clearing and zoom-threshold regression surface
- `flutter test test/widget/peak_list_peak_dialog_test.dart` - dialog route-entry camera behavior
- `flutter test test/widget/tasmap_map_screen_test.dart` - map-screen layering and selected-map behavior
- `flutter test test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - critical map-heavy journey regression
- `flutter test test/gpx_track_test.dart` - decode-layer and geometry behavior
- `flutter test test/providers/map_provider_import_test.dart` - provider import sanity only; do not rely on it for persistence timing
- `flutter test test/providers/map_peak_list_selection_persistence_test.dart` - real-`MapNotifier` persistence harness pattern
- `flutter analyze`

Manual verification expectation:
- Use one fixed profiling scenario before and after the change: map screen open with visible peaks enabled and at least one visible GPX track.
- Capture and report these artifacts from that same scenario:
  - `MapScreen` rebuild count while dragging,
  - confirmation that `SharedPreferences` writes no longer appear during drag or zoom frames,
  - before or after timeline evidence showing reduced CPU time in geometry decode or hover projection paths if those paths were optimized.
</validation>

<done_when>
- Pan and zoom interaction no longer performs redundant controller feedback writes during gesture-driven camera movement.
- Map camera persistence no longer writes preferences on every interaction frame, and each camera-mutation path now has one explicit final commit owner instead of duplicate or intermediate writes; currently non-persisting flows such as `centerOnPeak` and `selectAllSearchResults` remain non-persisting unless intentionally changed in a later approved spec.
- Provider-driven `cursorMgrs` and `hoveredTrackId` updates no longer rebuild the broad `FlutterMap` subtree, and hovered-peak updates are limited to the peak-marker presentation path unless that affordance is moved outside the map subtree.
- If Phase 4 is justified by profiling, track display geometry is not repeatedly JSON-decoded during normal redraw and hover paths.
- If Phase 4 is justified by profiling, hover projection work is reduced to safe invalidation seams rather than every pointer movement.
- Existing map behavior remains correct and the relevant automated tests and analysis pass.
- Profiling after the change shows a clear reduction in rebuild churn and hot-path work versus the baseline for the fixed profiling scenario captured in the validation section.
</done_when>

<handoff>
Record a minimal profiling artifact, such as a short markdown summary in the PR or follow-up notes, capturing the fixed scenario, rebuild observations, and movement-frame persistence evidence.
</handoff>
