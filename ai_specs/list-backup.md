# List Backups
## Goal
To export Peak Lists and Peaks to csv files.

### Settings Screen
- Add a new entry at the bottom named "Data Export"
- Add two buttons to this:
	- Export Peak Lists - exports all lists as below
	- Export Peaks - exports all peaks as below
- use the same confirmation dialog and success dialog as the rest of the items in the settings screen.

### PeakList entity export
- All of the lists in the PeakList entity, each row to be exported with the following headers:
	- Name: as per the name field
	- Height: lookup the peakOsmId in the Peak entity and grab this datum 
	- gridZoneDesignator: : as above
	- mgrs100kId: : as above
	- Easting: : as above
	- Northing: : as above
	- Latitude: : as above
	- Longitude: : as above
	- Points: as per the points field
- csv file name is as per the Name field with white space replaced by a dash, with "-peak-list" appended. File extension is ".csv"

### Peak entity export
- All of the peaks in the Peak entity, each row to be exported with the following headers:
	- name, elevation, Latitude, longitude, area, gridZoneDesignator, mgrs100kId, easting, northing, osmId, sourceOfTruth
