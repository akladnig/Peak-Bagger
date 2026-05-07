## Overview

Map camera hot-path refactor. Keep live motion in a narrow `MapScreen` seam; commit canonical camera only at accepted debounce/end points.

**Spec**: `ai_specs/map-camera-sync-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `widgets/`, `services/`
- **State management**: Riverpod `NotifierProvider`; `MapScreen` currently watches full `mapProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, `test/widget/map_screen_persistence_test.dart`, `test/widget/map_screen_trackpad_gesture_test.dart`
- **Assumptions/Gaps**: smallest viable seam likely local live-camera coordinator in `MapScreen` plus one pending-request object in `MapState`; secondary consumer narrowing only if instrumentation still shows churn; robot lane only if current widget harness can drive it without new infra

## Plan

### Phase 1: Inventory And Seams

- **Goal**: lock writer inventory; choose ownership seam before refactor
- [x] `ai_specs/map-camera-sync-spec.md` - append discovered-writers appendix from required grep audit; map each writer to continuous, discrete, or out-of-scope justification
- [x] `lib/screens/map_screen.dart` - identify extracted hot-path boundary for map viewport/live readouts/rebuild instrumentation
- [x] `lib/providers/map_provider.dart` - design pending camera request object; replace scattered `cameraRequest*` shape on paper before code
- [x] `test/widget/map_screen_persistence_test.dart` - add deterministic canonical-sync counting seam plan; avoid using persisted prefs as sole oracle
- [x] TDD: writer audit covers every `updatePosition`, controller `move`, `fitCamera`, request, and direct provider camera mutation before implementation starts
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Continuous Live-Camera Slice

- **Goal**: drag/wheel/trackpad/held-key use live local camera; canonical sync throttled
- [ ] `lib/screens/map_screen.dart` - add live-camera state/coordinator, latest-wins token, debounce/end-sync flush, live MGRS derivation, popup/hover/cursor side-effect reassignment
- [ ] `lib/screens/map_screen_panels.dart` - add stable app-owned keys for `MapMgrsReadout` and `MapZoomReadout`
- [ ] `lib/core/constants.dart` - reuse `MapConstants.cameraSaveDebounce`; touch only if tests prove a gap
- [ ] `test/widget/map_screen_persistence_test.dart` - migrate continuous-path assertions to live UI plus canonical-sync counter; cover debounce, dedupe, lifecycle flush, held-key end-sync, wheel no-extra-end-sync
- [ ] `test/widget/map_screen_trackpad_gesture_test.dart` - migrate in-motion assertions away from immediate provider zoom/center; assert live readouts and accepted end-sync behavior
- [ ] TDD: drag updates visible camera and readouts before canonical provider sync, then implement
- [ ] TDD: after `N` continuous updates, canonical sync count is less than `N`; debounce/end-sync dedupe keeps one final accepted commit, then implement
- [ ] TDD: trackpad pinch path stays functional, zoom clamps, popup dismissal timing stays coherent, then implement
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Discrete Acceptance Model

- **Goal**: one accepted-camera seam for direct moves, fit moves, off-route requests
- [ ] `lib/providers/map_provider.dart` - add pending request object schema with camera payload, selection semantics, clear flags, serial/token, persistence intent
- [ ] `lib/screens/map_screen.dart` - route all discrete controller moves and request consumption through accepted-apply helper; prevent stale continuous flush overwrite
- [ ] `lib/providers/map_provider.dart` - migrate legacy provider camera writers such as `centerOnLocationWithZoom()`, `centerOnPeak()`, `selectAllSearchResults()`, `requestCameraMove()` to the same ownership rule
- [ ] `test/widget/map_screen_keyboard_test.dart` - cover discrete keyboard zoom and `I` recenter as immediate accepted commits without stale echo
- [ ] `test/widget/map_screen_persistence_test.dart` - cover newer discrete intent beating older continuous pending flush; persistence only after winning visible apply
- [ ] TDD: discrete keyboard zoom commits immediately once per action, then implement
- [ ] TDD: newer goto/focus/request supersedes older pending continuous commit and stale persistence never writes, then implement
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Rebuild Narrowing And Journey Proof

- **Goal**: hot path isolated; non-camera UI insulated from camera churn
- [ ] `lib/screens/map_screen.dart` - split route root into narrow consumers; keep live subtree limited to viewport, selected-location marker, readouts, gesture-owned UI
- [ ] `lib/providers/peak_list_selection_provider.dart` - stop watching full `MapState`; depend only on peaks plus peak-list selection inputs
- [ ] `lib/widgets/map_action_rail.dart` - narrow `mapProvider` watch to track-related fields only; add explicit rebuild counter seam for widget tests
- [ ] `lib/widgets/map_peak_lists_drawer.dart` - narrow only if instrumentation still shows camera churn when drawer present
- [ ] `lib/widgets/map_basemaps_drawer.dart` - narrow only if instrumentation still shows camera churn when drawer present
- [ ] `lib/router.dart` - narrow map-route snackbar consumer only if instrumentation still shows churn
- [ ] `test/widget/map_screen_*` - add rebuild-proof tests for extracted hot-path boundary and visible non-camera consumer boundary
- [ ] `test/robot/` - add one map journey only if existing harness can drive selectors and timing deterministically; otherwise document omission in execution notes
- [ ] TDD: continuous camera motion does not rebuild the route-root seam or `MapActionRail`, then implement
- [ ] TDD: `filteredPeaksProvider` output stays correct after dependency narrowing, then implement
- [ ] Robot journey tests + selectors/seams for critical flows: `Key('map-interaction-region')`, readout keys, rebuild counter seam, deterministic debounce/time control if existing harness already supports it
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `flutter_map` may expose final accepted camera only after controller apply/post-frame; stale legacy writer sites may hide outside current seed list; rebuild instrumentation can become brittle if attached above the true churn boundary
- **Out of scope**: touch-pinch enablement; trackpad panning; overlay/track rendering algorithm work; persistence schema/key changes; settings-screen `mapProvider` consumption unless required by a discovered regression
