# Features to add
- [ ] Setup private OSM tileserver - use versatiler?
- [ ] investigate use of maplibre
- [ ] investigate openSnowMap, openTopoMap, sletuffe/openTopoMap and openHikingMap
- [ ] update peak search results to show map/area
- [ ] update search for advanced search: peaks between/below/above a certain height, within a certain area etc.
- [ ] Add database of all natural features, roads, cities and tracks.
- [ ] Add filter for the above
- [ ] Allow search for the above
- [ ] Add an overlay to display features names on hover - only for blue circles
- [ ] Remove legacy handling
- [ ] fix all SI units to have space in front of the unit.
- [ ] Check for internet connection before tile downloads
- [ ] Do not show failed http tile request

## Folder Structure
- [ ] Update to canonical folder Structure:
  - Bushwalking / PeakLists
  - Bushwalking / Features
  - Bushwalking / GPS
  - Bushwalking / GPS / Country / State (Region etc.) / Tracks
  - Bushwalking / GPS / Country / State (Region etc.) / Routes
  - Bushwalking / GPS / Country / State (Region etc.) / Waypoints

## Shared Services
- [ ] move number formatters from map_screen_panels to number_formatters.dart and consolidate
## Dashboard
- [ ] header text to be constant - expanded???
- [ ] change dropdown and make it similar in all the app.
- [ ] Add a summary card for year to date. Total km, ascent, peaks, walks etc.

## 2  Display map of Tasmania with zoom, pan and search function
- [ ] change zoom level display to actual distance
- [ ] Automatically ask for permissions
- [ ] implement smooth panning and scrolling. When clicking, smooth transition from one level to another.
- [ ] On max zoom exceeded for a given map switch to tracestrack
- [ ] Set min zoom to 4 and max zoom to 24.
- [ ] add go to feature - add to goto location?

## 3 Tasmanian Peaks and search
- [ ] update go to location  to accept UTM coordionates
- [ ] add My Ascents to peak info popup

## 4 Add Maps and location search
- [ ] Add min-max zooms to objectBox
- [ ] Reset the id on Reset Map Data
- [ ] Allow peak info to be show in blue circle on hover
- [ ] Clicking x on peak search clears blue circles
- [ ] Clicking in blue circle selects peak and clears blue circles
- [ ] Peak search not zooming to extents
- [ ] Fix mgrs jank
- [ ] add Map name to mgrs display
- [ ] Add a current peak list display under the mgrs

## 5 Gpx Tracks
- [ ] change import behaviour to only import from Tracks once application is complete.
- [ ] Add ObjectBox field detailing filter options
- [ ] Set filter on a per track level
- [ ] confirm where repair Track is used.
- [ ] move peak correlation to GpsImporter
- [ ] Confirm that peak correlation for mass import does not drop tracks for which there is no peak
- [ ] class GpxTrackImportResult change to GpxFileImportResult  to cater for routes and waypoints
- [ ] Fix date display for track info - incorrect date being calculated

### Speed
- [ ] averageSpeed
- [ ] movingSpeed
- [ ] maxSpeed30s
- [ ] maxSpeed1m
- [ ] maxSpeed3m
- [ ] maxSpeed5m
- [ ] ascentSpeed
- [ ] descentSpeed

### Time
- [x] totalTimeMillis (int?) - future, null for now (Duration stored as milliseconds)
- [x] movingTime
- [x] restingTime
- [ ] Time calculation are not working as expected.
### Climbs
- [ ] climbs

## Peak Lists
- [ ] Update dialogue to say import new list or update list
- [ ] remove legacy row handling
- [ ] Refresh lists on updates to peak name in ObjectBox Admin
- [ ] peak lists not updating on track import correlation
- [ ] peak lists not updating on change of peak details
- [ ] Change cursor on hover over clickables
- [x] Add peak info functionality as per map_screen
- [ ] Mini map - add +/- zoom keys
- [ ] Change details view header to Peak Name
- [ ] Remove points column
- [x] Selected row use primaryContainer as background and 5c47cd for dividers

 mgrs.Mgrs.toPoint can produce long decimal values (lib/services/peak_admin_editor.dart:175-178) change to 6 digits.

## Object Box Admin
- [ ] Allow entry of UTM coordinates
- [ ] add x in text field to clear it

F14. Add app-wide peak search, peak list selection widgets, and Peak Lists screen display out of scope for this iteration unless they are directly needed by the clicked-peak popup change.

## Settings
- [ ] Add a help dialogue to explain what the adjustable settings mean.
- [ ] Add retry in settings for gpx files that failed folder relocation
- [ ] Add Settings option to change track display - colour, thickness, outline etc.
- [ ] Add track opacity for non-selected tracks

### CSV export/import
- [ ] Update csv import to match export

## Routing
- [ ] implement routing using trip_routing (pub.dev/packages/trip_routing)

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
tba - layers
tba - show my position
b - basemaps
c - centre on selection
g - go to marker
m - enable map grid
s - feature search/goto location
t - tracks
i - info
