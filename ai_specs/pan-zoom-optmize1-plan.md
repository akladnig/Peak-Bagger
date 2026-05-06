## Overview

Remove rebuild-time camera replay. Replace with explicit non-controller request seam; keep visible-map camera ownership in `MapScreen`.

**Spec**: `ai_specs/pan-zoom-optmize1-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `widgets/`, `test/robot/`, `test/widget/`
- **State management**: Riverpod `NotifierProvider`; `MapScreen` owns `MapController`; `mapProvider` holds camera state
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `test/widget/map_screen_trackpad_gesture_test.dart`, `test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
- **Assumptions/Gaps**: follow codebase convention: screen owns controller moves, provider owns state; add `MapConstants.cameraEpsilon` and `MapConstants.defaultMapZoom`; one minimal non-controller request API preferred

## Plan

### Phase 1: Request Seam Vertical Slice

- **Goal**: prove non-controller route-entry camera request; remove generic build replay
- [x] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - replace legacy `syncEnabled` assertion; assert final camera and `selectedLocation`
- [x] `test/widget/` focused map sync test file - add route-entry request happy path; offstage-ready apply once; same-camera no-op
- [x] `lib/core/constants.dart` - add `MapConstants.cameraEpsilon`; add `MapConstants.defaultMapZoom`
- [x] `lib/providers/map_provider.dart` - add minimal non-controller camera request state/API; mark request consumed; keep `updatePosition(...)` controller-owned only
- [x] `lib/screens/map_screen.dart` - remove build-time `_mapController.move(...)`; apply request once when ready; same-camera guard; offstage-ready handling
- [x] `lib/screens/objectbox_admin_screen.dart` - migrate view-on-map flow from `updatePosition(...)` staging to request path
- [x] TDD: non-controller location request applies once after map branch navigation, then implement
- [x] TDD: same-camera external request is consumed without controller move, then implement
- [x] TDD: legacy objectbox-admin flow no longer depends on `syncEnabled`, then implement
- [x] Robot journey tests + selectors/seams for critical flows: keep key-first selectors; reuse `shared-app-bar` and existing robot actions; no extra async seams beyond deterministic pumps
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Visible-Map Ownership Split

- **Goal**: move visible-map recenter and goto paths onto direct controller ownership
- [x] `test/widget/` focused map sync test file - add keyboard `C`, `onSecondaryTap`, visible-map goto, selected-map goto zoom-derivation coverage
- [x] `lib/screens/map_screen.dart` - convert key `C` and `onSecondaryTap` to direct controller-owned recenter; convert visible-map goto completion to direct controller-owned move; forbid intermediate visible fit move for selected-map goto
- [x] `lib/providers/map_provider.dart` - split shared location helpers by caller ownership; add named non-controller selected-location request only if needed; keep `centerOnLocation(...)`/`centerOnSelectedLocation(...)` semantics explicit
- [x] `lib/widgets/map_action_rail.dart` - keep current-location and center-on-marker on request path; align to renamed API if introduced
- [x] TDD: visible-map selected-location recenter via keyboard `C` updates camera without request replay, then implement
- [x] TDD: selected-map goto derives zoom only and settles directly on resolved location with no intermediate visible fit move, then implement
- [x] TDD: non-controller center-on-marker remains request-driven and still lands on current selected location, then implement
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Remaining Callers And Regressions

- **Goal**: finish off-controller callers; preserve peak and fit behavior
- [ ] `test/widget/` focused map sync test file - add peak-dialog navigate-to-peak request coverage; keep `centerOnPeak(...)` distinct and non-persisting
- [ ] `test/widget/map_screen_peak_search_test.dart` - assert peak-search focus still uses visible-map focus-and-select semantics
- [ ] `lib/widgets/peak_list_peak_dialog.dart` - migrate `_navigateToPeakOnMap()` off direct `updatePosition(...)`; keep plain navigation semantics; keep track-open flow aligned to request/fit contract
- [ ] `lib/providers/map_provider.dart` - narrow or remove generic `syncEnabled` replay role; retain only compatibility state if still required
- [ ] `lib/screens/map_screen.dart` - preserve selected-map and selected-track fit serial gating; normalize selected-map fit fallback zoom to `MapConstants.defaultMapZoom`
- [ ] TDD: peak-dialog navigate-to-peak uses request path without setting `selectedPeaks`, then implement
- [ ] TDD: `centerOnPeak(...)` remains visible-map-only, non-persisting, and does not set `selectedLocation`, then implement
- [ ] TDD: selected-map fit fallback uses `MapConstants.defaultMapZoom`, then implement
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: request lifecycle can race with offstage map readiness; `syncEnabled` removal may touch more tests than expected; goto zoom derivation may expose hidden selected-map-fit assumptions
- **Out of scope**: hover/geometry/tile performance work; route redesign; persisted camera schema changes
