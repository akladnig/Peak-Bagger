## Overview

Add `Outlier Filter` + `None` options for the two smoother controls. Keep existing Hampel window values; disable dependent windows when parent stage is off.

**Spec**: `ai_specs/009-add-filter-options-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`lib/providers`, `lib/screens`, `lib/services`, `test/widget`, `test/robot`)
- **State management**: Riverpod `AsyncNotifier` + `SharedPreferences`
- **Reference implementations**: `lib/providers/peak_correlation_settings_provider.dart`, `lib/screens/settings_screen.dart`, `test/widget/gpx_filter_settings_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`, `test/services/gpx_track_filter_test.dart`
- **Assumptions/Gaps**: add stable `Key` for `Outlier Filter`; reuse current settings-screen patterns; no unresolved spec gaps

## Plan

### Phase 1: Settings model + filter gating

- **Goal**: explicit enum-based state; skip disabled stages in service
- [x] `lib/providers/gpx_filter_settings_provider.dart` - add `GpxTrackOutlierFilter`; add `None` to smoother enums; add outlier setter; persist/load enum names; keep Hampel window unchanged; preserve disabled selections
- [x] `lib/services/gpx_track_filter.dart` - gate Hampel/elevation/position stages on `None`; keep enabled-stage order unchanged
- [x] `test/services/gpx_track_filter_test.dart` - TDD: skip disabled outlier/smoother stages; keep enabled path unchanged; preserve fallback behavior
- [x] `test/services/gpx_importer_filter_test.dart` - TDD: importer path still produces same raw-fallback behavior when filters disabled/enabled
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Settings UI + journey coverage

- **Goal**: render new dropdowns; disable dependent windows; prove persistence via robot flow
- [x] `lib/screens/settings_screen.dart` - add `Outlier Filter` control; add `None` labels to smoothers; disable dependent window dropdowns; preserve stored values; update summary text; add stable key for `Outlier Filter`
- [x] `test/widget/gpx_filter_settings_test.dart` - TDD: dropdown options, `None` labels, disabled/re-enabled window controls, summary text, persistence
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add `setOutlierFilterNone()`, `setElevationSmootherNone()`, `setPositionSmootherNone()`; add selector for new key
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - TDD: settings journey persists disabled selections across navigation/reload
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / out of scope

- **Risks**: dropdown helper refactor completed; SharedPreferences round-trip preserves old numeric values; robot selectors use stable keys; full `flutter test` still fails on unrelated pre-existing `test/widget/gpx_tracks_selection_test.dart` and `test/robot/gpx_tracks/selection_journey_test.dart`
- **Out of scope**: changing Hampel window choices; altering filter order for enabled stages; localization work
