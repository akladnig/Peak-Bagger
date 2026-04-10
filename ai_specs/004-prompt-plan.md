## Overview

Add tasmap 50k database and goto search by map name. Users can search "Wellington 194507" → MGRS 55GEN1940050700. Map click shows popup with map name + nearby peak.

**Spec**: `ai_specs/004-prompt-spec.md`

## Context

- **Structure**: feature-first (models/, services/, providers/, screens/)
- **State management**: Riverpod NotifierProvider
- **Reference implementations**: 
  - `@lib/models/peak.dart` - ObjectBox entity with @Entity(), @Id()
  - `@lib/services/peak_repository.dart` - Repository pattern with Box<T>
  - `@lib/providers/map_provider.dart` - MapNotifier with parseGridReference logic
- **Assumptions**: None - spec is complete

## Plan

### Phase 1: Data Layer

- **Goal**: Tasmap50k entity + CSV import + repository
- [ ] `lib/models/tasmap50k.dart` - Entity with fields: id, series, name, parentSeries, mgrs100kId (List<String>), eastingMin, eastingMax, northingMin, northingMax
- [ ] `lib/services/tasmap_repository.dart` - Repository with Box<Tasmap50k>, methods: getAll(), findByName(), findByMgrs100kId(), isEmpty()
- [ ] `lib/services/csv_importer.dart` - CSV import using package:csv, parse MGRS column by splitting whitespace
- [ ] Add `csv` package to pubspec.yaml
- [ ] Regenerate ObjectBox: `dart run build_runner build`
- [ ] TDD: Verify CSV import parses "CP DP CQ DQ" to 4 elements
- [ ] TDD: Verify entity saves and queries correctly
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Goto Search Update

- **Goal**: Parse "MapName easting northing" and "EN 194507" formats
- [ ] `lib/providers/map_provider.dart` - Add tasmapRepository, update parseGridReference():
  - Detect map name vs MGRS 100k square input
  - Lookup map by name → get mgrs100kId list + ranges
  - Validate easting/northing against ranges (handle wrap-around 80-20)
  - Return error or construct full MGRS
- [ ] TDD: Parse "Wellington 194507" → MGRS 55GEN1940050700
- [ ] TDD: Parse "Wellington 194 507" (space between) → MGRS 55GEN1940050700
- [ ] TDD: Parse "Wellington 1950" (compact) → MGRS 55GEN1900050000
- [ ] TDD: Parse "Wellington 19 50" (space) → MGRS 55GEN1900050000
- [ ] TDD: Parse "EN 194507" → full MGRS 55GEN + coords
- [ ] TDD: Parse "Black Bluff 50" uses northingMin-northingMax range
- [ ] TDD: Error "Easting 50 out of range for Black Bluff. Valid range: 80-99 OR 0-20"
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Map Click Popup

- **Goal**: Show popup with map name on 'I' key press
- [ ] `lib/providers/map_provider.dart` - Add popup state: showPopup, popupMapName, popupPeakName, popupPeakElevation, popupMgrs
- [ ] `lib/screens/map_screen.dart` - Add 'I' key handler:
  - Convert current map center to MGRS
  - Find map by X/Y range (easting/northing within map ranges)
  - Find peak within 100m (use latlong2 Distance class)
  - Set popup state
- [ ] Add popup UI widget in map screen Stack
- [ ] Handle dismiss: Escape key or close button
- [ ] TDD: Popup displays correct map name for current center
- [ ] TDD: Popup shows peak name + elevation within 100m
- [ ] TDD: "Outside Tasmania 50k coverage" when no map found
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: First Launch Import

- **Goal**: Import CSV on first app run
- [ ] `lib/main.dart` - Add import check: if tasmapRepository.isEmpty() → import CSV
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 5: Integration

- [ ] Integration test: Enter "Wellington 194507" → navigates to correct location
- [ ] Integration test: Enter "Wellington 194 507" (space between) → navigates to correct location
- [ ] Integration test: Click on map → shows popup with correct map name
- [ ] Final verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: None identified
- **Out of scope**: 25k maps, offline map tiles