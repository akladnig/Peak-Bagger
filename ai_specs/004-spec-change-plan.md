## Overview

Update Tasmap50k to use pre-calculated map centers and corners from CSV. Fix broken CSV importer (File() → rootBundle, wrong column names).

**Spec**: `ai_specs/004-spec-change-spec.md`

## Context

- **Structure**: layer-first (models/, services/, providers/, screens/)
- **State management**: Riverpod NotifierProvider
- **Reference implementations**: `@lib/models/peak.dart` (ObjectBox entity pattern)
- **Assumptions**: None — spec is complete after review

## Plan

### Phase 1: Entity + CSV Importer Fix

- **Goal**: Add new fields, fix broken CSV import
- [x] `lib/models/tasmap50k.dart` - Add fields: mgrsMid (String), eastingMid (int), northingMid (int), tl (String), tr (String), bl (String), br (String)
- [x] `lib/services/csv_importer.dart` - Replace `File()` with `rootBundle.loadString()`, fix column names (eastingMin not Xmin), add new field imports
- [x] `dart run build_runner build` - Regenerate ObjectBox code
- [x] TDD: CSV import returns 75 maps with correct field values
- [x] TDD: CSV import handles missing columns gracefully
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Repository + Map Screen

- **Goal**: Use pre-calculated values, simplify map extent logic
- [x] `lib/services/tasmap_repository.dart` - Update getMapCenter(): use mgrsMid/eastingMid/northingMid, remove range averaging
- [x] `lib/screens/map_screen.dart` - Update _buildMapRectangle() and _buildAllMapRectangles(): parse corners (substring 0-2, 2-7, 7-12), convert via `55G{corner}`
- [x] TDD: getMapCenter() returns correct LatLng for Wellington using pre-calculated values
- [x] TDD: Corner parsing extracts correct MGRS100k, easting, northing from "BR2000069999"
- [x] TDD: Map extent polygon uses corner coordinates
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Database Migration + Integration

- **Goal**: Clear old data, re-import with new schema
- [ ] `lib/main.dart` - Add clearAll() before import check (one-time migration)
- [ ] Manual: Delete app data or run clearAll, verify re-import populates new fields
- [ ] Manual: "Wellington 194507" navigates to correct location
- [ ] Manual: Map overlay shows correct extents for all 75 maps
- [ ] Manual: Info popup shows correct map name at clicked location
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: ObjectBox schema migration may require app reinstall on existing devices
- **Out of scope**: 25k maps, offline map tiles
