## Overview

Implement GPX tracks display feature: import Tasmanian GPX tracks, save to ObjectBox, display on map with toggle.

**Spec**: `ai_specs/005-gpx-tracks-spec.md`

## Context

- **Structure**: Layer-first (lib/providers, lib/services, lib/models)
- **State management**: Riverpod
- **Reference implementations**: 
  - `lib/models/peak.dart` - ObjectBox entity pattern
  - `lib/services/peak_repository.dart` - CRUD pattern
  - `lib/providers/map_provider.dart` - MapNotifier pattern

## Implementation order (TDD slices)

### Phase 1: GPXTrack entity (TDD)

- [ ] `lib/models/gpx_track.dart` - Create entity following Peak pattern:
  - @Entity() class GPXTrack
  - @Id() int gpxTrackId
  - String fileLocation
  - String trackName
  - DateTime? startDateTime (nullable)
  - double? distance (nullable)
  - double? ascent (nullable)  
  - int? totalTimeMillis (nullable)
  - int trackColour (default 0xFFa726bc)
- [ ] Run `dart run build_runner build` to generate ObjectBox bindings
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Repository (TDD)

- [ ] `lib/services/gpx_track_repository.dart` - Create repository:
  - Constructor takes Store (ObjectBox)
  - addTrack(GPXTrack) → int (returns id)
  - getAllTracks() → List<GPXTrack>
  - getTrackCount() → int (for isEmpty check)
  - findById(int) → GPXTrack?
  - findByFileLocation(String) → GPXTrack?
  - deleteTrack(int) → bool
- [ ] `test/gpx_track_test.dart` - TDD test slices:
  - Slice 1 (RED): GPXTrack entity - empty constructor
  - Slice 2 (GREEN): Add fromMap/fromJson constructor
  - Slice 3 (RED): Repository.addTrack() persists to ObjectBox
  - Slice 4 (GREEN): Repository.getAllTracks() returns all tracks
  - Slice 5 (RED): Repository.findByFileLocation() finds track
  - Slice 6 (GREEN): Repository.getTrackCount() returns 0 when empty
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: GPXImporter service

- [ ] `lib/services/gpx_importer.dart` - Create import logic:
  - parseGpxFile(String path) → GPXTrack? - parses XML, extracts trackName, first point lat/lng
  - isTasmanian(double lat, double lng) → bool - checks coords within Tasmania bounds (-39 to -44 lat, 143 to 148 lng)
  - getTracksFolder() → String - configurable path for ~/Documents/Bushwalking/Tracks
  - getTasmaniaFolder() → String - configurable path for Tasmania subfolder
- [ ] Note: For initial implementation, extract only fileLocation and trackName from GPX
- [ ] Verify: `flutter analyze`

### Phase 4: Provider setup

- [ ] `lib/providers/gpx_track_provider.dart` - Provider setup:
  - Provider for GpxTrackRepository (requires objectboxStore)
- [ ] Verify: `flutter analyze`

### Phase 5: MapProvider state

- [ ] `lib/providers/map_provider.dart` - Add state:
  - import 'package:peak_bagger/models/gpx_track.dart'
  - import 'package:peak_bagger/providers/gpx_track_provider.dart'
  - Add to MapState: tracks (List<GPXTrack>), showTracks (bool)
  - Add toggleTracks() method to MapNotifier
  - Load tracks in build() using repository
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 6: UI - FABs

- [ ] `lib/router.dart` - Add FABs (order: info, show tracks, import placeholder, grid):
  - Show tracks FAB with Icons.route
  - Import FAB placeholder with Icons.input (for future)
  - Handle disabled state: onPressed: null, color: red (when tracks.isEmpty)
- [ ] Verify: `flutter analyze`

### Phase 7: UI - Map track rendering

- [ ] `lib/screens/map_screen.dart` - Add track rendering:
  - Import GpxTrackRepository via provider
  - Load tracks on build
  - Render polylines using flutter_map when showTracks is true
  - Use colour from trackColour field (#a726bc)
- [ ] Verify: `flutter analyze`

### Phase 8: Keyboard shortcut

- [ ] `lib/screens/map_screen.dart` - Add Shortcuts widget:
  - Wrap map with Shortcuts mapping 't' to toggleTracks intent
  - Wrap in Focus widget (same scope as other shortcuts)
  - Use Actions to handle intent
- [ ] Verify: `flutter analyze`

### Phase 9: First launch import

- [ ] `lib/providers/map_provider.dart` - Add import check:
  - In build(), check if repository.getTrackCount() == 0
  - If empty, call GPXImporter to scan folders
  - Set flag after successful import (via repository)
- [ ] Verify: `flutter analyze` && manual test

## Dependencies to add

- xml: ^6.0.0 (for GPX parsing)
- Platform permissions: Handle file access appropriately

## Risks / Out of scope

- **Risks**: GPX parsing library needs to be added to pubspec.yaml
- **Out of scope**: 
  - Move to folder logic (Phase 1 - leave in place)
  - Direction arrows on track
  - Track statistics (distance, ascent, time)
  - Colour selection per track