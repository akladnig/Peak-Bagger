## Overview

Add a persisted `Show Peak Info` toggle and shared peak-label renderer.
Thin slice first: settings -> main map -> shared tests; then fan out to mini-maps.

**Spec**: `ai_specs/peak-marker-info-spec.md` (read this file for full requirements)

## Context

- **Structure**: feature-first screens/widgets + shared providers/services
- **State management**: Riverpod `Notifier` / provider pattern
- **Reference implementations**: `lib/providers/theme_provider.dart`, `lib/providers/gpx_filter_settings_provider.dart`, `lib/screens/map_screen_layers.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/peaks/peak_info_journey_test.dart`
- **Assumptions/Gaps**: mini-maps stay icon-only under zoom 12; late hydration must not overwrite user toggles

## Plan

### Phase 1: Toggle + main map slice

- **Goal**: prove setting persistence + visible effect on main map
- [ ] `lib/core/constants.dart` - add `peakInfoMinZoom` and `peakInfoLabelMaxCharacters`
- [ ] `lib/providers/peak_marker_info_settings_provider.dart` - `Notifier<bool>`; default off; background hydrate; user value wins over late load
- [ ] `lib/screens/settings_screen.dart` - add `Show Peak Info` switch; wire to provider; stable key
- [ ] `lib/theme.dart` - add outlined-text painter/helper for filled surface text + onSurface outline
- [ ] `lib/screens/map_screen_layers.dart` - shared label composition for peak markers; preserve hitbox size; ellipsis after 2 lines; cap at 20 chars
- [ ] `lib/screens/map_screen.dart` - pass setting to main-map peak markers
- [ ] `test/providers/peak_marker_info_settings_provider_test.dart` - TDD: default off -> toggle on/off -> persist -> late hydrate does not clobber user state
- [ ] `test/widget/settings_screen_peak_info_test.dart` - TDD: switch visible; toggles provider; stable key
- [ ] `test/widget/map_screen_peak_info_test.dart` - TDD: main map labels hidden by default; visible at/above zoom threshold; hitbox/hover unchanged
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Shared renderer fan-out

- **Goal**: apply the same behavior to all peak-marker surfaces
- [ ] `lib/screens/peak_lists_screen.dart` - route mini-map markers through shared renderer; keep icon-only below zoom 12
- [ ] `lib/widgets/dashboard/latest_walk_card.dart` - route mini-map markers through shared renderer; keep icon-only below zoom 12
- [ ] `lib/screens/dashboard_screen.dart` - update wiring if the shared setting needs to flow through the dashboard card tree
- [ ] `test/widget/peak_lists_screen_test.dart` - TDD: mini-map remains icon-only under threshold; shared renderer still works
- [ ] `test/widget/latest_walk_card_test.dart` - TDD: latest-walk mini-map remains icon-only under threshold
- [ ] `test/widget/map_screen_peak_info_test.dart` - add coverage for long-name wrap/ellipsis behavior
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey

- **Goal**: end-to-end user flow from Settings to map result
- [ ] `test/robot/settings/peak_marker_info_robot.dart` - key-first robot helpers for settings switch + peak markers
- [ ] `test/robot/settings/peak_marker_info_journey_test.dart` - TDD: open settings, toggle on/off, return to map, assert labels on main map; assert mini-maps remain icon-only under threshold
- [ ] Stable selectors: `show-peak-info-switch`, `peak-marker-layer`, `peak-marker-hitbox-<osmId>`, `peak-marker-hover-<osmId>`
- [ ] Deterministic seams: in-memory prefs/store fakes; no network/tile dependency for assertions
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: outlined-text painter may need careful layout tuning; late hydration race with user toggles; label overflow must stay deterministic
- **Out of scope**: popup content changes; mini-map zoom support; database/API changes
