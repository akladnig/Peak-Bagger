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

## Manual Updates

- 2026-04-10: CSV now contains full 5-digit values for Xmin, Xmax, Ymin, Ymax (not *1000). Updated csv_importer.dart and map_provider.dart range display accordingly.

## Plan

### Phase 1: Data Layer

- **Goal**: Tasmap50k entity + CSV import + repository
- [x] `lib/models/tasmap50k.dart` - Entity with fields: id, series, name, parentSeries, mgrs100kId (List<String>), eastingMin, eastingMax, northingMin, northingMax
- [x] `lib/services/tasmap_repository.dart` - Repository with Box<Tasmap50k>, methods: getAll(), findByName(), findByMgrs100kId(), isEmpty()
- [x] `lib/services/csv_importer.dart` - CSV import using package:csv, parse MGRS column by splitting whitespace
- [x] Add `csv` package to pubspec.yaml
- [x] Regenerate ObjectBox: `dart run build_runner build`
- [x] Verify: CSV import parses "CP DP CQ DQ" to 4 elements (test exists)
- [x] Verify: entity saves and queries correctly (test exists)
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Goto Search Update

- **Goal**: Parse "MapName easting northing" and "EN 194507" formats
- [x] `lib/providers/map_provider.dart` - Add tasmapRepository, update parseGridReference():
  - Detect map name vs MGRS 100k square input
  - Lookup map by name → get mgrs100kId list + ranges
  - Validate easting/northing against ranges (handle wrap-around 80-20)
  - Return error or construct full MGRS
- [x] Parse "Wellington 194507" → MGRS 55GEN1940050700 (manual test passed)
- [x] Parse "Wellington 194 507" (space between) → MGRS 55GEN1940050700 (manual test passed)
- [x] Parse "Wellington 1950" (compact) → MGRS 55GEN1900050000 (manual test passed)
- [x] Parse "Wellington 19 50" (space) → MGRS 55GEN1900050000 (manual test passed)
- [x] Parse "EN 194507" → full MGRS 55GEN + coords (manual test passed)
- [x] Parse "Black Bluff 50" uses northingMin-northingMax range
- [x] Error "Easting 50 out of range for Black Bluff. Valid range: 80-99 OR 0-20"
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Map Click Popup

- **Goal**: Show popup with map name on 'I' key toggle
- [x] `lib/providers/map_provider.dart` - Add popup state: showPopup, popupMapName, popupPeakName, popupPeakElevation, popupMgrs
- [x] `lib/screens/map_screen.dart` - Add 'I' key handler:
  - Convert current map center to MGRS
  - Find map by X/Y range (easting/northing within map ranges)
  - Find peak within 100m (use latlong2 Distance class)
  - Set popup state
- [x] Add popup UI widget in map screen Stack
- [x] Handle dismiss: Escape key or close button
- [x] Handle dismiss: Click anywhere or press any other key
- [x] Handle dismiss: Click on any FAB or menu bar item (except theme toggle)
- [x] Popup displays to the right of marker (selected location), center screen if marker too close to right edge
- [x] Popup displays correct map name for current center (manual test passed)
- [x] Popup shows peak name + elevation within 100m
- [x] "Outside Tasmania 50k coverage" when no map found (test exists)
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: First Launch Import

- **Goal**: Import CSV on first app run
- [x] `lib/main.dart` - Add import check: if tasmapRepository.isEmpty() → import CSV
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 5: Integration

- [x] Enter "Wellington 194507" → navigates to correct location (manual test passed)
- [x] Enter "Wellington 194 507" (space between) → navigates to correct location (manual test passed)
- [x] Click on map → shows popup with correct map name (manual test passed)
- [x] Goto "Wellington 194 507" + press I → popup shows "Wellington" (not "Green Ponds") (manual test passed)
- [x] Final verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: None identified
- **Out of scope**: 25k maps, offline map tiles
