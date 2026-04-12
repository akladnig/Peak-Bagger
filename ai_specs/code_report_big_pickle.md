
Code Review Report
Duplicate Code Found
1. MGRS parsing logic duplicated in map_provider.dart (lines ~570-855)
- 4 distinct code paths parsing grid references: MGRS 100k square, space-separated coords, coordinate-only formats, original MGRS format
- Extract to GridReferenceParser class
2. Track point parsing (map_screen.dart:_buildTrackPolylines ~line 906)
- Similar parsing logic could be extracted to a utility
3. Duplicate mgrs.toPoint() → mgrs.forward() conversion patterns
- Appears ~10 times across map_provider.dart lines 544-560, 615-630, 695-710, etc.
Issues
1. _importTracks error handling silently swallows failures (map_provider.dart:235-237)
} catch (e) {
  // Import failed, keep empty state
}
Should at least log the error.
2. Missing null check (map_screen.dart:910)
if (rawPoints.isEmpty || rawPoints == '[]') continue;
rawPoints is always non-null from ObjectBox but pattern inconsistent with other null-checks in codebase.
3. Deprecated API (router.dart:458)
.withOpacity(0.7)
Should use .withValues(alpha: 0.7) per Flutter 3.27+
4. Unused _defaultCenter constant (map_provider.dart:24)
- _defaultCenter defined but unused - same values in build() method
5. Hardcoded path (gpx_importer.dart:30)
final tracksDir = Directory('/Users/adocuments/Bushwalking/Tracks');
Should use environment variable or config file.
6. Potential performance issue: gpx_importer.dart iterates all entities synchronously in _importTracksFromDirectory - could be slow with many files.
Suggestions
1. Extract MgrsUtils class: Consolidate repeated coordinate conversion logic
2. Refactor grid reference parsing: Create dedicated classes for each format
3. Add configuration: Make GPX tracks path configurable via env/config
4. Logging: Replace empty catch blocks with proper logging
5. Type safety: Consider non-nullable trackPoints field in GpxTrack entity
