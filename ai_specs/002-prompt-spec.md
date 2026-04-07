<goal>
Phase 2 of Peak Bagger app - Display interactive map of Tasmania with multiple basemaps, location services, and grid reference navigation.

Target users: Mountain enthusiasts who want to view and navigate maps while peak bagging in Tasmania.

MacOS-only (continuing from Phase 1).
</goal>

<background>
**Tech Stack:**
- Flutter with Dart SDK ^3.11.4
- flutter_map ^8.2.2 for map display
- geolocator ^14.0.2 for GPS location
- mgrs_dart ^3.0.0 for MGRS coordinate conversion
- Existing: go_router, shared_preferences, flutter_riverpod, font_awesome_flutter

**Existing Code:**
- @lib/screens/map_screen.dart - Current placeholder
- @lib/router.dart - Navigation setup
- @lib/providers/theme_provider.dart - Theme state

**Map Configuration:**
- Default center: Tasmania (approx -41.5°S, 146.5°E)
- Default zoom: ~8km wide x 5km high (roughly zoom level 10-11)
- Basemaps: Tracestrack topo (default), OpenStreetMap (alternative)

**Files to modify:**
- @lib/screens/map_screen.dart - Implement map with all controls
- @pubspec.yaml - Add flutter_map, geolocator, mgrs_dart dependencies

**Assets to create:**
- @assets/OSM_standard/ - Cached OpenStreetMap tiles
- @assets/OSM_tracestrack/ - Cached Tracestrack tiles
</background>

<user_flows>
Primary flow:
1. User taps Map in side menu
2. Map loads with default basemap (Tracestrack)
3. On first launch: center on current location (or Tasmania default if unavailable)
4. User can pan/zoom using touch or keyboard
5. User can switch basemaps via Layers icon
6. User can go to current location via My Location icon
7. User can enter grid reference to go to specific location

Alternative flows:
- First launch: No location permission → use default Tasmania view
- Offline mode: Use cached tiles if network unavailable
- Invalid grid reference: Show error, keep current position

Error flows:
- No internet: Show cached tiles or error message
- Location permission denied: Show message, allow manual entry
- Invalid grid reference: Show "Invalid grid reference" message
</user_flows>

<requirements>
**Functional:**
1. Display interactive map using flutter_map
2. Default zoom level showing ~8km wide x 5km high (zoom ~11)
3. On first launch: zoom to current location, default zoom level
4. Subsequent launches: restore last viewed position and zoom
5. Default basemap: Tracestrack topo (https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=8bd67b17be9041b60f241c2aa45ecf0d)
6. Alternative basemap: OpenStreetMap (https://tile.openstreetmap.org/{z}/{x}/{y}.png)
7. Floating Layers icon to switch between basemaps
8. Current MGRS location displayed as overlay text at top-left of map
9. Save tiles to assets folder for full offline mode (do not use built-in caching)
10. Separate folder under assets for each distinct tile set
11. Future: tiles will be saved in database
12. Floating Show My Location icon (Icons.near_me) - goes to current GPS location
13. Floating Go to Location icon (Icons.moved_location) - accepts 6 or 8 digit grid reference
14. Grid reference may have space in middle (e.g., "123 456" or "1234 5678")
15. Convert grid reference to lat/long for map positioning

**Keyboard Controls:**
16. Zoom in: + key
17. Zoom out: - key
18. Zoom in: , key
19. Zoom out: . key
20. Zoom in: < key
21. Zoom out: > key
22. Pan up: k or Up arrow
23. Pan down: j or Down arrow
24. Pan left: h or Left arrow
25. Pan right: l or Right arrow
26. Show My Location: s key
27. Go to Location: g key

**Touch Controls:**
28. Pinch-to-zoom
29. Drag-to-pan

**Persistence:**
30. Save last viewed position (lat, lng, zoom) to shared_preferences
31. Load saved position on app launch

**Error Handling:**
32. Invalid grid reference: Show error message, keep current position
33. Location permission denied: Show message, allow manual grid reference entry
34. No internet: Use cached tiles or show error
</requirements>

<boundaries>
Edge cases:
- First launch with no saved position: Use current location or default to Tasmania center
- Invalid grid reference: Display error, maintain current map position
- Location services unavailable: Fall back to saved position or default location
- Network unavailable: Use cached tiles, show offline indicator

Error scenarios:
- No GPS permission: Prompt user, allow grid reference entry instead
- Malformed grid reference: "Invalid grid reference" message
- Tile loading failure: Show error tile or fallback to cached version

Limits:
- Grid reference must be 6 or 8 digits (with optional space)
</boundaries>

<implementation>
**Patterns:**
- Use flutter_map for display (not Google Maps due to licensing)
- Use geolocator package for GPS location
- Use mgrs_dart for MGRS to lat/long conversion
- StateNotifier for map state (position, zoom, basemap)
- Load tiles from assets folder for full offline mode
- Each tile set in separate folder under assets

**Files to modify:**
- @pubspec.yaml - add flutter_map ^8.2.2, geolocator ^14.0.2, mgrs_dart ^3.0.0, declare assets
- @lib/screens/map_screen.dart - full map implementation
- @lib/providers/map_provider.dart - new state management

**To avoid:**
- Don't use Google Maps (requires API key, licensing issues)
- Don't use built-in flutter_map tile caching

**Note**: Assets must be declared in pubspec.yaml:
```yaml
flutter:
  uses-material-design: true
  assets:
    - assets/OSM_standard/
    - assets/OSM_tracestrack/
```
</implementation>

<discovery>
**Questions to answer:**
- How to implement MGRS grid reference to lat/long conversion?
  - Use mgrs_dart package (confirmed in dependencies)

**Patterns to research:**
- flutter_map keyboard interaction handling
- Geolocator permission handling on macOS
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
- Tiles load from assets folder for offline use
- Last viewed position persists across app restarts
- All tests pass
</done_when>