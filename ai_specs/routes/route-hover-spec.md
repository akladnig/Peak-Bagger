<goal>
Add hover affordances to route creation in the map route draft flow.
When a user moves the mouse over a draft route marker, the marker should highlight visually without changing route geometry, numbering, save behavior, or export behavior.
This is the baseline behavior, and the enhancement also shows a movable placement marker when hovering the route, with cursor tracking and click-to-commit target placement.
</goal>

<background>
The app is a Flutter/Riverpod map application.
Route placement markers are built in `./lib/screens/map_screen_layers.dart` from `RouteDraftDisplayMarker` and rendered by `./lib/widgets/route_marker.dart`.
Route visual constants live in `./lib/core/constants.dart` under `RouteUI`.
Route drafting state already lives in `./lib/providers/map_provider.dart`.
This change extends the existing draft-marker hover highlight and must not affect the existing persisted route hover/select flow or the route info panel.
Relevant tests already exist in `./test/widget/route_marker_test.dart`, `./test/widget/route_marker_layer_test.dart`, `./test/widget/map_screen_route_hover_test.dart`, and `./test/robot/map/map_route_journey_test.dart`.
</background>

<baseline>
The existing behavior stays in place: when a user moves the mouse over a draft route marker, the marker should highlight visually without changing route geometry, numbering, save behavior, or export behavior.
</baseline>

<enhancement>
The new behavior adds a movable placement marker when hovering the route, with cursor tracking and click-to-commit numbered-marker placement.
</enhancement>

<decisions>
1. Hover placement is transient preview state, separate from committed draft markers.
2. The preview comes from a draft-only segment hover detector that projects onto the rendered committed draft route path, not a straight marker-to-marker chord.
3. The preview marker is visual-only; pointer-up on the map performs the insert-into-segment transition and turns the preview point into a committed numbered marker.
4. The preview must not handle commit itself or cause a second insert.
5. The preview clears on pointer exit, pointer cancel, draft end, and after insert commit.
6. After an insert, subsequent route clicks continue from the last committed endpoint, not from the inserted preview point.
7. The inserted point becomes a real committed route point in the draft chain and is included in saved route geometry.
8. The inserted preview point is spliced into the ordered draft point list at the hovered segment position, and marker numbering is recomputed from list order.
9. On insert, the point becomes a numbered marker: if no numbered markers exist yet, assign `1`; otherwise assign the next number from the start of the hovered segment and renumber subsequent numbered markers to preserve ordered numbering.
10. When a committed draft route segment contains intermediate geometry between control markers, hover and insert must follow that visible geometry and remember which committed polyline segment was actually hit.
</decisions>

<discovery>
Verify how the current route draft marker rendering path can expose a movable hover-placement state with the smallest possible seam.
Confirm whether hover can stay local to the marker widgets or whether the map layer needs a provider-backed hover field for cursor tracking.
Check how a draft-only segment hover detector can project a point onto the rendered committed route path and how click-up inserts that projected point into the draft.
Check pointer-exit, pointer-cancel, route-click commit, and draft-end cleanup so the hover placement cannot remain stale.
</discovery>

<user_flows>
Primary flow:
1. User enters route drafting.
2. User moves the mouse over a draft route marker or a draft route segment.
3. The marker highlights visually without changing route geometry, numbering, save behavior, or export behavior.
4. As an enhancement, a movable placement marker appears on the hovered route path, using the circle style and numbered marker size.
5. The cursor changes to a pointing finger while the pointer remains over the route.
6. As the cursor moves, the placement marker tracks the nearest point on the visible route path.
7. User clicks the placement marker, which inserts it into the route segment and changes it to a numbered marker.

Alternative flows:
- Hovering a numbered marker keeps the label visible while the placement-marker behavior remains unchanged.
- Hovering the first circle marker or final target marker uses the same hover rules as other draft markers.
- On touch-only input, the route draft still works normally but no hover affordance appears.

Error flows:
- Pointer exit or pointer cancel clears the hover placement visual.
- Ending the route draft clears any hover placement visual automatically.
- If the pointer is not over the route, the normal marker rendering stays unchanged.
</user_flows>

<requirements>
**Functional:**
1. Use the existing `RouteUI.markerZoom = 1.2` constant in `./lib/core/constants.dart` for hover placement marker sizing.
2. Add a draft-only segment hover detector that projects the nearest point on the rendered committed draft route path and reports enough state to render a cursor-tracking placement marker.
3. Keep hover placement as transient preview state, separate from the committed routeDraftDisplayMarkers and routeDraftMarkers collections.
4. Add a hover-aware route-placement seam in `./lib/widgets/route_marker.dart` or a companion widget so hover state changes only presentation, not route geometry.
5. When the pointer is over a draft route segment during drafting, render a movable placement marker using the existing circle style and `RouteUI.markerNumberedSize` dimensions.
6. While hovered, keep the cursor as a pointing finger and move the placement marker with the cursor.
7. When the map receives pointer-up while a placement preview is active, insert the preview point into the current draft segment and render it as a numbered marker; the preview marker itself does not commit.
8. Route hover visuals apply only while route drafting is active in `./lib/screens/map_screen_layers.dart`; saved route polylines and the existing persisted-route hover/click flow must remain unchanged outside drafting.
9. Reuse the existing stable app-owned marker keys for hovered draft markers, and add a stable key for the draft segment hover preview such as `route-draft-segment-hover-<id>`, so tests can assert hover rendering deterministically.
10. After an insert, route drafting continues from the last committed endpoint for the next hover/click cycle, not from the inserted preview point.
11. Insertion preserves the original segment endpoints around the preview point; numbering is derived from the resulting ordered draft chain.
12. If no numbered markers exist when a point is inserted, assign the inserted marker number `1`.
13. If numbered markers already exist when a point is inserted, assign the inserted marker the next number from the start of the hovered segment and renumber subsequent numbered markers so numbering remains contiguous and ordered.
14. If the visible committed route path contains intermediate geometry between control markers, hover detection and preview placement must stay centered on that visible path, and commit must insert into the specific hovered committed polyline segment.

**Error Handling:**
15. Clear hover placement state on pointer exit, pointer cancel, route commit, and when route drafting ends.
16. If the pointer is touch-only or not actually over a draft segment, render the normal map without side effects.
17. Hover state changes must not mutate route geometry, numbering, selection state, persistence, or export behavior until the click commit occurs.

**Edge Cases:**
18. The hover placement marker should track smoothly during mouse movement and not lag behind the cursor.
19. Rapid hover enter/exit during panning must not leave a stale hover placement behind.
20. Narrow-screen route sheet layout and existing route save behavior must remain unchanged.
</requirements>

<boundaries>
Edge cases:
- This spec only covers route-creation hover placement, not the existing persisted-route hover/select feature.
- Touch devices should not synthesize hover state.
- Do not change marker numbering, marker order, or route draft geometry before the click commit.

Error scenarios:
- Pointer exit, pointer cancel, route commit, or draft teardown must clear the hover visual.
- Missing route hover hit targets must be a no-op.
- A failed route save must behave exactly as it does today; hover state is not part of save recovery.

Limits:
- Do not add a new route mode or a persisted hover field.
- Do not change route storage, export, or route-planning behavior.
- Do not alter track, peak, or persisted route hover behavior as part of this slice.
- Do not let the preview drift off the rendered route path or commit beside the hovered path segment.
</boundaries>

<implementation>
Files expected to change:
- `./lib/core/constants.dart`
- `./lib/screens/map_screen.dart`
- `./lib/widgets/route_marker.dart`
- `./lib/screens/map_screen_layers.dart`
- `./test/widget/route_marker_layer_test.dart`
- `./test/providers/map_provider_route_draft_hover_test.dart`
- `./test/widget/map_screen_route_hover_test.dart`
- `./test/robot/map/map_route_journey_test.dart`

Preferred approach:
- Keep the hover seam as small and local as possible.
- Prefer a marker-local hover widget or wrapper over expanding provider state unless a testability gap makes that impossible.
- Reuse the existing circle rendering for the hover shell and the numbered marker sizing rules instead of inventing a new visual language.
- Keep selectors key-first and app-owned.

Avoid:
- Avoid mutating draft geometry or route mode in response to hover before click commit.
- Avoid changing persisted route hover/select code paths.
- Avoid introducing additional route-draft state that is only needed for hover visuals.
</implementation>

<validation>
Use TDD slices in this order:
1. Add a failing widget test for route hover showing the movable circle-style placement marker at numbered-marker size.
2. Add a failing widget test for cursor pointer changes and hover tracking with mouse movement.
3. Add a failing widget or robot test for click commit inserting the hovered placement marker into a draft segment.
4. Add a failing robot journey for create draft -> hover segment -> move cursor -> click commit -> verify inserted numbered state with stable keys.
5. Add a failing provider or widget test for a route whose committed geometry bends between control markers, then verify hover stays on that rendered path and commit inserts into the hovered committed segment.
6. Add a failing provider or widget test for inserting before existing numbered markers, then verify the inserted marker takes the next segment number and subsequent numbered markers are renumbered.

Expected coverage outcomes:
- UI behavior: route hover renders the correct shell, size, cursor, and commit behavior.
- Critical journey: a desktop hover path on the route draft screen is covered end to end.
- Unit tests: only for any shared size or hover-flag helper that is extracted and reused.

Required seams:
- Stable keys for the marker root, hover shell, target state, and segment hover state.
- A deterministic way to drive pointer hover in tests.
- No dependency on private widget internals.

Test split:
- Widget tests: hover render state, size scaling, cursor changes, insert behavior, and cleanup.
- Robot tests: the route-draft hover journey on a desktop-sized surface.
- Unit tests: only any extracted shared size/flag helper.
</validation>

<stages>
Phase 1: Add the hover scaling constant and the marker rendering seam, then verify the rendered widget shape.
Phase 2: Wire cursor tracking and hover enter/exit into the route layer and verify cleanup behavior.
Phase 3: Add widget tests for the hover visuals, cursor changes, and insert behavior.
Phase 4: Add the robot hover journey and verify the stable keys.
</stages>

<done_when>
Hovering a draft route segment shows a movable placement marker that matches the circle style, uses numbered-marker size, and tracks the visible route path.
The cursor becomes a pointing finger while hovering the segment.
Clicking the placement marker inserts it into the hovered draft segment and changes it to a numbered marker, assigning `1` when it is the first numbered marker and otherwise renumbering from that segment onward.
Touch input, route saving, and existing persisted-route hover behavior remain unchanged.
The required automated tests pass.
</done_when>
