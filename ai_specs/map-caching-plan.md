## Overview

Tile-cache scope filter. Mandatory Tasmap selection, exact polygon download region, local-only settings state.

**Spec**: `ai_specs/map-caching-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `tests/`
- **State management**: Riverpod `NotifierProvider`; settings screen can watch `tasmapStateProvider.tasmapRevision`
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/providers/map_provider.dart`, `lib/services/tasmap_repository.dart`, `test/harness/test_tasmap_repository.dart`, `test/robot/tasmap/tasmap_robot.dart`
- **Assumptions/Gaps**: default map order must be name-sorted; selected-map chip needs stable key; reseed on `tasmapRevision` change if current selection disappears; no persistence; no clear-selection path

## Plan

### Phase 1: Scope Helper And Fakes

- **Goal**: deterministic scope selection; test seam first
- [x] `lib/services/tile_cache_download_scope.dart` - resolve selected-map polygon region from valid Tasmap points
- [x] `lib/screens/settings_screen.dart` - add narrow download seam around `startForeground`; keep region + flags snapshot-based
- [x] `test/unit/tile_cache_download_scope_test.dart` - `TDD:` name-sorted default map, exact polygon region, empty-repo disable path
- [x] `test/harness/test_tasmap_repository.dart` - align search semantics and expose stable name-sorted fixtures for tile-cache tests
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Settings UI State

- **Goal**: mandatory selected map visible in settings UI
- [x] `lib/screens/settings_screen.dart` - local search state, default selection chip/label, dropdown, suggestion list, `tasmapRevision` reseed
- [x] `lib/providers/tasmap_provider.dart` - no change needed; screen reads `tasmapRevision` directly
- [x] `test/widget/tile_cache_settings_screen_test.dart` - `TDD:` default chip on first build, live search, empty results preserve selection, reseed after Tasmap refresh, stable keys
- [x] `test/widget/tile_cache_settings_screen_test.dart` - assert `Key('tile-cache-basemap-dropdown')`, `Key('tile-cache-map-search-field')`, `Key('tile-cache-map-suggestion-0')`, `Key('tile-cache-selected-map-chip')`, `Key('tile-cache-download-button')`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Download Journey

- **Goal**: selected map drives foreground download; robot proof on critical path
- [ ] `lib/screens/settings_screen.dart` - wire selected-map polygon into download request; keep basemap store and skip-existing behavior unchanged
- [ ] `test/robot/settings/tile_cache_settings_journey_test.dart` - `TDD:` open settings, select basemap, confirm default map, search/select map, start download through fake seam
- [ ] `test/robot/settings/tile_cache_settings_journey_test.dart` - verify selected region snapshot, skip-existing flag, and mid-download UI edits only affect next request
- [ ] `test/robot/tasmap/tasmap_robot.dart` - reuse selector conventions only if journey harness needs a reference for stable key-first interactions
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: download seam may need a small callback/provider abstraction; Tasmap refresh reseed must stay synced with revision changes; name sort must stay deterministic across imports
- **Out of scope**: persisting tile-cache selection; clearing selected map; map-screen behavior changes; store/url switching by selected map
