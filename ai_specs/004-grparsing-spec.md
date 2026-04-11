<goal>
Clarify and standardize grid reference parsing rules for the goto input field. Ensure consistent, predictable behavior across all input formats so users can navigate to any location using map names, coordinates, or MGRS references.
</goal>

<spec_intent>
This spec refactors existing code in `parseGridReference` to match the standardized behavior described herein. The existing implementation has inconsistent coordinate interpretation rules that need to be corrected. This is a **breaking change** for some input formats (notably 3-digit and 4-digit coordinates).
</spec_intent>

<background>
**Tech Stack:** Flutter with Riverpod, mgrs_dart for coordinate conversion
**Project:** peak_bagger - Tasmanian peak bagging app
**Files to examine:**
- @lib/providers/map_provider.dart - parseGridReference function to update
- @lib/services/tasmap_repository.dart - getMapCenter, findByMgrs100kId

**Existing Patterns:**
- parseGridReference returns (LatLng?, String?) tuple
- MGRS format: "55GEN1940050700" (no spaces - mgrs_dart expects continuous string)
- Wellington map center: 55GEN2000055000
</background>

<user_flows>
**Primary Flow - Map Name Only:**
1. User types "Wellington" in goto input
2. System finds exact map match
3. System navigates to map center (55GEN2000055000)

**Primary Flow - Map Name + Coordinates:**
1. User types "Wellington 194507" or "Wellington 194 507"
2. System parses map name "Wellington" + coordinates
3. System constructs MGRS: 55GEN1940050700
4. System navigates to location

**Primary Flow - Coordinates Only (Current Map Context):**
1. User is viewing Wellington map area
2. User types "194507" or "194 507"
3. System uses current MGRS100k square (EN)
4. System constructs MGRS: 55GEN1940050700
5. System navigates to location

**Primary Flow - MGRS100k Prefix:**
1. User types "EN0123456789" or "EN 01234 56789"
2. System parses 2-letter prefix + coordinates
3. System constructs MGRS: 55GEN0123456789
4. System navigates to location

**Error Flow - Invalid Format:**
1. User types invalid input
2. System shows error message
3. User corrects input and retries
</user_flows>

<requirements>
**Functional - Map Name Only:**
1. "Wellington" → 55GEN2000055000 (map center)
2. Map name must match exactly (case-insensitive)
3. If multiple maps match, show dropdown (existing behavior)

**Functional - Map Name + Coordinates:**
4. "Wellington 15" → 55GEN1000050000 (1-digit easting, 1-digit northing)
5. "Wellington 1 5" → 55GEN1000050000 (space-separated 1-digit each)
6. "Wellington 1951" → 55GEN1900051000 (2-digit easting, 2-digit northing)
7. "Wellington 19 51" → 55GEN1900051000 (space-separated 2-digit each)
8. "Wellington 194507" → 55GEN1940050700 (3-digit easting, 3-digit northing)
9. "Wellington 194 507" → 55GEN1940050700 (space-separated 3-digit each)
10. "Wellington 19435078" → 55GEN1943050780 (4-digit easting, 4-digit northing)
11. "Wellington 1943 5078" → 55GEN1943050780 (space-separated 4-digit each)
12. "Wellington 1943250789" → 55GEN1943250789 (5-digit easting, 5-digit northing)
13. "Wellington 19432 50789" → 55GEN1943250789 (space-separated 5-digit each)
14. Space-separated coordinates with different digit counts are invalid: "Wellington 19 4507" → error "Easting and northing must have same digit count when space-separated"

**Functional - Coordinates Only (Current Map Context):**
15. When current MGRS display shows Wellington area (EN), "15" → 55GEN1000050000
16. When current MGRS display shows Wellington area (EN), "194507" → 55GEN1940050700
17. All coordinate formats from requirements 4-14 apply
18. If no current MGRS100k square available, show error

**Functional - MGRS100k Prefix:**
19. "EN0123456789" → 55GEN0123456789 (10-digit continuous: 5-digit easting + 5-digit northing)
20. "EN 01234 56789" → 55GEN0123456789 (space-separated 5-digit each)
21. "EN 194507" → 55GEN1940050700 (space-separated 3-digit each)
22. MGRS100k prefix must be valid 2-letter code from database
23. MGRS100k prefix + continuous digits: split evenly if even digit count, otherwise error "Coordinate digits must be even count for MGRS100k prefix"

**Coordinate Digit Interpretation (applies to requirements 4-14, 15-17, 19-21):**
24. 1-digit: multiply by 10000 (e.g., "1" → "10000")
25. 2-digit: multiply by 1000 (e.g., "19" → "19000")
26. 3-digit: multiply by 100 (e.g., "194" → "19400")
27. 4-digit: multiply by 10 (e.g., "1943" → "19430")
28. 5-digit: use as-is (e.g., "19432" → "19432")

**Error Handling:**
29. Invalid map name: "Map not found: [name]"
30. Invalid MGRS100k square: "Unknown MGRS square: [code]"
31. Coordinates out of range: "Coordinates out of range for [map name]"
32. No current MGRS context: "Cannot determine current location"
33. Invalid format: "Invalid format. Use: MapName coordinates or EN coordinates"
34. Mismatched digit counts: "Easting and northing must have same digit count when space-separated"
35. Odd digit count: "Coordinate digits must be even count"

**Edge Cases:**
36. Map name with spaces: "Port Davey 194507" → parse "Port Davey" as map name
37. Wrap-around ranges: Validate easting/northing against map ranges
38. Multiple MGRS100k squares: Select correct square based on easting value
39. Partial coordinate (odd digit count): "Wellington 194" → invalid, error "Coordinate digits must be even count" (BREAKING CHANGE from existing behavior)
40. Single coordinate value: "Wellington 19" → invalid, need both easting and northing
</requirements>

<boundaries>
**Edge Cases:**
- Extra spaces: "Wellington  194  507" → normalize and parse
- Leading zeros: "Wellington 019405" → treat as 6-digit, parse correctly

**Error Scenarios:**
- Unknown map name: Show error with suggestion if similar name exists
- Coordinates outside map range: Show valid range for that map
- Invalid MGRS conversion: Show "Invalid grid reference"

**Limits:**
- Maximum 10 digits per coordinate component
- Map names: case-insensitive matching
</boundaries>

<implementation>
**Files to modify:**
- @lib/providers/map_provider.dart - Update parseGridReference function

**Breaking Changes:**
- 3-digit coordinates: Previously accepted with northingMin, now rejected as invalid
- 4-digit coordinates: Previously split 2+2 and multiplied by 1000, now multiplied by 10
- Space-separated coordinates with different digit counts: Now rejected as invalid

**Parsing Logic:**
1. Check for MGRS100k prefix (2 letters + digits)
2. Check for map name + coordinates (space-separated)
3. Check for coordinates only (use current MGRS100k from state)
4. Check for map name only (navigate to center)

**Coordinate Conversion:**
- Apply digit interpretation rules (requirements 24-28)
- Construct MGRS: "55G" + MGRS100k + easting5digit + northing5digit (no spaces)
- Convert to LatLng using mgrs_dart

**What to avoid:**
- Don't change MGRS conversion logic in tasmap_repository.dart
- Don't break existing "Wellington 194507" format support (6-digit continuous)
</implementation>

<validation>
**Unit Tests Required:**
1. Map name only: "Wellington" → center coordinates
2. Map name + 1-digit: "Wellington 15" → 55GEN1000050000
3. Map name + 1-digit spaced: "Wellington 1 5" → 55GEN1000050000
4. Map name + 2-digit: "Wellington 1951" → 55GEN1900051000
5. Map name + 2-digit spaced: "Wellington 19 51" → 55GEN1900051000
6. Map name + 3-digit: "Wellington 194507" → 55GEN1940050700
7. Map name + 3-digit spaced: "Wellington 194 507" → 55GEN1940050700
8. Map name + 4-digit: "Wellington 19435078" → 55GEN1943050780
9. Map name + 4-digit spaced: "Wellington 1943 5078" → 55GEN1943050780
10. Map name + 5-digit: "Wellington 1943250789" → 55GEN1943250789
11. Map name + 5-digit spaced: "Wellington 19432 50789" → 55GEN1943250789
12. Coordinates only (with context): "194507" → 55GEN1940050700
13. MGRS100k prefix: "EN0123456789" → 55GEN0123456789
14. MGRS100k prefix spaced: "EN 01234 56789" → 55GEN0123456789
15. Invalid map name: returns error
16. Invalid MGRS100k: returns error
17. Coordinates out of range: returns error with range info
18. MGRS to LatLng conversion: "55GEN1940050700" → (-42.89606, 147.23761) within ±0.00001 degrees
19. Odd digit count: "Wellington 194" → returns error "Coordinate digits must be even count"
20. Mismatched digit counts: "Wellington 19 4507" → returns error "Easting and northing must have same digit count when space-separated"

**Test File:**
- Add tests to existing file: test/tasmap_repository_test.dart

**Test Setup for Coordinates-Only Tests:**
- Set `state.currentMgrs` to `'55G EN\n20000 55000'` before testing coordinates-only input
- This simulates user being in Wellington map area

**Validation Steps:**
- Run all unit tests: `flutter test test/tasmap_repository_test.dart`
- Manual test each input format in goto input field
- Verify error messages display correctly
</validation>

<done_when>
- [ ] parseGridReference handles all input formats correctly
- [ ] Unit tests pass for all 20 test cases
- [ ] Manual testing confirms correct behavior
- [ ] Error messages are clear and helpful
- [ ] No regression in existing functionality
- [ ] Breaking changes documented and tested
</done_when>
