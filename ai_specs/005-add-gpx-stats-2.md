## goal
Add a number of fields to the existing GPX tracks entity. The GPX track will be analysed to populate the fields described in the Schema section below.
A new spec needs to be created.
This is adds features to 005-gpx-tracks-spec.md and 005-add-gpx-stats-1-spec.md

file to review - required for schema updates:
- ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md

- calcluates track statistics from the gpxFile field in the GpxTracks entity.

- uses functions from geo.dart

### Schema
Retrofit the existing GPX track ObjectBox entity with the additional schema, existing fields remain untouched.

- ascent (double?) - The total vertical ascent. This is to be calculated from the GPX track using the function  calculateUphillDownhill in geo.dart
- descent (double) - The total vertical descent. This is to be calculated from the GPX track using the function  calculateUphillDownhill in geo.dart
- startElevation (double) - The elevation of the first trackpoint. This is to be retrieved from the GPX track 
- endElevation (double) - The elevation of the last trackpoint. This is to be retrieved from the GPX track 
- elevationProfile - use the same JSON-encoded format as trackPoints? - This is to be calculated from the GPX track. The elevation profile should show the elevation as a function of distance. A future requirement will be to display this as an x-y plot, with the x-axis as distance and the y-axis elevation. For each elevation point the time should also be stored as local time, for a future x-y plot with the x-axis as time.

