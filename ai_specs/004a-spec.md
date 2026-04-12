<goal>
Add ability to go to a specific map using map name only (no grid references), with auto-zoom to map extents and rectangle outline. Also add a grid overlay showing all maps with their names.

Users benefit by being able to navigate to any 50k map directly and visualize map coverage on the map.
</goal>

<background>
**Tech Stack:**
- Flutter with Riverpod, flutter_map, ObjectBox
- Project: peak_bagger - Tasmanian peak bagging app

**Files to examine:**
- @lib/models/tasmap50k.dart - Existing Tasmap50k entity with eastingMin, eastingMax, northingMin, northingMax, mgrs100kIdList
- @lib/services/tasmap_repository.dart - Repository with findByName(), getAllMaps()
- @lib/providers/map_provider.dart - MapNotifier with goto parsing, map selection state
- @lib/screens/map_screen.dart - Map UI with CircleLayer for selected peaks
- @lib/router.dart - FAB buttons for goto, info
- @pubspec.yaml - Dependencies already available (flutter_map, latlong2, mgrs_dart, objectbox)

**Existing Patterns:**
- CircleLayer for selected peaks (map_screen.dart:338-348)
- goto input field (map_screen.dart:474-525)
- Toggle FAB pattern in router.dart
- Map route-shell FABs should follow the same left-positioned tooltip/semantics wrapper pattern used by the import and show tracks FABs
</background>

<user_flows>
**Phase 4a - Go to Map by Name**

Primary flow:
1. User taps goto FAB or presses 'G' key
2. Goto input field appears
3. User enters map name only (e.g., "Wellington") - no coordinates
4. System looks up maps starting with "Wellington" (case-insensitive)
5. If 1 exact match: center map, zoom to fit, show rectangle
6. If multiple matches: show dropdown below input
7. User selects from dropdown (tap or arrow+Enter)
8. Map centers on map's calculated center (from MGRS)
9. Map zooms to fit map extents with 10% padding
10. Blue rectangle drawn around map boundary

Alternative flows:
- Map name-only (no coords): "Wellington" → lookup by name
- Map name with spaces: "Mount Field" → parses as one string
- Case insensitive: "WELLINGTON" → matches "Wellington"
- Partial name with spaces: "Mount Field" → matches starts-with
- Exact match auto-selects: If single exact match, show rectangle immediately
- Partial matches: Show dropdown with up to 10 matching maps

Error flows:
- Map name not found: Show error "Map not found: [name]" below input
- Multiple matches: Show dropdown for user selection

**Phase 4b - Show Maps Grid**

Primary flow:
1. User taps new "show maps" FAB (between goto and info FABs)
2. Grid overlay appears showing all 50k maps
3. Blue rectangles drawn around each map's boundary
4. Map name and series displayed at bottom-right of each rectangle
5. User can pan/zoom while overlay is visible

Alternative flows:
- Toggle: Tap FAB to show, tap again to hide
- Press 'M' key: Toggle map overlay
- Any other FAB closes overlay

Error flows:
- No maps in database: Show "No maps available" message
</user_flows>

<requirements>
**Phase 4a - Functional:**
1. Goto search accepts map name only (no coordinates)
2. Map name lookup is case-insensitive
3. On input change (debounce 300ms), show dropdown with matching maps
4. Dropdown shows up to 10 matching maps with map name + series
5. User selects from dropdown OR presses Enter on highlighted suggestion
6. If single exact match: auto-select without dropdown
7. Map centers on map's calculated center (from eastingMin/eastingMax/northingMin/northingMax)
8. Map zooms to fit map extents with 10% padding around the map so rectangle is visible
9. Blue rectangle (PolygonLayer with Polygon) drawn around map boundary
10. Blue rectangle visible at all zoom levels (not just zoom >= 12)
11. Error message shown if map name not found

**Phase 4a - State additions:**
- selectedMap (Tasmap50k?) - Currently selected map for rectangle display
- showMapOverlay (bool) - Whether grid overlay is visible
- mapOverlayMode (enum: none, gotoZoom, gridView) - Current overlay mode
- mapRects (List<MapRect>) - Rectangles to draw for grid view
- mapNameSuggestions (List<Tasmap50k>) - Suggested maps matching current input
- mapSearchQuery (String) - Current search query in goto field

**Phase 4b - Functional:**
1. Add new "show maps" FAB (Icons.grid_on) between goto and info FABs
2. The grid FAB uses the same left-positioned tooltip/semantics wrapper pattern as the import and show tracks FABs
3. 'M' key (shift+M) toggles map overlay
4. All maps displayed with blue rectangles
5. Map name + series shown at bottom-right of each rectangle
6. Overlay closes when any other FAB is tapped

**Error Handling:**
9. Map not found: "No maps found matching '[input]'" error below input
10. No maps in database: Show info message, continue without overlay
11. Invalid coordinates in map data: Skip invalid maps, log warning

**Repository methods needed:**
- searchMaps(prefix): Find maps where name starts with prefix (case-insensitive)
- getMapCenter(map): Calculate center LatLng from map's MGRS ranges

**Edge Cases:**
12. Map with wrap-around ranges (eastingMax < eastingMin): Use full MGRS grid for center calculation
13. Map covering multiple 100k squares: Use first mgrs100kId for center
14. User pans while gotoZoom mode active: Keep rectangle, allow pan
15. User zooms while gotoZoom mode active: Keep rectangle at new zoom level
</requirements>

<boundaries>
**Phase 4a - Edge cases:**
- Map name is empty: Show "Enter a map name" error
- Map name matches multiple: Use first match silently
- Map has no mgrs100kIds: Handle gracefully, use 0,0 center

**Phase 4b - Edge cases:**
- 100+ maps: Draw all (65 is typical for Tasmania 50k)
- Map with no Series/Name: Skip in grid view
- Overlapping maps in grid view: Draw all rectangles, later ones on top

**Error scenarios:**
- Database empty: Show "No maps available" in grid view
- Network timeout on first load: Use cached data if available

**Limits:**
- Map rectangles: Always visible (no zoom threshold)
- Grid view: Limit to 200 maps maximum
</boundaries>

<implementation>
**Files to modify:**
- @lib/providers/map_provider.dart - Add map selection state, parse map name (no coords), add mapOverlayMode state
- @lib/services/tasmap_repository.dart - Add getMapCenter() method, add searchMaps(prefix) method
- @lib/screens/map_screen.dart - Add ListView dropdown below goto TextField, add PolygonLayer for rectangles
- @lib/router.dart - Add grid FAB between goto and info FABs
  - make the grid FAB use the same left-positioned tooltip/semantics wrapper pattern as the import and show tracks FABs

**Patterns to follow:**
- Use existing CircleLayer pattern for rectangles (PolygonLayer)
- Use existing goto input field pattern
- Use existing FAB toggle pattern in router.dart

**Phase 4a approach:**
1. Add map name parsing in parseGridReference when input has no coordinates (single word, no digits)
2. Use mgrs_dart to convert: 55G + mgrs100kId + centerEasting + centerNorthing → LatLng center
3. Calculate center easting: (eastingMin + eastingMax) / 2, northing: (northingMin + northingMax) / 2
4. Use mapController.camera.fit() with LatLngBounds to zoom to extents with 10% padding
5. Use PolygonLayer to draw blue rectangle around map boundary

**Phase 4b approach:**
1. Add FAB with Icons.grid_on
2. 'M' key handler for toggle
3. On toggle: load all maps, create rectangles from each map's ranges
4. Draw all rectangles with PolygonLayer
5. Add text labels for name + series (use static labels or Annotations)

**What to avoid:**
- Don't use CircleLayer for rectangles (use PolygonLayer)
- Don't close goto input automatically on map name match (keep open for corrections)
- Don't block UI during rectangle generation (65 maps is small)
</implementation>

<validation>
**Test Strategy - Phase 4a:**
1. Unit test: parseGridReference with "Wellington" returns center location
2. Unit test: parseGridReference with "Mount Field" handles spaces
3. Unit test: map name not found returns error
4. Unit test: case insensitive "wellington" matches "Wellington"
5. Unit test: partial name "Welling" shows dropdown with matching maps
6. Unit test: exact match "Wellington" auto-selects without dropdown
7. Widget test: goto input shows dropdown on partial match
8. Widget test: goto input rectangle appears after selection
9. Widget test: blue rectangle visible at zoom level 8
10. Integration test: enter "Wellington", map zooms to fit, rectangle visible

**Test Strategy - Phase 4b:**
1. Widget test: grid FAB toggles overlay
2. Widget test: 'M' key toggles overlay
3. Widget test: all 65 rectangles visible in grid view
4. Widget test: map name + series shown on each rectangle
5. Widget test: tap other FAB closes grid overlay

**Default test split:**
- Robot tests: critical happy path for both Phase 4a and 4b (goto by name → zoom to fit → rectangle visible)
- Widget tests: screen-level edge cases (cancel, retry, validation errors, overlay toggle)
- Unit tests: business logic (map name parsing, center calculation, range handling)
</validation>

<done_when>
**Phase 4a:**
- [x] Goto accepts map name only (e.g., "Wellington")
- [x] Map centers on selected map
- [x] Map zooms to fit with padding
- [x] Blue rectangle shows map boundary
- [x] Rectangle visible at all zoom levels
- [x] Error message for unknown map

**Phase 4b:**
- [x] Grid FAB (Icons.grid_on) visible between goto and info
- [x] Tap FAB shows all map rectangles
- [x] Blue rectangles around all maps
- [x] Map name + series shown on each rectangle
- [x] 'M' key toggles overlay
- [x] Tap other FAB closes overlay

**Validation:**
- [x] Tests pass
- [x] App builds successfully
</done_when>
