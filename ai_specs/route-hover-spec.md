<goal>
Add hover affordances to route-creation markers in the map route draft flow.
When a user moves the mouse over a draft route marker, the marker should highlight visually without changing route geometry, numbering, save behavior, or export behavior.
This helps desktop users see which route point is active before they click or continue drafting.
</goal>

<background>
The app is a Flutter/Riverpod map application.
Route draft markers are built in `./lib/screens/map_screen_layers.dart` from `RouteDraftDisplayMarker` and rendered by `./lib/widgets/route_marker.dart`.
Route visual constants live in `./lib/core/constants.dart` under `RouteUI`.
Route drafting state already lives in `./lib/providers/map_provider.dart`.
This change must not affect the existing persisted route hover/select flow or the route info panel.
Relevant tests already exist in `./test/widget/route_marker_test.dart`, `./test/widget/route_marker_layer_test.dart`, `./test/widget/map_screen_route_sheet_test.dart`, and `./test/robot/map/map_route_journey_test.dart`.
</background>

<discovery>
Verify how the current route draft marker rendering path can expose hover state with the smallest possible seam.
Confirm whether hover can stay local to the marker widgets or whether the map layer needs a provider-backed hover field.
Check pointer-exit and draft-end cleanup so hover styling cannot remain stale.
</discovery>

<user_flows>
Primary flow:
1. User enters route drafting and adds draft markers.
2. User moves the mouse over a draft marker on the map.
3. The hovered marker shows the hover visual without changing the draft geometry.
4. User moves away or hovers a different marker, and the highlight updates or clears.
5. While route drafting is active, draft-marker hover suppresses the existing persisted-route hover/select handling.

Alternative flows:
- Hovering a numbered marker keeps the label visible while scaling the whole marker.
- Hovering the first circle marker or final target marker uses the same hover rules as other draft markers.
- On touch-only input, the route draft still works normally but no hover affordance appears.

Error flows:
- Pointer exit or pointer cancel clears the hover visual.
- Ending the route draft clears any hover visual automatically.
- If no draft marker is under the pointer, the normal marker rendering stays unchanged.
</user_flows>

<requirements>
**Functional:**
1. Add `RouteUI.markerZoom = 1.2` to `./lib/core/constants.dart` and use it as the scaling factor for hovered draft markers.
2. Add a small hover-aware route-draft marker seam in `./lib/widgets/route_marker.dart` or a companion widget so hover state changes only presentation, not geometry.
3. When a draft marker is hovered, render the hover shell as the existing circle visual at `RouteUI.markerNumberedSize` and apply `RouteUI.markerZoom` to both the outer `Marker` dimensions/hitbox and the inner `RouteMarker` visual.
4. When a numbered draft marker is hovered, keep the numeric label visible while scaling both the marker container and the child visual by `RouteUI.markerZoom`.
5. When a circle or target draft marker is hovered, keep its existing visual style and scale both the marker container and the child visual by `RouteUI.markerZoom`.
6. Route hover visuals apply only while route drafting is active in `./lib/screens/map_screen_layers.dart`; saved route polylines and the existing persisted-route hover/click flow must remain unchanged outside drafting.
7. Add stable app-owned keys for the hovered marker state, such as `route-draft-marker-<id>`, `route-draft-marker-hitbox-<id>`, and `route-draft-marker-hover-<id>`, so tests can assert hover rendering deterministically.

**Error Handling:**
8. Clear hover state on pointer exit, pointer cancel, and when route drafting ends.
9. If the pointer is touch-only or not actually over a draft marker, render the normal marker without side effects.
10. Hover state changes must not mutate route geometry, numbering, selection state, persistence, or export behavior.

**Edge Cases:**
11. The first draft marker and the final draft marker use the same hover rules as intermediate markers.
12. Rapid hover enter/exit during panning must not leave a stale hover highlight behind.
13. Narrow-screen route sheet layout and existing route save behavior must remain unchanged.
</requirements>

<boundaries>
Edge cases:
- This spec only covers route-creation markers, not the existing persisted-route hover/select feature.
- Touch devices should not synthesize hover state.
- Do not change marker numbering, marker order, or route draft geometry.

Error scenarios:
- Pointer exit, pointer cancel, or draft teardown must clear the hover visual.
- Missing draft markers must be a no-op.
- A failed route save must behave exactly as it does today; hover state is not part of save recovery.

Limits:
- Do not add a new route mode or a persisted hover field.
- Do not change route storage, export, or route-planning behavior.
- Do not alter track, peak, or persisted route hover behavior as part of this slice.
</boundaries>

<implementation>
Files expected to change:
- `./lib/core/constants.dart`
- `./lib/widgets/route_marker.dart`
- `./lib/screens/map_screen_layers.dart`
- `./test/widget/route_marker_test.dart`
- `./test/widget/route_marker_layer_test.dart`
- `./test/robot/map/map_route_journey_test.dart`

Preferred approach:
- Keep the hover seam as small and local as possible.
- Prefer a marker-local hover widget or wrapper over expanding provider state unless a testability gap makes that impossible.
- Reuse the existing circle rendering for the hover shell instead of inventing a new visual language.
- Keep selectors key-first and app-owned.

Avoid:
- Avoid mutating draft geometry or route mode in response to hover.
- Avoid changing persisted route hover/select code paths.
- Avoid introducing additional route-draft state that is only needed for hover visuals.
</implementation>

<validation>
Use TDD slices in this order:
1. Add a failing widget test for hovered numbered-marker scaling and label preservation.
2. Add a failing widget test for the circle hover shell size and style.
3. Add a failing widget or robot test for pointer enter/exit cleanup on a draft marker.
4. Add a failing robot journey for create draft -> hover marker -> verify hover affordance with stable keys.

Expected coverage outcomes:
- UI behavior: hovered markers render the correct shell, size, and label behavior.
- Critical journey: a desktop hover path on the route draft screen is covered end to end.
- Unit tests: only for any shared size or hover-flag helper that is extracted and reused.

Required seams:
- Stable keys for the marker root and hover state.
- A deterministic way to drive pointer hover in tests.
- No dependency on private widget internals.

Test split:
- Widget tests: hover render state, size scaling, label preservation, and cleanup.
- Robot tests: the route-draft hover journey on a desktop-sized surface.
- Unit tests: only any extracted shared size/flag helper.
</validation>

<stages>
Phase 1: Add the hover scaling constant and the marker rendering seam, then verify the rendered widget shape.
Phase 2: Wire hover enter/exit into the route draft marker layer and verify cleanup behavior.
Phase 3: Add widget tests for the hover visuals and label preservation.
Phase 4: Add the robot hover journey and verify the stable keys.
</stages>

<done_when>
Draft route markers visually highlight on mouse hover.
Hovered numbered markers keep their label and scale by `RouteUI.markerZoom`.
Hovered circle and target markers use the existing circle-style hover shell and scale by `RouteUI.markerZoom`.
Touch input, route saving, and existing persisted-route hover behavior remain unchanged.
The required automated tests pass.
</done_when>
