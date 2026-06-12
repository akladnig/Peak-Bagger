<goal>
Add per-item hide/show control for saved routes and GPX tracks in the shared map info panel so users can remove one route or track from the map without deleting it.
Persist that choice in ObjectBox so it survives app restarts, and keep the current global map layer toggles separate from per-item visibility.
</goal>

<background>
Flutter app using Riverpod, `flutter_map`, and ObjectBox.
The shared route/track panel lives in `./lib/screens/map_screen_panels.dart`, map rendering and hover logic live in `./lib/screens/map_screen.dart` and `./lib/screens/map_screen_layers.dart`, and persistence lives in `./lib/models/route.dart`, `./lib/models/gpx_track.dart`, `./lib/services/route_repository.dart`, and `./lib/services/gpx_track_repository.dart`.

Files to examine:
@./lib/screens/map_screen_panels.dart
@./lib/screens/map_screen.dart
@./lib/screens/map_screen_layers.dart
@./lib/models/route.dart
@./lib/models/gpx_track.dart
@./lib/services/route_repository.dart
@./lib/services/gpx_track_repository.dart
@./lib/providers/map_provider.dart
@./lib/providers/route_repository_provider.dart
@./lib/objectbox-model.json
@./test/widget/map_route_info_panel_test.dart
@./test/widget/map_track_info_panel_test.dart
@./test/providers/map_provider_selected_route_test.dart
@./test/providers/map_provider_selected_track_test.dart
@./test/robot/map/route_info_journey_test.dart
@./test/robot/gpx_tracks/gpx_tracks_journey_test.dart
</background>

<discovery>
1. Confirm the current route/track display and hover entry points before wiring the new visibility filter.
2. Confirm how ObjectBox regeneration handles new boolean properties so existing rows can be backfilled to visible without a behavioral regression.
3. Confirm the smallest repository seam needed for track visibility updates, since `GpxTrackRepository` currently has a write path only for ObjectBox storage.
</discovery>

<user_flows>
Primary flow:
1. User opens a saved route or track info panel on the map.
2. The bottom of the panel shows a single visibility row above the export footer divider.
3. The row label is `Hide this route on the map` or `Hide this track on the map` when `visible == true`, and `Show this route on the map` or `Show this track on the map` when `visible == false`.
4. The switch value reflects the same `visible` state and sits on the right side of the row.
5. Toggling the switch updates persistence and immediately updates the map layer.
6. Hiding the item removes only that route or track from the map, while the panel stays usable so the user can turn it back on.

Alternative flows:
- User opens the item from another part of the app, such as dashboard or ObjectBox Admin: `showRoute` / `showTrack` must bring the item back onto the map by setting `visible = true` before focusing it.
- Returning user: existing stored routes and tracks should still appear visible after the migration/backfill.
- Shared panel: the same visibility control must work for both route and track bodies without adding a second UI surface.

Error flows:
- If persistence fails during a visibility toggle, keep the previous state and do not leave the UI and stored row diverged.
- If the item disappears from the repository, keep the existing stale-selection clearing behavior.
- If the map is already showing a hidden item through stale state, do not crash; the next reconciliation or refresh should normalize it.
</user_flows>

<requirements>
**Functional:**
1. Add a `visible` boolean to `Route` and `GpxTrack` in `./lib/models/route.dart` and `./lib/models/gpx_track.dart`.
2. New routes/tracks must default to `visible = true`, and existing stored rows must be migrated/backfilled to `true` so the upgrade does not hide current data.
3. `GpxTrack.fromMap` / `toMap` must preserve `visible`, and any clone/replace flow must carry the current visibility forward.
4. The route/track info panel must render one compact row at the very bottom of the scrollable content, immediately above the export footer divider.
5. The row must use the exact action text pair above, with the switch on the right and the label on the left on the same line.
6. The switch value must map directly to the model field, and toggling it must persist the new `visible` value through the repository layer.
7. Route visibility writes must increment `routeRevisionProvider` (or an equivalent route-list refresh signal) so the route layer re-renders immediately after persistence.
8. Track visibility writes must use a dedicated update/save seam that works in both ObjectBox and `InMemoryGpxTrackStorage`; do not rely on `replaceTrack` for this toggle.
9. Track visibility writes must also update the in-memory `MapState.tracks` entry immediately so the map can re-render without waiting for a later reload.
10. Map rendering must ignore hidden routes/tracks when building polylines and hover candidates, and selection/zoom logic must also skip hidden items.
11. `showRoute` and `showTrack` must restore `visible = true` for the target item before selecting/focusing it.
12. The global `showRoutes` / `showTracks` layer toggles must remain independent of per-item visibility.

**Error Handling:**
13. A failed write must not silently flip the UI state; keep the previous visibility and surface the failure through the app's existing error/snackbar pattern if one is already used in that path.
14. Hidden items must not be treated as deleted or unavailable; availability providers and browsing lists should still see them.

**Edge Cases:**
15. Hiding an already selected item must not force-close the info panel; it should simply remove the item from the map layer.
16. The visibility row must remain usable on narrow widths; if text truncates, the switch must stay visible on the right and the row must not wrap into a two-line control.
17. Recalculation, import, or replace flows that rewrite a track must preserve the current `visible` flag.

**Validation:**
18. Add tests that prove `visible` defaults to true, persists through repository round-trips, and survives clone/replace/update flows.
19. Add widget tests that assert the new row text, placement, and switch state in both route and track panels.
20. Add provider/map tests that prove hidden items do not render, hover, or auto-zoom, while `showRoute` / `showTrack` restore visibility and route revision refreshes.
21. Add robot journey coverage for both route and track: open panel, hide item, verify map removal, show item again, verify return.
</requirements>

<boundaries>
Edge cases:
- Existing ObjectBox rows created before this change: backfill them to visible so the upgrade is non-destructive.
- Perform that backfill once at startup or repository initialization using the existing migration-marker pattern, then mark the migration complete so the rewrite is not repeated.
- Hidden item still selected: keep the panel open and let the user restore visibility from the same control.
- Hidden row in repository but not on the map: the item remains in admin/browse surfaces and can be re-shown.

Error scenarios:
- ObjectBox write failure during toggle: do not commit the new visibility in memory unless persistence succeeds.
- Missing route/track row: continue using the current stale-selection clearing path; do not invent a fallback item.

Limits:
- No bulk hide/show management screen in this change.
- No deletion, archiving, or separate visibility filter UI.
- No change to the meaning of the global `Show Routes` / `Show Tracks` drawer toggles.
</boundaries>

<implementation>
Modify `./lib/models/route.dart` and `./lib/models/gpx_track.dart` to add the new field and preserve it in constructors, cloning, and map serialization.

Update `./lib/services/route_repository.dart` and `./lib/services/gpx_track_repository.dart` so visibility toggles can be persisted in both production and in-memory/test storage paths, with a dedicated track update/save seam rather than an ObjectBox-only replace path.

Add a one-time startup or repository-initialization backfill for existing `Route` and `GpxTrack` rows so their new `visible` field is normalized to `true` on upgrade, using the existing migration-marker pattern rather than repeated ad hoc checks.

Update `./lib/screens/map_screen_panels.dart` to add the visibility row and wire it to the model state.

Update `./lib/screens/map_screen.dart` and `./lib/screens/map_screen_layers.dart` so hidden items are filtered out of route/track rendering, hover detection, and zoom-to-selection logic, while `showRoute` / `showTrack` restore visibility.

Regenerate `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` from the annotated entities; do not hand-edit generated output.

Keep the change minimal: reuse the current map/revision patterns, do not introduce a second visibility system, and do not repurpose the global show/hide drawer toggles as per-item state.
</implementation>

<stages>
Phase 1: Model and persistence.
Verify with focused tests that the new field exists, defaults to visible, and survives repository round-trips.

Phase 2: Map filtering.
Verify with provider/map tests that hidden items stop rendering and stop participating in hover/zoom selection.

Phase 3: Panel UI.
Verify with widget tests that the shared info panel shows the new row with the right label and switch placement.

Phase 4: Journey coverage.
Verify with robot tests that a user can hide and re-show both a route and a track from the map panel.
</stages>

<validation>
Use vertical-slice TDD: one failing test at a time, then the smallest implementation that makes it pass.

Required automated coverage outcomes:
- Logic/business rules: `visible` defaults to true, persists through save/replace/clone paths, and survives ObjectBox regeneration/backfill.
- UI behavior: the shared panel renders a single compact visibility row above the footer divider, with the exact label text and a right-aligned switch.
- Critical journeys: route hide/show and track hide/show both update the map immediately, keep the panel usable, and survive app restart.

Test split:
- Unit/provider tests for persistence, defaulting, filtering, and restore behavior.
- Widget tests for the shared info panel row and label/switch state.
- Robot tests for the end-to-end route and track journeys.

Stable selectors:
- Keep `track-info-panel` as the panel root.
- Add one stable key for the new switch, such as `track-info-panel-visibility-switch`, and reuse that same key for both route and track bodies in the shared panel.

Verification commands:
- Run the focused tests for `./test/widget/map_route_info_panel_test.dart`, `./test/widget/map_track_info_panel_test.dart`, `./test/providers/map_provider_selected_route_test.dart`, `./test/providers/map_provider_selected_track_test.dart`, `./test/robot/map/route_info_journey_test.dart`, and `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`.
- Run the repo's ObjectBox regeneration/build step and confirm `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` are regenerated, not edited by hand.
</validation>

<done_when>
1. Route and track info panels both expose the new visibility switch row with the requested copy and alignment.
2. Toggling the switch persists `visible` and updates the map without affecting the global layer toggles.
3. Hidden routes/tracks no longer render or hover on the map, but the selected info panel remains usable.
4. Existing stored routes/tracks still appear visible after migration, and show/open flows restore hidden items.
5. The targeted widget, provider, and robot tests pass.
</done_when>
