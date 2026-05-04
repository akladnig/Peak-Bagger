## Overview

Centralize shared constants into `lib/core/constants.dart`; keep pref keys local, preserve behavior, then update callsites/tests.

**Spec**: `ai_specs/constants-refactor-spec.md`

## Context

- **Structure**: layer-first (`providers/`, `services/`, `screens/`, `widgets/`, `models/`)
- **State management**: Riverpod + SharedPreferences
- **Reference implementations**: `lib/providers/gpx_filter_settings_provider.dart`, `lib/models/gpx_track.dart`, `lib/services/track_display_cache_builder.dart`
- **Assumptions/Gaps**: pref keys out of scope; `gpx_filter_settings_provider.dart` defaults must align with `GpxConstants`; `UiConstants` spans 5 files / 17 declarations

## Plan

### Phase 1: Core config

- **Goal**: move shared non-UI config; keep behavior stable
- [x] `lib/core/constants.dart` - add `MapConstants`, `GeoConstants`, `GpxConstants`, `PeakCorrelationConstants`, `RouterConstants`, `UiConstants`
- [x] `lib/providers/map_provider.dart` - use `MapConstants.defaultCenter/defaultZoom/searchRadiusMeters`
- [x] `lib/services/gpx_importer.dart` - use `GeoConstants`
- [x] `lib/services/gpx_track_filter.dart` - use `GpxConstants`
- [x] `lib/providers/gpx_filter_settings_provider.dart` - update defaults to `GpxConstants` values; keep keys local; sync save/load parsing
- [x] `lib/providers/peak_correlation_settings_provider.dart` - use `PeakCorrelationConstants.defaultDistanceMeters/distanceOptions`; keep key local
- [x] `lib/router.dart` - use `RouterConstants`
- [x] `lib/models/gpx_track.dart` - use `MapConstants.peakMinZoom/peakMaxZoom/defaultZoom`; clamp + `getSegments()` default
- [x] `lib/services/track_display_cache_builder.dart` - use `MapConstants.peakMinZoom/peakMaxZoom`
- [x] `test/services/gpx_filter_settings_provider_test.dart` - expect 5/none defaults; persistence round-trip
- [x] `test/gpx_track_test.dart` - cover `getSegments()`/`getSegmentsForZoom()` with `MapConstants.defaultZoom` + clamp bounds
- [x] `test/widget/peak_correlation_settings_test.dart` - keep provider defaults/options green after extraction
- [x] TDD: `GpxFilterConfig.defaults` round-trip -> 5/none defaults, persisted values restored
- [x] TDD: `GpxTrack.getSegments()` / `getSegmentsForZoom()` use `MapConstants.defaultZoom` + clamp bounds
- [x] TDD: `TrackDisplayCacheBuilder.buildJson()` still emits 6..18 caches, simplification unchanged
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: UI layout constants

- **Goal**: move single-file UI dimensions into `UiConstants`
- [x] `lib/screens/map_screen.dart` - use `UiConstants.scrollSpeed/scrollInterval/peakInfoPopupSize`; use `MapConstants.peakMinZoom/peakMaxZoom` for display zoom clamp
- [x] `lib/screens/map_screen_layers.dart` - use `MapConstants.peakMinZoom/peakMaxZoom` for display zoom clamp
- [x] `lib/widgets/peak_list_peak_dialog.dart` - use `UiConstants.dialogMargin`
- [x] `lib/screens/peak_lists_screen.dart` - use `UiConstants.dividerWidth/preferredLeftWidth/preferredRightWidth/minimumMiniMapAspectWidth/columnCellHorizontalPadding/headerLabelGap/rowHorizontalPadding/columnGap/headerIconWidth`
- [x] `lib/widgets/map_action_rail.dart` - use `UiConstants.railSpacing`
- [x] `lib/screens/objectbox_admin_screen_table.dart` - use `UiConstants.primaryColumnWidth/actionsColumnWidth`
- [x] `test/widget/peak_list_peak_dialog_test.dart`, `test/widget/peak_lists_screen_test.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/widget/tasmap_map_screen_test.dart`, `test/widget/objectbox_admin_shell_test.dart` - update only if compile/assertion deltas appear
- [x] TDD: preserve existing widget layout assertions after constant moves; fix only compile/assertion deltas
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `gpx_filter_settings_provider.dart` default shift 7 -> 5; `peak_lists_screen.dart` duplicated `headerLabelGap`; wide widget-test ripple from UI constant moves
- **Out of scope**: shared pref keys, `lib/services/objectbox_schema_guard.dart`, `lib/services/migration_marker_store.dart`, `lib/models/peak.dart`, widget `Key()` declarations
