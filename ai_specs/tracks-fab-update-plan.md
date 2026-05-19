## Overview

Tracks/routes drawer from rail + `T`; independent persisted visibility.
Add real route repo/read path so saved routes render and survive restart.

**Spec**: `./ai_specs/tracks-fab-update-spec.md` (read this file for full requirements)

## Context

- **Structure**: mixed; large map state in `lib/providers/map_provider.dart`, feature widgets/screens around it
- **State management**: Riverpod `NotifierProvider`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/services/gpx_track_repository.dart`, `lib/widgets/map_peak_lists_drawer.dart`, `lib/screens/map_screen_layers.dart`
- **Assumptions/Gaps**: keep route entities outside `MapState`; use map-local prefs loader seam instead of new app-global prefs abstraction

## Plan

### Phase 1: Visibility Slice

- **Goal**: drawer open path + persisted dual visibility, no route persistence yet
- [x] `lib/providers/map_provider.dart` - add `EndDrawerMode.tracksRoutes`, `showRoutes`, prefs keys/loaders, restore-before-track-load gate, user-wins-over-pending-restore logic, explicit track-availability state, non-mutating startup/import/delete visibility rules, drawer/snackbar UI state needed for this slice
- [x] `lib/providers/route_repository_provider.dart` - add route repo provider, route revision notifier, route list provider, route availability provider watching revision
- [x] `lib/screens/map_screen.dart` - open tracks/routes drawer from `T`, switch end-drawer surface by mode, read route providers, keep basemap/peak-list flows unchanged
- [x] `lib/widgets/map_action_rail.dart` - rename `show-tracks-fab` copy to `Show Tracks/Routes (T)` and open drawer even when datasets unavailable
- [x] `lib/widgets/map_tracks_routes_drawer.dart` - add scrollable drawer with stable keys, two switch rows, helper subtitles, whole-row tap parity, disabled-state rendering
- [x] TDD: prefs missing -> both flags restore `false`; user toggle before restore completion wins for that flag
- [x] TDD: startup/import/delete/recovery helpers update datasets only; do not rewrite stored visibility
- [x] TDD: rail tap and `T` open drawer; drawer stays open while toggling; stored values remain visible on disabled switches
- [x] Robot journey tests + selectors/seams for open drawer, `T`, both switches, disabled helper text; extend harness with prefs loader overrides and drawer-open helpers
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Route Persistence + Overlay

- **Goal**: saved routes become real data and render from visibility state
- [x] `lib/services/route_repository.dart` - add ObjectBox-backed + writable in-memory route storage, synchronous read/save API, stable ID-on-create contract
- [x] `lib/models/route.dart` - add zoom-cache decode helper mirroring track lookup and raw-geometry fallback support; keep `app_route.Route` alias rule where Flutter `Route` also imported
- [x] `lib/core/constants.dart` - add `RouteUI.width = 1.0`
- [x] `lib/providers/map_provider.dart` - add `saveRouteDraft()`, `isSavingRoute`, `routeDraftNameError`, route-save snackbar seam, revision bump only on successful save, post-save cleanup, blank-name validation, default red colour
- [x] `lib/widgets/map_route_bottom_sheet.dart` - wire save to notifier, show inline `A Route name must be entered`, disable save until valid, keep mode buttons visible/mutually selectable/no-op
- [x] `lib/screens/map_screen_layers.dart` - add route polyline builder using route cache first, raw `[route.gpxRoute]` fallback, stored colour, `RouteUI.width`, render below track layer
- [x] `lib/screens/map_screen.dart` - consume route-save snackbar seam, close sheet only on successful save, render route overlays only when `showRoutes` is true
- [x] TDD: save valid draft -> persisted route with red colour, raw geometry JSON, zoom cache, revision bump, draft cleanup, no success snackbar
- [x] TDD: blank/whitespace name or <2 markers -> save blocked, inline error shown, sheet stays open
- [x] TDD: repo save failure -> no phantom route, no revision bump, visibility unchanged, snackbar shown, draft preserved
- [x] TDD: route overlay uses cache JSON when valid, falls back to raw geometry when cache missing/invalid, skips only when both unusable
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Coverage + Regression Sweep

- **Goal**: stabilize journey coverage and repo seams
- [ ] `test/harness/test_map_notifier.dart` - add independent tracks/routes visibility seeding, route repo overrides, route availability overrides, save-state/snackbar hooks, prefs loader seams
- [ ] `test/widget/map_screen_keyboard_test.dart` - update `T` expectations from direct toggle to drawer open path
- [ ] `test/widget/map_action_rail_grouping_test.dart`, `test/widget/gpx_tracks_recovery_test.dart`, `test/widget/map_screen_route_sheet_test.dart` - update old disabled/toggle assumptions; add drawer, helper text, route-save, overlay, and restore assertions
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`, `test/robot/gpx_tracks/selection_journey_test.dart`, `test/robot/gpx_tracks/recovery_robot.dart` - add stable drawer/switch robot methods and restart-restore journey coverage
- [ ] `test/gpx_track_test.dart` or new route-focused test file near model/service scope - cover route cache parsing/raw fallback and repository create/read/update behavior
- [ ] TDD: restart with stored `showTracks`/`showRoutes` combinations restores same combination before later dataset changes
- [ ] TDD: turning tracks off still clears selected/hovered track state; turning routes off does not mutate tracks/selection
- [ ] Robot journey tests + selectors/seams for save route -> enable routes -> restart -> layer still restored
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `Route` name collision with Flutter nav types; large `MapNotifier` startup flow may hide visibility rewrites; route cache/ObjectBox contract may need generator refresh
- **Out of scope**: route editing UI beyond save wiring, real snap-to-trail routing/statistics, basemap/peak-list behavior changes
