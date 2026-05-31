## Overview

Persist zoom+chunk trail display cache at import time. Render overlay from cached rows, not raw chunk decode.

**Spec**: `ai_specs/trail-display-cache-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `models/`, `services/`, `providers/`, `screens/`, `widgets/`
- **State management**: Riverpod
- **Reference implementations**: `lib/services/route_graph_repository.dart`, `lib/services/route_graph_import_service.dart`, `lib/services/track_display_cache_builder.dart`
- **Assumptions/Gaps**: `showTrails` prefetch unchanged; shared simplifier only if small win; follow existing route-graph storage seams over new feature module

## Plan

### Phase 1: Runtime Cache Slice

- **Goal**: prove visible-trails path can read cache rows end-to-end
- [x] `lib/models/route_graph_trail_display_chunk.dart` - add ObjectBox entity; `generation`, `cacheZoom`, `chunkKey`, `recordKey`, payload
- [x] `lib/services/route_graph_repository.dart` - extend `RouteGraphPreparedGeneration`, `RouteGraphStorage`, repository reads/writes for trail cache rows; add in-memory support first
- [x] `lib/providers/route_graph_trail_provider.dart` - keep provider seam; pass updated query/service deps unchanged where possible
- [x] `lib/services/route_graph_query_service.dart` - add cache-row query API by visible bounds + rounded/clamped zoom + active generation; keep route-planning queries intact
- [x] `lib/services/route_graph_trail_service.dart` - replace raw chunk decode path with cached-row decode, `osmWayId` dedupe, existing dual-stroke styling
- [x] `lib/screens/map_screen.dart` - pass effective zoom into trail service; preserve current readiness/toggle behavior
- [x] `test/services/route_graph_repository_test.dart` - seed cache rows in memory; assert active-generation read shape
- [x] `test/services/route_graph_query_service_test.dart` - cover bounds+zoom cache row selection, empty viewport, generation isolation
- [x] `test/services/route_graph_trail_service_test.dart` - switch fixtures to cache rows; assert no raw chunk dependency in normal path
- [x] `test/widget/map_screen_layers_test.dart` - keep deterministic layer assertions from cached polyline output
- [x] TDD: cached row query returns only active-generation rows for visible chunks and rounded/clamped zoom; then implement minimal repository/query seam
- [x] TDD: trail service builds identical styled polylines from cached rows and dedupes duplicate `osmWayId`; then implement minimal runtime decode
- [x] TDD: map screen passes zoom into trail path and still hides overlay when not ready; then wire UI seam
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Import Build + Schema Enforcement

- **Goal**: generate cache rows during import; force rebuild on schema mismatch
- [x] `lib/services/track_display_cache_builder.dart` - extract pure simplifier/encoder only if reuse stays small; else copy minimal logic into route-graph import
- [x] `lib/services/route_graph_import_service.dart` - bump schema version; reject mismatched active manifest in `bootstrapIfNeeded()`; build trail cache rows during generation prep
- [x] `lib/services/route_graph_import_service.dart` - extend prepared-generation map parsing for trail cache rows; fail import on cache-build errors
- [x] `lib/services/route_graph_query_service.dart` - keep trail source filter canonical; reuse filter for import-time selection if practical
- [x] `test/services/route_graph_import_service_test.dart` - cover filter inclusion/exclusion, per-zoom row creation, schema mismatch rebuild, refresh failure retention
- [x] TDD: importer prepares trail cache rows only for allowed trail ways across supported zooms; then implement builder path
- [x] TDD: bootstrap reuses only matching schema version, otherwise rebuilds; then implement schema guard
- [x] TDD: import failure in trail cache generation aborts activation and preserves prior active generation; then implement failure path
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: ObjectBox Persistence + Journey Hardening

- **Goal**: production persistence, pruning, user-journey confidence
- [x] `lib/services/route_graph_repository.dart` - add ObjectBox box/query/prune support for trail cache rows; align with in-memory behavior
- [x] `lib/objectbox.g.dart` - regenerate ObjectBox bindings after entity addition
- [x] `test/services/route_graph_repository_test.dart` - assert stale-generation prune removes trail cache rows with chunks/way rows
- [x] `test/services/route_graph_query_service_test.dart` - add malformed cache row, missing zoom row, overlap edge cases
- [x] `test/robot/map/map_route_journey_test.dart` - seed cache-row-backed trail store; keep selectors `show-trails-fab`, `show-trails-switch`, `trail-polyline-layer`
- [x] `test/robot/map/map_route_robot.dart` - update fake route-graph store fixtures/seams for trail cache rows; deterministic generation state
- [x] TDD: ObjectBox active-generation reads and stale-generation pruning include trail cache rows; then implement production storage
- [x] TDD: malformed cache payload fails closed for trails only; then implement decode guard
- [x] TDD: robot journey toggles, pans, zooms, refreshes with cached overlay path only; then update fixtures/seams
- [x] Robot journey tests + selectors/seams for critical flows: trail toggle, pan, zoom, refresh; fake store seeds cache rows directly; avoid async flake via deterministic readiness/store state
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: paint cost may still dominate at high zoom; ObjectBox query shape may need index tuning; importer memory cost may spike on large overlapping trail sets
- **Out of scope**: changing `showTrails` warmup prefetch; alternate trail data sources; backward compatibility for pre-cache generations
