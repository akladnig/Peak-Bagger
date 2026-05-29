<goal>
Add a slide-out drawer that displays track details (name and date) when a track on the map is tapped. The drawer slides from the left side (same side as SideMenu), similar to the existing basemaps drawer which slides from the right.

This provides users with quick access to track metadata without navigating away from the map.
</goal>

<background>
This is an extension of existing functionality in a Flutter app using:
- flutter_map for map display
- Riverpod for state management
- GoRouter for navigation
- Existing basemaps drawer as reference implementation

Files to examine:
- @lib/router.dart (existing basemaps drawer pattern at lines 20-69)
- @lib/screens/map_screen.dart (map rendering, track polylines at lines 920-941)
- @lib/providers/map_provider.dart (MapState class)
- @lib/models/gpx_track.dart (track data model)
</background>

<user_flows>
Primary flow:
1. User views map with tracks displayed
2. User taps on a track polyline on the map
3. Drawer slides out from the left showing track name and track date
4. User can tap elsewhere or close drawer to dismiss

Alternative flows:
- No track selected: drawer remains closed, no highlighting
- Tap on track while other overlays (peak search, info popup) are open: close overlays first, highlight track, show drawer
- Tap on different track: update drawer, switch highlighting to new track
- Tap on empty map area: close drawer, clear selection, remove highlighting
</user_flows>

<requirements>
**Functional:**
1. Add `selectedTrack` field to MapState to store currently selected track
2. Add `setSelectedTrack(GpxTrack?)` method to MapProvider to set/clear selected track
3. Create left-side drawer in router.dart that shows when a track is selected
4. Handle track tap event in map_screen.dart to call setSelectedTrack and open drawer
5. Drawer displays trackName and trackDate (formatted) from selectedTrack

**State Management:**
6. selectedTrack should be null when no track is selected
7. Setting selectedTrack should close any open overlays (peak search, info popup)
8. Closing the drawer clears selectedTrack and removes highlighting (simplify: no persistent selection)

**Error Handling:**
9. If trackDate is null, display "Date unknown" or hide date field
10. If trackName is empty, display "Unnamed track"

**UI/UX Interaction:**
11. When mouse cursor is within 10 pixels of a track polyline, change cursor to pointing hand (SystemMouseCursor.grab)
12. When a track is selected (clicked), highlight it:
    - Increase stroke width from 3.0 to 5.0
    - Set opacity to 60% (transparent)
13. Track highlighted while drawer is open (clears on close)
</requirements>

<boundaries>
Edge cases:
- Tap on empty map area: drawer should close (clear selectedTrack)
- Track with no metadata: handle gracefully with defaults
- Multiple rapid taps: debounce or handle idempotently

Error scenarios:
- GPX data unavailable: show placeholder text
</requirements>

<implementation>
Files to modify:
- @lib/providers/map_provider.dart (add selectedTrack to MapState, add setter method)
- @lib/router.dart (add left-side drawer for track details)
- @lib/screens/map_screen.dart (add tap handler to polylines, add cursor detection, add highlighting logic)

Patterns:
- Follow existing basemaps drawer implementation pattern (Drawer widget, Consumer pattern)
- Use Navigator.pop(context) pattern for closing drawer
- Use flutter_map's Polyline tap handling if available, or use onPointerSignal/Listener for hit testing
- Use MouseRegion to detect cursor proximity to tracks
- Store highlightedTrackId separately from selectedTrack for UI-only highlighting

Avoid:
- Duplicating existing drawer code - extract to reusable widget if appropriate
- Adding unnecessary state - rely on existing providers
- Permanent highlighting - always clear on drawer close
</implementation>

<validation>
**Test Coverage Required:**

1. Unit tests for MapProvider:
   - setSelectedTrack correctly updates state
   - setSelectedTrack clears showPeakSearch
   - setSelectedTrack clears showInfoPopup
   - setSelectedTrack(null) clears selection

2. Widget tests for track drawer:
   - Drawer shows track name when track selected
   - Drawer shows formatted date or "Date unknown"
   - Drawer closes on tap outside or back

3. Track highlighting tests:
   - Polyline renders with strokeWidth 3.0 normally
   - Polyline renders with strokeWidth 5.0 and 60% opacity when selected
   - Highlight persists after drawer closes
   - Highlight removed when selection cleared

4. Cursor behavior tests:
   - Cursor changes to pointer when within 10px of track
   - Cursor reverts when moving away from track

5. Integration/robot tests for user journey:
   - Hover near track → cursor changes
   - Click on track → drawer opens, track highlights
   - Click on different track → drawer updates, new track highlights, old unhighlights
   - Click outside → drawer closes, selection clears, highlight removed

Baseline automated coverage:
- Logic: MapProvider state transitions for track selection
- UI: Drawer renders correctly with track data
- Journey: Full tap-track-to-view-drawer flow
</validation>

<done_when>
1. Track drawer appears from left when track is tapped
2. Drawer shows track name and date
3. Tapping elsewhere closes the drawer and clears selection
4. Cursor changes to pointer when near a track
5. Selected track is visually highlighted (wider stroke, 60% opacity)
6. All existing tests pass
7. New tests added for track selection, highlighting, and cursor behavior
</done_when>