## Overview

Add click-to-select GPX track highlighting on the macOS map.
Keep selection transient; green highlight wins over hover.

**Spec**: `ai_specs/005-track-selection-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`lib/providers/`, `lib/screens/`, `lib/services/`, `test/`)
- **State management**: Riverpod `MapNotifier` + `MapState`
- **Reference implementations**: `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, `./test/harness/test_map_notifier.dart`, `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: none beyond spec; selection stays UI-only, no persistence

## Plan

### Phase 1: Selection state + click path

- **Goal**: store/clear selected track id; select on primary click
- [ ] `./lib/providers/map_provider.dart` - add `selectedTrackId`, select/clear methods, clear stale selection on track rebuild/toggle paths
- [ ] `./lib/screens/map_screen.dart` - delay hover clear until after selection resolution; primary click selects hovered track; empty click clears selection; do not touch `selectedLocation`
- [ ] `./test/gpx_track_test.dart` - TDD: select hovered track, replace selection, empty click clears, pan/zoom preserves selection
- [ ] `./test/harness/test_map_notifier.dart` - extend seam only if selection helpers need it for deterministic tests
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Green render + visibility rules

- **Goal**: selected track renders green and stays visible above overlaps
- [ ] `./lib/screens/map_screen.dart` - render selected polylines last / foreground pass; keep hover cursor behavior; clear selection when tracks are hidden
- [ ] `./lib/providers/map_provider.dart` - clear selection in `_loadTracks()`, `_importTracks()`, `rescanTracks()`, `resetTrackData()`, `recalculateTrackStatistics()`
- [ ] `./test/widget/gpx_tracks_selection_test.dart` - TDD: selected track green, selected-over-hover wins, unselected tracks keep stored color
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey coverage

- **Goal**: prove end-to-end selection flow with stable selectors
- [ ] `./test/robot/gpx_tracks/selection_journey_test.dart` - TDD: hover -> primary click select -> pan/zoom preserve -> empty click clear -> hide tracks clears
- [ ] `./test/robot/gpx_tracks/gpx_tracks_robot.dart` - add helpers for click-select / clear / selected-state assertions; reuse `Key('map-interaction-region')`
- [ ] `./test/harness/test_map_notifier.dart` - use as shared deterministic seam for widget + robot coverage
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: overlap ordering; click flow must avoid stale hover state; test coverage can be brittle if selection helpers are not centralized
- **Out of scope**: touch selection, persistence/schema changes, import/statistics behavior beyond clearing stale selection
