## Overview
Trail overlay from bundled route graph; wire toggle, geometry decode, and layered render.

**Spec**: `ai_specs/trail-display-spec.md`

## Context
- **Structure**: feature-first (`lib/providers`, `lib/widgets`, `lib/screens`, `lib/services`)
- **State management**: Riverpod + shared prefs restore/persist in `map_provider.dart`
- **Reference implementations**: `lib/widgets/map_action_rail.dart`, `lib/widgets/map_tracks_routes_drawer.dart`, `lib/screens/map_screen.dart`, `lib/services/route_graph_query_service.dart`, `lib/providers/map_provider.dart`
- **Assumptions/Gaps**: trail geometry decode needs a small companion service; refresh once on enable/restore, then via debounced `visibleBounds`

## Plan

### Phase 1: Trail toggle wiring

- **Goal**: state + controls + persistence; no geometry risk yet
- [x] `lib/providers/map_provider.dart` - add `showTrails`, `show_trails` restore/persist, toggle, readiness gating
- [x] `lib/widgets/map_action_rail.dart` - add `Show Trails` FAB, distinct `heroTag`, disable only
- [x] `lib/widgets/map_tracks_routes_drawer.dart` - add `Show Trails` row + switch
- [x] `lib/screens/map_screen.dart` - immediate refresh on enable/restore; debounced visible-bounds refresh hook
- [x] TDD: trail restore/persist across startup; toggle enabled/disabled state; immediate refresh trigger on enable/restore
- [x] TDD: rail/drawer selectors stay stable; disabled FAB behavior matches other FABs
- [x] Verify: `flutter analyze && flutter test test/widget/map_action_rail_grouping_test.dart test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_info_test.dart`

### Phase 2: Trail geometry + render

- **Goal**: decode trail segments; paint map layer in correct order
- [x] `lib/services/route_graph_trail_service.dart` - decode active chunks into deduped polyline segments; fail closed on malformed/empty payloads
- [x] `lib/services/route_graph_query_service.dart` - add trail query helpers for filtered rows/chunks and buffered bounds
- [x] `lib/screens/map_screen_layers.dart` - build trail polylines and add stable layer hook
- [x] `lib/screens/map_screen.dart` - insert trail layer between basemap/tasmap and routes/tracks/peaks/labels
- [x] `lib/theme.dart` - centralize trail colors/widths used by render + tests
- [x] TDD: matching `highway=path` and long/tagged `footway`; excluded tags removed; chunk dedupe; malformed payload fail-closed
- [x] TDD: trail layer order + styling survives zoom/pan; empty match renders nothing
- [x] Verify: `flutter analyze && flutter test test/services/route_graph_query_service_test.dart test/services/route_graph_trail_service_test.dart test/widget/map_screen_layers_test.dart test/widget/map_screen_track_info_test.dart test/widget/map_screen_route_info_test.dart`

### Phase 3: Critical journey coverage

- **Goal**: prove end-to-end trail toggle + visible overlay + regression safety
- [x] `test/robot/map/` - add key-first trail journey using `show-trails-fab`, `show-trails-switch`, and trail layer key
- [x] `test/widget/` - add startup restore, disabled-state, and drawer/rail coverage
- [x] TDD: enable trails from map UI shows overlay; disable removes it; restore on startup keeps visibility
- [x] TDD: rapid pan/zoom keeps overlay stable; no-match viewport stays empty without error
- [x] Verify: `flutter analyze && flutter test test/services/route_graph_trail_service_test.dart test/services/route_graph_query_service_test.dart test/providers/map_tracks_routes_visibility_test.dart test/widget/map_tracks_routes_drawer_test.dart test/widget/map_action_rail_grouping_test.dart test/widget/map_screen_layers_test.dart test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope
- **Risks**: chunk payload decode assumptions; trail geometry may need a thin adapter if chunk shape differs from route payload shape
- **Out of scope**: live Overpass queries; compatibility shims beyond existing `show_trails` persistence
