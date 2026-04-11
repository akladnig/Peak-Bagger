<goal>
Phase 2 of Peak Bagger app - Display interactive map of Tasmania with multiple basemaps, location services, and grid reference navigation.

Target users: Mountain enthusiasts who want to view and navigate maps while peak bagging in Tasmania.

MacOS-only (continuing from Phase 1).
</goal>

<background>
**Tech Stack:**
- Flutter with Dart SDK ^3.11.4
- flutter_map ^8.2.2 for map display
- geolocator ^14.0.0 for GPS location service
- mgrs_dart ^2.0.0 for MGRS coordinate conversion
- Existing: go_router, shared_preferences, flutter_riverpod, font_awesome_flutter

**macOS Location Configuration:**
- Entitlements: Add `com.apple.security.personal-information.location` to both DebugProfile.entitlements and Release.entitlements
- Info.plist: Add NSLocationUsageDescription to explain why app needs location

**Existing Code:**
- @lib/screens/map_screen.dart - Current placeholder
- @lib/router.dart - Navigation setup
- @lib/providers/theme_provider.dart - Theme state

**Map Configuration:**
- Default center: Tasmania (approx -41.5°S, 146.5°E)
- Default zoom: ~8km wide x 5km high (roughly zoom level 15)
- Basemaps: Tracestrack topo (default), OpenStreetMap (alternative)
- Tiles: Loaded from network only. Tile download service exists at lib/services/tile_downloader.dart for future offline capability (out of scope for Phase 2).

**Files to modify:**
- @lib/screens/map_screen.dart - Implement map with all controls
- @pubspec.yaml - Add flutter_map, mgrs_dart dependencies

**Note:** Asset folders declared in pubspec.yaml are unused in Phase 2 (reserved for future offline capability).
</background>

<user_flows>
Primary flow:
1. User taps Map in side menu
2. Map loads with default basemap (Tracestrack)
3. On first launch of app AND first time visiting map screen: center on current location (or Tasmania default if unavailable)
4. User can pan/zoom using touch or keyboard
5. User can switch basemaps via Layers icon
6. User can go to current location via My Location icon
7. User can enter grid reference to go to specific location

Alternative flows:
- First launch of app AND first time visiting map screen: No location permission → use default Tasmania view
- Invalid grid reference: Show error, keep current position

Error flows:
- No internet: Show error message (offline tiles out of scope for Phase 2)
- Location permission denied: Show message, allow manual entry
- Invalid grid reference: Show "Invalid grid reference" message
</user_flows>

<requirements>
**Functional:**
1. Display interactive map using flutter_map
2. Default zoom level showing ~8km wide x 5km high (zoom ~15)
3. On first launch of app AND first time visiting map screen: zoom to current location, default zoom level
4. Subsequent launches: restore last viewed position and zoom
5. Default basemap: Tracestrack topo (https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=8bd67b17be9041b60f241c2aa45ecf0d)
6. Alternative basemap: OpenStreetMap (https://tile.openstreetmap.org/{z}/{x}/{y}.png)
7. Floating Layers icon to switch between basemaps - opens Drawer widget sliding from right side of screen. Floating action buttons use background color: surface, icon color: onSurface.
8. Current MGRS location displayed as overlay text at top-left of map using standard MGRS format:
   - Format: [Grid Zone][100km Square]\n[Easting] [Northing] with first 3 digits of easting/northing bolded
   - Example: "55G FN\n00000 00000" where 000 and 000 are bold
 9. MGRS display updates in three scenarios:
    a. User taps/clicks on map: show MGRS of tapped location (do not center map), set selected location
    b. User enters grid reference via Go to Location: show converted MGRS of destination, set selected location
    c. User taps Show My Location: show current GPS location as MGRS, set selected location
10. On finger movement: show MGRS at finger position in real-time. Drag does not update MGRS. Cursor icon: grab (open hand) normally within map region, hand-back-fist (grabbing) during drag. Normal arrow cursor on all other screens and UI elements (buttons, navigation bars, FABs, etc.).
11. Selected location shown on map with Icons.my_location marker, colored gold. Selected location is set when user taps/clicks on map (9a), enters grid reference (9b), or taps Show My Location (9c). On first view of map, marker displayed at default center location.
12. Future: offline tile caching (out of scope for Phase 2)
13. Floating Show My Location icon (Icons.near_me) - goes to current GPS location
15. Floating Center on Marker icon (Icons.my_location, colored gold) - centers map on selected location
16. Floating Go to Location icon (Icons.directions) - opens floating text input field
17. All floating action buttons use background color: surface, icon color: onSurface (except Center on Marker which uses gold icon)
16. Floating input field UI: TextField with "Go to location" placeholder, "Go" button to navigate, "X" button to close
17. Clicking "X" closes input field and stays at current map position (no navigation)
18. Input validation:
    - Show "Invalid grid reference" error below field if format invalid
    - Keep input field open while validation fails
    - Clear error message when user starts typing again
19. Grid reference format: optional grid zone + 6 or 8 digit coordinates with optional space (e.g., "55G 123 456", "55G 12345678", "123456", "1234 5678")
20. If grid zone not provided, default to zone 55G (Tasmania)
21. Convert grid reference to lat/long for map positioning

**Keyboard Controls:**
22. Map does not need focus. When any keyboard shortcut key is pressed, automatically give focus to map and perform the action.
23. Zoom in: + key
24. Zoom out: - key
25. Zoom out: , key
26. Zoom in: . key
27. Zoom in: < key
28. Zoom out: > key
29. Pan up: k or Up arrow
30. Pan down: j or Down arrow
31. Pan left: h or Left arrow
32. Pan right: l or Right arrow
33. Open Layers (basemap selector): b key
34. Show My Location: s key
35. Go to Location: g key
36. Center on Marker: c key

**Touch Controls:**
35. Pinch-to-zoom
36. Drag-to-pan
37. Right click: Center on selected location (gold marker) [two-finger click on trackpad]
37. Zoom level indicator at lower-left of map (e.g., "zoom: 15" or scale bar)

**Persistence:**
38. Save last viewed position to shared_preferences using keys: `map_position_lat`, `map_position_lng`, `map_zoom`
39. Save basemap selection to shared_preferences: `basemap_selection` key (values: 'tracestrack', 'openstreetmap')
40. Load saved position and basemap on app launch
41. Future: Tile caching and offline download (out of scope for Phase 2)

**Error Handling:**
42. Invalid grid reference: Show error message, keep current position
43. Location permission denied: Show message, allow manual grid reference entry
44. Location permission: Request on first tap of Show My Location icon or first tap on map screen
45. No internet: Use cached tiles or show error
46. Tile loading: Show spinner overlay while tiles load
47. Tile loading failure: Show error message with "Retry" button, allow fallback to cached tiles
</requirements>

<boundaries>
Edge cases:
- First launch of app AND first time visiting map screen with no saved position: Use current location or default to Tasmania center
- Invalid grid reference: Display error, maintain current map position
- Location services unavailable: Fall back to saved position or default location
- Network unavailable: Use cached tiles, show offline indicator
- Malformed grid reference: "Invalid grid reference" message
- Tile loading failure: Show error tile or fallback to cached version

Limits:
- Grid reference: optional grid zone (e.g., "55G") + 6 or 8 digits + optional space (e.g., "55G 123 456", "123456", "1234 5678"). If no zone provided, default to 55G.
</boundaries>

<implementation>
**Patterns:**
- Use flutter_map for display (not Google Maps due to licensing)
- Use IP-based location service for current location
- Use mgrs_dart for MGRS to lat/long conversion
- Use Notifier/NotifierProvider for map state (position, zoom, basemap)
- Load tiles from network only (no offline caching in Phase 2)

**Files to modify:**
- @pubspec.yaml - add flutter_map ^8.2.2, mgrs_dart ^2.0.0
- @lib/screens/map_screen.dart - full map implementation
- @lib/providers/map_provider.dart - new state management

**To avoid:**
- Don't use Google Maps (requires API key, licensing issues)
- Don't use built-in flutter_map tile caching
- Don't use asset-based tiles for Phase 2 (future offline capability only)
</implementation>

<discovery>
**Questions to answer:**
- How to implement MGRS grid reference to lat/long conversion?
  - Use mgrs_dart package (confirmed in dependencies)

**Patterns to research:**
- flutter_map keyboard interaction handling
- Loading tiles from assets folder with flutter_map
</discovery>

<validation>
**Unit tests:**
- Grid reference parser: 6-digit, 8-digit, with/without space
- Map state: save/load position from SharedPreferences

**Widget tests:**
- MapScreen: Renders with correct default zoom/position
- Basemap switching: Works correctly
- Location icons: Visible and functional

**Integration tests:**
- Map loads on navigation from side menu
- Keyboard shortcuts work (zoom, pan, location)
- Position persists across app restart

**Baseline automated coverage:**
- Logic: Grid reference parsing, position persistence
- UI: Map rendering, floating controls visibility
- Journey: Load map → pan/zoom → switch basemap → go to location
</validation>

<done_when>
- Map screen displays interactive map of Tasmania
- Default zoom shows ~8km x 5km area
- Current MGRS location shown as overlay text at top-left
- Touch controls work (pinch zoom, drag pan)
- Keyboard controls work (vim bindings, arrows, +/-)
- Floating icons visible: Show My Location, Go to Location, Layers
- Can switch between Tracestrack and OpenStreetMap basemaps
- Grid reference entry works for 6 and 8 digit references
- Basemap selection persists across app restarts
- Last viewed position persists across app restarts
- All tests pass
</done_when>