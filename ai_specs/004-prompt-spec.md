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
4. User presses Enter
5. System parses map name "Wellington" + easting 194 + northing 507
6. System looks up map in database to get MGRS 100k square ID
7. System constructs full MGRS: 55G + 100kSquare + easting + northing
8. System converts to LatLng and centers map
9. Goto input field closes

**Primary Flow - Map Click Popup:**
1. User presses 'I' key to toggle info popup at current map center
2. System converts current center position to MGRS coordinate
3. System looks up which 50k map covers that MGRS using X/Y range validation logic
   - Extract easting/northing from MGRS coordinates
   - Check which map's eastingMin-eastingMax and northingMin-northingMax includes the coordinate
   - Handle wrap-around ranges (Xmax < Xmin or Ymax < Ymin) as defined in validation logic
4. Popup dialog appears showing:
   - Map name (e.g., "Wellington")
   - If peak exists at location: peak name + elevation
5. User dismisses by pressing Escape or close button

**Alternative Flow - Full MGRS Input:**
1. User enters "55GEN1940050700" or "55G EN 19400 50700"
2. System parses as standard MGRS (existing behavior)
3. Map centers on location
4. Popup still shows map name for clicked locations

**Alternative Flow - MGRS 100k Square Only:**
1. User enters "EN 194507" (2-letter MGRS 100k square + coordinates, no map name)
2. System parses MGRS 100k square identifier (EN) from input
3. System looks up which 50k maps cover that 100k square area
4. System constructs full MGRS: 55G + 100kSquare + provided coordinates
5. System converts to LatLng and centers map
6. Popup shows map name(s) that cover the clicked location
</user_flows>

<requirements>
**Functional:**
1. Create Tasmap50k entity in ObjectBox with fields: id, series, name, parentSeries, mgrs100kId (list), eastingMin, eastingMax, northingMin, northingMax
2. Implement CSV import on first app launch, importing from assets/tasmap50k.csv
   - CSV headers (Series, Name, Parent, MGRS, Xmin, Xmax, Ymin, Ymax) map to entity fields:
     - Xmin → eastingMin
     - Xmax → eastingMax  
     - Ymin → northingMin
     - Ymax → northingMax
   - MGRS column contains space-separated 2-letter codes (e.g., "CQ   ", "CP  CQ ", "CP DP CQ DQ")
     - Parse by splitting on whitespace, filtering empty strings, to get List<String> of 100k square IDs
3. Store imported data in ObjectBox, querying by MGRS 100k square ID
4. Update goto search to parse format: "[MapName] [easting3digit] [northing3digit]" or with spaces: "[MapName] [easting3digit] [northing3digit]"
5. Lookup map by name, construct full MGRS from 100k square + provided coordinates
6. Handle click on map location to show popup with map name (using existing left-tap onPointerUp)
7. If clicked location has nearby peak (within 100m), show peak name + elevation in popup
8. Support MGRS 100k square only input: "EN 194507" looks up maps covering that 100k square area
9. Validate easting/northing against map's range (eastingMin/eastingMax, northingMin/northingMax)
   - If outside range, show error with valid range for that map
   - Handle wrap-around ranges (e.g., 80000-20000 means valid ranges 80000-99999 AND 0-20000)

**Popup State (MapState additions):**
- showPopup (bool): Whether popup is currently displayed
- popupMapName (String): Name of 50k map at click location
- popupPeakName (String?): Name of peak if within 100m, null otherwise
- popupPeakElevation (double?): Peak elevation if available
- popupMgrs (String): MGRS coordinate at click location (for display)

**MGRS 100k Square ID Structure:**
- Each map may have 1-4 MGRS 100k square IDs in the mgrs100kId list
- First letter = easting grid ID, second letter = northing grid ID (if present)
- When Xmax < Xmin, the easting range wraps (valid: Xmin-99999 AND 0-Xmax)
- When Ymax < Ymin, the northing range wraps (valid: Ymin-99999 AND 0-Ymax)

**Example: TK05 Black Bluff**
- MGRS: "CP DP CQ DQ"
- Xmin=80000, Xmax=20000 (easting wraps: 80000-99999 OR 0-20000)
- Ymin=90000, Ymax=20000 (northing wraps: 90000-99999 OR 0-20000)
- 100k ID mapping:
  - CP = easting 80000-99999 , northing 0-30000
  - DP = easting 0-20000, northing 0-30000
  - CQ = easting 80000-99999 , northing 90000-99999  OR 0-20000
  - DQ = easting 0-20000, northing 90000-99999  OR 0-20000

**Validation Logic:**
- User enters 3 digit grid reference easting=500, northing=100
- 500 falls in 0-20000 range for easting → use DP or DQ for easting
- 100 falls in 0-30000 range for northing → use DP for northing
- Combined 100k ID = DP matches valid for TK05
- If entered easting=500, northing=500:
  - 500 NOT in range (80000-99999  OR 0-20000) → Error: "Easting 500 out of range for Black Bluff. Valid range: 80000-99999  OR 0-20000"

**Error Handling:**
8. Invalid map name: Show error "Map not found: [name]"
9. Invalid coordinate format: Show error "Invalid format. Use: MapName easting northing"
10. Invalid MGRS 100k square: Show error "Unknown MGRS square: [code]"
11. Coordinate outside map range: Show error "Easting [X] out of range for [MapName]. Valid range: [min]-[max] OR [min2]-[max2]" (for wrap-around, display as "Valid range: 80000-99999  OR 0-20000")
12. Click outside all 50k map coverage: Show "Outside Tasmania 50k coverage"
13. CSV import failure: Log error, continue with empty map database

**Edge Cases:**
12. Map name case-insensitive: "wellington" matches "Wellington"
13. Partial coordinate: "Wellington 194" uses map's northingMin-northingMax range (if northingMax < northingMin, use northingMin-999 OR 0-northingMax)
14. Ambiguous map names: Return first match (unique in Tasmania)
15. Overlapping map coverage: Use first/primary map for 100k area
16. Coordinate-to-100k-ID mapping: Use Xmin/Xmax and Ymin/Ymax ranges to determine which 100k ID applies
    - When Xmax < Xmin, easting wraps (valid: Xmin-99999  AND 0-Xmax)
    - When Ymax < Ymin, northing wraps (valid: Ymin-99999  AND 0-Ymax)
17. Input coordinate outside valid ranges: Show range error as per error handling #11

**Validation:**
16. Map name must be non-empty string from database
17. Easting/northing must be 1-3 digits each (0-999)
18. MGRS 100k square must be valid 2-letter code from tasmap database
19. Easting must fall within map's eastingMin-eastingMax range (accounting for wrap-around 80000-20000)
20. Northing must fall within map's northingMin-northingMax range (accounting for wrap-around)
</requirements>

<boundaries>
**Runtime Boundaries:**
- Click on exact boundary between two 50k maps: Use either, no specific priority
- Location in ocean (outside Tasmania): Show "Outside map coverage"
- Peak at exact click position: Show peak info; otherwise just map name
- First launch during offline: Import CSV fails, empty database, continue without error
- First launch: Check tasmapRepository.isEmpty() → if true, import CSV on first app run

**Error Scenarios:**
- CSV file missing: Log error, create empty database
- Malformed CSV row: Skip row, log warning, continue import
- Database corruption: Recreate on next launch

**Limits:**
- Max 100 peaks shown in search results (existing)
- Map popup dismiss triggers: tap outside popup, pan map, zoom, press any key, or press close button
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
- Add `csv` package to pubspec.yaml dependencies
- CSV parsing: Use package:csv for robust parsing of whitespace-padded CSV format
- MGRS conversion: Use existing mgrs_dart package (already in deps)

**What to avoid:**
- Don't create separate ObjectBox store - use existing objectboxStore
- Don't duplicate MGRS parsing logic - extend existing parseGridReference
- Don't block UI on CSV import - 65 rows is fast enough (~few milliseconds) to not need loading state
</implementation>

<validation>
**Test Strategy:**
1. Unit test CSV import with sample data
2. Unit test map name lookup returns correct MGRS 100k square
3. Unit test parseGridReference with "MapName easting northing" format
4. Unit test CSV import parses "CP DP CQ DQ" to 4 elements (List<String>)
5. Unit test partial coordinate "MapName easting" uses northingMin-northingMax range
6. Unit test parseGridReference handles space-separated: "Wellington 194 507"
7. Unit test parseGridReference handles compact: "Wellington 1950" → 55GEN1900050000
8. Unit test parseGridReference handles space: "Wellington 19 50" → 55GEN1900050000
9. Widget test popup displays correct map name
10. Widget test popup shows peak info when near click location
11. Integration test: enter "Wellington 194507" navigates to correct location
12. Integration test: enter "Wellington 194 507" (space between) navigates to correct location
13. Integration test: click on map shows popup with correct map name

**Validation Steps:**
- Verify Tasmap50k entity saves and queries correctly
- Verify CSV import populates all 65 map records
- Verify "Wellington 194507" parses to MGRS 55GEN1940050700 (or close)
- Verify "Wellington 194 507" (space between) parses to MGRS 55GEN1940050700 (or close)
- Verify "Wellington 1950" (compact) parses to MGRS 55GEN1900050000 (or close)
- Verify "Wellington 19 50" (space) parses to MGRS 55GEN1900050000 (or close)
- Verify click popup shows map name for any point in Wellington coverage
- Verify click on peak shows name + elevation
- Verify easting out of range shows error with valid range
- Verify wrap-around ranges (80-20) correctly validate both 80-99 and 0-20
- Verify partial coordinate "Wellington 194" uses northingMin-northingMax from map
- Verify "CP DP CQ DQ" CSV MGRS column parses to 4 separate 100k IDs
</validation>

<done_when>
- [x] Tasmap50k entity created and ObjectBox code generated
- [x] CSV import runs on first launch, populates database
- [x] Goto search accepts "MapName easting northing" format
- [x] Map click shows popup with map name
- [x] Popup shows peak name + elevation when click is near peak
- [x] All tests pass
- [x] App builds successfully
</done_when>
