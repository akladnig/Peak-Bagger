## Overview

Add favourite-marker name labels under the heart marker. Reuse `OutlinedText`; make its visible text color configurable so peak labels and favourite labels can diverge cleanly.

**Spec**: quick plan from task description; no standalone spec file

## Context

- **Structure**: screen-driven Flutter UI; shared theme helpers in `lib/theme.dart`; map marker widgets in `lib/widgets`; map composition in `lib/screens/map_screen.dart`
- **State management**: Riverpod `Notifier` + immutable `MapState`; favourites come from `WaypointsRepository` via `mapProvider`
- **Reference implementations**: `lib/widgets/map_marker.dart`, `lib/theme.dart`, `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/screens/map_screen_peak_layer.dart`, `test/widget/map_screen_waypoint_test.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/map/drop_marker_journey_test.dart`
- **Assumptions/Gaps**: interpret “text colour” as the visible `OutlinedText` fill color; keep outline configurable/defaulted only as needed; no extra declutter/collision handling for favourite labels in this slice

## Plan

### Phase 1: Favourite label slice

- **Goal**: saved favourites render name under marker, end-to-end
 - [x] `lib/widgets/map_marker.dart` - extend `FavouriteMarker` to accept the favourite name and render marker + below-label in one widget; keep the existing heart marker visuals unchanged
 - [x] `lib/screens/map_screen.dart` - pass `favourite.name` into `FavouriteMarker`; increase marker layer width/height enough for the below-label footprint; add stable keys for favourite label lookup if not owned by the widget already
 - [x] TDD: `test/widget/map_screen_waypoint_test.dart` - save a favourite -> marker layer shows -> label widget appears with trimmed favourite name under the marker
 - [x] TDD: `test/widget/map_screen_waypoint_test.dart` - long favourite names stay bounded/ellipsized rather than widening the marker hit area indefinitely
 - [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_waypoint_test.dart`

### Phase 2: OutlinedText color plumbing + regression coverage

- **Goal**: `OutlinedText` supports peak and favourite color schemes without regressions
 - [x] `lib/theme.dart` - add explicit `OutlinedText` color inputs for visible text and, if needed, outline; preserve current defaults where callers do not opt in
 - [x] `lib/screens/map_screen_layers.dart` - pass the peak label color explicitly so peak labels use `Theme.of(context).colorScheme.onSurface`
 - [x] `lib/screens/map_screen_peak_layer.dart` - mirror the same peak label color wiring for the overlay label path
 - [x] `lib/widgets/map_marker.dart` - render favourite labels with `OutlinedText` using `favouriteMarkerColour`
 - [x] TDD: `test/widget/map_screen_peak_info_test.dart` - peak marker labels still use the peak color path after `OutlinedText` API changes
 - [x] `test/robot/map/drop_marker_robot.dart` - add favourite-label finder/helper only if the widget test selectors are not enough for journey coverage
 - [x] `test/robot/map/drop_marker_journey_test.dart` - TDD: save favourite -> label is visible on map; goto-favourite journey still works unchanged
 - [x] Stable selectors: reuse/add `favourite-marker-<id>` plus `favourite-marker-name-<id>` or `favourite-marker-labels-<id>`
 - [x] Deterministic seams: keep existing in-memory waypoint repository path; avoid map tile/render timing assertions beyond keyed widget presence
 - [ ] Verify: `flutter analyze` && `flutter test` (blocked: unrelated existing robot failures in `test/robot/settings/*` and `test/robot/tasmap/*`)

## Risks / Out of scope

- **Risks**: enlarged marker bounds can affect tap feel or overlap nearby UI; favorite-label color may need outline tuning for dark/light themes; dense favourite clusters can become visually noisy
- **Out of scope**: favourite label collision avoidance; editable favourite labels on-map; peak-label layout redesign beyond explicit color wiring
