# Peak to Track correlation

## Goal
When importing a track, identify if any peaks are within X metres of the track.

First identify the min/max lat/long bounds of the tracks, then search for any peaks within the track bounds.

Then for each peak within the track bounds, check if that peak is within X metrees of the track.

Peaks are in the peak entity and tracks in the GpxTrack entity.

- add a new field named peaks to GpxTrack which is a list any peaks found,  referenced back to the Peak entity. If no peaks exist then the list should note that no peaks were found as opposed to any empty list which indicates that the track has not been processed.

- tracks should be prossed on Reset Track Data or Recalculate Track Statistics 

The following research was carried out:

- latlong2.Distance is suitable for point-to-point only.
- In your repo, lib/services/geo.dart already has the most relevant helper: distanceFromLine(point, linePoint1, linePoint2).
- That is the right starting point for “peak within X metres of a GPX track”, because you want the minimum distance from the peak to any track segment, not just to track vertices.
Best approach:
1. Convert the peak to a Location
2. Convert the GPX track to Location points
3. For each adjacent pair of track points, compute distanceFromLine(peak, p1, p2)
4. Take the minimum and compare to X
Caveat:
- distanceFromLine in geo.dart is an approximation on lat/lon, not a true geodesic cross-track distance.
- For short GPX segments, it’s usually good enough.
- If you need higher accuracy, implement a spherical cross-track distance.
So the short answer is:
- latlong2: not enough by itself
- geo.dart: distanceFromLine is the best existing helper here
If you want, I can add a small isPeakNearTrack() helper and tests for it.
