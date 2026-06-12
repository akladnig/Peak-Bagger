## Overview

Prevent low-zoom ruler text from collapsing to an illegible small-scale label.
Approach: extend ruler-step selection through `50,000,000` m using the existing `1/2/3/5` progression; keep grid interval capped at `100 km`.

**Spec**: ad hoc bug fix request

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `widgets/`
- **State management**: Riverpod app-wide; ruler selection is pure service logic
- **Reference implementations**: `lib/services/map_ruler_scale.dart`, `lib/screens/map_screen_panels.dart`, `lib/screens/map_screen_layers.dart`, `test/services/map_ruler_scale_test.dart`, `test/widget/map_screen_ruler_test.dart`
- **Assumptions/Gaps**: request targets map ruler distance text; add large-step ladder `1,000,000`..`50,000,000` m; no new MGRS interval beyond existing `1 km` / `10 km` / `100 km`

## Plan

### Phase 1: Low-Zoom Ruler Fix

- **Goal**: readable ruler at far zoom-out; minimal scope
- [x] `lib/services/map_ruler_scale.dart` - extend supported ruler steps with `200000`, `300000`, `500000`, `1000000`, `2000000`, `3000000`, `5000000`, `10000000`, `20000000`, `30000000`, `50000000`; preserve largest-in-band selection; leave `mapMgrsGridIntervalForRulerMeters` capped at `hundredKilometers`
- [x] `test/services/map_ruler_scale_test.dart` - TDD: large-step ladder is selectable at low zooms; far zoom-out prefers larger steps instead of clamping to undersized `100000` m; keep `3 km` / `30 km` grid-threshold coverage intact
- [x] `test/widget/map_screen_ruler_test.dart` - TDD: `MapZoomReadout` shows a large-scale label from the new ladder for low-zoom cases that previously rendered too-small labels
- [x] Verify: `flutter analyze` && `flutter test test/services/map_ruler_scale_test.dart test/widget/map_screen_ruler_test.dart`

## Risks / Out of scope

- **Risks**: chosen low-zoom test fixtures may vary with latitude; keep assertions tied to explicit selection output and step ordering
- **Out of scope**: new grid-label formats; new MGRS intervals; unrelated distance-formatting surfaces
