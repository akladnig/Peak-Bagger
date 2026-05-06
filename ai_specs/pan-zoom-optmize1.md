# Goal
Optimize code in map screen to remove jank on pan and zoom.
Use the findings below to generate a spec.

## Initial Discovery Prompt
Review the code for pan and zoom in the map screen and advise what can be done to optimize the code as it is a bit janky

## Findings
1. High: MapScreen.build is scheduling a controller sync on every rebuild, including rebuilds caused by pan/zoom itself. lib/screens/map_screen.dart:376-392 calls _mapController.move(mapState.center, mapState.zoom) from a post-frame callback whenever syncEnabled is true. During a drag/zoom, onPositionChanged updates provider state (lib/screens/map_screen.dart:621-629), which rebuilds the screen, which then schedules another move to the same camera state. That feedback loop is a strong candidate for visible jank.
What To Change First
1. Remove _mapController.move(...) from the post-frame callback in build. Only push controller updates when state changes originate outside the map widget, and guard against no-op camera updates.
