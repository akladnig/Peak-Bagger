# Peak Bagger App
## Goal
A flutter app that imports GPX files and then automatically finds any matching peaks and displays the tracks on a map. Displays a summary screen similar to Summit Bag.

- Support for MacOs and iOS only.
- Phase 1 is complete
- Create specification for Phase 2 only.

## Phases
### Phase 1
#### Features
Application skeleton with vertical menu system on left.
- Left hand menu items from top to bottom, showing icons only, no text:
  - Dashboard
  - Map
  - Peak Lists
  - Settings
- dark/light icon at top right of screen which changes dark/light mode when clicked. Icon to change from Moon to Sun and vice-versa.
- Dark mode to use "Catppuccin Mocha" - refer to https://catppuccin.com/palette/ and https://github.com/catppuccin/catppuccin/blob/main/docs/style-guide.mdj
- Light mode to used "Catppuccin Latte"
- Dark Mode defaults to system preferences on first launch.
- Setting persists via shared preferences.
- app to start in full screen mode

Each item navigates to a new screen. Use GoRouter for navigation.
Each menu item to display an icon with tooltip text.

Each screen to display placeholder text showing the screen name.
Details of subsequent screens to be specified, planned and implemented in subsequent phases.

### Dependencies to Add (pubspec.yaml)

```yaml
dependencies:
  flutter:
    sdk: flutter
  go_router: ^17.2.0
  shared_preferences: ^2.5.0
  flutter_riverpod: ^3.2.1

dev_dependencies:
  flutter_test:
    sdk: flutter
  flutter_lints: ^6.0.0
```

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



### Phase 3

- on first launch Run a query on Overpass Turbo to get a list of Tasmanian peaks with a name and elevation
  - Sample query:
    ``` {{geocodeArea:Tasmania}}->.searchArea;
        node["natural"="peak"]["name"]["ele"](area.searchArea);
        out;```
- Save the peaks in an objectBox database.
Peak Database schema:
- PeakId
- PeakName
- PeakElevation
- PeakEasting
- PeakNorthing
- PeakMapId
- PeakArea

PeakArea is one of: North West, Central North, North East, Central West, Central South, Central East, South West and South East.

Add a search box at the top to allow search by name and elevation.
dependencies: objectbox ^5.3.1

### Phase 4
Import GPX tracks from a selected folder, save to an objectBox database and display on the map.

### Phase 5
Add database of Tasmanian Peak Lists.
- [ ] Abels
- [ ] Poimenas
- [ ] HWC lists
- [ ] 125 coinosseur.

- [ ] Add additional search and filter function.
- [ ] Add Checkboxes for peak lists.


Peak List Schema:
- ListId
- ListName
- List of PeakId


Map Database Schema:
- MapId
- 25kName
- 25kSeries

- 50kParentSeries
- 50kName
- 50kSeries
- 100kParent Series
- 100k Name
- 100k Series

### Phase 6
Add a settings screen
- [ ] dark/light/system mode
- [ ] units display - UTM MGRS, degrees decimal, degrees minutes seconds,
- [ ] Datum - WGS84, GDA94, GDA2020
- [ ] default gpx folder.

### Phase 7
- Add a layers button on the bottom right to allow selection of the basemap to be shown.

## Notes
- How to sync with Suunto?
- How to sync with Gaia?

