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
- [ ] `lib/services/tasmap_repository.dart` - add searchMaps(prefix), getMapCenter(map)
- [ ] `lib/providers/map_provider.dart` - add MapState fields: selectedMap, showMapOverlay, mapOverlayMode, mapNameSuggestions
- [ ] Verify: `flutter analyze`

### Phase 2: Map Name Parsing

- **Goal**: Parse "Wellington" (no coords)
- [ ] `lib/providers/map_provider.dart` - add map-name-only branch in parseGridReference:
  - Detect single word (no digits)
  - Call searchMaps(prefix)
  - Return center or suggestions
- [ ] Test: "Wellington" → center location
- [ ] Test: case insensitive works
- [ ] Verify: `flutter analyze`

### Phase 3: Dropdown UI

- **Goal**: Show dropdown on partial match
- [ ] `lib/screens/map_screen.dart` - add ListView below goto TextField
- [ ] Show suggestions on input change (debounce 300ms)
- [ ] Handle selection from dropdown
- [ ] Test: dropdown shows on partial
- [ ] Verify: `flutter analyze`

### Phase 4: Rectangle Display

- **Goal**: Blue rectangle around map
- [ ] `lib/screens/map_screen.dart` - add PolygonLayer for selected map rectangle
- [ ] Calculate center LatLng from getMapCenter()
- [ ] Use mapController.camera.fit() with padding
- [ ] Test: rectangle visible at zoom 8
- [ ] Verify: `flutter analyze`

### Phase 5: Grid FAB (Phase 4b)

- **Goal**: Show maps grid overlay
- [ ] `lib/router.dart` - add grid FAB (Icons.grid_on) between goto and info
- [ ] Add 'M' key handler for toggle
- [ ] `lib/screens/map_screen.dart` - draw all map rectangles (PolygonLayer)
- [ ] Show name + series labels (Annotations or text)
- [ ] Close on other FAB tap
- [ ] Test: FAB toggles overlay
- [ ] Test: all rectangles visible
- [ ] Verify: `flutter analyze`

### Phase 6: Integration

- [ ] Enter "Wellington" → zoom to fit, rectangle visible
- [ ] Enter "Welling" → dropdown with options
- [ ] Tap grid FAB → all 65 rectangles
- [ ] Final verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: PolygonLayer performance with 65+ rectangles (should be fine)
- **Out of scope**: 25k maps, offline tiles