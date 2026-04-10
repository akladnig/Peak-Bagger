## Overview

Add goto by map name (auto-zoom + rectangle) and map grid overlay. Phase 4a: map name → center + zoom + rectangle. Phase 4b: grid overlay with all maps.

**Spec**: `ai_specs/004a-spec.md`

## Context

- **Structure**: layer-first (providers/, services/, screens/)
- **State management**: Riverpod NotifierProvider
- **Reference implementations**:
  - `@lib/providers/map_provider.dart` - MapNotifier with parseGridReference
  - `@lib/services/tasmap_repository.dart` - findByName(), getAllMaps()
  - `@lib/screens/map_screen.dart` - goto input, CircleLayer pattern
  - `@lib/router.dart` - FABs pattern

## Plan

### Phase 1: Repository & State

- **Goal**: Add search methods and state
- [x] `lib/services/tasmap_repository.dart` - add searchMaps(prefix), getMapCenter(map)
- [x] `lib/providers/map_provider.dart` - add MapState fields: selectedMap, showMapOverlay, mapSuggestions
- [x] Verify: `flutter analyze`

### Phase 2: Map Name Parsing

- **Goal**: Parse "Wellington" (no coords)
- [x] `lib/providers/map_provider.dart` - add map-name-only branch in parseGridReference:
  - Detect single word (no digits)
  - Call searchMaps(prefix)
  - Return center or suggestions
- [x] Test: "Wellington" → center location
- [x] Test: case insensitive works
- [x] Verify: `flutter analyze`

### Phase 3: Dropdown UI

- **Goal**: Show dropdown on partial match
- [x] `lib/screens/map_screen.dart` - add ListView below goto TextField
- [x] Show suggestions on input change (debounce 300ms)
- [x] Handle selection from dropdown
- [x] Test: dropdown shows on partial
- [x] Verify: `flutter analyze`

### Phase 4: Rectangle Display

- **Goal**: Blue rectangle around map
- [x] `lib/screens/map_screen.dart` - add PolygonLayer for selected map rectangle
- [x] Calculate center LatLng from getMapCenter()
- [x] Use mapController.camera.fit() with padding
- [x] Test: rectangle visible at zoom 8
- [x] Verify: `flutter analyze`

### Phase 5: Grid FAB (Phase 4b)

- **Goal**: Show maps grid overlay
- [x] `lib/router.dart` - add grid FAB (Icons.grid_on) between goto and info
- [x] Add 'M' key handler for toggle
- [x] `lib/screens/map_screen.dart` - draw all map rectangles (PolygonLayer)
- [x] Show name + series labels (Annotations or text)
- [x] Close on other FAB tap
- [x] Test: FAB toggles overlay
- [x] Test: all rectangles visible
- [x] Verify: `flutter analyze`

### Phase 6: Integration

- [x] Enter "Wellington" → zoom to fit, rectangle visible
- [x] Enter "Welling" → dropdown with options
- [x] Tap grid FAB → all 65 rectangles
- [x] Final verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: PolygonLayer performance with 65+ rectangles (should be fine)
- **Out of scope**: 25k maps, offline tiles