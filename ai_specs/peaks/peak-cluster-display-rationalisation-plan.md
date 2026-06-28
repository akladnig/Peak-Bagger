## Overview

Unify peak rendering: viewport layer for map surfaces, marker helper for non-map UI. Add two persisted cluster toggles; remove runtime SVG peak path.

**Spec**: `ai_specs/peaks/peak-cluster-display-rationalisation-spec.md` (read this file for full requirements)

## Context

- **Structure**: hybrid; `screens/`, `widgets/`, `providers/`, `services/`, `test/`
- **State management**: Riverpod `NotifierProvider`; async hydrate via `SharedPreferences`
- **Reference implementations**: `lib/providers/peak_marker_info_settings_provider.dart`, `lib/screens/map_screen_peak_layer.dart`, `lib/screens/map_screen_layers.dart`, `lib/screens/peak_lists_screen.dart`, `lib/widgets/dashboard/latest_walk_card.dart`, `lib/screens/settings_screen.dart`
- **Assumptions/Gaps**: keep `map_screen_peak_layer.dart` filename unless reuse friction; keep raw SVG files in repo only if intentionally retained, but remove from `pubspec.yaml`

## Plan

### Phase 1: Map toggle slice

- **Goal**: persisted map-cluster toggle; main map honors it
- [x] `lib/providers/peak_map_cluster_display_settings_provider.dart` - add bool setting; hydrate/persist like `peak_marker_info_settings_provider.dart`
- [x] `lib/screens/settings_screen.dart` - add `Show Map Peak Clusters` tile/switch; stable keys/subtitle
- [x] `lib/screens/map_screen.dart` - read map toggle; feed cluster on/off into viewport-data build / peak layer path
- [x] `lib/screens/map_screen_peak_layer.dart` - accept cluster-disabled rendering path without changing individual peak/label behavior
- [x] `test/providers/peak_map_cluster_display_settings_provider_test.dart` - provider coverage
- [x] `test/widget/settings_screen_peak_cluster_test.dart` - settings wiring for map toggle
- [x] `test/widget/map_screen_peak_cluster_toggle_test.dart` - main-map clustered vs unclustered render
- [x] TDD: map toggle defaults on, persists, survives hydrate failure
- [x] TDD: main map hides clusters but keeps individual peaks/labels when toggle off
- [x] TDD: main map cluster-on path remains current behavior
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Peak-list mini-map parity

- **Goal**: viewport layer reuse; interaction parity with explicit contract
- [x] `lib/providers/peak_list_mini_map_cluster_display_settings_provider.dart` - add bool setting; hydrate/persist
- [x] `lib/screens/settings_screen.dart` - add `Show Peak List Mini-Map Clusters` tile/switch; stable keys/subtitle
- [x] `lib/screens/peak_lists_screen.dart` - replace SVG marker layer with shared viewport layer; preserve selected-location / selected-peak overlays
- [x] `lib/screens/peak_lists_screen.dart` - align hit-testing with viewport data; explicit rules for peak hover/tap and cluster tap expand
- [x] `lib/screens/map_screen_peak_layer.dart` or adjacent helper - expose reusable map-surface API for mini-map use without map-screen-only state coupling
- [x] `test/providers/peak_list_mini_map_cluster_display_settings_provider_test.dart` - provider coverage
- [x] `test/widget/peak_lists_screen_test.dart` - mini-map cluster toggle + popup/selection behavior
- [x] `test/widget/map_screen_peak_cluster_toggle_test.dart` - shared viewport layer regression if API changes
- [x] `test/robot/peaks/peak_lists_journey_test.dart` - cluster/selection robot journey; widget settings coverage accepted for mini-map toggle behavior
- [x] TDD: mini-map toggle defaults on, persists, survives hydrate failure
- [x] TDD: peak tap selects + opens popup; hover does not change selection
- [x] TDD: cluster tap expands camera, clears hover, closes popup, preserves selected peak
- [x] Robot journey tests + selectors/seams for toggle, viewport root, painted peak affordance, cluster affordance, popup shell/anchor
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Non-map helper + SVG removal

- **Goal**: latest-walk + popup UI off SVG path; asset registration removed
- [x] `lib/widgets/peak_marker_glyph.dart` - add shared peak marker helper; ticked/unticked + optional hover/info affordances only as needed
- [x] `lib/widgets/dashboard/latest_walk_card.dart` - replace SVG markers with shared helper; keep individual peaks only; preserve `Show Peak Info`
- [x] `lib/screens/map_screen_panels.dart` - replace inline `SvgPicture.asset` in `Move Peak to Marker`
- [x] `lib/screens/map_screen_layers.dart` - remove or retire `buildPeakMarkers()` and related SVG-only peak content if dead
- [x] `pubspec.yaml` - remove `assets/peak_marker.svg` and `assets/peak_marker_ticked.svg` registrations
- [x] `test/widget/latest_walk_card_test.dart` - helper rendering + `Show Peak Info` on latest-walk peaks
- [x] `test/widget/peak_info_popup_placement_test.dart` or focused popup widget test - `Move Peak to Marker` helper regression
- [x] `test/widget/peak_runtime_asset_removal_test.dart` - static/runtime guard for no migrated SVG peak usage, if practical; else assert via focused grep-backed test seam/doc check in execution notes
- [x] TDD: latest-walk never clusters, always individual peaks, still honors `Show Peak Info`
- [x] TDD: popup action uses shared peak marker helper, not SVG asset
- [x] TDD: migrated runtime code no longer references registered peak SVG assets
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 4: Journey hardening

- **Goal**: regression net; selectors stable; dead-path cleanup
- [x] `test/robot/peaks/peak_cluster_journey_test.dart` - extend for map toggle journey if better fit than new robot file
- [x] `test/robot/peaks/peak_info_journey_test.dart` or `test/robot/peaks/peak_lists_journey_test.dart` - cover popup/selection after cluster expansion
- [x] `lib/screens/map_screen.dart` / `lib/screens/peak_lists_screen.dart` / `lib/widgets/dashboard/latest_walk_card.dart` - finalize stable keys for viewport root, cluster affordances, painted peak affordances, latest-walk marker helper instances
- [x] `lib/screens/map_screen_layers.dart` - delete dead SVG peak renderer code if fully unused
- [x] TDD: selectors remain deterministic after painted-marker migration
- [x] Robot journey tests + selectors/seams for settings toggles, peak interaction, cluster expansion, popup close/reopen flow
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: viewport-layer reuse may need API split between map surfaces and non-map helper; painted affordances can break existing widget/robot selectors; removing asset registrations may expose stray legacy references
- **Out of scope**: clustering algorithm redesign; peak correlation/data model changes; unrelated map UI cleanup
