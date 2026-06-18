<goal>
Add a persistent waypoint workflow to the main map screen so users can:
1. arm a marker drop from the action rail,
2. tap empty map space to choose between marker, favourite, or drive-ETA actions,
3. return to the current marker or a saved favourite later, and
4. inspect and delete saved waypoint rows in ObjectBox Admin.

This matters because the map already supports a transient amber selected-location marker, peak-popup marker drops, and drive ETA, but those behaviors are split across unrelated entry points and are not persisted in one dedicated location model. The result should feel like one coherent location workflow for map exploration.
</goal>

<background>
The app is a Flutter + Riverpod + ObjectBox application.

Relevant code and patterns to examine before editing:
- `@lib/screens/map_screen.dart`
- `@lib/screens/map_screen_panels.dart`
- `@lib/widgets/map_action_rail.dart`
- `@lib/providers/map_provider.dart`
- `@lib/core/constants.dart`
- `@lib/services/objectbox_admin_repository.dart`
- `@lib/screens/objectbox_admin_screen.dart`
- `@lib/screens/objectbox_admin_screen_table.dart`
- `@lib/models/peak.dart`
- `@lib/models/peaks_bagged.dart`
- `@lib/models/route_waypoint.dart`
- `@lib/objectbox-model.json`
- `@lib/objectbox.g.dart`
- `@test/widget/map_screen_peak_info_test.dart`
- `@test/widget/map_screen_drive_eta_test.dart`
- `@test/widget/map_action_rail_grouping_test.dart`
- `@test/robot/peaks/peak_info_robot.dart`

Current constraints and conventions:
- `MapScreen` already owns pointer hit-testing order, popup orchestration, and anchored surface placement.
- `MapActionRail` owns the location-group FAB layout and stable keys for map actions.
- `MapProvider.selectedLocation` currently drives the amber marker and `Center on marker` behavior.
- Existing drive ETA behavior is already testable through `routeGraphDriveEtaHitServiceProvider`, `liveLocationServiceProvider`, and `openRouteServiceProvider`.
- The codebase already has a non-ObjectBox `RouteWaypoint` model. Do not overload it for this feature.
</background>

<user_flows>
Primary flow:
1. User presses the new `Drop Marker` FAB in the `Loc` group.
2. The app enters an armed drop-marker state.
3. User taps empty map space.
4. The app places or replaces the current marker at that tapped location, persists one `marker` waypoint row, updates the amber selected-location marker, exits armed state, and leaves the current camera position unchanged.

Secondary flow:
1. User taps empty map space without armed mode active.
2. The app opens a tap-action popup anchored to the tap point.
3. The popup always offers `Drop Marker` and `Drop Favourite`.
4. If the tapped point is routable using the stored tap-time ETA context, the popup also offers `Get driving time from Home` and `Get driving time from Marker`.
5. User chooses one action.
6. The app performs only that action, closes the popup, and preserves existing peak/track/route selection precedence outside the chosen action.

Favourite flow:
1. User taps empty map space.
2. User chooses `Drop Favourite`.
3. The app prompts for a favourite name before saving.
4. On valid save, the app persists a `favourite` waypoint row with the prompted name, updates `selectedLocation` to the saved point, and closes the prompt.
5. Later, user presses the new `Favourites` FAB, selects a favourite from the popup list, and the map pans/zooms to that waypoint using `MapConstants.defaultZoom`.
6. This goto-favourite action is camera-only; it does not update `selectedLocation` and does not replace the current persisted `marker` row.

Drive ETA flows:
1. User taps empty map space and chooses `Get driving time from Home`.
2. When the tap-action popup opens, the app captures the original tap-time ETA context by either precomputing the route-graph hit result or storing the original tap data needed to recompute it later.
3. The app resolves the hardcoded Home MGRS constant to a lat/lng origin, uses the stored tap-time ETA context to resolve the tapped destination, and shows the existing ETA loading/success/error popup behavior.
4. User taps empty map space and chooses `Get driving time from Marker`.
5. The app uses the current persisted marker/selected marker location as origin, the stored tapped snapped destination as destination, and reuses the same ETA popup contract.

Alternative flows:
- User taps a peak, track, route, route-draft control, or cluster: existing higher-priority interactions still win; the new empty-map popup must not appear.
- User taps the current marker FAB while armed: the armed state cancels without dropping a marker.
- User opens the favourites popup when no favourites exist: show an explicit empty state instead of a blank surface.

Error flows:
- User submits a blank or duplicate favourite name: keep the naming prompt open and show inline validation.
- User chooses marker-based ETA with no current marker: the chooser omits the marker-based ETA action entirely.
- If the tapped point cannot produce a qualifying snapped destination, omit both ETA actions from the chooser rather than showing actions that cannot succeed.
- ObjectBox save/delete fails: show user-facing error feedback and keep the previous persisted state intact.
</user_flows>

<requirements>
**Functional:**
1. Add a new ObjectBox entity named `Waypoints` in `./lib/models/waypoints.dart` so the ObjectBox Admin entity label also reads `Waypoints` and does not collide conceptually with existing `RouteWaypoint` models.
2. Persist `Waypoints` rows with exactly one type per row, not a list. Allowed persisted values are `home`, `marker`, and `favourite`.
3. In this slice, `home` is a reserved persisted type for a future settings-screen or click-to-set-home feature. This slice must not create, edit, or require a `home` row.
4. Store both `latitude`/`longitude` and a normalized single-line MGRS string in each waypoint row. Use a display-ready format like `55G EN 34028 50395` for persistence; multiline formatting may still be derived in UI.
5. Persist a human-readable `name` for every waypoint row.
6. Use one auto-incrementing primary key field for `Waypoints`.
7. Add a hardcoded Home constant in `./lib/core/constants.dart` using the supplied MGRS `55G EN 34028 50395`.
8. Add a `Drop Marker` FAB to the `Loc` action-rail group above `Center on marker`, using `Icons.location_pin`, tooltip `Drop Marker`, and a stable app-owned key.
9. Pressing the `Drop Marker` FAB must arm the next empty-map tap; it must not immediately place a marker at the current map center.
10. Armed mode must place or replace the current marker on the next empty-map tap, persist that row as type `marker`, update `MapProvider.selectedLocation`, and then clear armed mode.
11. Add a `Favourites` FAB to the `Loc` action-rail group below `Center on marker`, using `Icons.favorite`, tooltip `Goto Favourite`, and a stable app-owned key.
12. Pressing the `Favourites` FAB must open a popup listing persisted `Waypoints` rows where type is `favourite`.
13. Selecting a favourite must move the map to that waypoint and zoom to `MapConstants.defaultZoom`.
14. `Goto Favourite` is camera-only. It must not update `selectedLocation` and must not replace the singleton persisted `marker` row.
15. Tapping empty map space while not armed must open a tap-action popup anchored near the tap location.
16. Opening the tap-action popup must also capture the original tap-time ETA context by either:
17. storing a precomputed `RouteGraphDriveEtaHitResult`, or
18. storing the original tap screen offset, tapped `LatLng`, and enough camera/viewport context to recompute the hit deterministically when an ETA action is chosen.
19. While this popup-driven flow is active, the old immediate road-click ETA interception path must be bypassed so an eligible road tap still opens the action popup first.
20. The tap-action popup must always include these actions in this order:
21. `Drop Marker` with `Icons.my_location` and amber styling.
22. `Drop Favourite` with `Icons.favorite`.
23. If the stored tap-time ETA context resolves to a routable destination, append `Get driving time from Home` with `Icons.drive_eta`.
24. If the stored tap-time ETA context resolves to a routable destination and a current marker exists, append `Get driving time from Marker` with `Icons.drive_eta` and amber styling.
25. If the stored tap-time ETA context does not resolve to a routable destination, omit both ETA actions entirely.
26. If the tap is routable but no current marker exists, omit `Get driving time from Marker` entirely while still showing `Get driving time from Home`.
27. Choosing `Drop Marker` from the popup must place or replace the current marker at the tapped location, persist it as the single current `marker` row, update `selectedLocation`, and close the popup without recentering.
28. Choosing `Drop Favourite` from the popup must open a naming prompt before persistence.
29. The favourite naming prompt must require non-blank input, trim surrounding whitespace, reject exact duplicate names case-insensitively, and save the favourite only on success.
30. Saving a favourite must also update `selectedLocation` to the saved point so the user can immediately `Center on marker` or request marker-based ETA from that location.
31. `Waypoints` persistence must treat the current marker as a singleton logical record. A new marker drop replaces the previously persisted `marker` row instead of accumulating marker history.
32. Favourites must remain additive; saving a new favourite must not delete older favourites.
33. On map-screen initialization, if a persisted `marker` row exists, restore `selectedLocation` from it without forcing a camera move. This makes `Center on marker` meaningful after restart.
34. Reuse existing selected-location rendering; do not create a second visible marker system for the current marker.

**Error Handling:**
35. If Home MGRS cannot be resolved at runtime, fail loudly in development/tests and surface a clear user-facing ETA error in production flows rather than silently skipping the action.
36. If route-graph data, live location, or OpenRouteService fails after the user chooses an ETA action, continue using the existing drive ETA popup error contract instead of introducing a second error UI pattern.
37. If waypoint persistence fails during save or delete, show a `SnackBar` or equivalent inline feedback and leave the pre-action waypoint state unchanged.
38. If favourite deletion removes the currently selected favourite from the popup list while the popup is open, refresh the list safely and keep the UI stable.

**Edge Cases:**
39. Pressing `Escape`, tapping outside the popup, opening a higher-priority surface, or pressing the armed FAB again must cancel armed mode and dismiss the tap-action popup if visible.
40. While armed, taps on peaks, tracks, routes, route-draft controls, or other existing interactive map targets must preserve their current behavior and must not accidentally drop a marker underneath them.
41. While the tap-action popup is visible, the map must not also perform the old implicit empty-map selection action until the user chooses an action.
42. The popup must remain anchored sensibly near the tap point and clamp to the viewport, following the same general placement resilience as existing peak and ETA popups.
43. The favourites popup must handle long names, many rows, and narrow/mobile widths without overflow.
44. If no favourites exist, the favourites popup must show an explicit empty state with no crash and no broken layout.
45. If a stale or corrupted database ever contains multiple `marker` rows, use the newest/highest-id row for restore and normalize back to a single `marker` row during the next successful marker save.

**Validation:**
46. Add stable keys for every new user-visible action surface and row-level control needed by widget and robot tests.
47. Keep transient popup anchoring/UI state local to `MapScreen` where practical; persist only actual waypoint data and map-selection state.
48. Reuse existing repository/provider patterns from `PeaksBaggedRepository`, `PeakListRepository`, and `MapProvider` instead of inventing a one-off persistence layer.
49. Avoid encoding waypoint type as JSON or a comma-separated string because the clarified requirement is one role per row.
50. Avoid replacing the current `selectedLocation` marker widget or existing peak-popup `Drop a Marker on the Peak` semantics; adapt them to the new waypoint persistence contract instead.
</requirements>

<boundaries>
Edge cases:
- Armed mode is single-shot. It ends after one successful empty-map drop or an explicit cancel.
- The map-tap popup is for empty-map interactions only; it is not a generic replacement for all map click handling.
- `Get driving time from Marker` depends on a current marker/selected location. If none exists, omit the marker-based ETA action rather than guessing an origin.
- ETA actions are conditional on routable taps. A non-routable empty-map tap still opens the chooser, but only with marker/favourite actions.
- Favourite names are user-entered labels, not auto-generated map/MGRS strings in this slice.
- `home` remains a reserved waypoint type for a future settings-screen or click-to-set-home feature. This slice does not create or consume persisted `home` rows.

Error scenarios:
- Duplicate favourite name: inline validation, no save.
- Blank favourite name: inline validation, no save.
- ObjectBox write/delete failure: feedback shown, popup/dialog remains recoverable, no partial UI state committed.
- ETA origin/destination resolution failure: existing ETA error popup contract is reused.

Limits:
- Out of scope: editable Home waypoint, map-screen favourite editing/renaming, favourite grouping/filtering, import/export of waypoints, multiple saved marker history, migration of route waypoints into this entity, or broader action-rail redesign beyond the two new FABs.
- Keep the feature scoped to the main map screen; do not retrofit the peak-lists mini-map or unrelated secondary map surfaces in this slice.
</boundaries>

<implementation>
Create or modify these files:
- `./lib/models/waypoints.dart` - new ObjectBox entity, type contract, and lightweight helpers.
- `./lib/services/waypoints_repository.dart` - ObjectBox-backed storage plus test/in-memory seam following existing repository patterns.
- `./lib/providers/waypoints_provider.dart`, if a dedicated provider seam is needed for repository access and UI refresh notifications.
- `./lib/core/constants.dart` - Home MGRS constant and any narrow waypoint-related constants.
- `./lib/providers/map_provider.dart` - restore selected marker from persistence, expose narrow marker/favourite operations if provider ownership is the cleanest seam.
- `./lib/screens/map_screen.dart` - armed mode, empty-map tap popup orchestration, popup dismissal precedence, favourite selection, and ETA action dispatch.
- `./lib/screens/map_screen_panels.dart` - tap-action popup surface, favourites popup surface, favourite naming prompt widget or helper, and stable keys.
- `./lib/widgets/map_action_rail.dart` - add `Drop Marker` and `Favourites` FABs in the `Loc` group with the requested ordering.
- `./lib/services/objectbox_admin_repository.dart` - load, map, and preview `Waypoints` rows.
- `./lib/screens/objectbox_admin_screen.dart` - add delete handling for `Waypoints`.
- `./lib/screens/objectbox_admin_screen_table.dart` - add a dedicated delete key pattern for `Waypoints` rows.
- `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` - regenerate schema artifacts.

Implementation notes:
- Prefer a small dedicated waypoint repository over stuffing ObjectBox access directly into `MapScreen`.
- Keep the current amber marker sourced from `selectedLocation`; the persisted `marker` row should feed that state instead of creating parallel rendering.
- Preserve the current peak-popup `Drop a Marker on the Peak` button, but route it through the new marker persistence contract so peak drops and map drops behave consistently.
- Preserve action-rail grouping and spacing conventions from `MapActionRail`; the new buttons belong in the `Loc` group only.
- Give each new popup row and dialog control a deterministic key-first selector contract suitable for widget and robot tests.
- Store either the precomputed `RouteGraphDriveEtaHitResult` or the original tap-time data needed to recompute it later as part of the tap-action popup state; do not try to derive ETA availability from the popup-button tap itself.
- Do not implement settings-screen `home` editing or click-to-set-home behavior in this slice; only reserve the type and hardcoded constant for future follow-up work.

Recommended stable selectors:
- `Key('drop-marker-fab')`
- `Key('goto-favourite-fab')`
- `Key('map-tap-action-popup')`
- `Key('map-tap-action-drop-marker')`
- `Key('map-tap-action-drop-favourite')`
- `Key('map-tap-action-drive-home')`
- `Key('map-tap-action-drive-marker')`
- `Key('favourites-popup')`
- `Key('favourites-popup-empty')`
- `Key('favourites-popup-row-<id>')`
- `Key('favourite-name-dialog')`
- `Key('favourite-name-input')`
- `Key('favourite-name-save')`
- `Key('favourite-name-cancel')`
- `Key('objectbox-admin-waypoints-delete-<id>')`

Avoid:
- creating a second waypoint entity alongside `Waypoints`,
- persisting armed-mode UI state in ObjectBox,
- adding background migrations beyond the minimum needed to register the new entity,
- changing unrelated map click precedence for peaks, tracks, routes, or route drafting.
</implementation>

<stages>
Phase 1: Add the `Waypoints` model, repository/test seam, Home constant, and regenerated ObjectBox schema.
Verify completion by running focused model/repository tests and confirming ObjectBox Admin can load `Waypoints` rows.

Phase 2: Wire marker persistence and restoration into the map-state contract, including peak-popup marker drops and singleton marker replacement behavior.
Verify completion by proving a marker save updates `selectedLocation` without recentering and a persisted marker restores on screen load.

Phase 3: Add `Drop Marker` armed mode, empty-map tap popup, favourite naming/save flow, and favourites goto popup.
Verify completion by widget and robot tests that cover popup open/close, validation, save, selection, and action-rail ordering.

Phase 4: Route Home/Marker ETA actions through the popup and extend ObjectBox Admin delete support for `Waypoints`.
Verify completion by focused ETA widget tests plus admin delete coverage for the new entity.
</stages>

<illustrations>
Desired behavior examples:
- User arms `Drop Marker`, taps the map once, sees the amber marker move there, and can immediately use `Center on marker`.
- User taps empty map space, chooses `Drop Favourite`, enters `South Ridge Parking`, saves it, later opens `Favourites`, taps that row, and the map jumps there at default zoom.
- User taps empty map space near a routable road, chooses `Get driving time from Home`, and sees the existing ETA loading card become a success or inline error card.
- User taps a non-routable empty-map location and sees a chooser with `Drop Marker` and `Drop Favourite`, but no ETA actions.

Counter-examples to avoid:
- A plain empty-map tap still silently moves the amber marker without showing the new popup.
- Repeated marker drops accumulate multiple `marker` rows.
- A favourite is saved automatically with no prompt despite the clarified naming requirement.
- The new FAB immediately drops at map center instead of arming the next map tap.
- A routable road tap still bypasses the new chooser because the legacy immediate ETA hit-test path fires before the popup opens.
- A non-routable empty-map tap still shows ETA actions that can never succeed.
</illustrations>

<validation>
Require baseline automated coverage across logic, UI behavior, and critical user journeys.

TDD expectations:
- Follow strict vertical-slice RED -> GREEN -> REFACTOR cycles, one failing test at a time.
- Exercise public seams only: repository APIs, provider/notifier APIs, widget interactions, and robot methods.
- Prefer fakes/in-memory storage for waypoint persistence and existing fake DI seams for ETA services; mock only true external boundaries if a fake is impractical.

Behavior-first slice order:
1. Repository/model slice: saving a marker replaces the previous persisted marker; saving favourites accumulates rows; favourite name uniqueness is enforced.
2. Provider/state slice: persisted marker restoration updates `selectedLocation` on startup without moving the camera.
3. Widget slice: `MapActionRail` renders the new FABs in the correct `Loc` order with the requested tooltips and stable keys.
4. Widget slice: armed `Drop Marker` mode places a marker on the next empty-map tap and then clears armed state.
5. Widget slice: unarmed empty-map tap opens the action popup instead of immediately moving the marker.
6. Widget slice: `Drop Favourite` opens the naming prompt; blank/duplicate input is rejected; valid save succeeds.
7. Widget slice: selecting a favourite from the favourites popup requests the expected camera move but does not update `selectedLocation` or replace the persisted `marker` row.
8. Widget slice: opening the tap-action popup captures the original tap-time ETA context so later ETA actions do not depend on the popup-button tap position.
9. Widget slice: chooser contents vary correctly by tap context; non-routable taps omit ETA actions, routable taps show Home ETA, and marker ETA appears only when a current marker exists.
10. Widget slice: popup-triggered Home/Marker ETA actions reuse existing ETA loading/success/error surfaces with deterministic fake services.
11. Widget/admin slice: ObjectBox Admin shows a `Waypoints` delete icon and deleting a waypoint removes it from the backing store.

Default test split:
- `unit/service`: waypoint repository behavior, singleton marker normalization, favourite-name validation helpers, Home constant parsing helper if extracted.
- `widget`: map popup behavior, armed-mode state transitions, favourite naming dialog, favourites popup selection, camera-only goto-favourite behavior, ETA action dispatch, action-rail ordering, and ObjectBox Admin delete behavior.
- `robot`: critical map journeys that span multiple surfaces.

Robot-driven journey coverage:
- Journey 1: arm `Drop Marker` from the action rail, tap map background, confirm the marker appears and `Center on marker` remains usable.
- Journey 2: tap map background, choose `Drop Favourite`, enter a name, save, open `Favourites`, choose that favourite, confirm the map returns there, and confirm the return is camera-only without changing `selectedLocation` or the persisted current marker.

Required deterministic seams:
- in-memory waypoint storage override,
- fake live-location and OpenRouteService overrides for ETA,
- fake route-graph hit-service override for routable and non-routable taps,
- provider/container access to assert camera request state without depending on flaky visual positioning.

Required selectors/seams:
- keep using `Key('map-interaction-region')` for map input,
- add the new popup/FAB/dialog keys listed in `<implementation>`,
- reuse existing `drive-eta-popup-*` keys rather than inventing parallel ETA assertions.

Known test risks to manage explicitly:
- pointer-coordinate widget tests can be fragile; prefer keyed anchors and existing robot helpers over ad hoc pixel math where possible,
- popup anchoring near screen edges needs dedicated coverage on both wide and narrow layouts,
- ObjectBox schema generation must be kept in sync with committed generated files.
</validation>

<done_when>
The feature is complete when:
- `Waypoints` exists in ObjectBox schema and ObjectBox Admin can list and delete its rows.
- The main map has a `Drop Marker` FAB above `Center on marker` and a `Favourites` FAB below `Center on marker`.
- `Drop Marker` FAB arms the next empty-map tap instead of dropping immediately.
- Unarmed non-routable empty-map taps open an action popup with `Drop Marker` then `Drop Favourite` only.
- Unarmed routable empty-map taps open an action popup with `Drop Marker`, `Drop Favourite`, then `Get driving time from Home`, and `Get driving time from Marker` only when a current marker exists.
- Dropping a marker from either the map popup or the peak popup persists a single current `marker` row and updates the amber selected-location marker without unexpected recentering.
- Dropping a favourite prompts for a name, persists a `favourite` row on success, and rejects blank/duplicate names.
- Favourites popup lists saved favourites and selecting one pans/zooms to it at default zoom without changing `selectedLocation` or the persisted current marker.
- Home ETA uses the hardcoded Home MGRS origin and marker ETA uses the current marker origin.
- Existing peak, track, route, route-draft, and ETA popup behavior remains intact outside the new empty-map waypoint workflow.
- Automated tests cover repository logic, widget behavior, ObjectBox Admin behavior, and the critical robot journeys described above.
</done_when>
