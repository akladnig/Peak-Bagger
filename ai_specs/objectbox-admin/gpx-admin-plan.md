## Overview
Tighten `GpxTrack` admin presentation + actions.
Reuse existing Peak admin patterns, Riverpod map state, and `showDangerConfirmDialog`.

**Spec**: `ai_specs/gpx-admin-spec.md` (read this file for full requirements)

## Context
- **Structure**: layer-first (`screens/`, `services/`, `providers/`, `test/`)
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/objectbox_admin_screen.dart`, `lib/screens/objectbox_admin_screen_details.dart`, `test/widget/objectbox_admin_shell_test.dart`, `test/robot/objectbox_admin/objectbox_admin_journey_test.dart`, `test/harness/test_map_notifier.dart`
- **Assumptions/Gaps**: none; spec pins dialog wording, selector keys, and map cleanup

## Plan

### Phase 1: GpxTrack presentation

- **Goal**: format durations; cap details text
- [x] `lib/services/objectbox_admin_repository.dart` - format `totalTimeMillis`/`movingTime`/`restingTime`/`pausedTime` as `hh:mm:ss`; keep Peak formatting unchanged
- [x] `lib/screens/objectbox_admin_screen_details.dart` - render `gpxFile`/`filteredTrack` only in details view; non-selectable `Text(maxLines: 5, overflow: TextOverflow.ellipsis)`
- [x] `test/services/objectbox_admin_repository_test.dart` - TDD: duration format; null/long inputs; Peak regressions stay green
- [x] `test/widget/objectbox_admin_shell_test.dart` - TDD: details truncation visible; non-`GpxTrack` admin paths unchanged
- [x] `test/widget/objectbox_admin_browser_test.dart` - TDD: read-only details rendering unchanged in browser mode
- [ ] Verify: `flutter analyze && flutter test`

### Phase 2: Admin actions + map cleanup

- **Goal**: add view/delete flow; keep map state coherent
- [ ] `lib/screens/objectbox_admin_screen_table.dart` - add `GpxTrack` delete action + stable key `objectbox-admin-gpx-track-delete-<gpxTrackId>`
- [ ] `lib/screens/objectbox_admin_screen_details.dart` - add `GpxTrack` view icon + stable key `objectbox-admin-gpx-track-view-on-map`
- [ ] `lib/screens/objectbox_admin_screen.dart` - wire delete via `showDangerConfirmDialog`; Peak wording with `Track`/`trackName`; call `GpxTrackRepository.deleteTrack(trackId)`; wire view via `showTrack(trackId)` then `/map`
- [ ] `lib/providers/map_provider.dart` - add `MapNotifier.deleteTrack(trackId)`; remove from `tracks`, clear `selectedTrackId`/`selectedLocation`/`hoveredTrackId`, invalidate `selectedTrackFocusSerial`, recompute `showTracks`
- [ ] `test/widget/objectbox_admin_shell_test.dart` - TDD: delete confirm copy; delete selected/active track clears map state; view no-op for missing track; keys present
- [ ] `test/widget/objectbox_admin_browser_test.dart` - TDD: `GpxTrack` browse/read flows preserve existing admin behavior
- [ ] Verify: `flutter analyze && flutter test`

### Phase 3: Robot journey

- **Goal**: prove full admin path end-to-end
- [ ] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - add `GpxTrack` row/action helpers; add map-state assertion helpers if needed
- [ ] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - TDD: select `GpxTrack`, view on map, delete active track, assert row removed + map state cleared
- [ ] `test/harness/test_map_notifier.dart` - only if the journey needs explicit `GpxTrackRepository.test(...)` injection for deterministic `showTrack(trackId)` resolution
- [ ] Verify: `flutter analyze && flutter test`

## Risks / Out of scope
- **Risks**: delete cleanup must keep `tracks`/selection/focus serial consistent; admin view/delete wiring spans screen + provider + tests
- **Out of scope**: schema changes; GPX import/parsing; new admin actions beyond `GpxTrack` view/delete; line caps beyond `gpxFile` and `filteredTrack`
