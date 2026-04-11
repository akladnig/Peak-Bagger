<goal>
Update the Tasmap50k feature to use the new CSV format with pre-calculated map centers and corner coordinates. This simplifies the implementation by removing runtime calculations and ensures map extents are accurate.
</goal>

<background>
**Tech Stack:** Flutter with ObjectBox, Riverpod, flutter_map
**Project:** peak_bagger - Tasmanian peak bagging app
**Files to examine:**
- @lib/models/tasmap50k.dart - ObjectBox entity to update
- @lib/services/csv_importer.dart - CSV parsing to update
- @lib/services/tasmap_repository.dart - Repository with getMapCenter to update
- @assets/tasmap50k.csv - Updated CSV with new columns

**Existing Patterns:**
- ObjectBox entities use @Entity() annotation with @Id() for primary key
- Repository pattern for data access
- CSV headers now map directly to entity fields (no transformation needed)
</background>

<user_flows>
**Primary Flow - Goto by Map Name:**
1. User presses 'G' key or taps goto button
2. Goto input field appears
3. User enters "Wellington 194507"
4. System parses map name "Wellington" + easting 194 + northing 507
5. System looks up map in database to get MGRS 100k square ID
6. System constructs full MGRS: 55G + 100kSquare + easting + northing
7. System converts to LatLng and centers map
8. Goto input field closes

**Primary Flow - Map Name Autocomplete (Tab):**
1. User presses 'G' key or taps goto button
2. Goto input field appears
3. User types partial map name (e.g., "wel")
4. Dropdown shows matching maps (e.g., "Wellington")
5. User presses Tab key
6. Text box autocompletes with first map name from dropdown
7. User can then type grid reference (e.g., " 194507")
8. User presses Enter to navigate to location

**Primary Flow - Partial Match Navigation (Enter):**
1. User presses 'G' key or taps goto button
2. Goto input field appears
3. User types partial map name (e.g., "wel")
4. Dropdown shows matching maps
5. User presses Enter key
6. System navigates to first map in dropdown list (centers on map)

**Primary Flow - Map Click Popup:**
1. User presses 'I' key to toggle info popup at current map center
2. System converts current center position to MGRS coordinate
3. System looks up which 50k map covers that MGRS using eastingMin/eastingMax and northingMin/northingMax range validation
4. Popup dialog appears showing map name and nearby peak info

**Alternative Flow - Full MGRS Input:**
1. User enters "55GEN1940050700" or "55G EN 19400 50700"
2. System parses as standard MGRS (existing behavior)
3. Map centers on location

**Alternative Flow - MGRS 100k Square Only:**
1. User enters "EN 194507" (2-letter MGRS 100k square + coordinates)
2. System looks up maps covering that 100k square area
3. System constructs full MGRS and centers map

**Alternative Flow - Coordinates Only:**
1. User enters "194507" (coordinates without map name or MGRS square)
2. System extracts current MGRS 100k square from MGRS display
3. System finds correct map and centers on location
</user_flows>

<requirements>
**Functional:**
1. Update Tasmap50k entity with new fields:
   - `mgrsMid` (String): MGRS 100k square for map center
   - `eastingMid` (int): Easting coordinate for map center (5-digit)
   - `northingMid` (int): Northing coordinate for map center (5-digit)
   - `tl` (String): Top-left corner MGRS [100k][easting5][northing5]
   - `tr` (String): Top-right corner MGRS
   - `bl` (String): Bottom-left corner MGRS
   - `br` (String): Bottom-right corner MGRS

2. Fix CSV importer (currently broken):
   - **Bug fix**: Use `rootBundle.loadString()` instead of `File()` — Flutter assets cannot be read with dart:io File
   - **Bug fix**: Column names are `eastingMin`, `eastingMax`, `northingMin`, `northingMax` (not Xmin/Xmax/Ymin/Ymax)
   - `mgrsMid` column → `mgrsMid` field
   - `eastingMid` column → `eastingMid` field
   - `northingMid` column → `northingMid` field
   - `TL` column → `tl` field
   - `TR` column → `tr` field
   - `BL` column → `bl` field
   - `BR` column → `br` field

3. Update `getMapCenter()` in TasmapRepository:
   - Use pre-calculated `mgrsMid`, `eastingMid`, `northingMid` from entity
   - Remove calculation logic that averaged eastingMin/eastingMax and northingMin/northingMax
   - Construct MGRS: `55G{mgrsMid} {eastingMid padded to 5 digits} {northingMid padded to 5 digits}`
   - Convert to LatLng using mgrs_dart

4. Update map extent calculation in map_screen.dart:
   - Use pre-calculated corner coordinates (tl, tr, bl, br) from entity
   - Parse corner format (12 characters): `corner.substring(0,2)` = MGRS100k, `corner.substring(2,7)` = easting (5 digits), `corner.substring(7,12)` = northing (5 digits)
   - Convert corner to LatLng: construct full MGRS `55G{corner}` and use `mgrs_dart.Mgrs.toPoint()`
   - Remove complex wrap-around calculation logic

5. Database migration: Clear existing database and re-import CSV after entity changes (ObjectBox schema change requires fresh data)

6. Regenerate ObjectBox code after entity changes

**Error Handling:**
7. Invalid map name: Show error "Map not found: [name]"
8. Invalid coordinate format: Show error "Invalid format. Use: MapName easting northing"
9. Invalid MGRS 100k square: Show error "Unknown MGRS square: [code]"
10. Coordinate outside map range: Show error with valid range
11. Click outside all 50k map coverage: Show "Outside Tasmania 50k coverage"
12. CSV import failure: Log error, continue with empty map database

**Edge Cases:**
13. Map name case-insensitive: "wellington" matches "Wellington"
14. Partial coordinate: "Wellington 194" uses map's northingMin-northingMax range
15. Ambiguous map names: Return first match (unique in Tasmania)
16. Overlapping map coverage: Use first/primary map for 100k area
17. Wrap-around ranges (eastingMax < eastingMin or northingMax < northingMin): Validate both segments

**Validation:**
18. Map name must be non-empty string from database
19. Easting/northing must be 1-3 digits each (0-999)
20. MGRS 100k square must be valid 2-letter code from tasmap database
21. Easting must fall within map's eastingMin-eastingMax range (accounting for wrap-around)
22. Northing must fall within map's northingMin-northingMax range (accounting for wrap-around)

**Goto Input Keyboard Behavior:**
23. Tab key: Autocomplete with first map name from dropdown list, append space for grid reference entry
24. Enter key with partial match: Navigate to first map in dropdown list (center on map)
25. Enter key with full input: Navigate to parsed location (existing behavior)
26. Dropdown shows up to 10 matching maps as user types
</requirements>

<boundaries>
**Runtime Boundaries:**
- Click on exact boundary between two 50k maps: Use either, no specific priority
- Location in ocean (outside Tasmania): Show "Outside map coverage"
- Peak at exact click position: Show peak info; otherwise just map name
- First launch during offline: Import CSV fails, empty database, continue without error
- First launch: Check tasmapRepository.isEmpty() → if true, import CSV

**Error Scenarios:**
- CSV file missing: Log error, create empty database
- Malformed CSV row: Skip row, log warning, continue import
- Database corruption: Recreate on next launch

**Limits:**
- Max 100 peaks shown in search results (existing)
- Map popup dismiss triggers: tap outside, pan map, zoom, press any key, close button, FAB click, menu item click
</boundaries>

<implementation>
**Files to modify:**
- @lib/models/tasmap50k.dart - Add new fields: mgrsMid, eastingMid, northingMid, tl, tr, bl, br
- @lib/services/csv_importer.dart - Update column mapping to use eastingMin/eastingMax/northingMin/northingMax, add new field imports
- @lib/services/tasmap_repository.dart - Update getMapCenter() to use pre-calculated values
- @lib/screens/map_screen.dart - Update _buildMapRectangle() and _buildAllMapRectangles() to use corner coordinates
- @lib/objectbox.g.dart - Regenerate after entity changes

**Patterns to follow:**
- Use existing ObjectBox entity pattern
- CSV parsing: Use package:csv with direct column name mapping
- MGRS conversion: Use existing mgrs_dart package

**What to avoid:**
- Don't use `File()` for CSV import — use `rootBundle.loadString()` for Flutter assets
- Don't calculate map center from ranges - use pre-calculated values
- Don't calculate map corners from ranges - use pre-calculated values
- Don't use Xmin/Xmax/Ymin/Ymax column names - use eastingMin/eastingMax/northingMin/northingMax
</implementation>

<validation>
**Test Strategy:**
1. Unit test CSV import with new columns
2. Unit test getMapCenter() returns correct LatLng using pre-calculated values
3. Unit test parseGridReference with "MapName easting northing" format
4. Unit test map extent calculation using corner coordinates
5. Widget test popup displays correct map name
6. Widget test popup shows peak info when near click location
7. Integration test: enter "Wellington 194507" navigates to correct location
8. Integration test: click on map shows popup with correct map name

**Validation Steps:**
- Verify Tasmap50k entity saves and queries correctly with new fields
- Verify CSV import populates all 75 map records with new fields
- Verify getMapCenter() uses pre-calculated mgrsMid, eastingMid, northingMid
- Verify map extent uses corner coordinates (tl, tr, bl, br)
- Verify "Wellington 194507" parses to correct location
- Verify click popup shows map name for any point in Wellington coverage
- Verify click on peak shows name + elevation
- Verify easting out of range shows error with valid range
- Verify wrap-around ranges correctly validate both segments
</validation>

<done_when>
- [ ] Tasmap50k entity updated with new fields (mgrsMid, eastingMid, northingMid, tl, tr, bl, br)
- [ ] CSV importer fixed: uses rootBundle.loadString() and correct column names
- [ ] getMapCenter() updated to use pre-calculated values
- [ ] Map extent calculation updated to use corner coordinates
- [ ] Database cleared and re-imported after entity changes
- [ ] ObjectBox code regenerated
- [ ] Tab key autocompletes map name from dropdown
- [ ] Enter key with partial match navigates to first map in dropdown
- [ ] All tests pass
- [ ] App builds successfully
</done_when>
