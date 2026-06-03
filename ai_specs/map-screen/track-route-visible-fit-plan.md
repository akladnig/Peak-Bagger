## Overview

Click-selected track/route should refit into the unobscured map lane.
Reuse current focus-serial zoom path; replace symmetric fit padding with overlay-aware padding.

**Spec**: bug report only; quick plan, no separate spec file.

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `widgets/`, `test/`
- **State management**: Riverpod `MapNotifier`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `lib/widgets/map_action_rail.dart`, `lib/screens/map_screen_panels.dart`, `test/widget/tasmap_map_screen_test.dart`, `test/widget/map_screen_route_info_test.dart`
- **Assumptions/Gaps**: click on an already-selected visible item should refocus; visible-fit math should follow current left panel + right rail geometry plus safe areas; narrow widths may need clamped padding and existing fallback move path

## Plan

### Phase 1: Track Click Slice

- **Goal**: click-selected track refocuses and fits inside visible lane
- [ ] `test/providers/map_provider_selected_track_test.dart` - TDD: `selectTrack()` bumps `selectedTrackFocusSerial` for visible tracks, including same-track reselection; hidden/invalid ids stay no-op
- [ ] `lib/providers/map_provider.dart` - make click selection publish a fresh track focus serial while preserving hidden-item guards and route clearing
- [ ] `test/widget/tasmap_map_screen_test.dart` - TDD: selected-track fit on desktop biases camera away from the left panel/right rail; same-track reselection re-fits after camera drift
- [ ] `lib/screens/map_screen.dart` - add small helper for selection-fit padding from current overlay geometry; replace track `EdgeInsets.all(50)` fit with asymmetric padding; keep single-point and exception fallbacks
- [ ] Verify: `flutter analyze` && `flutter test test/providers/map_provider_selected_track_test.dart test/widget/tasmap_map_screen_test.dart`

### Phase 2: Route Parity And Journeys

- **Goal**: route click matches track behavior; end-to-end click flow hardened
- [ ] `test/providers/map_provider_selected_route_test.dart` - TDD: `selectRoute()` bumps `selectedRouteFocusSerial` for visible routes, including same-route reselection; hidden/invalid ids stay no-op
- [ ] `lib/providers/map_provider.dart` - mirror fresh focus-serial behavior for route click selection
- [ ] `test/widget/map_screen_route_info_test.dart` - TDD: map click selects route, opens shared panel, and refits inside the visible lane
- [ ] `lib/screens/map_screen.dart` - reuse the same overlay-aware fit padding helper for route bounds fit; keep unrelated camera flows unchanged
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` / `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - robot journey: click track -> panel opens -> camera center shifts away from panel with tolerant assertions; add selector/seam only if current harness lacks one
- [ ] `test/robot/map/route_info_robot.dart` / `test/robot/map/route_info_journey_test.dart` - robot journey: click route -> panel opens -> camera center shifts away from panel; reuse key-first selectors
- [ ] Verify: `flutter analyze` && `flutter test test/providers/map_provider_selected_route_test.dart test/widget/map_screen_route_info_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart test/robot/map/route_info_journey_test.dart`

## Risks / Out of scope

- **Risks**: overlay-padding math may overconstrain narrow widths; `flutter_map` post-fit camera values may need tolerance-based assertions; robot camera assertions can flake without a deterministic settle seam
- **Out of scope**: peak/map extent fitting, end-drawer/search/goto obstruction handling, panel/rail layout redesign
