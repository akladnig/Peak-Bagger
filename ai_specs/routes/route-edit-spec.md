<goal>
Add route editing from the saved route info panel so a user can modify an existing route without recreating it from scratch.
The edit action should reuse the current route as the draft baseline, then save changes back to the same route record.
</goal>

<background>
Flutter app using Riverpod state in `./lib/providers/map_provider.dart`, route info UI in `./lib/screens/map_screen_panels.dart`, route draft UI in `./lib/widgets/map_route_bottom_sheet.dart`, and persistence in `./lib/services/route_repository.dart`.
The current create-route flow is create-only; `saveRouteDraft()` always creates a new `Route` and `endRouteDraft()` clears the draft state.
This feature must add an edit-session source route id so the app can close the route panel while still knowing which saved route is being edited.
The edit session must restore `selectedRouteId` from `sourceRouteId` before reopening the route info panel on save or cancel.
Files to examine: `./lib/screens/map_screen_panels.dart`, `./lib/providers/map_provider.dart`, `./lib/widgets/map_route_bottom_sheet.dart`, `./lib/services/route_repository.dart`, `./lib/models/route.dart`, `./test/widget/map_screen_route_sheet_test.dart`, `./test/widget/map_route_info_panel_test.dart`, `./test/robot/map/route_info_journey_test.dart`.
</background>

<user_flows>
Primary flow:
1. User opens a saved route in the route info panel.
2. User taps the edit icon in the header.
3. The route info panel closes.
4. Route draft mode opens with the existing route name, geometry, metadata, and source route id loaded as the draft baseline.
5. User makes changes and saves.
6. The app updates the same route id, refreshes route state, and reopens the updated route info panel.

Alternative flows:
- Cancel edit: user abandons changes and the app restores the original route unchanged, then reopens the original route info panel.
- Reopen after cancel: edit should reload from the latest saved route state, not stale draft state.
- Hidden or selected route: editing should not implicitly change visibility or selection outside the normal transition into draft mode.

Error flows:
- Draft initialization fails: keep the original route view intact and avoid corrupting the selected route.
- Save fails: keep the unsaved draft state, show a recoverable edit-specific error, and leave the original route unchanged.
- Route disappears during edit: exit edit mode and clear stale selection through the existing reconciliation path.
</user_flows>

<requirements>
**Functional:**
1. Add an `icons.edit` icon button to the route info panel header, immediately left of the close button, with tooltip text `Edit Route`.
2. The edit action must only be available when a saved route is being displayed.
3. Clicking edit must close the route info panel, retain `sourceRouteId`, and enter route draft mode using the selected route as the source of truth.
4. The draft must be seeded from the existing route using the exact mapping below so the user edits the current route instead of starting from an empty draft.
5. Saving from edit mode must update the same route id instead of creating a new route record.
6. Cancelling edit must restore the original route, restore `selectedRouteId` from `sourceRouteId`, clear edit-session state, and leave the saved route unchanged.
7. After a successful save, the app must emit route revision or refresh notifications, restore `selectedRouteId` from `sourceRouteId`, clear edit-session state, and reopen the updated route info panel.
8. After cancel, the app must restore `selectedRouteId` from `sourceRouteId`, clear edit-session state, and reopen the original route info panel.

**Route-to-draft mapping:**
9. `sourceRouteId = route.id`.
10. `routeDraftName = route.name`.
11. `routeDraftColour = route.colour`.
12. `routeDraftCommittedPoints = List<LatLng>.from(route.gpxRoute)`.
13. `routeDraftMarkers = List<LatLng>.from(route.gpxRoute)`.
14. `routeDraftControlEndpoints` must be rebuilt from `route.gpxRoute` in order, using stable ids based on point index and deterministic endpoint kinds for edit entry. Seed all geometry points as manual/tapped endpoints unless a persisted waypoint explicitly marks the point as peak-derived.
15. `routeDraftDisplayMarkers` must be derived from `routeDraftControlEndpoints` with the existing display-marker rules.
16. `routeDraftStage` must start as `awaitingStart` when the route has fewer than 2 points, otherwise `awaitingNextPoint`.
17. `routeDraftPointElevations = route.gpxRouteElevations.map((value) => value?.toDouble()).toList()`.
18. `routeDraftElevationSummary` must be initialized from the saved route metrics using the saved 3D distance, ascent, descent, and elevation bounds, with request and geometry ids reset for the edit session.
19. `routeDraftElevationLoading = false` and `routeDraftElevationError = null` on entry.
20. `routeDraftRequestId = 0`, `routeDraftElevationRequestId = 0`, and `routeDraftGeometryVersion = 0` on entry.
21. `route.routeWaypoints` must be preserved only as the baseline reference for the edit session; on save, regenerate waypoints from the edited draft geometry using the existing save-builder rules.

**Error Handling:**
22. If edit setup fails, keep the original route view intact and show an `Edit Route`-specific failure message.
23. If save fails, keep the unsaved draft state and show a recoverable `Edit Route`-specific failure message instead of silently discarding changes.
24. If the route has been deleted or becomes unavailable while editing, exit edit mode, clear stale selection using the existing reconciliation path, and show a route-unavailable message.

**Edge Cases:**
25. Editing a route with an empty or trimmed-only name must still apply the existing route name validation rules before save.
26. Editing must preserve non-editable route metadata and geometry fields that are not explicitly changed by the draft.
27. Re-entering edit after cancel or save must not reuse stale draft state from the previous session.
28. The edit icon must not shift or hide the close button on narrow layouts beyond existing header overflow behavior.
29. Concurrent save/cancel taps must be ignored while a save is in flight.

**Validation:**
15. Add a unit or widget-level test slice for the edit-state initializer, save/update branching, and cancel restore behavior using deterministic fakes.
16. Add a widget test that asserts the route info panel header shows the edit icon with the correct tooltip and placement relative to the close button.
17. Add a widget or robot test that covers the full edit journey: open route, start edit, verify route info panel closes, verify draft opens with the existing route name, save, and confirm the same route id was updated.
18. Add a cancellation test that verifies abandoning edit restores the original route unchanged.
19. Require baseline automated coverage across route-edit logic, route-edit UI behavior, and the critical edit/save journey.
20. Follow vertical-slice TDD: write the smallest failing test for each behavior, implement just enough to pass, then refactor after green.
21. Keep tests deterministic by injecting route repository and map state fakes rather than depending on live persistence or network.
22. Use robot-driven coverage for the critical cross-screen journey and widget tests for the header action, cancel, and error-state edges.
</requirements>

<boundaries>
Edge cases:
- Editing while the route draft overlay is already active should be rejected or no-op rather than corrupting the current draft session.
- Editing a route that has no geometry should remain disabled or fail fast with a clear error because there is nothing meaningful to seed.
- A hidden route should still be editable from its info panel if the panel can be opened, but the edit action must not implicitly change visibility unless that is already part of the existing selection flow.

Error scenarios:
- Repository save failures: surface an error and retain unsaved draft state for retry.
- Deleted route during edit: exit edit mode and clear selection.
- Concurrent save/cancel actions: the first completed action wins; subsequent taps should be ignored while save is in flight.

Limits:
- Do not introduce a parallel route-edit storage model unless required by the current route draft architecture.
- Do not implement a second editor UI; reuse the existing route draft UI and state transitions so the behavior stays consistent with route creation.
</boundaries>

<implementation>
- Update `./lib/screens/map_screen_panels.dart` to add the edit header action and invoke the new edit entrypoint.
- Extend `./lib/providers/map_provider.dart` with `sourceRouteId`, route-edit entry/exit state, route draft seeding from an existing `Route`, and save branching that updates an existing route id when editing.
- Reuse `./lib/widgets/map_route_bottom_sheet.dart` for the edit UI; avoid a separate editor surface.
- Keep persistence in `./lib/services/route_repository.dart` unchanged unless the edit state needs a small helper for update semantics.
- Preserve route geometry, elevations, waypoints, and display cache fields when editing, unless the user explicitly changes them through the draft.
- Add or update tests under `./test/widget/` and `./test/robot/map/` to cover the edit button, draft seeding, save/update, and cancel restore paths.
</implementation>

<discovery>
Before implementation, inspect how route draft state is captured and restored in `lib/providers/map_provider.dart`, then identify the smallest set of new state fields needed to remember the source route and restore it on cancel.
Verify whether the existing route info panel header can accommodate an extra icon without layout changes on narrow widths.
Confirm which route draft tests already cover save and cancel so the new tests can extend existing slices instead of duplicating them.
</discovery>

<stages>
Phase 1: Add the route info panel edit control and a failing widget test for the header action. Verify the button appears with the correct tooltip and placement.
Phase 2: Add route-edit entry state in the map provider and a failing test for seeding the draft from an existing route. Verify the draft opens with the route name and source route data.
Phase 3: Implement save/update branching and cancel restore behavior. Verify the same route id is updated and the original route remains unchanged on cancel.
Phase 4: Add robot coverage for the full edit journey and error-path coverage for deleted-route or save-failure recovery. Verify the edit/save flow remains stable across the map shell and route panel.
</stages>

<illustrations>
Desired:
- Route info panel shows an edit icon left of close, tooltip `Edit Route`.
- Clicking edit closes the panel and opens the route draft with the selected route already loaded.
- Saving an edited route updates the same saved route record.

Avoid:
- Clicking edit starting a blank route draft.
- Saving edit as a brand-new route copy.
- Clearing or mutating the original route when the user cancels.
</illustrations>

<validation>
- Use vertical-slice TDD for each behavior: write one failing test, implement the smallest change, confirm green, then move to the next slice.
- Required test split: robot tests for the critical open-edit-save journey; widget tests for the route panel header, cancel, and error edges; unit tests for route-edit state transitions and save/update branching.
- Required seams: inject route repository fakes, avoid time-dependent logic in edit state transitions, and keep route-draft seeding deterministic from the selected route object.
- Baseline automated coverage outcomes:
  - Logic/business rules: edit-entry state, save/update branching, cancel restore, stale-route reconciliation.
  - UI behavior: header action visibility, tooltip, panel close transition, draft prefill.
  - Critical journey: open route, edit, save, and observe the same route updated end-to-end.
- Add explicit assertions that the original route record remains unchanged after cancel and that the persisted id remains stable after save.
- Add explicit assertions that the route info panel reopens after save and after cancel, with the correct route context each time.
- Report any residual risk if route geometry editing or route-draft restoration cannot be fully covered with deterministic tests.
</validation>

<done_when>
- The route info panel has an `Edit Route` icon button in the correct position.
- Clicking edit closes the route info panel and opens route draft mode seeded from the selected route.
- Saving edits updates the same route record and refreshes the route view.
- Cancelling edits restores the original route with no persisted changes.
- Tests cover header rendering, cancel/save behavior, and the cross-screen edit journey.
</done_when>
