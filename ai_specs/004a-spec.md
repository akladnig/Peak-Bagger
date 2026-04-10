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
</background>

<user_flows>
**Phase 4a - Go to Map by Name**

Primary flow:
1. User taps goto FAB or presses 'G' key
2. Goto input field appears
3. User enters map name only (e.g., "Wellington")
4. User presses Enter
5. System looks up map in database by name
6. System constructs MGRS center from map's easting/northing ranges
7. Map centers on the map's center location
8. Map zooms to fit map extents with padding
9. Blue rectangle drawn around map boundary

Alternative flows:
- Map name with spaces: "Mount Field" → same as "MountField"
- Case insensitive: "WELLINGTON" → "Wellington"
- Partial name: "Wellington" matches starts-with
- Partial match: Show dropdown with matching maps, user selects one

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
2. 'M' key toggles map overlay
3. All maps displayed with blue rectangles
4. Map name + series shown at bottom-right of each rectangle
5. Overlay closes when any other FAB is tapped

**Error Handling:**
9. Map not found: "Map not found: [name]" error below goto input
10. No maps in database: Show info message, continue without overlay
11. Invalid coordinates in map data: Skip invalid maps, log warning

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
- @lib/providers/map_provider.dart - Add map selection state, parse map name goto, add mapOverlayMode state
- @lib/services/tasmap_repository.dart - Add getAllMaps() if not exists, method to get map center
- @lib/screens/map_screen.dart - Add PolygonLayer for map rectangles, update on map name goto
- @lib/router.dart - Add grid FAB between goto and info FABs

**Patterns to follow:**
- Use existing CircleLayer pattern for rectangles (PolygonLayer)
- Use existing goto input field pattern
- Use existing FAB toggle pattern in router.dart

**Phase 4a approach:**
1. Add map name parsing in parseGridReference when input has no coordinates
2. Calculate map center: (eastingMin + eastingMax) / 2, (northingMin + northingMax) / 2
3. Use CameraFit to zoom to map extents with padding
4. Use PolygonLayer to draw blue rectangle around map boundary

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