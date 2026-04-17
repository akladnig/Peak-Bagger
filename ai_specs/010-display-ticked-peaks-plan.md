## Overview

Show track-correlated peaks on the map with a single peak renderer.
`showPeaks` controls peak visibility; `correlatedPeakIds` lives in `MapNotifier`.

**Spec**: `ai_specs/010-display-ticked-peaks-spec.md`

## Context

- **Structure**: feature-first (`screens/`, `providers/`, `services/`, `widgets/`)
- **State management**: Riverpod `Notifier<MapState>`
- **Reference implementations**: `lib/widgets/map_action_rail.dart`, `lib/screens/map_screen.dart`, `test/widget/tasmap_map_screen_test.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: `showPeaks` defaults `true`; `correlatedPeakIds` rebuilds with `MapState` mutation; no schema/correlation changes

## Plan

### Phase 1: Peak state seam

- **Goal**: `showPeaks` + correlated ids source of truth
- [x] `lib/providers/map_provider.dart` - add `showPeaks` default-on, `togglePeaks()`, `correlatedPeakIds`; rebuild set on track load/refresh/recalc
- [x] `test/harness/test_map_notifier.dart` - fake notifier support for peak toggle + correlated ids state
- [x] `test/widget/tasmap_map_screen_test.dart` - TDD: `showPeaks` starts on; toggle flips; correlated ids dedupe by `osmId`; map rebuilds with updated ids
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Combined peak renderer

- **Goal**: one marker layer; ticked vs unticked SVG by correlation
- [x] `pubspec.yaml` - register `assets/peak_marker_ticked.svg`
- [x] `lib/widgets/map_action_rail.dart` - add `Show Peaks` FAB below `Show Tracks`; `Icons.landscape`; stable key
- [x] `lib/screens/map_screen.dart` - render combined peak markers; choose SVG by `correlatedPeakIds`; keep `zoom >= 12`; key the peak marker layer
- [x] `test/widget/tasmap_map_screen_test.dart` - TDD: peak toggle visible/default-on; hidden peaks hide all markers; correlated peaks use ticked SVG; unticked fallback remains; zoom gate respected
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey

- **Goal**: end-to-end peak toggle + visible correlated peaks
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add helpers/selectors for `show-peaks-fab` and peak layer assertions
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - TDD: enable tracks + peaks; correlated peaks shown; toggle off/on hides/reveals markers
- [x] `test/harness/test_map_notifier.dart` - deterministic correlated ids/tracks fixtures for robot flow
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `correlatedPeakIds` rebuilds must accompany a `MapState` mutation; combined renderer must not duplicate catalog peaks; robot selectors need stable keys
- **Out of scope**: correlation algorithm changes; ObjectBox schema changes; track-details screen; search-selection behavior
