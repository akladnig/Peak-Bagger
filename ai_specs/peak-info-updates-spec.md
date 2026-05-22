<goal>
Update the shared peak info popup so it supports a direct Drop Marker action, shows the user's recorded ascents for that peak, and renders the popup values with consistent emphasis and numeric formatting.

This helps map users act on a peak without leaving context, and keeps the same popup readable and useful when opened from the main map or the peak-lists mini map.
</goal>

<background>
This is a Flutter UI change with shared popup content and map-state wiring.

Relevant files to examine:
- `./ai_specs/peak-info-updates.md` - source task note
- `./lib/services/peak_info_content_resolver.dart` - shared popup content builder and resolver helper
- `./lib/screens/map_screen_panels.dart` - `PeakInfoPopupCard` and placement logic
- `./lib/screens/map_screen.dart` - main map popup host and map-state callbacks
- `./lib/screens/peak_lists_screen.dart` - mini-map popup host that reuses the same card
- `./lib/providers/map_provider.dart` - selected location, popup open/refresh state, and main-map popup content rebuild
- `./lib/providers/peak_list_provider.dart` - peak list and ascent revision providers used to invalidate popup content
- `./lib/services/peaks_bagged_repository.dart` - ascent rows and sort order
- `./lib/services/gpx_track_repository.dart` - track name lookup for ascent rows
- `./lib/core/number_formatters.dart` - height formatting helper
- `./lib/core/date_formatters.dart` - existing date-formatting patterns if a new ascent-row helper is extracted
- `./test/services/peak_info_content_resolver_test.dart` - resolver coverage
- `./test/harness/test_map_notifier.dart` - popup refresh seam used by widget tests
- `./test/widget/map_screen_peak_info_test.dart` - main popup coverage
- `./test/widget/peak_lists_screen_test.dart` - mini-map popup coverage
- `./test/widget/peak_info_popup_placement_test.dart` - placement math coverage
- `./test/robot/peaks/peak_info_robot.dart` - robot selectors and helpers
- `./test/robot/peaks/peak_info_journey_test.dart` - critical journey coverage

Current behavior to preserve:
- The popup stays anchored to the peak marker and still closes the same way.
- `PeakInfoPopupCard` remains shared by the map screen and peak-lists mini map.
- Existing map-name and list-name lookup behavior remains intact.
- `resolvePeakInfoPopupPlacement()` keeps the same logic unless the popup size constant changes.
</background>

<user_flows>
Primary flow:
1. User taps a peak marker on the map.
2. The peak info popup opens.
3. The popup shows the peak title, formatted height, optional My Ascents section, map name, MGRS, and list memberships.
4. The user taps Drop Marker to place the shared selected-location marker on that peak.
5. The user closes the popup with the close icon.

Alternative flows:
- Peak-lists mini map: the same popup card opens from the mini map and shows the same content and actions.
- Peak-lists mini map after Drop Marker: the shared selected-location marker is also visible there so the action has feedback in both hosts.
- Peak with one ascent: show a single indented ascent entry under `My Ascents:`.
- Peak with multiple ascents: show multiple indented ascent entries sorted newest to oldest, breaking ties by name ascending.
- Peak with no ascents: omit the `My Ascents:` section entirely.

Error flows:
- Missing or incomplete MGRS data: omit the `MGRS:` row and keep the existing `Map:` fallback behavior.
- Missing track lookup for an ascent row: fall back to a safe track label instead of crashing.
- Repository failure while resolving popup data: fail closed by omitting the unavailable section, not by breaking the popup.
- Drop Marker on an existing selected location: replace the marker position with the peak location.
</user_flows>

<requirements>
**Functional:**
1. Add a Drop Marker button to `PeakInfoPopupCard`, placed on the same top row as the close icon and immediately to its left.
2. Give the Drop Marker button the tooltip text `Drop a Marker on the Peak`.
3. Give the close icon the tooltip text `Close Peak Info`.
4. Use the same marker icon and color already used for the map's selected-location marker so the new action matches existing marker visuals.
5. Wire Drop Marker to set the shared selected location to the current peak's latitude/longitude.
6. Drop Marker must not recenter the map or change zoom; it only updates the shared selected-location state.
7. Add a `My Ascents:` section below `Height:` and above `Map:` when at least one recorded ascent exists for the peak.
8. Render ascent rows in the same popup using the peak's recorded ascent history, sorted newest to oldest, breaking ties by name ascending.
9. Show each ascent as `Trackname (dd MMM yyyy)` using the track name and the recorded ascent date from the bagged ascent row, for example `Mt Wellington Loop (04 Mar 2026)`.
10. If a track lookup fails or the track name is blank, use a safe fallback label such as `Track #<gpxId>` so the ascent still renders.
11. Format the `Height:` value with `formatElevationMetres(...)` and keep the `m` suffix used in the current UX.
12. Render the value portions for labeled rows in bold while leaving the label text style unchanged.
13. Keep the existing title, alt-name, map-name, MGRS, and list-name content in the same overall popup.
14. Keep the title/action row fixed and make only the content area scroll within the card so long ascent histories stay bounded without pushing the close or Drop Marker controls off screen.
15. Increase `UiConstants.peakInfoPopupSize.height` if needed so the new button row and ascent content remain readable and the placement math stays accurate.
16. Ensure the same fixed-header/scrollable-body structure is used by both popup hosts.
17. Rebuild peak-info popup content when `peaksBaggedRevisionProvider` changes while the popup is open so open popups do not show stale ascent rows after sync or import.
18. Keep popup-content resolution behind the shared `resolvePeakInfoContent(...)` helper so the main map and mini map cannot diverge in how they build `PeakInfoContent`.

**Error Handling:**
19. If ascent data cannot be resolved for a peak, do not throw; omit the section or use safe fallbacks, but never break popup rendering.
20. If the peak has no recorded ascents, do not render a placeholder section.
21. If MGRS parts are incomplete after trimming, keep the current `Map:` fallback and do not render a malformed `MGRS:` row.
22. If the selected location already exists, Drop Marker should overwrite it rather than create a second marker concept.

**Edge Cases:**
23. Keep whitespace trimming behavior for list names and MGRS parts unchanged.
24. Preserve the existing row order except for inserting `My Ascents:` under `Height:`.
25. Preserve deterministic ascent order on refresh so the popup does not reorder rows unexpectedly.
26. Keep the popup usable on narrow viewports; update placement expectations if the popup size constant changes.
27. Keep hover, click-close, and background-close behavior unchanged.

**Validation:**
28. Add or update unit tests in `./test/services/peak_info_content_resolver_test.dart` for the new ascent data in the shared popup content.
29. Add or update widget tests in `./test/widget/map_screen_peak_info_test.dart` for the Drop Marker button, the close tooltip, the height formatting change, and the `My Ascents:` rendering.
30. Add or update widget tests in `./test/widget/peak_lists_screen_test.dart` so the shared mini-map popup and selected-location marker stay visible after Drop Marker.
31. Add or update widget tests in `./test/widget/map_screen_peak_info_test.dart` or `./test/widget/peak_lists_screen_test.dart` to prove an open popup refreshes when `peaksBaggedRevisionProvider` changes and the ascent rows update without closing the popup.
32. Add or update popup-placement tests in `./test/widget/peak_info_popup_placement_test.dart` if `UiConstants.peakInfoPopupSize.height` changes or the popup body needs scroll-bounded coverage.
33. Extend `./test/robot/peaks/peak_info_robot.dart` and `./test/robot/peaks/peak_info_journey_test.dart` with a journey that opens the popup, verifies the new content, taps Drop Marker, and confirms the selected location updates.
34. Keep the test split stable: unit tests for content resolution and ascent formatting, widget tests for popup rendering and action wiring, robot tests for the critical end-to-end journey.
35. Follow vertical-slice TDD for each new behavior slice instead of batching all popup tests first.
</requirements>

<boundaries>
Edge cases:
- Do not clear or replace non-related map state when Drop Marker is used.
- Do not recenter the map or change zoom when Drop Marker is used.
- Do not change popup dismiss behavior just to accommodate the new button.
- Do not alter the existing map-name fallback logic unless the new ascent data path requires the same shared safety check.
- Do not deduplicate or reorder list names beyond the current trimmed filtering behavior.

Error scenarios:
- If ascent lookup fails for one row, keep the rest of the popup visible.
- If the popup content cannot be resolved from a repository, prefer an omitted section over a crash.
- If the popup height grows, adjust placement expectations rather than weakening the placement assertions.

Limits:
- Keep the change localized to the peak info popup data flow and presentation layer.
- Do not change persistence models unless a new popup field absolutely requires it.
- Do not add dependencies.
</boundaries>

<discovery>
Before implementing, examine thoroughly:
1. How `PeakInfoContent` is built and copied through `resolvePeakInfoContent()`, `map_provider.dart`, and `test/harness/test_map_notifier.dart`.
2. How the shared popup card is hosted in both `map_screen.dart` and `peak_lists_screen.dart`.
3. How ascent rows can be sourced deterministically from `PeaksBaggedRepository.ascentsForPeakId()` and paired with `GpxTrackRepository.findById()`.
4. How the existing popup tests assert text order, placement, and shared-card behavior.
</discovery>

<implementation>
Use the smallest correct change.

Recommended implementation shape:
1. Expand `PeakInfoContent` with a pre-resolved ascent view model so both popup hosts render the same data without extra widget-side repository logic.
2. Resolve ascent rows in `./lib/services/peak_info_content_resolver.dart` using the bagged-ascent repository plus the track repository, and keep the current safe fallback behavior for missing data.
3. Use `resolvePeakInfoContent(...)` as the shared helper for both popup hosts, passing the repositories it needs in one place so `PeakInfoContent` cannot diverge between the main map and mini map.
4. Update `./lib/providers/map_provider.dart` `openPeakInfoPopup()` and `_refreshedPeakInfo()` so the ascent section is preserved when the popup opens and refreshes on the main map, and invalidate/rebuild popup content when ascent-related revisions change.
5. Add an optional `onDropMarker` callback to `PeakInfoPopupCard` and wire it from both popup hosts.
6. In `./lib/screens/map_screen.dart`, pass a callback that sets `mapProvider.selectedLocation` to the current peak coordinates.
7. In `./lib/screens/peak_lists_screen.dart`, pass the same shared-location callback and render the shared selected-location marker in the mini map so Drop Marker has visible confirmation there too.
8. Render the labeled rows with `Text.rich` or equivalent so the label style stays unchanged while the value text becomes bold.
9. Keep the MGRS row styling monospace, even when the value is bold.
10. Implement a fixed header row plus a scrollable/bounded content body so ascent history can grow without clipping the controls.
11. Update `UiConstants.peakInfoPopupSize.height` only as much as needed, then adjust placement tests to match the new value.
12. Update the test harness copy path for `PeakInfoContent` so refresh behavior remains deterministic.
13. Keep the card layout shared; do not fork a separate popup widget for the mini map.

Avoid:
- Do not calculate ascent text ad hoc inside the widget when the resolver can own the data.
- Do not change the popup's anchor logic or dismissal wiring unless a test proves it is required.
- Do not broaden the map-state change beyond the selected-location marker update.
- Do not add a separate popup widget for the mini map.
</implementation>

<validation>
Follow vertical-slice TDD. Write one failing test for the next behavior, implement the minimum code to pass, then refactor while green. Do not batch all tests before implementation.

Behavior-first slices:
1. Resolver slice: resolve a peak with ascents into shared popup content that includes ordered ascent rows.
2. Resolver slice: missing track lookup and blank track names fall back safely.
3. Widget slice: the popup shows the new Drop Marker button and close tooltip.
4. Widget slice: the popup renders `Height:` with `formatElevationMetres(...)` formatting and bold value text.
5. Widget slice: the popup shows `My Ascents:` below `Height:` and hides the section when there are no ascents.
6. Widget slice: pressing Drop Marker updates the selected location to the peak coordinates.
7. Widget slice: the shared mini-map popup still renders the same content.
8. Placement slice: the updated popup size still places correctly near screen edges.
9. Robot slice: the critical journey opens the popup, verifies the content, taps Drop Marker, and confirms the marker state changes.

Required coverage:
- Unit tests must cover the data resolver and any ascent formatting helpers with public APIs only.
- Widget tests must cover popup layout, button wiring, tooltip text, and the new section ordering.
- Robot tests must cover the user-visible happy path using stable keys and deterministic repository overrides.

Required seams and selectors:
- Keep the existing popup key `peak-info-popup`.
- Add a stable key `peak-info-popup-drop-marker` for the Drop Marker button.
- Add a stable key `peak-lists-selected-location-marker` for the mini-map selected-location marker.
- Keep `peak-info-popup-close` stable.
- Use repository test doubles or in-memory storage for peaks, peak lists, bagged ascents, and tracks.

Final verification commands:
- `flutter analyze`
- `flutter test`
</validation>

<stages>
Phase 1: Shared ascent data
- Expand the popup content model and resolve the ascent rows.
- Verify with unit tests for ordering, fallback labels, and missing-data handling.

Phase 2: Popup actions and formatting
- Add Drop Marker, the close tooltip, and the bold value formatting.
- Verify with focused widget tests on the main map popup.

Phase 3: Shared popup hosts
- Wire the same popup behavior through the peak-lists mini map.
- Verify with the existing mini-map widget coverage.

Phase 4: Placement and journey coverage
- Update the popup size constant and placement tests.
- Extend the robot journey and run `flutter analyze` plus `flutter test`.
</stages>

<done_when>
- `./ai_specs/peak-info-updates-spec.md` exists and is the source spec for planning.
- The popup has a Drop Marker button with the requested tooltip and marker styling.
- The close icon has the requested tooltip.
- `My Ascents:` renders under `Height:` only when recorded ascents exist.
- The height row uses `formatElevationMetres(...)` and the labeled value text is bold.
- Shared popup rendering still works on both the main map and the peak-lists mini map.
- Popup placement remains correct after any size change.
- Unit, widget, and robot tests cover the specified behavior.
- `flutter analyze` passes.
- `flutter test` passes.
</done_when>
