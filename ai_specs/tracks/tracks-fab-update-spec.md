<goal>
Update the map rail so the current track control becomes `Show Tracks/Routes (T)` and opens a right-side drawer with independent switches for tracks and routes.
The app must remember both visibility choices in SharedPreferences, render track and route overlays from those choices after restart, and persist newly created routes so the routes toggle controls real app data rather than fixture-only records.
This matters because users need a quick way to declutter the map, compare imported tracks with saved routes, and trust that their visibility preferences survive startup, import, and reload flows.
</goal>

<background>
Flutter app using Riverpod, ObjectBox, `flutter_map`, and `shared_preferences`.
Current map visibility is track-only: `MapState.showTracks` drives the track polyline layer, `MapNotifier.toggleTracks()` flips that state, and `LogicalKeyboardKey.keyT` currently toggles tracks directly.
Route data uses the existing persisted `Route` entity in `./lib/models/route.dart`, but the map has no route visibility state or route overlay toggle yet, and the current route-draft flow does not persist saved routes into ObjectBox for map display. This slice is the app's first non-admin route read/write integration.
The app already uses right-side end drawers for basemaps and peak lists, so this slice should follow that pattern instead of inventing a new surface.
Route overlays must read from a dedicated route repository/provider seam and a lightweight revision signal so map rendering stays decoupled from ObjectBox internals and refreshes deterministically after route changes.
`Route` collides with Flutter's `material.dart` type name, so any file importing both Flutter route types and the model must use a repo-style package import alias such as `import 'package:peak_bagger/models/route.dart' as app_route;` and reference `app_route.Route` explicitly.

Files to examine:
- `./lib/core/constants.dart`
- `./lib/providers/map_provider.dart`
- `./lib/providers/peak_list_selection_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_layers.dart`
- `./lib/widgets/map_action_rail.dart`
- `./lib/widgets/map_basemaps_drawer.dart`
- `./lib/widgets/map_peak_lists_drawer.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`
- `./lib/models/route.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/track_display_cache_builder.dart`
- `./test/harness/test_map_notifier.dart`
- `./test/widget/map_screen_route_sheet_test.dart`
- `./test/robot/gpx_tracks/recovery_robot.dart`
- `./test/robot/gpx_tracks/selection_journey_test.dart`
- `./test/gpx_track_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `./test/widget/map_screen_keyboard_test.dart`
- `./test/widget/gpx_tracks_recovery_test.dart`
- `./test/widget/map_action_rail_grouping_test.dart`
</background>

<user_flows>
Primary flow:
1. User taps the `Show Tracks/Routes (T)` control or presses `T` on the keyboard.
2. The right-side tracks/routes drawer opens.
3. The drawer shows `Show Tracks` and `Show Routes` with leading switches.
4. User toggles either switch independently.
5. The map updates immediately.
6. User sees the existing `Snap to Trail` and `Straight Line` buttons in the route sheet.
7. For this slice, those buttons remain visible, remain mutually selectable, and affect only local visual mode selection; they do not change saved route geometry.
8. User creates a new route from the existing draft flow and saves it.
9. The saved route becomes available to the routes toggle and appears on the map when `Show Routes` is enabled.
10. After app restart, the visibility combination is restored.

Alternative flows:
- User enables tracks only, routes only, both, or neither; all four combinations are valid.
- User reopens the drawer later and sees the persisted switch positions.
- User opens basemaps or peak lists instead; those drawers must continue to work unchanged.
- User starts with no tracks or no routes loaded; the relevant switch is disabled, but the drawer still opens.
- User has a stored preference of `Show Routes = true` before any routes exist; when a route is later saved, that route appears without silently rewriting the preference.

Error flows:
- If SharedPreferences cannot be read or written, the app falls back to default visibility for the current session and keeps the map usable.
- If the route cache for a stored route is missing or invalid, render from the stored raw route geometry instead of hiding the route.
- If tracks are in the existing loading/recovery-disabled state, the tracks switch remains disabled until the state is healthy again.
- If route save fails, no phantom route is created, no false revision increment occurs, and the app surfaces save failure feedback while preserving the draft.
</user_flows>

<requirements>
**Functional:**
1. Rename the rail action text, tooltip, and semantics to `Show Tracks/Routes (T)`.
2. Keep the existing stable button key `show-tracks-fab` so current robot and widget selectors do not break.
3. Tapping the rail action or pressing `T` must open the tracks/routes drawer instead of directly toggling track visibility.
4. Add an explicit end-drawer mode for tracks/routes and render it from `MapScreen` alongside the existing basemaps and peak lists drawers.
5. The drawer must show two rows, in this order: `Show Tracks`, then `Show Routes`.
6. Each row must use a leading switch and reflect live visibility state.
7. Tracks and routes must be independent booleans; the valid states are tracks on/routes off, tracks off/routes on, both on, and both off.
8. Add `showRoutes` to `MapState`, update notifier methods to change both visibility flags, and keep the existing `showTracks` semantics for clearing selected/hovered track state when tracks are turned off.
9. Persist `showTracks` and `showRoutes` separately in SharedPreferences by writing immediately from the notifier when either switch changes.
10. Missing prefs must default both toggles to `false`.
11. The startup chain must restore stored visibility preferences before `_loadTracks()` or any route dataset mutation is allowed to rewrite visibility.
12. Startup, import, and reload flows must respect the stored visibility preference even when tracks or routes exist; user preference always wins, and visibility must not be auto-enabled from loaded data.
13. If a user changes a visibility toggle before prefs restore completes, that first user-initiated toggle wins and supersedes any pending restore result for that flag.
14. Only user-initiated visibility toggle methods and explicit reveal/focus commands may mutate `showTracks` or `showRoutes`. Startup track load, import/rescan, selective import, delete-to-empty flows, and recovery/reset helpers may update datasets, loading flags, disabled-state reasons, and selection cleanup, but must not rewrite visibility flags.
15. If a stored visibility preference is `true` while the corresponding dataset is empty or unavailable, keep the stored preference as `true`; render no overlay and show the disabled state instead of resetting the preference.
16. Deleting the last visible track or route may leave no overlay rendered because the dataset is empty, but it must not rewrite the stored visibility preference unless the user explicitly toggled that layer off.
17. A brief first-frame default visibility state before prefs restore completes is acceptable, provided restored prefs settle deterministically before any later dataset-driven mutation can override them.
18. Render track overlays only when `showTracks` is true.
19. Render route overlays only when `showRoutes` is true.
20. Route overlays must be built from persisted `Route` entities accessed through the route repository/provider seam and their cached zoomed point data, using the same zoom-aware lookup pattern as tracks.
21. Overlay rendering must use the stored route color value via `Color(route.colour)` and use `RouteUI.width` from `./lib/core/constants.dart`, where `RouteUI.width = 1.0`.
22. Persisted routes must render below persisted track polylines so tracks remain the primary comparison surface. Route-draft markers remain above both persisted routes and persisted tracks.
23. A route draft is valid only when it has at least 2 route draft markers and a non-blank trimmed route name.
24. The route name cannot be blank. When the route name field is blank or whitespace-only, the route sheet must show the inline error text `A Route name must be entered` immediately under the text box.
25. The route save action must remain disabled until the draft is valid.
26. `MapNotifier.saveRouteDraft()` must own route-draft validation, persistence, revision bumping, post-save cleanup, and route-save failure signaling for this slice.
27. Newly created routes must default to red on initial save and persist that red value into `Route.colour`.
28. Saving a new route must persist raw geometry through the `gpxRouteJson` / `gpxRoute` accessor contract, build `displayRoutePointsByZoom` from `routeDraftMarkers` in draft order, and store both the raw route geometry and the display cache on the persisted route.
29. If cached route display data is absent or invalid for an existing route, route rendering must attempt cache-based geometry first, then fall back to raw `gpxRoute`, and only skip the route when both are unusable. Raw fallback must render as a single segment: `[route.gpxRoute]`.
30. Routes must use the same cache JSON shape and the same `MapConstants.trackMinZoom..trackMaxZoom` range as tracks.
31. Route statistics such as `distance2d`, `distance3d`, `ascent`, `descent`, `startElevation`, `endElevation`, `lowestElevation`, and `highestElevation` are out of scope for this slice and may remain at existing default values until a future enhancement introduces `trip_routing`-based route generation and statistics.
32. The route repository/provider seam is production behavior, not a test-fixture-only seam; it must support real saved routes created in the app.
33. Turning one switch off must not mutate the other switch.
34. The drawer should stay open while the user toggles switches so they can change both settings in one visit.
35. For this slice, the existing `Snap to Trail` and `Straight Line` route-mode buttons remain visible and mutually selectable but are functional no-ops; both modes persist the same marker-order polyline until real routing is added later.

**Error Handling:**
36. Keep the tracks switch disabled when track data is unavailable, still loading, or in the existing recovery-disabled state.
37. Keep the routes switch disabled when there are no route entities.
38. SharedPreferences failures must be best-effort only; the map must keep working with in-memory defaults.
39. If route loading fails, keep route visibility untouched and fall back to raw route geometry whenever cached data is unavailable but raw route geometry still exists.
40. If route save fails, leave the in-progress route draft behavior intact, keep the route sheet open, do not increment route revision, and show save failure feedback via a snackbar without corrupting visibility preferences.

**Edge Cases:**
41. The tracks/routes drawer must work when only one of the two data sets exists.
42. The tracks/routes control should remain tappable even when one or both switches are disabled, so users can still open the drawer.
43. Disabled switches must still reflect the stored preference value; disabling interaction must not silently clear user intent.
44. A stored `Show Routes = true` state while no routes currently exist is a restore-only scenario. Users must not be able to newly enable routes while the routes switch is disabled, but a previously stored `true` preference must remain visible and take effect automatically once routes become available again.
45. A stored `Show Tracks = true` state while no tracks currently exist is also a restore-only scenario. Users must not lose the stored `true` preference merely because startup, import, delete, or recovery flows leave the track dataset empty or unavailable.
46. The route availability provider must distinguish these states explicitly: `empty` and `available`.
47. Track availability must distinguish these states explicitly: `loading`, `recoveryDisabled`, `empty`, and `available`, derived from existing `tracks`, `isLoadingTracks`, and `hasTrackRecoveryIssue` state.
48. When a switch is disabled, the drawer must show concise helper text for the reason. Required strings for this slice are: `Loading tracks...`, `Tracks unavailable during recovery`, `No tracks loaded`, and `No routes available`.
49. Each drawer row must use the existing drawer/ListTile visual pattern: a single row with the leading switch and title, and helper text rendered as that row's subtitle directly below the title. If both switches are disabled, both subtitles may be visible at the same time.
50. Whole-row tap on an enabled row must toggle the same value as tapping the switch. Disabled rows remain non-interactive.
51. The drawer must scroll on short viewports instead of clipping controls.
52. Existing basemap and peak-list drawer behavior, map selection behavior, and keyboard shortcuts other than `T` must remain unchanged.
53. The FAB behavior change is intentional: `show-tracks-fab` remains tappable even when tracks or routes are unavailable, because it now opens the drawer instead of directly toggling the layer. Existing tests that assert a disabled FAB in empty/loading/recovery states must be updated rather than preserved.

**Validation:**
54. Require baseline automated coverage for logic/state, drawer UI, map overlay behavior, route save/load behavior, and the critical open/toggle/restore journey.
55. Use deterministic seams for prefs and route data so tests do not depend on real storage.
56. Robot coverage must verify the `T` shortcut, drawer open, both switches, route save visibility, and layer restoration after a restart.
57. Keep stable selectors for the new surface: `Key('tracks-routes-drawer')`, `Key('show-tracks-switch')`, and `Key('show-routes-switch')`.
</requirements>

<boundaries>
Edge cases:
- The user can turn both layers off; that is a valid state, not an error.
- Missing route caches should fall back to raw stored route geometry for that route whenever raw geometry is still present.
- The tracks switch should preserve the existing hide-selection behavior when turning tracks off.
- The routes switch should not clear tracks or selection state.
- A disabled switch reflects stored user intent even when no overlay is currently visible.

Error scenarios:
- Read/write prefs failures must not block the drawer or crash the map.
- An empty route or track collection should disable only the affected switch, not the entire control surface.
- Route save failure must not create a phantom route entry or a false revision increment.
- A blank route name must keep the route sheet open, show `A Route name must be entered`, and block save.

Limits:
- Do not add a combined tri-state visibility model; keep tracks and routes separate.
- Do not change basemap or peak-list behavior.
- Do not remove the existing `show-tracks-fab` selector.
- Do not make the `T` shortcut toggle tracks directly after this slice; it should open the drawer.
- Do not let startup, import, or reload logic override persisted visibility preferences.
- Do not broaden this into route editing UI beyond the persistence wiring required to save newly created routes and display them.
</boundaries>

<implementation>
1. Update `./lib/providers/map_provider.dart` to add `showRoutes`, persistence keys, load/save helpers, and notifier methods for tracks/routes visibility.
2. Use the same map-local provider pattern as the existing track repository rather than shell bootstrap overrides: define the route repository provider next to map/provider code and default it directly from `objectboxStore`, while still allowing tests to override it.
3. Match the repo's current feature-local loader-provider pattern for prefs. Add a local loader provider in `./lib/providers/map_provider.dart` or an adjacent map-specific provider file rather than introducing a shared global preferences provider, so SharedPreferences access can be overridden in tests and read/write failure behavior can be simulated deterministically.
4. Add `./lib/services/route_repository.dart` and `./lib/providers/route_repository_provider.dart` as the route read seam. `RouteRepository` must mirror the existing repository pattern used elsewhere in the repo: storage abstraction, ObjectBox-backed implementation, and writable in-memory test storage. It must own ObjectBox reads and writes for `Route`, expose a synchronous API suitable for current ObjectBox-backed reads, and be wired through `routeRepositoryProvider`.
5. Add a derived route list provider and a derived route-availability provider near the route repository seam. Both providers must watch `routeRevisionProvider`. The route list provider is the source of route entities for `MapScreen`; the route-availability provider exposes current routes and whether routes are available. For this slice, route availability is `available` when the route list is non-empty and `empty` when it is empty.
6. Narrow `routeRevisionProvider` semantics to every route collection mutation implemented in this slice: successful route create/save and any explicit route collection replacement/reset path introduced here. Update/delete/reimport revision semantics are follow-up work unless they are newly implemented here.
7. Add a dedicated startup restore gate in the map-provider startup chain. The stored visibility preferences must be restored before `_loadTracks()` runs, and these existing mutation classes must stop rewriting visibility except where explicitly allowed: startup track load, import/rescan, selective import, delete-to-empty, and recovery/reset helpers.
8. Update `./lib/screens/map_screen.dart` to add the tracks/routes drawer to `endDrawer`, change the `T` keyboard handler to open the drawer, and render the route overlay when `showRoutes` is true. Keep visibility flags in `MapState`, keep route entities out of `MapState`, and have `MapScreen` read route data and route availability from the dedicated route providers.
9. Route polyline construction must follow the existing layer-helper pattern in `./lib/screens/map_screen_layers.dart`, beside the current track polyline helper, rather than expanding raw layer-building logic inline in `MapScreen`.
10. Add `MapNotifier.saveRouteDraft()` as the single owner of route-draft validation, persistence, revision bumping, post-save cleanup, and save-failure signaling. `MapState` must hold the minimum UI state the route sheet needs for this flow, including `isSavingRoute` and `routeDraftNameError`.
11. Define the route repository save contract explicitly: `RouteRepository.saveRoute(Route route)` must assign a stable ID on create, preserve ID on update, return the saved route with that ID populated, and throw on failure. `MapNotifier.saveRouteDraft()` catches failures, queues snackbar feedback, and only bumps `routeRevisionProvider` after a successful save.
12. Add a consumable route-save snackbar message seam and consume it in `./lib/screens/map_screen.dart`, so save failures raised by `MapNotifier.saveRouteDraft()` can be shown without requiring router-level wiring for this slice.
13. Update `./lib/widgets/map_route_bottom_sheet.dart` to call `MapNotifier.saveRouteDraft()` for save, render the inline route-name validation state from `MapState`, keep the existing `Snap to Trail` and `Straight Line` buttons visible and mutually selectable as no-ops for this slice, and rely on snackbar feedback for repository save failures.
14. On successful route save, close the sheet, clear draft state, exit route-drafting mode, restore map focus, keep camera/selection unchanged, and show no success snackbar.
15. Update `./lib/widgets/map_action_rail.dart` so the rail action opens the drawer and uses the new `Show Tracks/Routes (T)` copy.
16. Add `./lib/widgets/map_tracks_routes_drawer.dart` for the new drawer surface, modeled after the existing basemap and peak-list drawers.
17. Update `./lib/models/route.dart` to add the small zoom-cache helper needed to mirror the track lookup pattern. Reuse the track-model cache parsing pattern to define invalid cache data: if decode fails or required zoom data cannot be read, fall back to raw route geometry.
18. Update `./lib/core/constants.dart` to add `RouteUI` and define `RouteUI.width = 1.0` as the stable route stroke-width source of truth for this slice.
19. Update `./test/harness/test_map_notifier.dart` so widget tests can seed independent tracks/routes visibility and track data states.
20. Files to create: `./lib/services/route_repository.dart`, `./lib/providers/route_repository_provider.dart`, and `./lib/widgets/map_tracks_routes_drawer.dart`.
21. Files to update: `./lib/core/constants.dart`, `./lib/models/route.dart`, `./lib/providers/map_provider.dart`, `./lib/screens/map_screen.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/widgets/map_action_rail.dart`, `./lib/widgets/map_route_bottom_sheet.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/widget/gpx_tracks_recovery_test.dart`, `./test/widget/map_action_rail_grouping_test.dart`, `./test/widget/map_screen_route_sheet_test.dart`, `./test/robot/gpx_tracks/recovery_robot.dart`, `./test/robot/gpx_tracks/selection_journey_test.dart`, `./test/robot/gpx_tracks/gpx_tracks_robot.dart`, `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`, and `./test/gpx_track_test.dart`.
22. Add a short testing design seam before widget/robot work: the harness must gain independent tracks/routes visibility state, route repository overrides, local prefs loader overrides, route availability overrides, route save-state overrides, snackbar-message consumption hooks, and drawer-open helpers so tests can assert the new behavior cleanly.
23. Expand the impacted test surface beyond the initially named files: update all suites that currently depend on direct `show-tracks-fab`/`T` toggling or automatic `showTracks` mutation from import/delete helpers.
24. Preserve the existing explicit reveal behavior for `showTrack()`-style commands by allowing those commands to force in-memory visibility on for the relevant layer without rewriting the stored drawer preference. Apply the same rule to any route reveal command added in this slice.
25. Avoid changing the map selection or peak-search flows unless a visible regression forces a narrow fix beyond the required route-save persistence wiring.
</implementation>

<stages>
Phase 1: State and drawer plumbing
1. Add `showRoutes`, the feature-local prefs seam, SharedPreferences persistence, the new drawer mode, the route availability provider, and the explicit startup ordering.
2. Verify the drawer opens from both the rail action and `T`.
3. Verify the drawer shows the two switches, helper text, disabled reasons, and stored state.

Phase 2: Route persistence and rendering
1. Add or wire the route-data seam and route revision flow.
2. Persist a newly saved drafted route with default red color, required non-blank name, and a built route display cache.
3. Render route overlays only when `showRoutes` is true, falling back to raw stored route geometry if cached display data is absent.
4. Verify track visibility still behaves as before when its switch changes.

Phase 3: Test and polish
1. Update widget, robot, and harness coverage.
2. Verify restart persistence for both switches.
3. Run the relevant Flutter tests and fix regressions before finishing.
</stages>

<illustrations>
Desired:
1. Tap `Show Tracks/Routes (T)` -> drawer opens -> turn on tracks and routes independently.
2. Enable tracks only -> only track polylines remain visible.
3. Enable routes only -> only route polylines remain visible.
4. Reopen after restart -> the same combination is restored.
5. Save a new route -> the route is persisted with red `Route.colour` and appears when routes are visible.
6. Route polylines render using stored `Route.colour` and `RouteUI.width = 1.0`.
7. Leave the route name blank -> save stays blocked and the field shows `A Route name must be entered`.

Undesired:
1. `T` toggles tracks directly without opening the drawer.
2. Turning routes on also turns tracks on.
3. Missing prefs crash the map or reset the drawer to an unexpected mixed state.
4. Saving a route creates stored route data but the routes toggle cannot ever surface it.
</illustrations>

<validation>
1. Unit tests should cover any pure route-selection or persistence helper, including missing-pref fallback behavior, route zoom-cache lookup, raw-geometry fallback, and startup-order normalization.
2. Widget tests should prove the tracks/routes drawer opens, scrolls on short viewports, and updates `MapState` without closing on every switch tap.
3. Widget tests should prove the track switch still clears selected/hovered track state when turned off.
4. Widget tests should prove disabled switches retain their stored values and show the correct helper reason.
5. Widget tests should prove the route switch only affects route overlays, that newly saved routes persist red `Route.colour` by default, and that blank route names show `A Route name must be entered` and block save.
6. Widget tests should prove route save failures surface via the consumable snackbar-message seam while leaving the sheet open.
7. Robot tests should use the stable drawer/switch keys and verify the keyboard `T` path as well as the tap path.
8. Include repository/provider tests for the RouteRepository abstraction, the route list provider, and the route availability provider, including create/read/update/delete coverage at the repository layer with writable test storage, stable ID assignment on create, preserved ID on update, and narrowed revision behavior only for create/save and any replacement/reset path added in this slice.
9. Include a restart/fresh-repository test proving a saved route survives reload through the persisted `gpxRouteJson` / `gpxRoute` contract.
</validation>

<done_when>
The slice is complete when the map rail reads `Show Tracks/Routes (T)`, the `T` shortcut opens a drawer with independent tracks/routes switches, both visibility choices persist across restarts, new routes are actually saved and discoverable through the routes layer, route overlays render from stored `Route.colour`, and the updated widget and robot coverage passes.
</done_when>
