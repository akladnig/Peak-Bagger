## Overview

Add ObjectBox database for storing Tasmanian peaks from Overpass API with search and map markers.

**Spec**: `ai_specs/003-prompt-spec.md`

## Context

- **Structure**: Feature-first (screens, providers, services, widgets)
- **State management**: Riverpod (NotifierProvider)
- **Reference**: lib/providers/map_provider.dart, lib/screens/map_screen.dart
- **Dependencies to add**: objectbox, objectbox_generator, build_runner

## Plan

### Phase 1: Database Setup + Peak Entity

- **Goal**: ObjectBox configured, Peak entity created, OverpassService querying peaks

- [x] pubspec.yaml - Add objectbox ^5.3.1, objectbox_generator, build_runner
- [x] lib/models/peak.dart - Create Peak entity (id, name, elevation, latitude, longitude, area)
- [x] lib/main.dart - Initialize ObjectBoxStore before runApp()
- [x] lib/services/overpass_service.dart - Query Overpass API for Tasmanian peaks
- [x] lib/services/peak_repository.dart - CRUD operations for peaks
- [x] TDD: Parse Overpass JSON response → validate 1029 peaks loaded
- [x] Verify: dart run build_runner build && flutter analyze

### Phase 2: Map Integration + State

- **Goal**: Peaks load on map screen, display as firebrick triangles at zoom 12+

- [x] lib/providers/map_provider.dart - Add peaks, isLoadingPeaks, searchResults, searchQuery to MapState
- [x] lib/screens/map_screen.dart - Add MarkerLayer for peak triangles at zoom >= 12
- [x] TDD: Search filtering logic by name/elevation
- [x] Verify: flutter analyze && flutter test

### Phase 3: Search UI + Markers

- **Goal**: Search box with dropdown, tooltips on hover

- [x] lib/screens/map_screen.dart - Add TextField search box with dropdown overlay
- [x] lib/screens/map_screen.dart - Add Marker tooltips with name + elevation (not supported in flutter_map 8.x - feature not implemented)
- [x] lib/router.dart - Ensure search FAB toggles showPeakSearch
- [x] TDD: Mount Arthur search returns 3 results
- [x] Verify: flutter analyze && flutter test

### Phase 4: Settings + Refresh

- **Goal**: Refresh Peak Data button in Settings

- [x] lib/screens/settings_screen.dart - Add Refresh Peak Data button (below Download Offline Tiles)
- [x] TDD: Refresh button triggers re-fetch from Overpass
- [x] Verify: flutter analyze && flutter test

## Risks / Out of scope

- **Risks**: Overpass API rate limiting; 1029 peaks may exceed 1500 limit
- **Out of scope**: Clustering at lower zoom levels; area field population