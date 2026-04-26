## Overview

Implement persistent tile caching using flutter_map_tile_caching (FMTC) for all 5 basemaps. Single FMTCTileProvider with urlTransformer scales to N basemaps.

**Spec**: `ai_specs/002-tile-caching-spec.md`

## Context

- **Library**: flutter_map_tile_caching ^10.1.1
- **State management**: Riverpod (flutter_riverpod ^3.2.1)
- **Structure**: Feature-first, services live in `lib/services/`, screens in `lib/screens/`
- **Reference implementations**:
  - `lib/main.dart` - ObjectBox init pattern (lines 19-29)
  - `lib/screens/map_screen.dart` (line 442) - NetworkTileProvider replacement
  - `lib/screens/map_screen_layers.dart` - mapTileUrl function
- **Assumptions**:
  - FMTC stores map entry key must correspond to basemap name used in urlTransformer
  - tasmap URLs use {z}/{y}/{x} format, handled in urlTransformer

## Plan

### Phase 1: FMTC Integration + Map Provider Replacement

- **Goal**: Replace NetworkTileProvider with FMTCTileProvider, verify build
- [x] `pubspec.yaml` - add flutter_map_tile_caching: ^10.1.1 (BLOCKED - no compatible version)
- [ ] `lib/main.dart` - init FMTC ObjectBox before runApp, create 5 stores on startup
- [ ] `lib/services/tile_cache_service.dart` - create FMTCTileProvider with urlTransformer
- [ ] `lib/screens/map_screen.dart` (line 442) - replace NetworkTileProvider with TileCacheService provider
- [ ] Verify: `flutter analyze` && `flutter test`
- [ ] TDD: FMTCTileProvider created with urlTransformer → returns correct URL based on mapState.basemap

**BLOCKER**: All FMTC versions conflict with objectbox ^5.3.1 (flat_buffers: 25.9.23 vs ^23.5.26 required by FMTC)

### Phase 2: Settings UI - Cache Management

- **Goal**: Map Tile Cache section in Settings with metadata display, download, clear
- [ ] `lib/screens/settings_screen.dart` - replace existing ListTile (line 52-63) with expanded Map Tile Cache section
- [ ] TDD: Settings shows cache metadata per store (tile count, size)
- [ ] TDD: Zoom range input validates (min 0, max 18)
- [ ] TDD: Download button disabled during active download
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Bulk Download Implementation

- **Goal**: Bulk download tiles for selected basemap/zoom range with progress
- [ ] `lib/services/tile_cache_service.dart` - add bulkDownload method using FMTC bulk download API
- [ ] TDD: bulk download completes for valid bounds
- [ ] TDD: download progress shows during operation
- [ ] TDD: download can be cancelled, partial cache retained
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 4: Error Handling + Edge Cases

- **Goal**: Handle network errors, storage full, corrupted tiles
- [ ] `lib/services/tile_cache_service.dart` - add error handling per spec E1-E4
- [ ] TDD: Handle network timeout gracefully (E1)
- [ ] TDD: Preserve partial cache on download failure (E2)
- [ ] TDD: Show warning on storage full (E3)
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**:
  1. **BLOCKED: FMTC has dependency conflicts** with objectbox ^5.3.1 (flat_buffers version mismatch)
     - Need to either: upgrade objectbox, or find alternative caching solution
  2. tasmap URL format ({z}/{y}/{x}) may need custom URL transformer - add note in implementation to test
  3. urlTransformer closure captures ref - verify Riverpod scoping is correct at runtime
- **Out of scope**:
  - Export/cache sharing between devices
  - Pinch-to-zoom on mobile (handled by flutter_map)