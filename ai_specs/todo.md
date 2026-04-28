# Features to add
- [ ] tiles not being saved
- [ ] update spec - check assets folder first only download if required.
- [ ] Setup private OSM tileserver - use versatiler?
- [x] goto location should use map name or mgrs two-letter pair
- [x] use hand icon (font awesome hand) for normal cursor movement, closed hand (hand-back-fist) for grab and drag
- [ ] investigate use of maplibre
- [x] investigate use of listmaps
- [ ] update peak search results to show map/area
- [ ] update search for advanced search: peaks between/below/above a certain height, within a certain area etc.
- [x] update search results so that blue circles drawn around matching peaks. Zoom out to view all peaks on search completion.
- [ ] Add database of all natural features, roads, cities and tracks.
- [ ] Add filter for the above
- [ ] Allow search for the above
- [ ] Add an overlay to display features names on hover - only for blue circles
- [ ] Remove legacy handling

## Folder Structure
- [ ] Update to canonical folder Structure:
  - Bushwalking / PeakLists
  - Bushwalking / Features
  - Bushwalking / GPS
  - Bushwalking / GPS / Country / State (Region etc.) / Tracks
  - Bushwalking / GPS / Country / State (Region etc.) / Routes
  - Bushwalking / GPS / Country / State (Region etc.) / Waypoints

## 1 Application Skeleton

## 2  Display map of Tasmania with zoom, pan and search function
- [ ] Change two finger from pan to zoom
- [ ] disable 2 finger map rotation
- [ ] change zoom level display to actual distance
- [ ] Automatically ask for permissions
- [ ] implement smooth paning and scrolling. When clicking, smooth transition from one level to another.
- [ ] On max zoom exceeded for a given map switch to tracestrack
- [ ] Set min zoom to 4 and max zoom to 24.
- [ ] add go to feature - add to goto location?
- [x] bug - click on map no longer sets marker
- [x] Add a new data source - geocode Area

## 3 Tasmanian Peaks and search
- [ ] Add a tooltip when a peak is hovered over to display info
- [ ] Add an altName to peak entity
- [x] Make peak marker a bit smaller
- [ ] update go to location  to accept UTM coordionates

## 4 Add Maps and location search
- [x] place info popup to right of marker
- [x] add info fab
- [x] Wrong map shown on info
- [x] Peak info not being displayed
- [x] Do not re-import Tasmap on every launch.
- [x] update tooltips - Goto Location, Show Map Grid
- [x] click on I toggles
- [ ] Add min-max zooms to objectBox
- [ ] Reset the id on Reset Map Data
- [ ] when clicking on track open a left drawer with info about the track

## 4a
- [x] add go to map only, centre on map and zoom to map extents, and draw a blue rectangle around the map extents so that the map can be seen when zooming out.
- [x] Add show maps - a blue grid of all maps. Map name and series to be shown at bottom right of each map.
- [x] Change map drawing from rectangle to a polygon.

## 5 Gpx Tracks
- [ ] implement gpx track import - multiple file import.
- [ ] change import behaviour to only import from Tracks once application is complete.
- [x] use geo.dart, ported from gpxpy.
- [ ] Add option to view raw data
- [x] Highlight track on click
- [x] Add filter options to none
- [ ] Add ObjectBox field detailing filter options
- [ ] Set filter on a per track level
- [ ] confirm where repair Track is used.
- [ ] move peak correlation to GpsImporter
- [ ] Confirm that peak correlation for mass import does not drop tracks for which there is no peak
- [ ] class GpxTrackImportResult change to GpxFileImportResult  to cater for routes and waypoints
- [ ] Add retry in settings for gpx files that failed folder relocation

### Distance
- [x] distance (double?) - future, null for now
- [x] Distance to Peak, Distance from Peak

### Elevation 
- [x] ascent (double?) - future, null for now
- [x] descent
- [x] elevationProfile
- [x] startElevation
- [x] endElevation
- [x] lowestElevation
- [x] highestElevation
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

- [x] add to spec and implement distance3d algorthims as per gpxpy: https://github.com/tkrajina/gpxpy/blob/dev/gpxpy/geo.py

## Peak Lists
- [ ] Add import waypoints
- [x] csv import - cater for missing lat/long or UTM
- [x] On refresh data - if a peak was missing from OSM, the update the osmId if it is added at a later stage.
- [x] Reset the id to 1.
- [x] If the sourceOfTruth is HWC, just create the list and do not overwrite data in Peaks 
- [x] If csv height is blank, set to 0, do not flag as invalid.
- [ ] Update dialogue to say import new list or update list
- [ ] remove legacy row handling
- [x] Move import to TR of Peak Lists
- [x] Move list of Peak to RHS
- [x] Move map to BL
- [x] Set map aspect to 4:3
- [x] clicking on a peak will highlight the peak with a blue circle
- [x] Add points column and add points metrics
- [x] Add add peak to list
- [x] click on peak in details will go to the peak on the Map screen and zoom to 15.
- [ ] Refresh lists on change to peak name in ObjectBox Admin

## Object Box Admin
- [x] Rescan entity on entry, for the current entity being shown.
- [x] Add "Add new peak" to Peak entity
- [x] Add a goto peak button in the delete column, name of peak and details. Use an eye icon.
- [ ] Allow entry of UTM coordinates

## Settings
- [x] move settings UI stuff from router.md to settings screen
- [ ] Add a help dialogue to explain what the adjustable settings mean.

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


# Errors
- [x] Zoom display not updating
- [x] keyboard keys should change focus to search boxes
- [x] duplicate peak search
- [x] peaks not showing
