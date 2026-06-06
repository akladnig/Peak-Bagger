## Overview
Trim zoom jank when `Show Polygons` is on.
Keep polygon rendering off the camera-hot rebuild path; prove it with a zoom regression test.

**Spec**: `task description` (quick plan; no spec file)

## Context
- **Structure**: feature-first map screen + providers/services
- **State management**: Riverpod `Notifier` + `FutureProvider`
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, `lib/providers/polygon_assets_provider.dart`, `test/widget/map_screen_rebuild_test.dart`, `test/widget/map_screen_layers_test.dart`
- **Assumptions/Gaps**: hotspot is the `MapScreen` viewport rebuild path; if the counter points elsewhere, keep the same regression and move the cache boundary there

## Plan

### Phase 1: Pin the regression
- **Goal**: failing zoom test; identify polygon-layer rebuild churn
- [x] `lib/widgets/map_rebuild_debug_counters.dart` - add polygon-layer build counter seam
- [x] `test/widget/map_screen_rebuild_test.dart` - `TDD:` zoom/pan with `Show Polygons` on should not bump polygon-layer build count after initial load
- [x] `test/widget/map_screen_layers_test.dart` - keep layer config stable; guard key/colors/points
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Hoist polygon work
- **Goal**: isolate polygon layer from camera ticks
- [x] `lib/screens/map_screen.dart` - move polygon asset layer out of the viewport rebuild closure; rebuild only on toggle/load changes
- [x] `lib/screens/map_screen_layers.dart` - keep `buildPolygonAssetLayer(...)` pure; no per-frame list churn
- [x] `lib/providers/polygon_assets_provider.dart` - no provider change needed; cache at map screen boundary
- [x] `test/widget/map_screen_rebuild_test.dart` - `TDD:` toggle still shows/hides polygons; zoom keeps build count flat
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: jank source may be map-layer transform, not list build; overlay may still be expensive if it shares the hot path
- **Out of scope**: polygon asset parsing/manifest changes, visual styling tweaks, new toggle behavior
