## Overview

Implement Phase 2 - Interactive map of Tasmania with multiple basemaps, location services, and grid reference navigation.

**Spec**: `ai_specs/002-prompt-spec.md`

## Context

- **Structure**: Layer-first (screens, widgets, providers)
- **State management**: Riverpod 3.x Notifier pattern
- **Reference implementations**: `lib/providers/theme_provider.dart` shows Notifier pattern
- **Dependencies**: Already added in pubspec.yaml (flutter_map, mgrs_dart, http)

## Implementation Plan

### Phase 1: Map Provider & State

- [x] Create `lib/providers/map_provider.dart` with Notifier for map state (position, zoom, basemap)
- [x] Add SharedPreferences keys: `map_position_lat`, `map_position_lng`, `map_zoom`
- [x] Implement position save/load on app launch

### Phase 2: Map Screen UI

- [x] Replace placeholder in `lib/screens/map_screen.dart` with flutter_map
- [x] Set default center: Tasmania (-41.5°S, 146.5°E), zoom ~15
- [x] Implement Tracestrack topo as default basemap
- [x] Implement OpenStreetMap as alternative basemap

### Phase 3: Floating Controls

- [x] Add floating Layers icon - opens Drawer from right with basemap selection
- [x] Add floating Show My Location icon (Icons.near_me) - IP-based location
- [x] Add floating Go to Location icon - opens floating text input field

### Phase 4: MGRS Display

- [x] Display MGRS at top-left of map in standard format (e.g., "55G FN\n00000 00000")
- [x] Update MGRS on: map tap/click, Go to Location input, Show My Location
- [x] Real-time MGRS during pan/zoom at lower-left

### Phase 5: Grid Reference Input

- [x] Implement floating TextField with "Go to location" placeholder
- [x] Add "Go" button to navigate, "X" button to close (stays at current position)
- [x] Implement validation: optional grid zone + 6 or 8 digit coordinates
- [x] Default to zone 55G if not provided
- [x] Show "Invalid grid reference" error below field if invalid

### Phase 6: Keyboard Controls

- [x] Implement auto-focus on any keyboard shortcut
- [x] Zoom in: +, ,, <
- [x] Zoom out: -, ., >
- [x] Pan: k/j/h/l or arrow keys
- [x] Open Layers: b key
- [x] Show My Location: s key
- [x] Go to Location: g key

### Phase 7: Touch Controls

- [x] Pinch-to-zoom
- [x] Drag-to-pan
- [x] Zoom level indicator at lower-left

### Phase 8: Tile Management

- [ ] On first launch: download tile sets for zoom levels 6-14
- [ ] Load tiles from assets folder (not built-in caching)
- [ ] Implement loading spinner overlay
- [ ] Implement error dialog with "Retry" button

### Phase 9: Location Services

- [x] IP-based location using ipapi.co
- [ ] (Not needed - using IP instead of GPS)

## Risks / Out of scope

- **Risks**: None identified
- **Out of scope**: iOS support, GPX import, database tile storage (future phases)