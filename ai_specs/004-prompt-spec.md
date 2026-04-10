<goal>
Adds a database of Tasmanian 1:50,000 topographic maps to support goto location search by map name. Users can search using formats like "Wellington 194507" which maps to full MGRS coordinate 55GEN1940050700. Also displays a popup showing map name when user clicks on the map.
</goal>

<background>
**Tech Stack:** Flutter with ObjectBox, Riverpod, flutter_map
**Project:** peak_bagger - Tasmanian peak bagging app
**Files to examine:**
- @lib/models/peak.dart - Existing ObjectBox entity pattern
- @lib/objectbox.g.dart - ObjectBox generated code
- @lib/providers/map_provider.dart - Map state management, goto search logic
- @lib/screens/map_screen.dart - Map UI with click handling
- @assets/tasmap50k.csv - 50k map data source

**Existing Patterns:**
- ObjectBox entities use @Entity() annotation with @Id() for primary key
- Repository pattern for data access (see PeakRepository)
- State management via Riverpod NotifierProvider
</background>

<user_flows>
**Primary Flow - Goto by Map Name:**
1. User presses 'G' key or taps goto button
2. Goto input field appears with placeholder "Go to location (e.g., Wellington 194507)"
3. User enters "Wellington 194507"
4. System parses map name "Wellington" + easting 194 + northing 507
5. System looks up map in database to get MGRS 100k square ID
6. System constructs full MGRS: 55G + 100kSquare + easting + northing
7. System converts to LatLng and centers map

**Primary Flow - Map Click Popup:**
1. User clicks/taps on map location (not drag)
2. System converts click position to MGRS coordinate
3. System looks up which 50k map covers that MGRS
4. Popup dialog appears showing:
   - Map name (e.g., "Wellington")
   - If peak exists at location: peak name + elevation
5. User dismisses by tapping elsewhere or close button

**Alternative Flow - Full MGRS Input:**
1. User enters "55GEN1940050700" or "55G EN 19400 50700"
2. System parses as standard MGRS (existing behavior)
3. Map centers on location
4. Popup still shows map name for clicked locations
</user_flows>

<requirements>
**Functional:**
1. Create Tasmap50k entity in ObjectBox with fields: id, series, name, parentSeries, mgrs100kId, eastingMin, eastingMax, northingMin, northingMax
2. Implement CSV import on first app launch, importing from assets/tasmap50k.csv
3. Store imported data in ObjectBox, querying by MGRS 100k square ID
4. Update goto search to parse format: "[MapName] [easting3digit] [northing3digit]"
5. Lookup map by name, construct full MGRS from 100k square + provided coordinates
6. Handle click on map location to show popup with map name
7. If clicked location has nearby peak (within 500m), show peak name + elevation in popup

**Error Handling:**
8. Invalid map name: Show error "Map not found: [name]"
9. Invalid coordinate format: Show error "Invalid format. Use: MapName easting northing"
10. Click outside all 50k map coverage: Show "Outside Tasmania 50k coverage"
11. CSV import failure: Log error, continue with empty map database

**Edge Cases:**
12. Map name case-insensitive: "wellington" matches "Wellington"
13. Partial coordinate: "Wellington 194" uses default northing range (000-999)
14. Ambiguous map names: Return first match (unique in Tasmania)
15. Overlapping map coverage: Use first/primary map for 100k area

**Validation:**
16. Map name must be non-empty string from database
17. Easting/northing must be 1-3 digits each (0-999)
</requirements>

<boundaries>
**Edge Cases:**
- Click on exact boundary between two 50k maps: Use either, no specific priority
- Location in ocean (outside Tasmania): Show "Outside map coverage"
- Peak at exact click position: Show peak info; otherwise just map name
- First launch during offline: Import CSV fails, empty database, continue without error

**Error Scenarios:**
- CSV file missing: Log error, create empty database
- Malformed CSV row: Skip row, log warning, continue import
- Database corruption: Recreate on next launch

**Limits:**
- Max 100 peaks shown in search results (existing)
- Map popup dismisses on any other interaction
</boundaries>

<implementation>
**Files to create:**
- @lib/models/tasmap50k.dart - New ObjectBox entity
- @lib/services/tasmap_repository.dart - Data access for tasmap50k
- @lib/services/csv_importer.dart - CSV parsing and import logic

**Files to modify:**
- @lib/objectbox.g.dart - Regenerate after adding entity
- @lib/providers/map_provider.dart - Add tasmap repository, update parseGridReference, add popup state
- @lib/screens/map_screen.dart - Add popup dialog on map click, handle popup display
- @lib/main.dart - Add first-launch CSV import check

**Patterns to follow:**
- Use existing Peak entity pattern: @Entity(), @Id(), constructor
- Use existing PeakRepository pattern: constructor takes Store, box operations
- Use SharedPreferences for first-launch flag: key 'tasmap_imported'
- CSV parsing: Use dart:io or package:csv
- MGRS conversion: Use existing mgrs_dart package (already in deps)

**What to avoid:**
- Don't create separate ObjectBox store - use existing objectboxStore
- Don't duplicate MGRS parsing logic - extend existing parseGridReference
- Don't block UI on CSV import - use async with loading state
</implementation>

<validation>
**Test Strategy:**
1. Unit test CSV import with sample data
2. Unit test map name lookup returns correct MGRS 100k square
3. Unit test parseGridReference with "MapName easting northing" format
4. Widget test popup displays correct map name
5. Widget test popup shows peak info when near click location
6. Integration test: enter "Wellington 194507" navigates to correct location
7. Integration test: click on map shows popup with correct map name

**Validation Steps:**
- Verify Tasmap50k entity saves and queries correctly
- Verify CSV import populates all 65 map records
- Verify "Wellington 194507" parses to MGRS 55GEN1940050700 (or close)
- Verify click popup shows map name for any point in Wellington coverage
- Verify click on peak shows name + elevation
</validation>

<done_when>
- [ ] Tasmap50k entity created and ObjectBox code generated
- [ ] CSV import runs on first launch, populates database
- [ ] Goto search accepts "MapName easting northing" format
- [ ] Map click shows popup with map name
- [ ] Popup shows peak name + elevation when click is near peak
- [ ] All tests pass
- [ ] App builds successfully
</done_when>
