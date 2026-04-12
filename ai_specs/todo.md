# Features to add
- [ ] tiles not being saved
- [ ] update spec - check assets folder first only download if required.
- [ ] Setup private OSM tileserver - use versatiler?
- [x] goto location should use map name or mgrs two-letter pair
- [x] use hand icon (font awesome hand) for normal cursor movement, closed hand (hand-back-fist) for grab and drag
- [ ] investigate use of maplibre
- [ ] investigate use of listmaps
- [ ] update peak search results to show map/area
- [ ] update search for advanced search: peaks between/below/above a certain height, within a certain area etc.
- [x] update search results so that blue circles drawn around matching peaks. Zoom out to view all peaks on search completion.
- [ ] Add database of all natural features, roads, cities and tracks.
- [ ] Add filter for the above
- [ ] Allow search for the above
- [ ] Add an overlay to display features names on hover - only for blue circles

## 1 Application Skeleton
## 2  Display map of Tasmania with zoom, pan and search function
- [ ] Change two finger from pan to zoom
- [ ] change zoom level display to actual distance
- [ ] Automatically ask for permissions
## 3 Tasmanian Peaks and search
## 4 Add Maps and location search
- [x] place info popup to right of marker
- [x] add info fab
- [x] Wrong map shown on info
- [x] Peak info not being displayed
- [ ] Do not re-import Tasmap on every launch.
- [ ] disable 2 finger map rotation
- [ ] get filename from gpx track name
- [ ] fix "&amp;"
- [ ] update tooltips - Goto Location, Show Map Grid 
## 4a
- [x] add go to map only, centre on map and zoom to map extents, and draw a blue rectangle around the map extents so that the map can be seen when zooming out.
- [ ] Add show maps - a blue grid of all maps. Map name and series to be shown at bottom right of each map.
## 5
- [ ] implement gpx track import - multiple file import or just scan default folder.
- [ ] distance (double?) - future, null for now
- [ ] ascent (double?) - future, null for now
- [ ] totalTimeMillis (int?) - future, null for now (Duration stored as milliseconds)

# Keyboard Mapping
## Menu
d - dashboard
m - map
p - peak
tba - settings

## Global
h,j,k,l - vim motion
t - theme toggle
i - info

## Map Screen
-,+, _, = - zoom
s - feature search
tba - layers
tba - show my position
g - go to marker
m - enable map grid
i - info


# Errors
- [x] Zoom display not updating
- [x] keyboard keys should change focus to search boxes
- [x] duplicate peak search
- [x] peaks not showing
