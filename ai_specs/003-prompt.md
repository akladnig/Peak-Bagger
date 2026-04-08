# Phase 3
## Goal
Add objectBox ^5.3.1 database. This database will store a list of all Tasmanian Peaks, which will be gathered from OpenStreetMap. It will also store a list of Tasmanian maps references. A search box will be added to allow navigation to the peak.

- Before implementing this Phase 3 confirm Phases 1&2 are complete.

## Requirements
### ObjectBox Database
- create an objectbox database which will contain multiple tables.
- initial table will be a Peaks Table
 
Peak table schema:
- PeakId
- PeakName
- PeakElevation
- PeakEasting
- PeakNorthing
- PeakMapId
- PeakArea

- Intial database setup will only contains data for PeakName and PeakElevation

### Initial data ingestion
- on first launch Run a query on Overpass Turbo to get a list of Tasmanian peaks with a name and elevation and location.

  - Sample partial query:
    ``` {{geocodeArea:Tasmania}}->.searchArea;
        node["natural"="peak"]["name"]["ele"](area.searchArea);
        out;```

- Save the peaks in objectBox table above.

### Features
- add an Update Peaks button in the settings screen for future updates.
- Each peak is to be displayed on the map a small rose coloured triangle.
- Hovering over the peak will display a tooltip showing the name and elevation of the peak.
- The tooltip should be placed to the right of peak.

### Search Box
- Add a search box at the top to allow search by name and/or elevation.
- Display results oin a dropdown box to allow the user to select the peak to navigate to.

### Future
- A subsequent phase will add map data and area names.

## dependencies
- objectbox ^5.3.1

