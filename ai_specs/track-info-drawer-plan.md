## Overview

Desktop-only left track-info panel in `MapScreen`; derived from visible selected-track state.
Narrow slice: notifier reconciliation, in-body panel, deterministic formatting, keyboard/robot coverage.

**Spec**: `ai_specs/track-info-drawer-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-by-area; map route logic concentrated in `lib/screens/map_screen.dart`, shared map widgets in `lib/screens/map_screen_panels.dart`, state in `lib/providers/map_provider.dart`
- **State management**: Riverpod `Notifier`; `MapNotifier` owns selected-track state, drawers, keyboard-adjacent UI flags
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `test/widget/map_screen_keyboard_test.dart`, `test/widget/map_screen_route_entry_test.dart`, `test/robot/gpx_tracks/selection_journey_test.dart`
- **Assumptions/Gaps**: keep new formatter local to map screen/panel code; use visible `state.tracks` membership over repository fallback for selected-track UI/focus; width seam added in shared map test/robot pumps where needed

## Plan

### Phase 1: State Contract + Escape Ownership

- **Goal**: thin end-to-end slice; valid selected track -> panel can exist, stale selection reconciled, close path owned
- [x] `lib/providers/map_provider.dart` - tighten `selectTrack(...)` contract; add `reconcileSelectedTrackState()`; clear stale selection on unresolved `showTrack(...)`; invoke reconciliation in explicit replacement/reset/toggle paths only
- [x] `lib/screens/map_screen.dart` - trigger safe init reconciliation before selected-track focus work; gate selected-track focus on `showTracks` + membership in `state.tracks`; remove repository fallback for selected-track focus
- [x] `lib/screens/map_screen.dart` - move route-level keyboard dismissal policy to explicit ordered handling: end drawer, peak popup, map info popup, track info panel; re-focus `_mapFocusNode` after track-panel close
- [x] `test/providers/map_provider_selected_track_test.dart` - add focused notifier-contract coverage file
- [x] `test/widget/map_screen_keyboard_test.dart` - add `Escape` precedence coverage for drawer then track panel; preserve existing non-`Escape` behavior
- [x] `test/widget/map_screen_route_entry_test.dart` - cover pre-seeded stale selected-track normalization and unresolved `showTrack(...)` miss path
- [x] TDD: invalid `selectTrack(trackId)` is no-op; valid visible id sticks; stale selected id reconciles to null
- [x] TDD: `showTrack(trackId)` repository miss clears selection and does not queue stale focus/panel state
- [x] TDD: `Escape` closes one highest-priority surface per keypress, with track panel last among overlays in scope
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Panel UI + Local Formatting

- **Goal**: render desktop-only panel with deterministic content and fallback rules
- [x] `lib/screens/map_screen.dart` - derive `selectedTrack` from visible `MapState.tracks`; width-gate on `RouterConstants.shellBreakpoint`; add inner-stack panel overlay; hide MGRS/zoom readouts while panel visible
- [x] `lib/screens/map_screen_panels.dart` - add `MapTrackInfoPanel` widget, section widgets, required keys, pinned header, `SafeArea`, scrollable body, deterministic slide animation, width = `UiConstants.preferredLeftWidth`
- [x] `lib/screens/map_screen_panels.dart` - add small pure/local formatting helpers for date, time, duration, distance, elevation, peaks normalization/dedup/sort
- [x] `lib/widgets/map_basemaps_drawer.dart` - add `Key('basemaps-drawer')`
- [x] `lib/widgets/map_action_rail.dart` - add `Key('show-basemaps-fab')` to basemaps FAB
- [x] `test/widget/map_track_info_formatting_test.dart` - unit coverage for formatter and peaks presentation rules
- [x] `test/widget/map_screen_track_info_test.dart` - widget coverage for visibility gate, close button, content sections, `None` fallbacks, readout hiding, long-content scroll/header access, basemap coexistence
- [x] TDD: desktop width + visible selected track renders `Key('track-info-panel')`; narrow width hides panel without changing selected-track state/highlight behavior
- [x] TDD: close button clears only selected-track state and re-hides panel
- [x] TDD: header/date/time/summary/peaks/elevation/time sections render exact mappings and specified fallback strings
- [x] TDD: peak names trim, blank->`Unknown Peak`, sort case-insensitively, dedupe by raw `osmId`; shared highest-point block shown once only when allowed
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Interaction Journeys + Regression Hooks

- **Goal**: prove click-select, replacement, route-entry, and drawer coexistence through real journeys
- [x] `test/harness/test_map_notifier.dart` - mirror narrowed production selected-track contract only where widget/robot determinism requires it
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add width seam, key-first selectors for track panel open/close assertions
- [x] `test/robot/gpx_tracks/selection_journey_test.dart` - extend journey: hover/select track -> panel visible -> close button clears selection -> background click closes -> toggle tracks hides
- [x] `test/widget/peak_list_peak_dialog_test.dart` - regression for `showTrack(...)` entry opening panel when route surface is wide enough
- [x] `test/widget/tasmap_map_screen_test.dart` - only overlap cases for selected-track focus with panel-visible selected state
- [x] TDD: selecting another visible track updates panel content immediately without extra close/open cycle
- [x] TDD: route-entry/programmatic `showTrack(...)` reveals panel on return to map when selected id resolves
- [x] TDD: basemaps drawer can open with selected track + panel visible; first `Escape` closes drawer, later `Escape` closes track panel
- [x] Robot journey tests + selectors/seams for critical flows
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `MapScreen` keyboard/focus path is dense and regression-prone; timezone-sensitive time assertions need explicit deterministic fixtures; selected-track reconciliation can conflict with route-entry focus if ordered incorrectly
- **Out of scope**: mobile/touch panel behavior; new persistence or ObjectBox schema; per-peak distance rows or broader transient-overlay cleanup refactor
