## Overview

Defer map camera persistence off hot paths; keep visible camera behavior unchanged.

**Spec**: `ai_specs/pan-zoom-optmize2-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `widgets/`, `models/`
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `test/widget/map_screen_camera_request_test.dart`, `test/widget/tasmap_map_screen_test.dart`
- **Assumptions/Gaps**: no open spec gaps; add lifecycle observer in `MapScreen`; extra real-notifier route-entry tests likely needed beyond current named files

## Plan

### Phase 1: Drag/Wheel Vertical Slice

- **Goal**: split persistence; prove drag/wheel no longer writes per frame
- [x] `lib/core/constants.dart` - add shared camera-save debounce constant (`150ms`)
- [x] `lib/providers/map_provider.dart` - split transient camera update vs final camera commit; split camera saves from peak-list preference saves; keep `isFirstLaunch` on camera load/commit only
- [x] `lib/screens/map_screen.dart` - add pending drag/wheel save owner in `MapScreen`; debounce commit from `onPositionChanged`; consume pending state after successful flush
- [x] `test/providers/map_peak_list_selection_persistence_test.dart` - keep peak-list saves immediate after persistence split
- [x] `test/widget/map_screen_persistence_test.dart` - real-notifier drag/wheel persistence lane
- [x] TDD: transient `updatePosition(...)` updates state but does not write prefs; then implement split API
- [x] TDD: drag/wheel settles -> one final camera save only; then implement debounce owner + final commit
- [x] TDD: peak-list selection still saves immediately after camera-save split; then implement dedicated non-camera save path
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Interactive Completion + Lifecycle Flush

- **Goal**: trackpad, keyboard, pause/dispose flush; no duplicate flush
- [x] `lib/screens/map_screen.dart` - wire `PointerPanZoomEnd`, `_stopScrolling()`, discrete keyboard zoom commit, `WidgetsBindingObserver`, pause flush, disposal flush, consume-on-flush
- [x] `test/widget/map_screen_persistence_test.dart` - real-notifier keyboard, trackpad, pause, dispose, consume-on-flush coverage
- [x] `test/widget/map_screen_keyboard_test.dart` - keep gesture/UI assertions only; adapt if keys or timing seams change
- [x] `test/widget/map_screen_trackpad_gesture_test.dart` - keep gesture/UI assertions only; adapt if handler shape changes
- [x] TDD: trackpad update defers save; `PointerPanZoomEnd` commits once; then implement end seam
- [x] TDD: held-key pan commits once at `_stopScrolling()`; discrete keyboard zoom commits once per keydown; then implement keyboard seams
- [x] TDD: pause flush and disposal flush consume pending final camera so same camera cannot flush twice; then implement lifecycle owner
- [x] Robot journey tests + selectors/seams for critical flows: update existing robot only for visible gesture behavior if UI changes; keep persistence proof outside robot unless real-notifier lane added
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Route-Entry + Serial-Gated Fits

- **Goal**: preserve cold-start/hidden-branch route-entry behavior; remove duplicate final saves
- [x] `lib/providers/map_provider.dart` - classify and route final persistence ownership for `requestCameraMove(...)`, `selectMap(...)`, `showTrack(...)`, `centerOnLocation(...)`, `centerOnSelectedLocation(...)`, `centerOnPeak(...)`, `selectAllSearchResults(...)`
- [x] `lib/screens/map_screen.dart` - preserve `cameraRequest*`, `selectedMapFocusSerial`, `selectedTrackFocusSerial` handoffs; keep one-shot serial gating; preserve cold-start vs hidden-branch behavior
- [x] `test/widget/map_screen_camera_request_test.dart` - keep/extending real-notifier `cameraRequest*` and selected-map route-entry coverage
- [x] `test/widget/map_screen_route_entry_test.dart` - new real-notifier selected-map/selected-track cold-start + hidden-branch replay/gating coverage
- [x] `test/widget/tasmap_map_screen_test.dart` - keep/update selected-track visible behavior if existing assertions still fit best there
- [x] TDD: off-screen `requestCameraMove(...)` preserves `selectedLocation`, `selectedPeaks`, `clearGotoMgrs`, hover-clear flags across cold-start and hidden branch; then implement handoff contract
- [x] TDD: `selectMap(...)` preserves `selectedMap`, `tasmapDisplayMode`, `clearSelectedLocation`, `mapSuggestions`, `mapSearchQuery`; one-shot fit only; then implement/retain serial gating
- [x] TDD: `showTrack(...)` preserves `tracks`, `selectedTrackId`, `selectedLocation`, `showTracks`, `clearHoveredTrackId`, `clearGotoMgrs`; final persisted camera owned by fit path, not pre-fit provider save; then implement duplicate-save cleanup
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Journey Regression Sweep

- **Goal**: user-visible map journeys still coherent
- [ ] `test/robot/tasmap/tasmap_journey_test.dart` + `test/robot/tasmap/tasmap_robot.dart` - keep selected-map goto journey green; stable keys only; no persistence assertions unless real notifier intentionally used
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` or focused robot lane - cover selected-track route-entry journey if Phase 3 changes visible behavior
- [ ] TDD: critical journey stays visually/functionally correct after persistence refactor; then adjust robot helpers/selectors minimally
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: lifecycle pause timing on fast app suspension; duplicate final saves across pause/dispose or fit/readback paths; hidden-branch route-entry regressions for selected-map/track serial gates
- **Out of scope**: controller-feedback cleanup beyond persistence ownership needs; rebuild-isolation work; geometry/hover caching; persisted schema/key changes
