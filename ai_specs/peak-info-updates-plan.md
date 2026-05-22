## Overview

Shared peak popup upgrade: Drop Marker action, ascent history, consistent row emphasis/formatting.
Keep resolver shared across map + mini map; preserve anchor/close behavior.

**Spec**: `ai_specs/peak-info-updates-spec.md`

## Context

- **Structure**: feature-first screens/services/providers
- **State management**: Riverpod
- **Reference implementations**: `lib/services/peak_info_content_resolver.dart`, `lib/screens/map_screen_panels.dart`, `lib/providers/map_provider.dart`, `lib/screens/peak_lists_screen.dart`, `test/widget/map_screen_peak_info_test.dart`
- **Assumptions/Gaps**: ascent view model added to shared popup content; fallback label `Track #<gpxId>` if track lookup/name missing; popup height may need small bump

## Plan

### Phase 1: Shared ascent data

- **Goal**: resolve ascent rows once; share across both hosts
- [x] `lib/services/peak_info_content_resolver.dart` - extend `PeakInfoContent`; resolve bagged ascents + track names; safe fallbacks; stable sort newest-to-oldest, name tie-break
- [x] `lib/providers/map_provider.dart` - refresh popup content when `peaksBaggedRevisionProvider` changes; keep open popup in sync
- [x] `test/services/peak_info_content_resolver_test.dart` - TDD: ordered ascent rows, missing track fallback, empty/failure omission
- [x] `test/harness/test_map_notifier.dart` - keep peak-info refresh seam deterministic for open-popup rebuilds
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: full suite still has unrelated failing tests in existing robot/widget coverage)

### Phase 2: Popup actions and formatting

- **Goal**: fixed header, scrollable body, action wiring, bold values
- [x] `lib/screens/map_screen_panels.dart` - add Drop Marker button + tooltip; close tooltip; fixed top row; scrollable body; bold value text; `formatElevationMetres(...)` for height; keep MGRS monospace; optional popup height bump
- [x] `lib/screens/map_screen.dart` - wire Drop Marker to shared selected location only; no camera move/zoom
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: button/tooltips, height format, My Ascents section, drop-marker state update, no recenter/zoom regressions
- [x] `test/widget/peak_info_popup_placement_test.dart` - adjust expectations if popup size changes
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Shared popup hosts

- **Goal**: identical popup behavior on mini map
- [x] `lib/screens/peak_lists_screen.dart` - pass Drop Marker callback; keep shared popup card; render shared selected-location marker feedback
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: popup survives on mini map, Drop Marker feedback visible, selected-location marker shown
- [x] `test/robot/peaks/peak_info_robot.dart` - add stable selectors for Drop Marker + updated assertions
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: repo-wide `flutter test` still has unrelated failures in existing robot/widget coverage)

### Phase 4: Journey + placement

- **Goal**: end-to-end proof of popup content + marker update
- [x] `test/robot/peaks/peak_info_journey_test.dart` - TDD: open popup, verify new content, tap Drop Marker, confirm selected location update
- [x] `test/widget/peak_info_popup_placement_test.dart` - final placement assertions after any size change
- [ ] `lib/core/constants.dart` - only if needed for readable popup bounds (not needed; popup size unchanged)
- [ ] Verify: `flutter analyze` && `flutter test` (blocked: repo-wide `flutter test` still has unrelated failures in existing robot/widget coverage)

## Risks / Out of scope

- **Risks**: popup height/placement coupling; ascent history ordering on refresh; fallback text edge cases
- **Out of scope**: persistence model changes; map recenter/zoom behavior; new popup widget fork
