<goal>
Display GPX tracks on the map. Import Tasmanian GPX tracks from a folder, save to an ObjectBox database, and render them on the map with a toggle control.

Who: Users who want to view their Bushwalking tracks on the map
Why: Track visualization is needed for navigation and trip planning
</goal>

<background>
Tech stack: Flutter, Riverpod, ObjectBox, flutter_map
Context: Peak bagging app with map viewing capability
Files to examine:
- @lib/models/peak.dart - ObjectBox entity pattern
- @lib/router.dart - FAB placement and MapProvider usage
- @pubspec.yaml - Dependencies (latlong2, csv already present)

Constraints:
- Tracks stored in ~/Documents/Bushwalking/Tracks (parent folder)
- Also examine subfolder: ~/Documents/Bushwalking/Tracks/Tasmania
- No other child folders examined
- First track point determines country/state for import decision
- Track color: #a726bc (purple)
</background>

<user_flows>
Primary flow:
1. App launches for first time
2. System scans ~/Documents/Bushwalking/Tracks and ~/Documents/Bushwalking/Tracks/Tasmania
3. For each GPX file, read first track point
4. Determine if track is in Tasmania
5. If Tasmanian track:
   - If NOT in Tasmania folder → move to Tasmania folder
   - If already in Tasmania folder → leave in place
   - Import track metadata to ObjectBox
6. If non-Tasmanian track in Tasmania folder → move to Tracks folder
7. User taps "show tracks" FAB
8. Tracks render on map with color #a726bc

Alternative flows:
- No tracks found: Show disabled FAB icon
- Tracks already imported: Skip import on subsequent launches

Error flows:
- Folder doesn't exist: Create folder structure
- Invalid GPX file: Skip file, continue to next
- Permission denied: Show error, allow manual retry
</user_flows>

<requirements>
**Functional:**
1. Create GPX track ObjectBox entity with schema:
   - gpxTrackId (int, @Id)
   - fileLocation (String) - populated now
   - trackName (String) - populated now
   - startDateTime (DateTime) - future, null for now
   - distance (double) - future, null for now
   - ascent (double) - future, null for now
   - totalTime (Duration) - future, null for now
   - trackColour (int) - populated now with #a726bc
2. Import Tasmanian GPX tracks from ~/Documents/Bushwalking/Tracks and Tasmania subfolder
3. Auto-organize tracks: move Tasmanian tracks to Tasmania folder, non-Tasmanian to parent
4. Add "show tracks" FAB with Icons.route, positioned between info and grid FAB (order: info, show tracks, import placeholder, grid)
5. FAB shows disabled icon when no tracks in database
6. Toggle displays/hides tracks on map with color #a726bc
7. Add keyboard shortcut 't' via Map screen Shortcuts widget wrapping map
8. Add "import" FAB placeholder with Icons.input between info and show tracks FAB (future implementation)

**State Management:**
9. Add to MapState: showTracks (bool), tracks (List<GPXTrack>)
10. Add toggleTracks() method to MapNotifier
11. Tracks imported on first launch only (check SharedPreferences flag)

**Error Handling:**
12. Missing folder: Create ~/Documents/Bushwalking/Tracks and Tasmania subfolder
13. Invalid GPX: Log error, skip file, continue
14. First track point unreadable: Skip file, continue

**Edge Cases:**
15. Empty Tracks folder: Show disabled FAB
16. Tasmania folder doesn't exist: Create it
17. Duplicate track names: Append unique identifier to trackName
</requirements>

<boundaries>
Error scenarios:
- Permission denied reading folder: Show snackbar "Could not access tracks folder"
- Permission denied writing to folder: Show snackbar "Could not organize tracks"
- Corrupted GPX: Skip silently, log to console

Limits:
- Only examine Tracks and Tasmania subfolder (no recursive depth)
- First track point only for location detection
</boundaries>

<implementation>
Files to create:
- @lib/models/gpx_track.dart - ObjectBox entity
- @lib/services/gpx_track_repository.dart - CRUD for tracks
- @lib/services/gpx_importer.dart - Import logic


Files to modify:
- @lib/providers/map_provider.dart - Add showTracks state and toggle method
- @lib/router.dart - Add show tracks FAB and import FAB placeholders
- @lib/screens/map_screen.dart - Add track rendering to map
- @lib/main.dart - Call import on first launch

Dependencies to add:
- xml: ^6.0.0 (for GPX parsing) - verify not already in pubspec

Patterns:
- Follow existing ObjectBox entity pattern from Peak entity
- Use existing Provider pattern from MapNotifier
- Track rendering: examine flutter_map polylines
</implementation>

<validation>
**TDD expectations for entity and repository:**
- Test file: @test/gpx_track_test.dart
- Test slice 1 (RED): GPXTrack entity - empty constructor creates with null values
- Test slice 2 (GREEN): Add fromMap/fromJson constructor
- Test slice 3 (RED): Repository.addTrack() persists to ObjectBox
- Test slice 4 (GREEN): Repository.getAllTracks() returns all tracks
- Test slice 5 (RED): Repository.findByFileLocation() finds track

Testability seams required for test-first:
- Repository takes Store in constructor (same as PeakRepository)
- GPXImporter takes file system dependency injectable for testing
- File paths configurable (not hardcoded)

**UI behavior tests:**
- Widget test: Show tracks FAB disabled when tracks list is empty
- Widget test: Show tracks FAB enabled when tracks exist
- Widget test: Toggle tracks changes showTracks state

**Critical journey tests (robot/f widget):**
- First launch import flow: Empty database → scan folders → tracks imported
- Toggle tracks: Tap FAB → tracks appear on map

Verify: flutter analyze passes, flutter test passes
</validation>

<done_when>
1. ObjectBox entity created with specified schema
2. Import logic scans folders and organizes tracks correctly
3. Show tracks FAB toggles display on map
4. Keyboard shortcut 't' works
5. Tracks render with #a726bc color
6. No analyze errors, tests pass
</done_when>