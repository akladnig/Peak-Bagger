## Overview
Add Tasmap polygon labels on the map screen.
Make Grid cycle a single active Tasmap mode; keep label rendering derived from existing Tasmap data.

**Spec**: `./ai_specs/004-map-name-spec.md` (read this file for full requirements)

## Context

- **Structure**: screen-first Flutter app; map shell owns Tasmap rendering
- **State management**: Riverpod `mapProvider` + `tasmapStateProvider`
- **Reference implementations**: `./lib/screens/map_screen.dart`, `./lib/providers/map_provider.dart`, `./lib/widgets/map_action_rail.dart`, `./lib/widgets/tasmap_outline_layer.dart`, `./test/widget/tasmap_refactor_test.dart`, `./test/robot/tasmap/tasmap_journey_test.dart`
- **Assumptions/Gaps**: add explicit Tasmap display-mode state; assume map selection surfaces `selectedMap` mode; add stable Grid/label keys for tests

## Plan

### Phase 1: Tasmap mode model

- **Goal**: single Tasmap visibility source; label seam
- [ ] `./lib/providers/map_provider.dart` - add Tasmap display mode state; cycle `showMapOverlay -> none -> selectedMap -> showMapOverlay`; keep selected map data separate
- [ ] `./lib/widgets/map_action_rail.dart` - add stable key for Grid FAB; call mode cycle, not boolean toggle
- [ ] `./lib/widgets/tasmap_polygon_label.dart` - dedicated label/helper for `name\nseries`, anchor from polygon points/bounds, translucent backing or text shadow, font size 12
- [ ] TDD: cycle behavior; label formatting; blank-line handling; label hidden below zoom 10
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Map render + journeys

- **Goal**: one visible Tasmap layer; labels in map UI
- [ ] `./lib/screens/map_screen.dart` - render only active Tasmap layer; attach label helper to selected/overlay paths; suppress labels below zoom 10; preserve zoom/search/Goto behavior
- [ ] `./test/widget/tasmap_refactor_test.dart` - one-layer cycle, selected-map label, overlay label, zoom-threshold hide, label styling
- [ ] `./test/robot/tasmap/tasmap_journey_test.dart` - stable Grid selector + label assertion in the existing map-select journey
- [ ] TDD: widget checks for layer visibility before robot assertion; verify label moves with polygon and inherits outline color
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: label overlap on tiny polygons; ambiguous behavior if a map is selected while the current mode is none/overlay; robot flake if Grid/label keys are missing
- **Out of scope**: Tasmap import/schema/admin changes; collision-avoidance; label dedupe across non-Tasmap layers
