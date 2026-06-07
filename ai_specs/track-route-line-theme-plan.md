## Overview

Centralize route/track polyline styling in `lib/theme.dart`.
Keep render behavior unchanged; selected-state border/overlay still explicit, just sourced from one theme class.

**Spec**: `user request`

## Context

- **Structure**: layer-first map rendering; `lib/screens`, `lib/core`, `lib/theme.dart`, widget tests under `test/widget`
- **State management**: Riverpod, but this change is pure render config
- **Reference implementations**: `lib/theme.dart`, `lib/screens/map_screen_layers.dart`, `lib/core/constants.dart`, `test/widget/route_polyline_layer_test.dart`, `test/widget/gpx_tracks_selection_test.dart`
- **Assumptions/Gaps**: one shared line-style container for route/track/draft routes; `RouteUI` keeps marker-only constants; model-sourced route/track colors stay in data, theme owns widths, opacity, and selected-state paint

## Plan

### Phase 1: Centralize line styles

- **Goal**: one source of truth for route/track polyline widths + selection styling
- [x] `lib/theme.dart` - add `TrackRouteLineTheme` with shared stroke width; inactive alpha; selected width, border, border color, overlay color, overlay width
- [x] `lib/core/constants.dart` - remove `RouteUI.width`; keep marker sizing/stroke constants only
- [x] `lib/screens/map_screen_layers.dart` - replace hardcoded route/track/draft polyline widths and selection literals in `buildDraftRoutePolylines`, `buildRoutePolylines`, `buildTrackPolylines` with theme constants
- [x] `test/widget/route_polyline_layer_test.dart` - TDD: route builder and draft-route builder both use theme widths; selected route still renders base + border + overlay stack; unselected route dims only when another route is selected
- [x] `test/widget/gpx_tracks_selection_test.dart` - TDD: track polylines use theme widths; selected track still renders base + border + overlay stack; unselected track dims only when another track is selected
- [x] Verify: `flutter analyze && flutter test test/widget/route_polyline_layer_test.dart test/widget/gpx_tracks_selection_test.dart`

## Risks / Out of scope

- **Risks**: missed `RouteUI.width` caller; pixel drift in selected border/overlay appearance; accidental marker-style changes
- **Out of scope**: trail overlay styling, route selection logic, marker sizing/stroke, map interaction behavior
