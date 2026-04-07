## Overview

Implement Phase 2 - Interactive map of Tasmania with multiple basemaps, location services, and grid reference navigation.

**Spec**: `ai_specs/002-prompt-spec.md`

## Context

- **Structure**: Layer-first (screens, widgets, providers)
- **State management**: Riverpod 3.x Notifier pattern
- **Reference implementations**: `lib/providers/theme_provider.dart` shows Notifier pattern
- **Dependencies**: Already added in pubspec.yaml (flutter_map, geolocator, mgrs_dart)

## Implementation Plan

### Phase 1: Map Provider & State

- [x] Create `lib/providers/map_provider.dart` with Notifier for map state (position, zoom, basemap)
- [x] Add SharedPreferences keys: `map_position_lat`, `map_position_lng`, `map_zoom`
- [x] Implement position save/load on app launch

### Phase 2: Map Screen UI

- [x] Replace placeholder in `lib/screens/map_screen.dart` with flutter_map
- [x] Set default center: Tasmania (-41.5°S, 146.5°E), zoom ~11
- [x] Implement Tracestrack topo as default basemap
- [x] Implement OpenStreetMap as alternative basemap

### Phase 3: Floating Controls

- [x] Add floating Layers icon - opens sliding panel with radio buttons for basemap selection
- [x] Add floating Show My Location icon (Icons.near_me)
- [x] Add floating Go to Location icon (Icons.moved_location) - opens floating text input field

### Phase 4: MGRS Display

- [x] Display MGRS at top-left of map in standard format (e.g., "55G FN00000 00000")
- [x] Update MGRS on: map tap/click, Go to Location input, Show My Location
- [ ] Show cursor arrow during trackpad drag with real-time MGRS at cursor

### Phase 5: Grid Reference Input

- [x] Implement floating TextField with "Go to location" placeholder
- [x] Add "Go" button to navigate, "X" button to close (stays at current position)
- [x] Implement validation: optional grid zone + 6 or 8 digit coordinates
- [x] Default to zone 55G if not provided
- [x] Show "Invalid grid reference" error below field if invalid

### Phase 6: Keyboard Controls

- [ ] Implement auto-focus on any keyboard shortcut
- [ ] Zoom in: +, ,, <
- [ ] Zoom out: -, ., >
- [ ] Pan: k/j/h/l or arrow keys
- [ ] Show My Location: s key
- [ ] Go to Location: g key

### Phase 7: Touch Controls

- [ ] Pinch-to-zoom
- [ ] Drag-to-pan
- [ ] Zoom level indicator at bottom-left

### Phase 8: Tile Management

- [ ] On first launch: download tile sets for zoom levels 6-14
- [ ] Load tiles from assets folder (not built-in caching)
- [ ] Implement loading spinner overlay
- [ ] Implement error dialog with "Retry" button

### Phase 9: Location Services

- [ ] Request permission on first tap of Show My Location or map screen
- [ ] Handle permission denied gracefully - allow manual grid reference entry

## Risks / Out of scope

- **Risks**: None identified
- **Out of scope**: iOS support, GPX import, database tile storage (future phases)