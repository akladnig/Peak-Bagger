# Peak Bagger App

- Before implementing this Phase 2 confirm Phase 1 is complete.

### Phase 2
Display map of Tasmania with zoom, pan and search function.
- Display map in the map sreen
- In full screen mode, the map should zoom to approximately 8 km wide by 5 km high. Set this as the default zoom level.
- On first launch pan and zoom to current location using the default zoom level. Subsequent launches to go to last viewed location.
- Default location for subsequent launches is the previously used location.
- On first launch zoom to default zoom level.
- use https://tile.tracestrack.com/topo__/{z}/{x}/{y}.webp?key=APIKEY as the default basemap.
- use OpenStreetMap. url is https://tile.openstreetmap.org/{z}/{x}/{y}.png. Allow selection of this map using the layers icon.
- APIKEY= 8bd67b17be9041b60f241c2aa45ecf0d
- Add a floating layers icon below the go to location icon to allow selection of basemap.
- Save the Open Street Map tiles to the assets/OSM_standard folder locally so that it can be used offline.
- Save the tracestrack Map tiles to the assets/OSM_tracestrack folder locally so that it can be used offline.

- Add a floating location icon at the top right of the map to go to the current location.
- Then add a floating goto location icon below which accepts a 6 or 8 digit grid reference.
- When clicking on the location icon or floating location icon, set the zoom level default.
- The grid reference needs to be converted to lat/long

Dependencies:
flutter_map ^8.2.2
