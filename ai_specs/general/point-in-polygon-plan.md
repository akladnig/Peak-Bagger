## Overview

Reusable polygon containment + pure `.poly` parsing; utility-only.
Small vertical slices: containment first, parser/repository split second.

**Spec**: `ai_specs/general/point-in-polygon-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/services`, `lib/models`, `lib/providers`, `test/services`
- **State management**: Riverpod (`Provider`, `FutureProvider`, `NotifierProvider`)
- **Reference implementations**: `lib/services/polygon_asset_repository.dart`, `test/services/polygon_asset_repository_test.dart`, `test/services/map_grid_geometry_test.dart`
- **Assumptions/Gaps**: utility-only; no caller adoption; generic parser result can use repo-style named constructors, not current `MapPolygonAsset` payload

## Plan

### Phase 1: Containment Slice

- **Goal**: pure `bool` containment API; fail-fast invalid rings
- [x] `lib/services/polygon_geometry.dart` - add public containment helper; normalize optional closing vertex; boundary-inclusive single-ring algorithm; `ArgumentError` on empty or <3 distinct vertices
- [x] `test/services/polygon_geometry_test.dart` - add first pure-service test file in repo style
- [x] TDD: square inside/outside containment -> implement minimal helper
- [x] TDD: on-edge and on-vertex count as inside -> add boundary handling
- [x] TDD: open ring and duplicate closing vertex normalize identically -> add ring normalization
- [x] TDD: concave polygon returns correct inside/outside results -> tighten algorithm
- [x] TDD: empty ring and <3 distinct vertices throw `ArgumentError` -> add fail-fast validation
- [x] Verify: `flutter analyze` && `flutter test test/services/polygon_geometry_test.dart`

### Phase 2: Parser Extraction + Repository Delegation

- **Goal**: pure parser + unchanged asset-loading surface
- [ ] `lib/services/polygon_geometry.dart` - add generic polygon parse result and pure `.poly` parser returning generic polygon data
- [ ] `lib/services/polygon_asset_repository.dart` - delegate parsing to `polygon_geometry.dart`; keep manifest loading, asset reads, logging, `MapPolygonAsset` wrapping
- [ ] `test/services/polygon_geometry_test.dart` - add malformed parser cases and Tasmania inside/outside regression via parsed vertices
- [ ] `test/services/polygon_asset_repository_test.dart` - retain repository-layer coverage; update for delegation/wrapping split if needed
- [ ] TDD: valid Tasmania `.poly` parses into generic vertices -> implement parser happy path
- [ ] TDD: malformed coordinate line, missing `END`, empty ring, extra ring fail with typed result -> implement parser failures
- [ ] TDD: repository wraps parsed polygon data into `MapPolygonAsset` and still filters manifest entries -> refactor repository after parser is green
- [ ] TDD: parsed Tasmania vertices contain `(-42.896016, 147.237306)` and exclude `(-33.865143, 151.209900)` -> prove parser + containment interop
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: boundary math off by epsilon; parser/result rename may ripple through tests; Tasmania regression relies on exact current asset ordering/content
- **Out of scope**: `PeakAdminEditor` adoption; `TasmapRepository` containment APIs; MGRS/map-name flow changes; multi-ring/hole support; antimeridian handling; widget/robot coverage
