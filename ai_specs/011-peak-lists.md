# Peak Lists
## Goal
Import a list of peaks which will to be used by the user to "tick off" the peaks "bagged".
Adds functionality to peak_lists_screen.dart

## UI
- Add a FAB named "Import Peak List"
- on click open a dialogue box that shows a button "Select Peak Lists", and a text box displaying "List Name"
- File Picker Opens and allows selection of a single csv file.
- User then clicks an import button at the bottom of the dialogue box to commence the import. Display an error "A list name is required" if the text box is empty.

Each import creates a new list with the selected name. If the name is a duplicate display a warning - "This list already exists - do you want to update the existing list?"

Only creates the list which are viewable by ObjectBox Admin. Future functionality will include summary views such as % of peaks ticked.


- **Dependencies**: 
  - file_picker (^10.3.10) - file selection
  - path (^1.9.0) - path manipulation
  - path_provider (^2.1.0) - platform-specific directories

## Import file format
The import file format is csv with the following columns:
1. Name - the name of the peak
2. Height - height of the peak
3. Zone - mgrs grid zone designator
4. Easting
5. Northing
6. Latitude
7. Longitude
8. Points

### Example
This is an example row from a csv file:
"Wellington, Mount","1271","55G","5 19 375","52 50 705","-42.89602","147.23731","1"

This is the matching example in the Peak entity:
name: "kunanyi / Mount Wellington"
elevation: 1270.53
latitude: -42.896007
longitude: 147.2373052
gridZoneDesignator: 55G
mgrs100kId: EN
easting: 19374
northing: 50706

The row of the csv file is a match to the row from the Peak entity.

## New ObjectBox Entity
A new objectbox entity named peakLists will need to be created with the following fields:
- peakListId - used as the primary key
- peakList - a list of peaks and associated points from the csv Points column.

the peak list is a list of tuples: [(peakId1, points1), (peakId2, points2),...]
- peakId - a link to the osmId in the Peak entity
- points - a direct copy of the Points column - column 8.

## Peak matching

The peaks in the imported list should be correlated with the peaks in the Peak entity by doing the following checks:
1. csv Latitude and Longitude match Peak entity latitude and longitude within a threshold of 50m e.g. csv latitude matches -42.89602 Peak entity field latitude: -42.896007
2. csv Zone matches Peak entity gridZoneDesignator.
3. csv Easting and Northing may or may not be space separated digits.
4. csv Easting and Northing are UTM easting and northing.
5. csv Zone, Easting and Northing combined provide a valid UTM reference which will need to be converted to mgrs format e.g. Zone: "55G", Easting: "5 19 375", Northing: "52 50 705" would be converted to "55GEN1937550705" which would need to match the following fields of the Peak entity:
    gridZoneDesignator: 55G
    mgrs100kId: EN
    easting: 19374 (note: would match 19375 from above)
    northing: 50706 (note: would match 50705 from above)

6. csv height (e.g. 1271) matches Peak entity elevation (e.g. 1270.53).
7. csv name (e.g. "Wellington, Mount" or "Mount Wellington" or "Mt Wellington") matches Peak entity name (e.g. "Mount Wellington" or "kunanyi / Mount Wellington"). If the name does not match show a warning, and log a warning with a timestamp to import.log

## How to pick a file for import
- 
## Files to review
review the files in ai_docs and all sub-directories as some of the files provide solutions to issues previously encountered with csv file import and objectBox import/creation/staleness
