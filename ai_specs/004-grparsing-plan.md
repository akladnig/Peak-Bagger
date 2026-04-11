## Overview

Refactor `parseGridReference` to standardize coordinate interpretation. Extract parsing logic into testable helper; fix breaking changes for 3-digit and 4-digit formats.

**Spec**: `ai_specs/004-grparsing-spec.md`

## Context

- **Structure**: Layer-first (lib/providers, lib/services, lib/models)
- **State management**: Riverpod
- **Reference implementations**: `lib/providers/map_provider.dart:306-811` (existing parseGridReference)
- **Assumptions/Gaps**: Tests will target extracted helper function; parseGridReference integration tested manually

## Plan

### Phase 1: Extract coordinate parsing logic

- **Goal**: Create testable helper function for coordinate digit interpretation
- [x] `lib/services/grid_reference_parser.dart` - Create `GridReferenceParser` class with static methods:
  - `parseCoordinates(String coords, {int? digitCount})` → `({String easting, String northing})?`
  - `interpretDigit(String digit, int position)` → `String` (multiply by appropriate power of 10)
  - `validateEvenDigitCount(String coords)` → `String?` (error message or null)
- [x] TDD: 1-digit "1" → "10000" for both easting and northing
- [x] TDD: 2-digit "19" → "19000" for both
- [x] TDD: 3-digit "194" → "19400" for both
- [x] TDD: 4-digit "1943" → "19430" for both (BREAKING: was split 2+2)
- [x] TDD: 5-digit "19432" → "19432" for both
- [x] TDD: Odd digit count "194" → returns error "Coordinate digits must be even count"
- [x] TDD: Space-separated mismatched "19 4507" → returns error
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Update parseGridReference

- **Goal**: Refactor parseGridReference to use GridReferenceParser
- [x] `lib/providers/map_provider.dart` - Import GridReferenceParser
- [x] `lib/providers/map_provider.dart:416-476` - Replace coordinate interpretation logic with GridReferenceParser calls
- [x] `lib/providers/map_provider.dart:435-441` - Remove 3-digit special case (now rejected as invalid)
- [x] `lib/providers/map_provider.dart:442-453` - Fix 4-digit handling (use GridReferenceParser instead of split 2+2)
- [x] `lib/providers/map_provider.dart:351-367` - Add validation for mismatched space-separated digit counts
- [x] TDD: "Wellington 194" → error "Coordinate digits must be even count"
- [x] TDD: "Wellington 19 4507" → error "Easting and northing must have same digit count when space-separated"
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Comprehensive test coverage

- **Goal**: Add all 20 test cases from spec
- [ ] `test/grid_reference_parser_test.dart` - Create new test file for GridReferenceParser
- [ ] TDD: Map name + 1-digit continuous: "Wellington 15" → 55GEN1000050000
- [ ] TDD: Map name + 1-digit spaced: "Wellington 1 5" → 55GEN1000050000
- [ ] TDD: Map name + 2-digit continuous: "Wellington 1951" → 55GEN1900051000
- [ ] TDD: Map name + 2-digit spaced: "Wellington 19 51" → 55GEN1900051000
- [ ] TDD: Map name + 3-digit continuous: "Wellington 194507" → 55GEN1940050700
- [ ] TDD: Map name + 3-digit spaced: "Wellington 194 507" → 55GEN1940050700
- [ ] TDD: Map name + 4-digit continuous: "Wellington 19435078" → 55GEN1943050780
- [ ] TDD: Map name + 4-digit spaced: "Wellington 1943 5078" → 55GEN1943050780
- [ ] TDD: Map name + 5-digit continuous: "Wellington 1943250789" → 55GEN1943250789
- [ ] TDD: Map name + 5-digit spaced: "Wellington 19432 50789" → 55GEN1943250789
- [ ] TDD: MGRS100k prefix continuous: "EN0123456789" → 55GEN0123456789
- [ ] TDD: MGRS100k prefix spaced: "EN 01234 56789" → 55GEN0123456789
- [ ] TDD: MGRS100k prefix 3-digit spaced: "EN 194 507" → 55GEN1940050700
- [ ] TDD: MGRS to LatLng: "55GEN1940050700" → (-42.89601, 147.237612) ±0.00001
- [ ] TDD: Invalid map name → error
- [ ] TDD: Invalid MGRS100k → error
- [ ] TDD: Coordinates out of range → error with range info
- [ ] TDD: Odd digit count: "Wellington 194" → error "Coordinate digits must be even count"
- [ ] TDD: Mismatched digit counts: "Wellington 19 4507" → error "Easting and northing must have same digit count when space-separated"
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Integration verification

- **Goal**: Manual testing of goto input field
- [ ] Manual: Test "Wellington" → navigates to map center
- [ ] Manual: Test "Wellington 194507" → navigates to correct location
- [ ] Manual: Test "194507" (with current MGRS context) → navigates correctly
- [ ] Manual: Test "EN0123456789" → navigates correctly
- [ ] Manual: Test "Wellington 194" → shows error message
- [ ] Manual: Test "Wellington 19 4507" → shows error message
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: Breaking change for users expecting 3-digit/4-digit old behavior; MGRS format string construction may need adjustment
- **Out of scope**: Changes to tasmap_repository.dart, changes to MGRS conversion logic, UI changes to goto input field
