## goal
Add a number of fields to the existing GPX tracks entity. The GPX track will be analysed to populate the fields described in the Schema section below.
A new spec needs to be created.
This is adds features to 005-gpx-tracks-spec.md, 005-add-gpx-stats-1-spec.md and 005-add-gpx-stats-2-spec.md

file to review - required for schema updates:
- ai_docs/solutions/bug-fixes/005-gpx-reset-failure.md

- calcluates track statistics from the gpxFile field in the GpxTracks entity.


### Schema
Retrofit the existing GPX track ObjectBox entity with the additional schema, existing fields remain untouched.

- durationHint (String) populated with "This is the duration hint"
- rename totalTimeMillis to totalTime. Calculate from the first <trkpt> with a valid and last <trkpt> with valid time.
- movingTime - The total duration of movement - i.e. not stopped.
- restingTime - this is total duration of which no movement was detected i.e. stopped.
What is the minimum distance between points to be classified as being stopped?
- pausedTime - this is the total duration for which track recording was paused.
