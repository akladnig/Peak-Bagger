# Goal
Optimize code in map screen to remove jank on pan and zoom.
Use the findings below to generate a spec.

## Initial Discovery Prompt
Review the code for pan and zoom in the map screen and advise what can be done to optimize the code as it is a bit janky

## Findings
1. High: MapScreen.build is scheduling a controller sync on every rebuild, including rebuilds caused by pan/zoom itself. lib/screens/map_screen.dart:376-392 calls _mapController.move(mapState.center, mapState.zoom) from a post-frame callback whenever syncEnabled is true. During a drag/zoom, onPositionChanged updates provider state (lib/screens/map_screen.dart:621-629), which rebuilds the screen, which then schedules another move to the same camera state. That feedback loop is a strong candidate for visible jank.
2. High: camera updates are being persisted to SharedPreferences on the hot interaction path. updatePosition immediately calls savePosition() (lib/providers/map_provider.dart:1133-1144), and savePosition() does SharedPreferences.getInstance() plus multiple writes (lib/providers/map_provider.dart:1103-1119). That happens from gesture-driven paths like onPositionChanged (lib/screens/map_screen.dart:621-629), trackpad zoom updates (lib/screens/map_screen.dart:319-349), and keyboard scrolling (lib/screens/map_screen.dart:955-962). Persisting on every frame is much too expensive.
3. High: hover and cursor state are routed through the same global MapState, so pointer movement can rebuild the whole map screen. MapScreen watches the entire provider (lib/screens/map_screen.dart:367-369), while hover paths call setCursorMgrs, setHoveredPeakId, and setHoveredTrackId from onPointerHover (lib/screens/map_screen.dart:208-255, 613-619; lib/providers/map_provider.dart:1231-1233, 1266-1275, 1326-1335). Because MapState is a plain class without value equality (lib/providers/map_provider.dart:66-294), each copyWith produces a new state object and forces dependents to rebuild even when the effective value is unchanged.
4. Medium: the track rendering path repeatedly decodes cached geometry on interactive frames. GpxTrack.getSegmentsForZoom() decodes displayTrackPointsByZoom JSON every call (lib/models/gpx_track.dart:165-171, 197-247). That is used both for drawing tracks (lib/screens/map_screen_layers.dart:184-215) and for hover hit testing (lib/screens/map_screen.dart:267-289). With several tracks loaded, this creates avoidable JSON parsing and allocation during pan/zoom/hover.
5. Medium: hover hit-testing rebuilds projected candidate lists from scratch on every pointer move. Peaks are reprojected in _buildPeakHoverCandidates (lib/screens/map_screen.dart:183-206), and track segments are reprojected in _buildTrackHoverCandidates (lib/screens/map_screen.dart:257-293). Also, when the pointer is not over a peak, setCursorMgrs is called twice per hover event: once in _handleMapHover and again in _handleTrackHover (lib/screens/map_screen.dart:214-220, 228-229). That is extra state churn right in the interaction loop.
What To Change First
1. Remove _mapController.move(...) from the post-frame callback in build. Only push controller updates when state changes originate outside the map widget, and guard against no-op camera updates.
2. Stop calling savePosition() from updatePosition(). Persist on gesture end, move-end/zoom-end, app pause, or with a short debounce.
3. Split transient interaction state out of the main map provider. cursorMgrs, hoveredPeakId, and hoveredTrackId should not force the full MapScreen tree to rebuild. Use smaller providers, local state, or select(...)-based consumers.
4. Add no-op guards and/or value equality to MapState updates so repeated identical values do not notify listeners.
5. Cache decoded track geometry once per track instead of decoding JSON in getSegmentsForZoom() on every use.
6. Cache projected hover candidates per camera revision, or recompute them only when camera/zoom changes, not on every mouse move.
Likely Impact
1. The first two changes should give the biggest improvement immediately.
2. The provider split and geometry caching should make desktop hover and large-track scenarios much smoother.
3. If peak counts are large, the next step after that is reducing MarkerLayer rebuild pressure or moving peak rendering/hit-testing to a more cache-friendly layer.
Testing Gap
Static review only. I did not profile a running build, so I’d confirm with Flutter DevTools by checking:
1. widget rebuild counts while dragging,
2. timeline events around SharedPreferences,
3. CPU time in JSON decode / hover projection paths.
