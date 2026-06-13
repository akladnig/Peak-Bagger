## Overview

Peak-list drawer should scope rows to the region polygon under the cursor, not the visible peak set.
Keep `All Peaks`; update selection reconciliation to follow cursor-region changes.

**Spec**: `task description` (quick plan; no spec file)

## Context

- **Structure**: feature-first; map UI in `lib/screens`/`lib/widgets`; state in Riverpod `Notifier`s
- **State management**: Riverpod `Notifier` + derived `Provider`
- **Reference implementations**: `lib/widgets/map_peak_lists_drawer.dart`, `lib/providers/map_provider.dart`, `lib/services/peak_list_visibility.dart`, `lib/services/region_manifest_catalog.dart`, `lib/screens/map_screen.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/providers/map_peak_list_selection_state_test.dart`, `test/providers/peak_list_selection_provider_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: if `cursorPoint` is null, likely fall back to `center` like basemaps; if cursor sits outside all polygons, only `All Peaks` remains

## Plan

### Phase 1: Cursor-region core

- **Goal**: region lookup drives list validity + selection reconcile
- [x] `lib/services/peak_list_visibility.dart` - switch helper(s) from visible-bounds filtering to cursor-region/polygon matching; preserve invalid-list skip behavior
- [x] `lib/providers/map_provider.dart` - reconcile on cursor updates, not viewport bounds; use current cursor-region for valid specific-list ids
- [x] `test/providers/peak_list_selection_provider_test.dart` - TDD: helper returns only lists with peaks inside current region polygon; malformed lists still skipped
- [x] `test/providers/map_peak_list_selection_state_test.dart` - TDD: cursor-region change prunes specific selection; visibleBounds-only change no longer clears it; empty region falls back to `All Peaks`
- [x] Verify: `flutter analyze` && `flutter test test/providers/peak_list_selection_provider_test.dart test/providers/map_peak_list_selection_state_test.dart`

### Phase 2: Drawer + journeys

- **Goal**: drawer rows follow cursor region live while open
- [ ] `lib/widgets/map_peak_lists_drawer.dart` - watch cursor point/center; render rows from region match, not map viewport; keep `All Peaks` + failure message
- [ ] `test/widget/map_screen_peak_info_test.dart` - TDD: open drawer with peaks visible in one area but cursor in another; shown rows match cursor region; moving cursor updates rows without reopening
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add hover helper/selector if needed for region switch checks
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - robot journey: hover into two regions, open peak drawer, assert row set changes by cursor region
- [ ] Verify: `flutter analyze` && `flutter test test/widget/map_screen_peak_info_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

## Risks / Out of scope

- **Risks**: cursor-null fallback may need UX call; frequent hover reconcile can be noisy if region boundaries are dense
- **Out of scope**: peak-list schema changes, new region metadata, non-cursor map filters
