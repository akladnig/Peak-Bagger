# Findings
## Critical — copyWith clears unrelated state
*Problem:* MapState.copyWith resets error and gotoMgrs to null whenever callers omit them. That means unrelated updates like panning, toggling layers, or cursor movement can silently wipe error banners and goto state.  
*Evidence:* lib/providers/map_provider.dart:120-217, especially error: error and gotoMgrs: gotoMgrs.  
*Fix:*
MapState copyWith({
  String? error,
  bool clearError = false,
  String? gotoMgrs,
  bool clearGotoMgrs = false,
  // ...
}) {
  return MapState(
    // ...
    error: clearError ? null : (error ?? this.error),
    gotoMgrs: clearGotoMgrs ? null : (gotoMgrs ?? this.gotoMgrs),
  );
}

## High — Peak correlation bbox is too narrow east/west
*Problem:* _boundsFor uses the same meters-to-degrees delta for latitude and longitude. At Tasmania latitudes, longitude degrees are shorter, so the bbox can exclude valid peaks before the exact distance check runs.  
*Evidence:* lib/services/track_peak_correlation_service.dart:42-65.  
*Fix:*
final latDelta = thresholdMeters / 111320.0;
final meanLatRad = _meanLatitudeRadians(segments);
final lonDelta = thresholdMeters /
    (111320.0 * math.cos(meanLatRad).abs().clamp(0.1, 1.0));
return (
  minLat: minLat - latDelta,
  maxLat: maxLat + latDelta,
  minLon: minLon - lonDelta,
  maxLon: maxLon + lonDelta,
);

## Medium — Nearby-peak lookup returns first hit, not nearest
*Problem:* _findNearbyPeak returns the first peak within 100m, which can show the wrong name/elevation if multiple peaks are near the map center.  
*Evidence:* lib/providers/map_provider.dart:1363-1375.  
*Fix:*
(String?, double?) _findNearbyPeak(LatLng location) {
  const searchRadiusMeters = 100.0;
  Peak? nearest;
  var bestDistance = searchRadiusMeters;
  for (final peak in state.peaks) {
    final distance = _distance.as(
      LengthUnit.Meter,
      location,
      LatLng(peak.latitude, peak.longitude),
    );
    if (distance <= bestDistance) {
      bestDistance = distance;
      nearest = peak;
    }
  }
  return nearest == null ? (null, null) : (nearest.name, nearest.elevation);
}

## Low — addTrack and putTrack are duplicate logic
*Problem:* GpxTrackRepository.addTrack and putTrack do the same thing. That’s two names for one operation, and it creates drift risk.  
*Evidence:* lib/services/gpx_track_repository.dart:9-15.  
*Fix:*
int putTrack(GpxTrack track) => _box.put(track);
@Deprecated('Use putTrack')
int addTrack(GpxTrack track) => putTrack(track);

## Best Practices Already Present
- Repository abstraction + InMemoryPeakStorage test seam.
- Constructor injection in TrackPeakCorrelationService for the geometry parser.
- Transaction wrapper in PeakStorage.replaceAll() rollback path.
- Stable Keys on critical map actions and peak layer, good for robot tests.
- ObjectBox query builder usage, not raw SQL.

## Security
- No obvious SQL injection path.
- No shell execution or unsafe deserialization found in the reviewed paths.

## Performance Bottlenecks
1. Peak marker rebuild churn
   - MapScreen rebuilds the whole MarkerLayer and every SvgPicture.asset on each map rebuild/zoom.
   - Trade-off: caching reduces CPU/jank, but adds invalidation complexity and some memory overhead.
2. Peak search scans the full collection
   - searchPeaks() does an in-memory pass over every peak on each keystroke.
   - Trade-off: debounce/querying reduces CPU, but adds a bit of UI latency and more search plumbing.
3. Correlation matching is still nested-loop heavy
   - TrackPeakCorrelationService.matchPeaks() walks peaks × track segments × segment points.
   - Trade-off: spatial indexing or cached segment bounds speeds imports/recalc, but increases code complexity and memory use.


# Patch plan:
1. Fix MapState.copyWith
- Add explicit clear flags for error and gotoMgrs
- Preserve existing values when callers omit fields
- Add regression for unrelated state updates not clearing banners/input
2. Fix peak bbox math
- Use latitude delta and longitude delta separately
- Scale longitude by cos(latitude)
- Add test for a valid peak near the bbox edge at Tasmania latitudes
3. Return nearest nearby peak
- Replace first-match logic in _findNearbyPeak with nearest-match logic
- Add test for multiple peaks within 100m
4. Remove addTrack/putTrack duplication
- Keep putTrack as the canonical method
- Deprecate or remove addTrack
- Update call sites to one name only
5. Optional performance follow-up
- Debounce peak search input
- Consider caching marker widgets/assets if zoom rebuilds become janky
- Consider a spatial prefilter/index if correlation import becomes slow again
