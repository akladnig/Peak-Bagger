<goal>
Add the map-screen peak info popup to the Peak Lists mini-map so users can inspect a peak without leaving the peak lists screen.
The mini-map should show the same peak details as the main map popup, using the same peak data and formatting rules.
</goal>

<background>
This is a Flutter/Riverpod app. The main peak info popup already exists on the map screen and renders `PeakInfoContent` via `PeakInfoPopupCard` in `lib/screens/map_screen_panels.dart`.
On the map screen, popup opening is driven by `FlutterMap` pointer-up hit testing in `lib/screens/map_screen.dart`, which calls `openPeakInfoPopup` when a peak marker is tapped.
The Peak Lists screen already renders a mini-map in `lib/screens/peak_lists_screen.dart` with marker keys and a selected-peak highlight circle.
The peak info text on the main map is resolved from Tasmap and peak-list repositories in `lib/providers/map_provider.dart`; the mini-map needs the same source data to stay consistent.
The shared peak-info resolver/service must become the single source of truth for both screens so map and mini-map cannot drift.

Files to examine:
- `./lib/screens/map_screen_panels.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/peak_lists_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/services/tasmap_repository.dart`
- `./lib/services/peak_list_repository.dart`
- `./lib/services/peak_info_content_resolver.dart`
- `./lib/services/peak_hover_detector.dart`
- `./test/widget/map_screen_peak_info_test.dart`
- `./test/widget/peak_lists_screen_test.dart`
- `./test/robot/peaks/peak_info_robot.dart`
- `./test/robot/peaks/peak_info_journey_test.dart`
</background>

<discovery>
Confirmed implementation choices:
- Reuse the popup content model through a shared resolver/service so map screen and mini-map stay in sync.
- Mini-map interaction is tap/click only; no hover behavior is required.
- Tapping a mini-map marker selects the corresponding peak row and opens the popup for that peak.
- Tapping outside the popup closes the popup and leaves the selected row/highlight in place.
- The mini-map should use a map-level tap hit test like the main map, not marker `onTap` callbacks.
</discovery>

<user_flows>
Primary flow:
1. User opens Peak Lists and selects a peak list.
2. Mini-map renders the list's peaks and the current selected-peak highlight.
3. User taps/clicks a mini-map peak marker.
4. The corresponding peak row becomes selected and a popup appears on the mini-map showing peak name, height, map name, MGRS, and list names.
5. User closes the popup with the close button or by tapping outside the popup.

Alternative flows:
- User taps a different mini-map marker: the selected row, highlight, and popup should switch to that peak.
- User changes the selected peak row in the details pane: the popup should refresh to match the newly selected peak.
- User opens Peak Lists with no peaks in the selected list: the mini-map still renders, but no popup is available.

Error flows:
- Peak has no elevation: show `Height: —`.
- Peak cannot be resolved to a Tasmap sheet: show `Map: Unknown`.
- Peak has no alternate name: omit the alt-name line.
- Peak has no list memberships: omit the list line.
</user_flows>

<requirements>
**Functional:**
1. The mini-map must support opening a peak info popup from a marker tap/click.
2. The mini-map popup content must match the main map popup content and formatting rules for name, alt name, height, map name, MGRS, and list names.
3. The mini-map and main map must use the same peak-info content resolution logic via a shared resolver/service.
4. The popup must be anchored/positioned so it is visible within the mini-map area and does not obscure the entire Peak Lists screen.
5. The existing selected-peak circle highlight on the mini-map must continue to work.
6. The main map popup path must also delegate to the shared resolver/service so both screens use the same source of truth.

**Error Handling:**
7. Missing data must follow the same fallback rules as the main map popup (`Unknown`, `—`, omitted lines).
8. Closing the popup must be deterministic and must clear any popup state local to the Peak Lists screen/mini-map.

**Edge Cases:**
9. Tapping a second marker should replace the currently open popup rather than open multiple popups.
10. Resizing or switching peak lists should not leave a stale popup anchored to the wrong marker.
11. The feature must not change the main map popup behavior.

**Validation:**
12. Add stable selectors for the mini-map popup host, close action, and the selected peak row so tests can target them without relying on layout offsets.
</requirements>

<boundaries>
Edge cases:
- Empty peak list: mini-map renders bounds/no markers and no popup.
- Single-peak list: popup should still open and remain positioned correctly.
- Peak with whitespace-only optional fields: treat them as empty.

Error scenarios:
- Popup placement cannot fit on the mini-map: clamp it into the mini-map bounds instead of letting it disappear off-screen.
- Missing map/list resolution data: keep the popup open and show the known fallback text.

Limits:
- Do not add new app-wide popup state unless the mini-map needs it; prefer local state or a small reusable popup host.
- Do not change peak search, peak detail tables, or list selection semantics as part of this work.
</boundaries>

<implementation>
Modify `./lib/screens/peak_lists_screen.dart` to make the mini-map interactive and show a popup for the tapped marker.

Extract `./lib/services/peak_info_content_resolver.dart` so both the map screen and the peak-lists mini-map resolve `PeakInfoContent` through the same public API:

`PeakInfoContent resolvePeakInfoContent({required Peak peak, required PeakListRepository peakListRepository, required TasmapRepository tasmapRepository})`

Refactor `MapNotifier.openPeakInfoPopup()` in `./lib/providers/map_provider.dart` to call the shared resolver/service and store the resulting `PeakInfoContent` in state.
Update any popup refresh/rebuild path in `MapNotifier` (including `_refreshedPeakInfo(...)`) to also use the shared resolver/service rather than copying old `PeakInfoContent` fields forward.

If the popup card or placement helper needs to be shared, move only the shared piece into `./lib/widgets/` and have both screens use it. Do not duplicate the popup text formatting in the peak list screen.

Keep the Peak Lists mini-map local to the screen: the popup should be driven by mini-map state, not by the main map provider's popup state, but marker taps should also update the selected peak row so the highlight and popup stay aligned.

Implement the mini-map popup as a local overlay inside `_MiniPeakMapContainer`/`_MiniPeakMap` using a `Stack` around the `FlutterMap`. Use the existing popup placement helper against the mini-map viewport, and close the popup when the user taps outside it.

Mirror the main map's interaction model: use map-level tap hit-testing for mini-map markers rather than hover or marker `onTap` callbacks. Extract the shared candidate-builder/hit-test inputs from `MapScreen` into `./lib/services/peak_hover_detector.dart` (or a new helper alongside it) so both screens use the same `PeakHoverDetector.findHoveredPeak(...)` flow instead of duplicating the logic in both screens.

Read `tasmapRepositoryProvider` in `./lib/screens/peak_lists_screen.dart` or inject the equivalent dependency into the shared resolver so `Map:` text is resolved the same way as the main map popup.

Preserve the existing main map popup behavior and keys unless a mini-map-specific wrapper key is needed for testing.
</implementation>

<stages>
Phase 1: Discovery and reuse
- Confirm the shared popup resolver/service shape and mini-map state model.
- Verify existing peak list selection and selected-peak circle behavior remains unchanged.
- Add the shared resolver unit tests before wiring the mini-map UI.

Phase 2: Mini-map popup interaction
- Add marker tap/click handling to the mini-map.
- Add popup state and rendering for the selected mini-map peak.
- Ensure popup close behavior works cleanly.

Phase 3: Tests and polish
- Update widget tests for the mini-map popup content, fallback text, and close behavior.
- Add a robot journey that opens the popup from Peak Lists and verifies the critical content.
- Verify layout on small and large screens.
</stages>

<validation>
Use vertical-slice TDD:
- Add one failing test at a time.
- Prefer widget tests for mini-map popup state and layout.
- Use fakes for repositories/providers; do not mock private methods.
- Keep the implementation minimal until each test passes.

Required automated coverage:
- Widget test: tapping a mini-map marker opens the popup and shows peak name, height, map name, MGRS, and list names.
- Widget test: tapping a mini-map marker also selects the corresponding peak row/highlight.
- Widget test: missing elevation shows `Height: —`.
- Widget test: unknown map shows `Map: Unknown`.
- Widget test: closing the popup removes it and leaves the mini-map usable.
- Widget test: changing selection or list context does not leave a stale popup.
- Robot journey: open Peak Lists, tap a mini-map marker, verify the popup content, then close it.
- Unit test: the shared resolver returns the same `PeakInfoContent` shape as the current main-map logic for name, map, and list fallbacks.

Required stable selectors/seams:
- `peak-lists-mini-map`
- `peak-lists-mini-map-marker-<peakId>-ticked`
- `peak-lists-mini-map-marker-<peakId>-unticked`
- `peak-lists-details-row-<peakId>`
- `peak-lists-mini-map-peak-info-popup`
- `peak-lists-mini-map-peak-info-popup-close`

Baseline coverage outcomes:
- Logic/state: popup content selection and fallback values are deterministic.
- UI behavior: popup appears, positions correctly, and closes cleanly.
- Critical journey: a real Peak Lists user can inspect peak details from the mini-map without navigating away.
</validation>

<done_when>
The Peak Lists mini-map can open the same peak info popup content as the main map, with deterministic tests covering open, content, close, and fallback behavior.
</done_when>
