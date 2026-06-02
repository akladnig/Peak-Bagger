## Overview

Show peak info on pointer hover, reusing the existing peak popup flow.
Keep click-popup behavior; add transient hover mode first, then harden edge cases.

**Spec**: quick plan from task description; no standalone spec file

## Context

- **Structure**: screen-driven Flutter app; shared provider/service layer; map interaction concentrated in `lib/screens/map_screen.dart`
- **State management**: Riverpod `Notifier` + immutable `MapState`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `lib/screens/map_screen_panels.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/peaks/peak_info_robot.dart`, `test/robot/peaks/peak_info_journey_test.dart`
- **Assumptions/Gaps**: desktop pointer UX only; hover popup is transient; click pins popup for actions; popup must stay open while pointer moves from marker onto popup

## Plan

### Phase 1: Hover popup slice

- **Goal**: prove hover opens the existing popup without regressing click selection
- [x] `lib/providers/map_provider.dart` - add peak-popup presentation state/source (`hover` vs pinned/click); keep `openPeakInfoPopup` as pinned path; add hover-open/hover-close methods
- [x] `lib/screens/map_screen.dart` - wire `_handlePeakHover` / `_handleMapHover` to open transient popup for hovered peak; keep background click selected-location behavior; click on hovered peak pins popup
- [x] `lib/screens/map_screen_panels.dart` - add only minimal popup surface hooks needed to keep hover popup alive while pointer is over the popup
- [x] TDD: `test/widget/map_screen_peak_info_test.dart` - hover over peak -> popup opens with peak content -> cursor/halo still correct
- [x] TDD: `test/widget/map_screen_peak_info_test.dart` - move off peak and popup -> transient hover popup closes; non-peak hover keeps popup absent
- [x] TDD: `test/widget/map_screen_peak_info_test.dart` - click on hovered peak pins popup; existing close/drop-marker actions still work
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Interaction hardening + journey coverage

- **Goal**: stabilize pointer transitions and preserve existing map interaction rules
- [x] `lib/screens/map_screen.dart` - clear transient popup on drag, route-draft mode, peak layer hidden, zoom below threshold, anchor invalidation, map exit without popup hover
- [x] `lib/providers/map_provider.dart` - ensure reload/peak removal/route-draft entry close transient or pinned popup consistently
- [x] TDD: `test/widget/map_screen_peak_info_test.dart` - pointer transfer marker -> popup keeps transient popup open; leaving popup closes it; background click still selects location and clears popup
- [x] `test/robot/peaks/peak_info_robot.dart` - add hover-popup journey helpers for marker, popup, and background transitions
- [x] `test/robot/peaks/peak_info_journey_test.dart` - TDD: hover shows popup; popup remains while hovered; click pins; move away closes transient-only case
- [x] Stable selectors: reuse `map-interaction-region`, `peak-marker-hitbox-<osmId>`, `peak-marker-hover-<osmId>`, `peak-info-popup`, `peak-info-popup-close`; add a popup hover-region key only if needed
- [x] Deterministic seams: existing in-memory repositories + test notifier overrides; avoid tile/network assertions
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: popup flicker when pointer crosses overlay boundary; hover and click states can fight if source is not explicit; desktop hover rules must not break touch tap flow
- **Out of scope**: mobile long-press UX; popup content redesign; peak marker label settings
