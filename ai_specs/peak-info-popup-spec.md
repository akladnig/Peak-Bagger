<goal>
Update the shared peak info popup so the Drop Marker action closes the popup immediately, the popup height is driven by its content instead of a fixed blank reserve, and the peak height row continues to use `formatElevationMetres(...)`.

This matters because map users need a fast one-tap flow from peak details to marker placement, and the popup should stay compact and readable across different peak records and hosts.
</goal>

<background>
This is a Flutter UI change in the shared peak info popup used by the map screen and any other host that reuses the same card.

Relevant files to examine:
- `./ai_specs/peak-info-popup.md` - source task note
- `./lib/screens/map_screen_panels.dart` - peak info popup card and placement logic
- `./lib/screens/map_screen.dart` - main map popup host and selection update wiring
- `./lib/screens/peak_lists_screen.dart` - shared mini-map popup host that reuses the same popup card
- `./lib/core/constants.dart` - popup size constant used by placement tests
- `./lib/core/number_formatters.dart` - `formatElevationMetres(...)`
- `./test/widget/map_screen_peak_info_test.dart` - main popup coverage
- `./test/widget/peak_info_popup_placement_test.dart` - popup placement coverage
- `./test/widget/peak_lists_screen_test.dart` - shared-host coverage, if applicable
- `./test/robot/peaks/peak_info_robot.dart` - stable selectors for the journey tests
- `./test/robot/peaks/peak_info_journey_test.dart` - end-to-end popup flow coverage
</background>

<user_flows>
Primary flow:
1. User taps a peak marker.
2. Peak info popup opens and shows the peak height plus other peak details.
3. User taps `Drop a Marker on the Peak`.
4. The app updates the selected location to the peak coordinates and closes the popup.

Alternative flows:
- User opens the same popup from the main map or the shared mini-map host: the popup should use the same height behavior and the same Drop Marker close-on-action behavior.
- User closes the popup with the close icon instead of dropping a marker: the existing close behavior stays unchanged.

Error flows:
- Peak height is missing: keep the existing placeholder behavior for the height row.
- The Drop Marker action is unavailable in a given host: do not show the button, and do not change the existing popup behavior.
</user_flows>

<requirements>
**Functional:**
1. Keep the Drop Marker action in the peak info popup.
2. When the user taps `Drop a Marker on the Peak`, update the selected location to the current peak coordinates.
3. Close the popup immediately after the Drop Marker action runs.
4. Keep the close icon behavior unchanged.
5. Render the popup height so it sizes to its content rather than reserving a fixed empty height.
6. Preserve a bounded scroll area if the popup content becomes taller than the available viewport.
7. Keep the height label formatted with `formatElevationMetres(...)` and the existing `m` suffix convention.
8. Keep the popup content rows, labels, and ordering otherwise unchanged.
9. Apply the same popup height and close-on-drop behavior in both the main map host and the shared mini-map host.

**Error Handling:**
10. Do not recenter the map or change zoom when Drop Marker is tapped.
11. Do not clear any unrelated map state when Drop Marker is tapped.
12. Do not break popup rendering if the peak has no elevation value.

**Edge Cases:**
13. The popup should remain compact for short content and expand naturally for taller content.
14. The popup should still behave correctly on small screens and near the placement boundaries.
15. If another host reuses the popup card, it should inherit the same content-sized height behavior and close-on-drop behavior.

**Validation:**
16. Keep the `formatElevationMetres(...)` output covered by widget assertions on the rendered height row.
</requirements>

<boundaries>
Edge cases:
- Short content: the popup should not keep a large blank lower area.
- Tall content: the popup should scroll only when needed, not because of a fixed empty-height container.
- Missing elevation: keep the current fallback text for the height row.

Error scenarios:
- Drop Marker must not move the map camera.
- Drop Marker must not create any extra popup state.
- Existing dismiss paths must continue to work after the layout change.

Limits:
- Keep the change localized to the peak info popup presentation and its action callback wiring.
- Do not add dependencies.
- Do not change the selected-location model unless the current wiring requires no alternative.
</boundaries>

<implementation>
Update `./lib/screens/map_screen_panels.dart` so the popup card no longer hardcodes the full popup height and instead sizes to its content with a scrollable body only when needed.

Wire the Drop Marker action so it updates the selected location and then closes the popup in the same callback path.

Keep the shared popup card reusable by both the main map host and the shared mini-map host; do not fork a second popup widget.

Keep `UiConstants.peakInfoPopupSize` as the placement and max-height hint so placement remains deterministic, and let the popup shrink within that bound instead of remeasuring after build.
</implementation>

<validation>
Baseline automated coverage must include logic, UI behavior, and the critical journey.

Behavior-first slices:
1. Widget slice: the popup renders the height row with `formatElevationMetres(...)` output.
2. Widget slice: tapping Drop Marker updates the selected location and closes the popup.
3. Widget slice: the popup height no longer leaves a fixed blank lower section when content is short.
4. Widget slice: the close icon still dismisses the popup without changing selection.
5. Placement slice: popup placement assertions still pass if the rendered size changes.
6. Widget slice: the shared mini-map host renders the same popup height and close-on-drop behavior.
7. Robot slice: replace the existing peak info journey that expects the popup to stay open; the updated journey opens the popup, taps Drop Marker, and verifies the popup closes while selection updates.

Required test split:
- Widget tests for popup rendering, button wiring, and close behavior.
- Unit tests for any pure placement or sizing helper if one is introduced.
- Robot tests for the user-visible happy path from popup open to marker drop.
- Update the shared-host widget coverage so the mini-map path proves the same popup behavior.

Required seams and selectors:
- Keep `peak-info-popup` stable.
- Keep `peak-info-popup-drop-marker` stable.
- Keep `peak-info-popup-close` stable.
- Keep the map selection update deterministic through the existing provider/test harness seams.

Final verification commands:
- `flutter analyze`
- `flutter test`
</validation>

<done_when>
- The popup no longer keeps a fixed empty height.
- Tapping `Drop a Marker on the Peak` updates the selected location and closes the popup.
- The height row still uses `formatElevationMetres(...)`.
- Existing close behavior still works.
- The shared mini-map host shows the same popup behavior as the main map host.
- Widget and robot coverage prove the new behavior.
- `flutter analyze` passes.
- `flutter test` passes.
</done_when>
