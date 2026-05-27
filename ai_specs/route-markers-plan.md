## Overview

Route draft markers refactor. New render-facing marker model + single widget; then wire map draft flow to it.

**Spec**: `ai_specs/route-markers.md` (read this file for full requirements)

## Context

- **Structure**: layer-first, split across `lib/providers`, `lib/screens`, `lib/widgets`, `test/widget`
- **State management**: Riverpod
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen_layers.dart`, `test/widget/map_screen_route_sheet_test.dart`
- **Assumptions/Gaps**: render-facing route marker model added; route draft markers full opacity; 99-point cap applies to numbered route points only

## Plan

### Phase 1: Marker model + widget

- **Goal**: standalone `RouteMarker` rendering
- [x] `lib/core/constants.dart` - add `RouteUI.markerSize`, `RouteUI.markerMinSize`, `RouteUI.markerFontSize`, `RouteUI.strokeWidth`, `RouteUI.strokeDarkenAlpha`
- [x] `lib/models/route_marker_display.dart` - add render-facing marker model for `point`, `kind`, `number`, `isCommitted`
- [x] `lib/widgets/route_marker.dart` - add `RouteMarker` + `RouteMarkerKind`
- [x] TDD: circle renders white fill + colored stroke; target renders ring + center dot; numbered clamps to `1..99`
- [x] TDD: 20 px minimum size holds number/ring without clipping; 8 px font stays centered
- [x] TDD: numbered stroke uses fixed darken/alpha constant from `RouteUI`
- [ ] Verify: `flutter analyze && flutter test test/widget/route_marker_test.dart` (blocked by existing robot failure in `test/robot/map/map_route_journey_test.dart`)

### Phase 2: Draft wiring + journey coverage

- **Goal**: provider emits render-ready markers; map layer renders `RouteMarker`
- [x] `lib/providers/map_provider.dart` - derive render-ready draft markers from ordered state; start/circle, middle/numbered, end/target; peak skip; out-and-back overlap; 99-point reject + inline error
- [x] `lib/screens/map_screen_layers.dart` - swap draft marker child from `Container` to `RouteMarker`; remove committed/provisional alpha split; keep existing keys
- [x] `test/widget/map_screen_route_sheet_test.dart` - add journey coverage for draft marker progression, peak skip, out-and-back overlap, and 99-point rejection/error text
- [x] `test/widget/route_marker_layer_test.dart` - prove map layer now emits `RouteMarker` output, not the old container path
- [x] TDD: one-point, two-point, three-point progression; peak-target insertion; out-and-back z-order; 99th point rejection path
- [x] Robot journey: stable-key route-sheet flow using `route-draft-marker-layer` and `route-draft-marker-*`
- [ ] Verify: `flutter analyze && flutter test` (blocked by existing robot failure in `test/robot/map/map_route_journey_test.dart`)

## Risks / Out of scope

- **Risks**: label fit at the minimum size; z-order when target overlaps start; route-to-peak numbering edge cases
- **Out of scope**: route planning changes, route persistence changes, marker hit testing changes, peak marker visuals
