<goal>
Add peak hover and click interactions on the map screen.
Hovering a peak should change the cursor to `click` and visually highlight that peak marker.
Clicking/tapping a peak should open a peak info popup beside the peak, without recentering the map.
The popup should show peak name, height, map name, and list memberships when present.
</goal>

<background>
Flutter app, Riverpod state, `flutter_map` rendering.
Peak hover must fit the existing map interaction model; track hover already uses `TrackHoverDetector` and `MapState.hoveredTrackId`.
Keep the existing center-based map info popup behavior intact and separate from the new peak popup.
Peak memberships come from peak list repository data, so the map feature needs a shared repository/provider path.
Files to examine: `./lib/screens/map_screen.dart`, `./lib/screens/map_screen_layers.dart`, `./lib/screens/map_screen_panels.dart`, `./lib/providers/map_provider.dart`, `./lib/services/track_hover_detector.dart`, `./lib/services/peak_list_repository.dart`, `./lib/screens/peak_lists_screen.dart`, `./test/widget/map_screen_peak_search_test.dart`, `./test/widget/map_screen_keyboard_test.dart`, `./test/gpx_track_test.dart`.
</background>

<user_flows>
Primary flow:
1. User hovers a peak marker.
2. Cursor switches to `click` and that peak highlights.
3. User clicks/taps the peak.
4. Peak info popup opens beside the peak.
5. Popup shows peak name, height, map name, and memberships when any.
6. User closes popup or taps another peak.

Alternative flows:
- Touch devices: tap opens popup; no hover state.
- Peak with no memberships: hide the `List(s)` row.
- Peak with unknown height: show `—` for height.
- Peak near the right edge: popup shifts/flips left to stay visible.
- Empty map or non-peak target: no popup, default map cursor.

Error flows:
- Peak leaves the viewport while popup is open: close or re-anchor the popup deterministically.
- Peak markers become hidden while popup is open: close the popup.
- Click misses the peak hit radius: no peak popup state change; existing map selection behavior continues.
</user_flows>

<requirements>
**Functional:**
1. Hovering a peak sets separate peak hover state, `click` cursor, and visible marker highlight.
2. Clicking/tapping a peak opens a separate peak-specific popup anchored to that peak and does not recenter or zoom the map.
3. Popup content includes peak name, height, map name, and comma-separated memberships when any exist.
4. Popup placement prefers the right side of the peak and auto-flips/shifts to remain onscreen.
5. Existing center-based map info popup behavior remains unchanged and must not be reused for peak clicks.
6. Map clicks that do not hit a peak continue the existing map selection behavior.
7. Peak hit testing runs before track hit testing and existing map tap behavior. When a pointer hits a peak, suppress track hover/selection and skip map-level selected-location updates for that event.
8. Use central hit testing in the map pointer handler before existing `onPointerUp` map tap logic; do not rely on marker-child gestures alone to prevent double handling.
9. Opening search, goto, basemaps, location actions, shell navigation, pressing Escape or other map shortcut keys, or tapping map background closes the peak popup.
10. Resolve popup map name from complete peak MGRS fields first; if peak MGRS fields are incomplete, derive MGRS from peak latitude/longitude before calling `TasmapRepository`; fallback to `Unknown`.

**Error Handling:**
11. Non-peak hover clears peak hover state but leaves any open peak popup unchanged. Non-peak click does not open a peak popup and continues the existing map selection behavior.
12. Missing map coverage or missing peak data falls back cleanly to `Unknown`, `—` for unknown height, or no memberships.
13. Malformed or unsupported peak list payloads are skipped during membership lookup; valid list memberships still display sorted, and the `List(s)` row is omitted when none can be decoded.

**Edge Cases:**
14. Touch input has no hover state but still opens the popup on tap.
15. Overlapping peaks resolve deterministically to the nearest hit in screen space; exact distance ties choose the first candidate in rendered marker order.
16. Map pan/zoom while popup is open keeps placement deterministic or closes the popup when it leaves the viewport.
17. Close the peak popup when `showPeaks` becomes false, zoom drops below the marker visibility threshold, the popup peak is removed from `MapState.peaks`, or the popup peak projects outside the viewport.

**Validation:**
18. Use behavior-first tests: hover cursor/highlight before popup content before edge placement.
19. Keep test seams deterministic: fake map state, fake peak repository, fake peak list repository, fixed viewport, fixed peak coordinates.
</requirements>

<boundaries>
Edge cases:
- Hover target near marker boundary: highlight only within the chosen hit radius.
- Hover highlight renders as an additional ring/halo overlay that preserves the ticked/unticked marker asset, draws above the search-selected circle, and does not change `selectedPeaks`.
- Peak belongs to multiple lists: show all names, sorted, comma-separated.
- Peak belongs to no lists: omit the `List(s)` row.

Error scenarios:
- Popup would overflow viewport: clamp/flip; never render offscreen.
- Peak data unavailable or stale: fail closed, no popup.
- Malformed peak list payload: skip that list for memberships; never crash popup rendering.
- Peak lacks complete MGRS fields: derive MGRS from latitude/longitude for map-name lookup before falling back to `Unknown`.

Limits:
- Do not change peak search, track hover, or the existing center-based info popup unless shared layout requires it.
- Do not recenter/select the peak on click; popup only.
- Do not reuse `showInfoPopup` for peak clicks; keep the center info popup and peak popup independent.
- Do not use marker-child tap handlers as the only guard against map-level pointer handling; central map pointer hit testing must decide peak-vs-map-vs-track behavior.
</boundaries>

<implementation>
Create or modify:
- `./lib/providers/map_provider.dart` - peak hover/popup state and notifier methods
- `./lib/screens/map_screen.dart` - central peak hit testing before existing map tap/track logic, popup anchoring, cursor changes, close/re-anchor logic
- `./lib/screens/map_screen_layers.dart` - peak marker rendering, stable marker keys, and highlight rendering
- `./lib/screens/map_screen_panels.dart` - peak info popup card UI and pure popup placement helper, reusing existing popup styling where practical
- `./lib/widgets/map_action_rail.dart` - close peak popup during transient UI cleanup for map actions
- `./lib/router.dart` - close peak popup during shell navigation cleanup
- `./lib/main.dart` - update peak-list provider imports/overrides after provider relocation
- `./lib/services/peak_hover_detector.dart` or equivalent shared helper - deterministic peak hit-testing in screen space
- `./lib/providers/peak_list_provider.dart` or equivalent shared provider file - move peak-list data/service providers out of `peak_lists_screen.dart`, including `peakListRepositoryProvider`, `peaksBaggedRepositoryProvider`, `peakListImportServiceProvider`, `peakListImportRunnerProvider`, and `peakListDuplicateNameCheckerProvider`
- `./lib/screens/peak_lists_screen.dart` - consume the shared peak-list providers instead of defining screen-local providers
- `./lib/services/peak_list_repository.dart` - shared membership lookup for peak list names, skipping malformed list payloads
- `./test/widget/map_screen_peak_info_test.dart` - widget coverage for hover, click, content, placement
- `./test/widget/peak_lists_screen_test.dart` - update provider imports/overrides after provider relocation
- `./test/robot/peaks/peak_info_journey_test.dart` and helper - critical journey coverage
- `./test/robot/peaks/peak_lists_robot.dart` - update provider imports/overrides after provider relocation

Use existing patterns: Riverpod state, `Key`-based selectors, `flutter_map` marker layers, and the existing info popup card style.

Avoid:
- ad hoc hover logic in multiple widgets
- hard-coded popup offsets without viewport clamping
- coupling popup content to map-center state
- mixing peak popup state into the existing center info popup fields
- allowing peak clicks to also run selected-location, track selection, or map-background tap behavior
</implementation>

<validation>
Automated coverage:
- Unit tests for peak hit-testing / popup placement math and membership lookup behavior.
- Widget tests for hover cursor, peak highlight, popup open/close, content rows, and edge placement.
- Robot journey tests for the full hover/click flow with stable keys.

Popup placement helper:
- Inputs: `anchorScreenOffset`, `viewportSize`, `popupSize`, `markerSize`, `margin`, and `preferredGap`.
- Preferred placement: right of the marker, vertically centered on the marker.
- Overflow policy: flip left if right-side placement overflows, then clamp horizontally and vertically within `margin`.
- Output: top-left `Offset` for a `Positioned` popup and whether the popup remains anchorable; close the popup when the anchor is outside the viewport.

TDD expectations:
- Write one failing test per behavior slice.
- Order slices: hover cursor/highlight, popup opens on click, popup content, edge placement, touch path.
- Prefer fakes for map state, peak repository, and peak list repository; avoid mocking internal state.

Robot coverage:
- Use stable selectors: `map-interaction-region`, `peak-marker-$osmId`, `peak-marker-hitbox-$osmId`, `peak-info-popup`, and `peak-info-popup-close`.
- Example keys for OSM ID `6406`: `peak-marker-6406` and `peak-marker-hitbox-6406`.
- Include deterministic viewport/peak coordinates so popup placement is reproducible.
- Report any coverage gap if marker overlap cannot be made deterministic in widget tests.

Interaction notes:
- Peak hit testing must run centrally in the map pointer handler before track hover/selection and before existing map tap behavior.
- Peak hits must win over track hits; outside the peak hit radius, existing track hover and selection behavior remains unchanged.
- Peak hit-test candidates must use the same order as rendered markers, including the current unticked-before-ticked grouping from `buildPeakMarkers`.
- Opening a peak popup should close the center-based info popup if it is open, and opening the center-based info popup should close any peak popup.
- Peak popup cleanup must be wired into action rail transient UI cleanup and shell navigation cleanup.
- Hover state should be cleared when the pointer leaves the map or the popup is closed.

Required commands:
- `flutter analyze`
- `flutter test`
</validation>

<stages>
Phase 1: peak hover and selection state. Verify cursor/highlight with widget test.
Phase 2: peak popup model and rendering. Verify popup content and list memberships.
Phase 3: popup placement and map interaction. Verify right-side placement, auto-flip, close/re-anchor behavior.
Phase 4: robot journey coverage. Verify end-to-end hover/click on a peak.
</stages>

<done_when>
- Hovering a peak shows click cursor and highlight.
- Clicking/tapping a peak opens a peak info popup beside the peak.
- Popup shows peak name, height, map name, and memberships when present.
- Popup stays onscreen via shift/flip logic.
- Existing map info popup behavior is unchanged.
- Automated tests pass.
</done_when>
