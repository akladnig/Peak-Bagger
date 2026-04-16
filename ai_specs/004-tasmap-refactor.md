# TasMap 50K refactor
## Goal
Refactor the Tasmap50k import and display of maps

Currently each map is drawn as a rectangle but some maps are a more complex polygon with 6 to 8 vertices.

Currently the csv import used tl, tr, bl, br to define the 4 vertices, the csv file will now be changed to provide a series of points from 4 to 8 points stored in columns p1 to p8, with the first point (column p1) denoted the top right corner of the map.

The objectBox entity will need to be updated to reflect this new schema.

The grid refence in each p1-p8 column is stored as one of the follwing formats:
- [MGRS 100k square][easting5digit][northing5digit]
- [MGRS 100k square] [easting5digit] [northing5digit] i.e. space separated.

When the map polygons are drawn they should now use points p1-p8.
