<goal>
Analyze GPX tracks on import to detect signal loss between track segments and optionally repair by inserting interpolated points. This prevents false straight-line connections across time gaps caused by GPS signal loss.
</goal>

<background>
GPX track segments (<trkseg>) group related track points together. A new segment begins when:
- User pauses recording
- GPS signal is lost/forgotten to restart

When there is a time gap between segments:
- **Genuine pause**: minimal location change (user stopped but GPS maintained lock)
- **Signal loss**: significant location change (device kept moving while GPS lost lock)

The current implementation treats all segments the same, leading to false straight-line "connections" across time gaps.

Tech stack: Flutter with xml package for GPX parsing, ObjectBox for persistence.
Files to examine:
- @lib/models/gpx_track.dart (entity - needs new field)
- @lib/services/gpx_importer.dart (import logic)
- @lib/services/gpx_track_statistics_calculator.dart (statistics calculation)
</background>

<user_flows>
Primary flow (track import with repair):
1. User imports GPX file via file picker
2. System parses GPX, extracts track segments with timestamps
3. System analyzes each time gap between consecutive segments
4. For gaps > ~60 seconds:
   - Calculate distance between segment end and next segment start
   - If distance > 50m threshold: signal loss detected
   - Insert interpolated segment with 2 points (copy of end + start)
   - Add <type>interpolated</type> tag
5. Save repaired GPX to gpxFileRepaired field
6. Use gpxFileRepaired for statistics calculation

Alternative: No repair needed
- If all gaps are genuine pauses (< 50m distance change)
- Set gpxFileRepaired to empty string
- Use original gpxFile for statistics

Recalculate flow:
- On "Reset Track Data", check gpxFileRepaired
- If not empty, use gpxFileRepaired as the input to the existing `processTrack(...)` flow for recalculation
- If empty, run repair analysis on gpxFile first, then pass the repaired-or-original XML into `processTrack(...)` (which may populate gpxFileRepaired)
</user_flows>

<requirements>
**Functional:**
1. Add `gpxFileRepaired` field to GpxTrack entity as a non-nullable String with default empty string, and update `GpxTrack.toMap()` / `GpxTrack.fromMap()` so recalc clones preserve the field
2. Create `GpxTrackRepairService` class with:
    - `analyzeAndRepair(String gpxXml)` method returning repair result
    - `RepairResult` class with fields: repairedXml (String), repairPerformed (bool), gapCount (int), interpolatedSegmentCount (int), warning (String?)
3. On track import, run repair analysis on raw `gpxFile` before the existing `processTrack(...)` filtering/statistics pipeline
4. Store repaired XML in gpxFileRepaired when repair is performed; keep the original XML in gpxFile
5. Pass repaired-or-original XML into the existing `processTrack(...)` flow so filteredTrack, displayTrackPointsByZoom, and statistics all derive from the same repaired input
6. Use the same repaired-or-original XML input for peak correlation rebuilds; do not keep peak correlation on raw `gpxFile` when repaired XML is available
7. On recalculate: if gpxFileRepaired is not empty, use it as the input to `processTrack(...)`; if it is empty, run repair analysis on gpxFile first and then pass the repaired-or-original XML into `processTrack(...)`

**Repair Logic:**
8. Parse all track segments with timestamps
9. For each consecutive segment pair with time gap > 60 seconds:
    - Calculate distance between last point of first segment and first point of second segment
    - If distance > 50m: signal loss → create interpolated segment
    - If distance ≤ 50m: genuine pause → no repair needed
10. Interpolated segment contains exactly 2 <trkpt> elements:
    - First: copy of last point from previous segment (lat, lon, ele, time)
    - Second: copy of first point from next segment (lat, lon, ele, time)
11. Set interpolated segment <type> to "interpolated"
12. Insert interpolated segment between original segments in XML

**Edge Cases:**
13. Handle tracks with single segment: no repair needed
14. Handle tracks with no timestamps: skip repair, set gpxFileRepaired to empty
15. Handle already-repaired tracks: detect by presence of <type>interpolated</type>, skip re-repair, preserve the existing repaired XML source as-is, and persist that XML into `gpxFileRepaired` as the effective repaired source while still keeping the imported file contents in `gpxFile`
16. Handle XML parse errors gracefully: skip repair, log warning

**Validation:**
17. Distance threshold configurable via constructor (default 50m)
18. Time gap threshold configurable via constructor (default 60 seconds)
</requirements>

<boundaries>
Error scenarios:
- Invalid XML: return repair result with repairPerformed=false, gapCount=0
- Single segment: return repair result with repairPerformed=false, gapCount=0
- No timestamps: return repair result with repairPerformed=false, gapCount=0, warning set

Limits:
- Time gap threshold: 60 seconds (configurable)
- Distance threshold: 50 meters (configurable)
</boundaries>

<implementation>
Files to create:
- @lib/services/gpx_track_repair_service.dart (new service)

Files to modify:
- @lib/models/gpx_track.dart (add gpxFileRepaired field)
- @lib/services/gpx_importer.dart (integrate repair on import)
- @lib/providers/map_provider.dart (use gpxFileRepaired on recalculate)
- @lib/services/objectbox_admin_repository.dart (surface gpxFileRepaired in admin/debug views)

Patterns:
- Follow existing GpxTrackStatisticsCalculator pattern for XML parsing
- Use latlong2 Distance for distance calculations
- Return structured result (not just XML string)
- Inject thresholds for testability
</implementation>

<validation>
Unit tests (required):
1. Single segment track: no repair performed
2. Two segments with small gap (< 60s): genuine pause, no repair
3. Two segments with large gap (> 60s, < 50m): genuine pause, no repair
4. Two segments with large gap (> 60s, > 50m): repair performed with interpolated segment
5. Multiple gaps requiring repair
6. Track with no timestamps: no repair, warning set
7. Already-repaired track detected: no re-repair
8. Invalid XML: graceful error handling

Integration test (required):
9. Full import flow with repair creates correct gpxFileRepaired
10. Recalculate uses gpxFileRepaired when available
11. Recalculate repairs raw gpxFile first when gpxFileRepaired is empty, then processes and correlates from that repaired-or-original XML

Widget/robot tests (not required - service layer only):
- N/A

Testability seams:
- Constructor with configurable thresholds (distanceMeters, gapSeconds)
- Public result class for assertions
- No external dependencies beyond xml and latlong2
</validation>

<done_when>
1. GpxTrack entity has gpxFileRepaired field persisting to ObjectBox
2. GpxTrackRepairService analyzes tracks and returns correct repair results
3. Track import runs repair on raw GPX and then uses repaired-or-original GPX as the input to the existing processTrack/filter/statistics pipeline
4. Recalculate uses gpxFileRepaired when available, otherwise repairs gpxFile first and then runs the same processTrack/filter/statistics/peak-correlation pipeline
5. All required unit tests pass
6. All required integration tests pass
</done_when>
