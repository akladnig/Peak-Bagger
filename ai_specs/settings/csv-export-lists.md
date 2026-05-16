# PeakList CSV export
## Goal
Exports the ObjectBox PeakList entity in CSV format

### PeakList Entity Export
- Exports each row in the PeakList entity as a separate csv file.
- The name of the csv file should be the name field with whitespace collapsed and replaced with a dash, and "-peak-list" appended.
- For each row in the PeakList entity export the data with the following headers:
  - Name
  - Alt Name
  - Elevation
  - Zone (gridZoneDesignator field)
  - mgrs100kId
  - Easting
  - Northing
  - Points
  - osmId
- osmId and Points are available directly from the PeakList entity
- all other headers will need to be derived by looking up the osmId in the Peak entity.
