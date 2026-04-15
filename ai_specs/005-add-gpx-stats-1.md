## goal
Add a number of fields to the existing GPX tracks entity. The GPX track will be analysed to populate the fields described in the Schema section below.
A new spec needs to be created.
This is adds features to 005-gpx-tracks-spec.md

file to review - required for schema updates:
- ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md

- calcluates track statistics from the gpxFile field in the GpxTracks entity.
- add a new button in the SettingsScreen under Reset Track Data named Recalculate Track Statistics
- Statistics to be recalulated on button press or on initial track import following Reset Track Data.

### Schema
Retrofit the existing GPX track ObjectBox entity with the additional schema, existing fields remain untouched.

- distance (double?) - This is an existing field. The total length of the track. This is to be calculated from the GPX track 
- add a new field distanceToPeak (double?) - The distance from the first trackpoint to the highest elevation. This is to be calculated from the GPX track 
- add a new field distanceFromPeak (double?) - The distance from the highest elevation to the last trackpoint. This is to be calculated from the GPX track 
- add a new field lowestElevation (double) - The lowest elevation. Scans the gpx data to find the <ele> tag with the lowest elevation
- add a new field highestElevation (double) - The highest elevation. Scans the gpx data to find the <ele> tag with the highest elevation

