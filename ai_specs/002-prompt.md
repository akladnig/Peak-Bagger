# Peak Bagger App

- Before implementing this Phase 2 confirm Phase 1 is complete.

### Phase 2
Display map of Tasmania with zoom and pan function.
- Display map in the map sreen
- In full screen mode, the map should zoom to approximately 8 km wide by 5 km high. Set this as the default zoom level.
- On first launch pan and zoom to current location using the default zoom level. Subsequent launches to go to last viewed location.
- Default location for subsequent launches is the previously used location.
- On first launch zoom to default zoom level.
- use https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=APIKEY as the default basemap.
- APIKEY= 8bd67b17be9041b60f241c2aa45ecf0d
- use OpenStreetMap. url is https://tile.openstreetmap.org/{z}/{x}/{y}.png. Allow selection of this map and other future maps using the Layers icon (Icons.stacks).
- Add a floating Layers icon below the go to Location icon to allow selection of basemap.
- Save the Open Street Map tiles to the assets/OSM_standard folder locally so that it can be used offline.
- Save the tracestrack Map tiles to the assets/OSM_tracestrack folder locally so that it can be used offline.

- Add a floating Show My Location icon (Icons.near_me) at the top right of the map to go to the current location.
- Then add a floating Goto Location icon (Icons.moved_location) below. This calls a text box which accepts a 6 or 8 digit grid reference.
- The 6 or 8 digit grid reference may be seperated by a space in the middle of the grid reference e.g. 123 456, 1234 5678
- When clicking on the Show My Location icon or Goto Location icon, set the zoom level to default.
- The grid reference needs to be converted to lat/long

- Zoom controls: +, -, [, ], <, >, ",", "." keys
- Pan controls: use VIM bindings h,j,k,l and up, down, left, right arrow keys.
- Show My Location control: s key
- Goto Location control: g key
- Pinch-to-zoom and drag-to-pan
- 
Dependencies:
flutter_map ^8.2.2
