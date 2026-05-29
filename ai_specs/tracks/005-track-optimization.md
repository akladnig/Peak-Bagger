# Track display optimizatijn

## Goal
Optimize the gpx track for display on macOS.

Currently all trackPoints are being stored in the database and then displayed. This however is overkill in terms of the number of trackpoints required for display.

## requirements

- update the database  schema to store the original gpx file (new field gpxFile) allowing a gpx export as a future requirement.
- filter the original gpx to provide an optimal number of trackpoints for display at zoom level of 15.
- database migration should use the existing migration mechanism

## Questions/Notes
The trackPoints should be filtered to allow efficient display for all the supported zoom levels and a maximum screen size of 5120x2880. How is this screen size mapped to the actual screen resolution used by macOS?

For a zoom level of 15 it appears the x distance is approx 5.2km and y distance approx 3.2km, so it is close to 1:1 ratio of metres to pixels? But if flutterMap uses lat long then a different conversion would be required.

The question then is, what are the minimum number of trackpoints required for optimal display at a zoom level of 15?


 

