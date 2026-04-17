<goal>
Add on-screen GPX track selection to the macOS map UI. A user should be able to click a hovered track, keep that track selected while they pan or zoom the map, and see the selected track rendered with a thicker stacked highlight that keeps its original color.

Who: map users inspecting imported GPX tracks.
Why: when tracks overlap or the map is busy, the user needs one track to stay visually anchored while they continue working.
</goal>

<background>
Flutter app with Riverpod, `flutter_map`, and existing GPX hover detection. Track hover already exists in `./lib/screens/map_screen.dart` and `./lib/providers/map_provider.dart` through `hoveredTrackId` and `TrackHoverDetector`.

Selection must be transient UI state only. Do not add ObjectBox schema fields or SharedPreferences persistence for selection.

Files to examine:
- `./lib/screens/map_screen.dart`
- `./lib/providers/map_provider.dart`
- `./lib/models/gpx_track.dart`
- `./lib/services/track_hover_detector.dart`
- `./lib/services/gpx_importer.dart`
- `./test/gpx_track_test.dart`
- `./test/widget/gpx_tracks_recovery_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_robot.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
</background>

<user_flows>
Primary flow:
1. User moves the mouse over a visible GPX track and the map cursor changes to click, as it does today.
2. User performs a primary/left click on the hovered track.
3. App marks that track as selected.
4. The selected track renders with a stacked highlight and stays selected while the user pans, zooms, or moves the pointer away.

Alternative flows:
- User clicks a different hovered track: the new track replaces the previous selection.
- User clicks the same selected track again: selection stays on that track and does not toggle off.
- User clicks empty map space: selection clears and no location marker is created or moved.
- User refreshes, imports, resets, or otherwise rebuilds the track list: stale selection clears.

Error flows:
- User clicks where no track is hovered: do not create a selection.
- A malformed track cannot be hit-tested or rendered: skip that track and keep the rest of the map working.
- A selected track disappears because the track list was replaced: clear the stale selection.
</user_flows>

<requirements>
**Functional:**
1. Add transient selected-track state to `MapState` and `MapNotifier` using track identity, not the track object itself. One track may be selected at a time.
2. A track can only be selected from the existing hover hit-test result on a primary/left mouse click. Delay hover clearing until after selection resolution so the click can use the track the user clicked, not a cleared or stale hover value.
3. Selection persists across mouse movement, panning, and zooming.
4. The selected track renders with a stacked highlight that keeps the original track color: a wider dark shadow underlay, the thicker original-color track line, and a thin white line overlaid on top. Selected styling wins over hover styling if both apply.
5. Clicking empty map space clears selection and must not update `selectedLocation`.
6. Track selection consumes the click and must not call `setSelectedLocation` or otherwise move the amber location marker.
7. Refresh/import/reset flows that replace the track list clear any stale selection state before the new track list becomes active.
8. Toggling track visibility off clears selection because the selected track is no longer visible.
9. Selection must not be persisted to ObjectBox, SharedPreferences, or any file-backed store.
10. Multi-segment tracks must highlight all segments for the selected track, not just the clicked segment.

**Error Handling:**
11. Clicking the map when no track is hovered must be a no-op for selection and must not crash.
12. Drag gestures that become pans must not create a selection.
13. If track hit-testing fails for a malformed track, skip that track and keep the rest of the map interactive.

**Edge Cases:**
14. If the selected track is also currently hovered, the stacked highlight remains visible and the cursor still shows click.
15. Selecting a different track replaces the existing selection immediately.
16. Selection does not survive app restart because it is view state only.
17. Track visibility changes that rebuild or hide the track overlay should clear stale selection if the selected track is no longer visible.

**Validation:**
18. Keep the interaction anchored to stable app-owned keys, especially `Key('map-interaction-region')`.
19. Add TDD-first coverage for state transitions, rendering color override, and click/clear behavior.
</requirements>

<boundaries>
Edge cases:
- A selected track can remain selected while the user pans or zooms, even if it moves off-screen.
- Hover and selection are separate states; hover should not clear selection.
- Selection is single-select only.

Error scenarios:
- Empty-map click: clear selection, do not show an error.
- Malformed track geometry: skip the track and leave the rest of the map usable.
- Track refresh/import/reset: clear stale selection rather than retaining an invalid track id.

Limits:
- Mouse/pointer selection only; do not add touch-specific selection behavior in this slice.
- No persistence, schema migration, or database changes for selection.
- Do not change track import, peak correlation, or track statistics behavior beyond clearing stale selection when track data is replaced.
</boundaries>

<implementation>
1. Update `./lib/providers/map_provider.dart` and `MapState` to add `selectedTrackId` plus explicit select/clear methods.
2. Update `./lib/screens/map_screen.dart` so a primary/left click on a hovered track selects it, a click on empty map space clears selection, and pan gestures do not select. Preserve the hovered track id long enough for click selection even though hover is cleared during pointer down.
3. Update track rendering in `./lib/screens/map_screen.dart` so the selected track uses `Colors.green` while unselected tracks keep `trackColour`, and selected tracks render in a foreground pass or last in z-order.
4. Clear selection in the existing track refresh/import/reset/recalculate paths when the track list is replaced.
5. Clear selection when track visibility is toggled off.
6. Add or update unit tests in `./test/gpx_track_test.dart` for selection state transitions and stale-selection clearing.
7. Add widget coverage in `./test/widget/gpx_tracks_selection_test.dart` or the closest GPX map widget test file for the green highlight and click-clear behavior.
8. Use `./test/harness/test_map_notifier.dart` as the shared seam for widget and robot coverage, then add robot coverage in `./test/robot/gpx_tracks/selection_journey_test.dart` and extend `./test/robot/gpx_tracks/gpx_tracks_robot.dart` with helpers for click-select and clear flows.
9. Do not change `./lib/models/gpx_track.dart` unless a later requirement needs selection persistence, which is out of scope here.
</implementation>

<stages>
Phase 1: Add selection state and unit tests for select, replace, and clear behavior. Verify selection survives pan/zoom state changes and clears when track data is replaced.

Phase 2: Update map click handling and stacked polyline selection styling. Verify the selected track renders with the stacked highlight and hover still drives the click cursor.

Phase 3: Add widget and robot coverage for click-to-select, click-empty-to-clear, and refresh/import clearing. Verify existing GPX journeys still pass.
</stages>

<validation>
1. TDD order: write one failing selection-state test first, then one failing render-color test, then one failing journey test. Keep each red-green-refactor cycle small and behavior-first.
2. Unit tests must cover:
   - selecting a hovered track stores its id
   - selecting another track replaces the prior selection
   - clicking empty map space clears selection
   - pan/zoom updates do not clear selection
   - refresh/import/reset replacement clears stale selection
3. Widget tests must cover:
   - the selected track renders as a stacked highlight using the original color
   - selected styling wins when the selected track is also hovered
   - unselected tracks keep their stored color
4. Robot tests must cover the primary journey using `Key('map-interaction-region')`:
   - hover a visible track
   - primary/left click to select it
   - pan or zoom without losing selection
   - click empty map space to clear it
   - toggle track visibility off and observe selection clear
5. Stable selectors:
   - reuse `Key('map-interaction-region')`
   - reuse existing track/import/reset controls where needed
   - if a new track-layer key is added, keep it app-owned and stable; do not rely on localized text
   - use `./test/harness/test_map_notifier.dart` as the shared deterministic state seam for widget and robot tests
6. Baseline automated coverage outcome:
   - logic/state rules: unit tests
   - UI rendering behavior: widget tests
   - critical user journey: robot test
</validation>

<done_when>
1. A user can click a hovered track and see it stay selected in green.
2. The selection survives pan/zoom and hover changes until an explicit clear or replacement.
3. Clicking empty map space clears the selection.
4. Refresh/import/reset operations do not leave a stale selected track behind.
5. Automated tests cover the selection state, green rendering, and the click-select journey.
</done_when>
