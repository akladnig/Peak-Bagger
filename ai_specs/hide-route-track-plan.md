## Overview

Per-item hide/show for saved routes + GPX tracks in the shared map info panel.
Persist via ObjectBox; map filters hidden items; panel can re-show them.

**Spec**: `ai_specs/hide-route-track-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; models/services/providers/screens/tests
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/screens/map_screen.dart`, `lib/providers/map_provider.dart`, `lib/services/migration_marker_store.dart`, `test/robot/map/route_info_robot.dart`
- **Assumptions/Gaps**: one-time backfill via existing migration-marker pattern; no `trackRevisionProvider`, so track visibility must update `MapState.tracks` directly; shared panel needs a callback seam for visibility toggle

## Plan

### Phase 1: Persist visible

- **Goal**: schema + repo + one-time backfill
 - [x] `lib/models/route.dart` - add `visible`, default true
 - [x] `lib/models/gpx_track.dart` - add `visible`, default true, preserve in `fromMap`/`toMap`
 - [x] `lib/services/route_repository.dart` - persist `visible` in save path
 - [x] `lib/services/gpx_track_repository.dart` - add update/save seam; in-memory support
 - [x] `lib/services/migration_marker_store.dart` - add visibility migration marker
 - [x] `lib/services/item_visibility_backfill_service.dart` - new one-time rewrite of legacy route/track rows to `visible=true`
 - [x] `lib/providers/map_provider.dart` - trigger backfill on startup/init
 - [x] `lib/objectbox-model.json` / `lib/objectbox.g.dart` - regenerate schema artifacts
 - [x] `test/services/route_repository_test.dart` - route visible round-trip + default
 - [x] `test/services/gpx_track_repository_test.dart` - track visible round-trip + update/save seam
 - [x] `test/providers/map_tracks_routes_visibility_test.dart` - backfill once; restored defaults stay visible
 - [x] TDD: default true -> backfill false rows once -> update/save seam persists -> route write bumps revision
 - [x] Verify: `dart run build_runner build --delete-conflicting-outputs && flutter analyze && flutter test test/services/route_repository_test.dart test/services/gpx_track_repository_test.dart test/providers/map_tracks_routes_visibility_test.dart`

### Phase 2: Filter map layers

- **Goal**: hidden items stop rendering/hover/zoom; show actions restore visibility
- [ ] `lib/screens/map_screen_layers.dart` - skip hidden routes/tracks in polyline builders
- [ ] `lib/screens/map_screen.dart` - filter hover candidates; skip hidden items in zoom queue; pass visibility-aware routes/tracks into panel flow
- [ ] `lib/providers/map_provider.dart` - add visibility setters; `showRoute`/`showTrack` restore `visible=true`; `selectRoute`/`selectTrack` reject hidden items; route write increments revision
- [ ] `test/providers/map_provider_selected_route_test.dart` - hidden route no-select; showRoute restores
- [ ] `test/providers/map_provider_selected_track_test.dart` - hidden track no-select; showTrack restores
- [ ] `test/widget/map_screen_route_info_test.dart` - panel state stays sane when route hidden/shown
- [ ] `test/widget/map_screen_track_info_test.dart` - panel state stays sane when track hidden/shown
- [ ] TDD: hidden route/track omitted from draw + hover + zoom; visible restore path reselects and refocuses
- [ ] Verify: `flutter analyze && flutter test test/providers/map_provider_selected_route_test.dart test/providers/map_provider_selected_track_test.dart test/widget/map_screen_route_info_test.dart test/widget/map_screen_track_info_test.dart`

### Phase 3: Shared panel + journeys

- **Goal**: bottom-row switch in shared panel; end-to-end hide/show journeys
- [ ] `lib/screens/map_screen_panels.dart` - add visibility row, shared switch key, callback prop
- [ ] `lib/screens/map_screen.dart` - wire panel callback to route/track visibility setters; keep panel open on hide
- [ ] `test/widget/map_route_info_panel_test.dart` - route row text, key, alignment, toggle state
- [ ] `test/widget/map_track_info_panel_test.dart` - track row text, key, alignment, toggle state
- [ ] `test/robot/map/route_info_robot.dart` / `test/robot/map/route_info_journey_test.dart` - hide/show route journey; stable selectors
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` / `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - hide/show track journey; stable selectors
- [ ] TDD: panel row copy + right-aligned switch -> toggle persists -> hidden item stays selectable in panel -> robot journey covers both entities
- [ ] Verify: `flutter analyze && flutter test test/widget/map_route_info_panel_test.dart test/widget/map_track_info_panel_test.dart test/robot/map/route_info_journey_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

## Risks / Out of scope

- **Risks**: backfill timing vs startup load; track state sync can drift if the in-memory update path is missed; selector churn across shared panel tests
- **Out of scope**: bulk hide/show UI, delete/archive, changing global `Show Routes` / `Show Tracks` semantics
