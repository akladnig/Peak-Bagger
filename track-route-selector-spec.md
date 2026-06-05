<goal>
Add a transient chooser popup for ambiguous hover hits on the map so a user can disambiguate between overlapping tracks and routes before opening the existing info panel.

This matters because dense map areas can contain several visible track/route geometries at the same pointer location, and the app currently has no explicit disambiguation surface for that case.
The chooser should feel like the existing popup language in `./tr-select.png` and reuse the map app's existing selection flow once the user picks an item.
</goal>

<background>
Flutter/Riverpod map app with hover-driven map interactions, single-item route/track selection, and shared route/track info panels.

Relevant code paths:
- `@./lib/screens/map_screen.dart` - map hover handling, click handling, and overlay composition.
- `@./lib/screens/map_screen_panels.dart` - shared route/track info panel widgets and popup/card patterns.
- `@./lib/providers/map_provider.dart` - selected/hovered route and track state, selection actions, and popup lifecycle state.
- `@./lib/services/route_hover_detector.dart` - route hover hit-testing.
- `@./lib/services/track_hover_detector.dart` - track hover hit-testing.
- `@./test/widget/map_screen_route_info_test.dart` - current route info panel and map selection coverage.
- `@./test/widget/map_screen_track_info_test.dart` - current track info panel and map selection coverage.
- `@./test/robot/map/route_info_robot.dart` - route panel robot harness.
- `@./test/robot/map/map_route_robot.dart` - route drafting robot harness with stable selector conventions.
- `@./test/robot/gpx_tracks/selection_journey_test.dart` and `@./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - track selection journey coverage.
- `@./tr-select.png` - visual reference for the chooser layout.

Current behavior to preserve:
- Single-track and single-route hover/selection behavior stays intact.
- The existing shared info panel remains the destination after a user chooses an item.
- Desktop hover behavior must not regress touch selection flows.
</background>

<discovery>
Before implementation, confirm these points in code:
1. Where the current single best route/track hit is resolved so the chooser can reuse or extend that logic without duplicating geometry math.
2. Which map overlay host should own the chooser lifecycle so it can be inserted, updated, and removed centrally.
3. Which existing select/show method already opens the shared info panel for a route or track once the user chooses a row.
4. Which geometry source should drive the thumbnail micro-map for each row so the preview matches the rendered item shape.
</discovery>

<user_flows>
Primary flow:
1. User moves the pointer over a dense map area containing more than one visible track or route candidate.
2. The app opens a compact chooser popup anchored to the hover location.
3. The popup shows one row per candidate with a micro-map thumbnail, the item name, and a compact metadata line.
4. The user clicks a row.
5. The chooser closes and the existing route/track info panel opens for the chosen item.

Alternative flows:
- Single visible candidate: the current one-item hover/selection behavior remains unchanged and no chooser appears.
- Touch interaction: taps continue to use the existing selection flow; no hover chooser is introduced for touch-only use.
- Returning user: reopening a dense hover area should rebuild the chooser from current map state, not from stale rows.

Error flows:
- A candidate disappears, becomes hidden, or is deleted while the chooser is open: close the chooser cleanly and do not crash.
- The popup would render outside the viewport: reposition or clamp it so it remains visible.
- Thumbnail geometry is unavailable: show a placeholder thumbnail and keep the row selectable.
- Pointer leaves both the map hit area and the chooser: dismiss the chooser without changing the underlying selection state.
</user_flows>

<requirements>
**Functional:**
1. Open a chooser popup only when the hover hit-test resolves more than one visible track/route candidate at the pointer location.
2. Surface routes and tracks in the same chooser when both types are present; do not split them into separate popups.
3. Keep the chooser transient and map-owned so it is inserted, updated, and removed from the map overlay layer rather than embedded in the shared info panel.
4. Selecting a chooser row must close the chooser and route through the existing select/show flow so the shared info panel opens for the chosen item.
5. Each row must include a non-interactive micro-map thumbnail on the left, the item name in bold, and a compact secondary line. Track rows show `Track`, distance, date, and time when available; route rows show `Route` and distance only because route rows do not carry timestamp metadata.
6. The chooser must ignore hidden, unavailable, or otherwise non-renderable candidates and must never offer rows for items the map would not currently select.
7. The chooser must stay open while the pointer is inside the popup and close when the pointer leaves both the map target and the popup surface.
8. Use deterministic row ordering: show all tracks first sorted by `trackDate` descending with null dates last, then show all routes sorted by the displayed route name ascending with blank names falling back to `Unnamed Route`, and use id as the final stable tie-breaker in each group so the popup does not reshuffle between rebuilds.
9. Keep the chooser visually compact and viewport-safe on desktop widths; it should behave like a popup/card, not a drawer or full-height sheet.
10. Keep the popup visually aligned with the existing popup language used by peak info popups and the `./tr-select.png` reference, but do not reuse the peak popup's content or actions.
11. Add stable app-owned keys for the chooser root, each row, each thumbnail, and the close action if a close icon is present.
12. Do not add persistence, import/export behavior, or new route/track data models unless the chooser itself requires a minimal presentation helper.

**Error Handling:**
13. If the chooser cannot be anchored fully inside the viewport, clamp or reposition it rather than rendering offscreen or throwing.
14. If row thumbnail geometry cannot be built, render a blank thumbnail placeholder and keep the item selectable.
15. If the candidate set changes during pointer motion or after a row tap, stale popup content must not remain visible.
16. Dismissal through Escape, pointer exit, or a map mutation must leave the app in a consistent state and must not clear unrelated route/track selection state unless the existing selection flow already does so.

**Edge Cases:**
17. Dense map areas with several overlapping segments must remain legible and clickable without compressing the row content into an unusable two-line control.
18. On narrow desktop widths, the chooser may scroll vertically if needed, but row text and the row tap target must remain usable.
19. Touch-only interactions should continue to behave like today because there is no hover state to disambiguate.
20. If both route and track candidates are present at the same location, the chooser must preserve both types and not silently drop one type.
21. Reopening the chooser after a selection must not preserve stale rows from a previous hover location.
</requirements>

<boundaries>
Edge cases:
- Hidden items must not appear in the chooser even if stale hover state still points at them.
- The chooser should not steal permanent selection focus until the user actually picks a row.
- Pointer exit and map motion should dismiss transient chooser state predictably.

Error scenarios:
- No candidate set after a hover update: close the chooser instead of leaving an empty popup on screen.
- Stale route/track removed from the repository: dismiss the chooser and fall back to the existing stale-selection handling path.
- Popup placement failure: clamp, flip, or dismiss cleanly; never let the popup block the map because it is partly offscreen.

Limits:
- No bulk track/route chooser screen.
- No persistence or migration work.
- No change to the meaning of the existing single-item route/track info panel.
</boundaries>

<implementation>
Likely files to update:
- `./lib/screens/map_screen.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/providers/map_provider.dart`
- `./lib/services/route_hover_detector.dart`
- `./lib/services/track_hover_detector.dart`
- `./test/widget/map_screen_route_info_test.dart`
- `./test/widget/map_screen_track_info_test.dart`
- `./test/widget/map_screen_route_entry_test.dart`
- `./test/robot/map/route_info_robot.dart`
- `./test/robot/map/map_route_robot.dart`
- `./test/robot/gpx_tracks/selection_journey_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

Implementation shape:
- Introduce a small chooser presentation model that can hold both route and track candidates plus anchor information.
- Keep the chooser lifecycle in the map screen overlay host so hover updates and dismissal are centralized.
- Reuse the existing map popup positioning style where practical, but keep the chooser layout distinct from the peak info popup.
- Build thumbnails from each item's `getSegmentsForZoom()` geometry at the current display zoom; if the geometry is missing or empty, render the blank placeholder instead of inventing preview content.
- Keep micro-map thumbnails non-interactive so they do not interfere with row taps or hover dismissal.
- Prefer small private widget extraction over a new generalized popup framework unless the chooser needs shared popup shell code.
</implementation>

<stages>
1. Candidate aggregation.
   - Extend the hover-hit path so the map can identify and surface multiple visible route/track candidates at one pointer location.
   - Verify with focused logic tests that the track-first/date-first ordering, blank-name fallback, null-date handling, and filtering are deterministic.
2. Chooser popup.
   - Add the popup card/surface, row layout, placeholder handling, and viewport-safe placement.
   - Verify with widget tests that the chooser renders, scrolls if needed, and dismisses cleanly.
3. Selection wiring.
   - Connect row taps to the existing route/track select/show actions and close the chooser after selection.
   - Verify that the shared info panel opens for the chosen item and that stale chooser state is cleared.
4. Journey coverage.
   - Add a robot-driven desktop hover journey that opens the chooser on overlapping candidates, selects a row, and lands on the correct info panel.
   - Run the focused widget and robot slice plus analyze checks to confirm no regressions in single-item selection.
</stages>

<illustrations>
Desired:
- Hovering a dense overlap shows a compact list popup with one thumbnail-and-text row per candidate, similar to `./tr-select.png`.
- Clicking a row closes the popup and opens the shared info panel for that exact route or track.
- Moving the pointer away dismisses only the transient chooser state.

Counter-examples:
- Showing only the nearest item and hiding the rest.
- Turning the chooser into a modal dialog or drawer.
- Letting the popup remain on screen after the candidate list changes.
</illustrations>

<validation>
Baseline automated coverage outcomes:
- Logic/business rules: candidate aggregation, visible-item filtering, and deterministic ordering are covered by unit or focused widget tests.
- UI behavior: chooser rendering, thumbnail fallback, viewport-safe placement, row layout, and dismissal states are covered by widget tests.
- Critical journey: a desktop hover-overlap flow opens the chooser, selects a row, and lands on the correct shared info panel through robot coverage.

TDD expectations:
- Write one failing test slice at a time: candidate aggregation, chooser widget, row selection wiring, then the robot journey.
- Keep the implementation minimal for each slice and refactor only after the current slice is green.
- Prefer public seams and stable keys over private-method testing.

Robot-testing expectations:
- Use stable app-owned `Key` selectors for the chooser root, rows, thumbnails, close action, and the existing shared info panel roots.
- Use deterministic in-memory fixtures for routes and tracks; do not depend on network tiles or live map data.
- Cover the primary hover-overlap journey and at least one stale/cancel dismissal path.

Recommended test split:
- Unit tests: hit aggregation and ordering.
- Widget tests: chooser rendering, popup placement, scrolling, placeholder thumbnails, and dismissal.
- Robot tests: end-to-end hover overlap and item selection.
</validation>

<done_when>
1. Hovering an overlap with multiple visible routes and/or tracks opens a chooser popup instead of silently picking one item.
2. Selecting a row closes the chooser and opens the existing shared info panel for the chosen item.
3. Single-item and touch flows continue to behave as they do today.
4. The chooser is stable at desktop sizes, dismisses cleanly, and has automated widget and robot coverage for the critical flow.
</done_when>
