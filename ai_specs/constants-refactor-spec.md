<goal>
Centralize shared constants scattered across the peak_bagger codebase into a single file `lib/core/constants.dart` using domain-organized static classes. This makes configuration discoverable, removes magic numbers, and simplifies future updates.
</goal>

<background>
Flutter/Dart project using flutter_riverpod, flutter_map, and ObjectBox. Constants are currently scattered across several files as `const` variables, `static const` class members, and magic numbers. No `lib/core` directory exists yet.

Files with significant constants to review:
- @lib/providers/map_provider.dart (default center/zoom, search radius)
- @lib/screens/map_screen.dart (scroll speed, popup size)
- @lib/widgets/peak_list_peak_dialog.dart (dialog margin)
- @lib/screens/peak_lists_screen.dart (layout dimensions)
- @lib/services/gpx_importer.dart (Tasmania geo bounds)
- @lib/services/gpx_track_filter.dart (filter thresholds)
- @lib/services/track_display_cache_builder.dart (zoom bounds, tile size)
- @lib/providers/peak_correlation_settings_provider.dart (default distance, options)
- @lib/router.dart (breakpoints, insets)
- @lib/widgets/map_action_rail.dart (rail spacing)
- @lib/screens/objectbox_admin_screen_table.dart (table widths)
- @lib/services/objectbox_schema_guard.dart (schema signature key - leave in-place)
- @lib/services/migration_marker_store.dart (migration keys - leave in-place)
- @lib/models/peak.dart (source constants - leave in-place)
- @lib/models/gpx_track.dart (zoom constants - update to reference MapConstants)

Note: `defaultHampelWindow = 5` is intentionally changed from the current codebase default of 7, per user instruction.
</background>

<requirements>
**Functional:**

1. Create `lib/core/constants.dart` with domain-organized static classes.

2. Extract shared configuration constants into the following domains:

   **MapConstants** - map defaults and configuration:
   - `defaultCenter = LatLng(-41.5, 146.5)`
   - `defaultZoom = 15.0`
   - `searchRadiusMeters = 100.0`
   - `peakMinZoom = 6`
   - `peakMaxZoom = 18`

   **GeoConstants** - geographic bounds for Tasmania:
   - `tasmaniaLatMin = -44.0`, `tasmaniaLatMax = -39.0`
   - `tasmaniaLngMin = 143.0`, `tasmaniaLngMax = 149.0`

   **GpxConstants** - GPX processing thresholds:
   - `maxSpeedMetersPerSecond = 12.0`
   - `maxJumpMeters = 2500.0`
   - `defaultHampelWindow = 5`
   - `defaultElevationWindow = 5`
   - `defaultPositionWindow = 5`
   - `defaultOutlierFilter = 'none'`
   - `defaultElevationSmoother = 'none'`
   - `defaultPositionSmoother = 'none'`
   - This is an intentional behavior change from the current provider defaults; update dependent logic and tests to match.

   **PeakCorrelationConstants** - correlation settings:
   - `defaultDistanceMeters = 50`
   - `distanceOptions = <int>[10, 20, 30, 40, 50, 60, 70, 80, 90, 100]`
   - Keep `peakCorrelationDistanceKey` local in `peak_correlation_settings_provider.dart`.

   **RouterConstants** - layout breakpoints:
   - `shellBreakpoint = 720.0`
   - `wideNavigationWidth = 132.0`
   - `themeActionRightInset = 16.0`

   **UiConstants** - UI layout constants consolidated from single-file declarations:
   - `scrollSpeed = 0.001`
   - `scrollInterval = Duration(milliseconds: 16)`
   - `peakInfoPopupSize = Size(320, 120)`
   - `dialogMargin = 24.0`
   - `dividerWidth = 1.0`
   - `preferredLeftWidth = 320.0`
   - `preferredRightWidth = 360.0`
   - `minimumMiniMapAspectWidth = 294.0`
   - `columnCellHorizontalPadding = 12.0`
   - `headerLabelGap = 12.0` (used in two places in `peak_lists_screen.dart`)
   - `rowHorizontalPadding = 40.0`
   - `columnGap = 12.0`
   - `headerIconWidth = 18.0`
   - `railSpacing = 8.0`
   - `primaryColumnWidth = 144.0`
   - `actionsColumnWidth = 72.0`
   - `scrollSpeed`, `scrollInterval`, and `peakInfoPopupSize` come from `map_screen.dart`.
   - `dialogMargin` comes from `peak_list_peak_dialog.dart`.
   - `dividerWidth`, `preferredLeftWidth`, `preferredRightWidth`, `minimumMiniMapAspectWidth`, `columnCellHorizontalPadding`, `headerLabelGap`, `rowHorizontalPadding`, `columnGap`, and `headerIconWidth` come from `peak_lists_screen.dart`.
   - `railSpacing` comes from `map_action_rail.dart`.
   - `primaryColumnWidth` and `actionsColumnWidth` come from `objectbox_admin_screen_table.dart`.
   - These are 17 declarations across 5 files; `headerLabelGap` appears twice in `peak_lists_screen.dart` and should still be centralized as a single `UiConstants.headerLabelGap`.

   **ObjectBoxConstants** - leave in current files (do NOT move to constants.dart):
   - `lib/services/objectbox_schema_guard.dart`: schema signature key stays in-place
   - `lib/services/migration_marker_store.dart`: migration keys stay in-place

3. Replace all extracted constant references in source files with the new static class references.

4. Add `import '../core/constants.dart';` to each modified file (adjust relative path as needed).

5. Update `lib/providers/map_provider.dart`:
   - Replace `_defaultCenter` with `MapConstants.defaultCenter`
   - Replace `_defaultZoom` with `MapConstants.defaultZoom`
   - Replace any shared `searchRadiusMeters` usage with `MapConstants.searchRadiusMeters`

6. Update `lib/models/gpx_track.dart`:
   - Replace `minDisplayZoom = 6` with `minDisplayZoom = MapConstants.peakMinZoom`
   - Replace `maxDisplayZoom = 18` with `maxDisplayZoom = MapConstants.peakMaxZoom`
   - Replace `zoom.clamp(6, 18)` in `getSegmentsForZoom` with `zoom.clamp(MapConstants.peakMinZoom, MapConstants.peakMaxZoom)`
   - Add `import '../core/constants.dart';`

7. Update `lib/services/track_display_cache_builder.dart`:
   - Replace `minZoom = 6` with `minZoom = MapConstants.peakMinZoom`
   - Replace `maxZoom = 18` with `maxZoom = MapConstants.peakMaxZoom`
   - Leave `_epsilon` and `_tileSize` as local constants
   - Add `import '../../core/constants.dart';`

8. Update `lib/providers/peak_correlation_settings_provider.dart`:
   - Keep `peakCorrelationDistanceKey` local in the file
   - Replace `peakCorrelationDefaultDistanceMeters` with `PeakCorrelationConstants.defaultDistanceMeters`
   - Replace `peakCorrelationDistanceOptions` with `PeakCorrelationConstants.distanceOptions`
   - Add `import '../core/constants.dart';`

 9. Do NOT modify:
    - Test files
    - `lib/models/peak.dart` (domain constants stay)
    - `lib/services/objectbox_schema_guard.dart` (ObjectBox constants stay in-place)
    - `lib/services/migration_marker_store.dart` (ObjectBox constants stay in-place)
    - Widget `Key()` declarations

10. Avoid:
   - Do not use `package:` imports for the constant file
   - Do not create a barrel file or re-export pattern

**Error Handling:**

11. If a constant is referenced before the new import is added, the analyzer will catch it; fix all analyzer errors before completing.

**Validation:**

12. All numeric constants must use appropriate types (double for distances, int for zoom levels).
13. Static classes must use the `abstract final` pattern, which is supported by the project SDK constraint `^3.11.4`.
</requirements>

<boundaries>
Edge cases:
- Constant used in 1 file but conceptually shared config (e.g. `searchRadiusMeters`) -> extract anyway.
- Constant used in 1 file as implementation detail (e.g. `_scrollSpeed`) -> leave in-place.
- Same magic number appearing in multiple files for different purposes -> extract only if the semantic meaning is the same.
- `const _distance = Distance()` instances -> leave in-place.

Error scenarios:
- Renaming a constant that's also used in tests -> update the tests or keep the key local.
- Circular import risk -> `constants.dart` must not import app-specific files.

Limits:
- No constant values should be changed, except `defaultHampelWindow` per user instruction.
- Do not introduce new constants not already present in the codebase.
</boundaries>

<implementation>
1. Create directory `lib/core/` if it doesn't exist.
2. Create `lib/core/constants.dart` with this structure:

```dart
import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

abstract final class MapConstants {
  static const defaultCenter = LatLng(-41.5, 146.5);
  static const defaultZoom = 15.0;
  static const searchRadiusMeters = 100.0;
  static const peakMinZoom = 6;
  static const peakMaxZoom = 18;
}

abstract final class GeoConstants {
  static const tasmaniaLatMin = -44.0;
  static const tasmaniaLatMax = -39.0;
  static const tasmaniaLngMin = 143.0;
  static const tasmaniaLngMax = 149.0;
}

abstract final class GpxConstants {
  static const maxSpeedMetersPerSecond = 12.0;
  static const maxJumpMeters = 2500.0;
  static const defaultHampelWindow = 5;
  static const defaultElevationWindow = 5;
  static const defaultPositionWindow = 5;
  static const defaultOutlierFilter = 'none';
  static const defaultElevationSmoother = 'none';
  static const defaultPositionSmoother = 'none';
}

abstract final class PeakCorrelationConstants {
  static const defaultDistanceMeters = 50;
  static const distanceOptions = <int>[10, 20, 30, 40, 50, 60, 70, 80, 90, 100];
}

abstract final class RouterConstants {
  static const shellBreakpoint = 720.0;
  static const wideNavigationWidth = 132.0;
  static const themeActionRightInset = 16.0;
}

abstract final class UiConstants {
  static const scrollSpeed = 0.001;
  static const scrollInterval = Duration(milliseconds: 16);
  static const peakInfoPopupSize = Size(320, 120);
  static const dialogMargin = 24.0;
  static const dividerWidth = 1.0;
  static const preferredLeftWidth = 320.0;
  static const preferredRightWidth = 360.0;
  static const minimumMiniMapAspectWidth = 294.0;
  static const columnCellHorizontalPadding = 12.0;
  static const headerLabelGap = 12.0;
  static const rowHorizontalPadding = 40.0;
  static const columnGap = 12.0;
  static const headerIconWidth = 18.0;
  static const railSpacing = 8.0;
  static const primaryColumnWidth = 144.0;
  static const actionsColumnWidth = 72.0;
}
```

3. For each source file with extracted constants (`map_provider.dart`, `gpx_importer.dart`, `gpx_track_filter.dart`, `router.dart`, `peak_correlation_settings_provider.dart`, `track_display_cache_builder.dart`, `gpx_track.dart`, `map_screen.dart`, `peak_list_peak_dialog.dart`, `peak_lists_screen.dart`, `map_action_rail.dart`, `objectbox_admin_screen_table.dart`):
    - Add `import '../core/constants.dart';` or the correct relative path
    - Replace local constant references with the new static class references
    - Remove the old `const` declaration

4. Update `lib/providers/map_provider.dart`:
    - Replace `_defaultCenter` with `MapConstants.defaultCenter`
    - Replace `_defaultZoom` with `MapConstants.defaultZoom`
    - Replace any shared `searchRadiusMeters` usage with `MapConstants.searchRadiusMeters`

5. Update `lib/models/gpx_track.dart`:
    - Replace `minDisplayZoom = 6` with `minDisplayZoom = MapConstants.peakMinZoom`
    - Replace `maxDisplayZoom = 18` with `maxDisplayZoom = MapConstants.peakMaxZoom`
    - Replace `zoom.clamp(6, 18)` in `getSegmentsForZoom` with `zoom.clamp(MapConstants.peakMinZoom, MapConstants.peakMaxZoom)`
    - Add `import '../core/constants.dart';`

6. Update `lib/services/track_display_cache_builder.dart`:
    - Replace `minZoom = 6` with `minZoom = MapConstants.peakMinZoom`
    - Replace `maxZoom = 18` with `maxZoom = MapConstants.peakMaxZoom`
    - Leave `_epsilon` and `_tileSize` as local constants
    - Add `import '../../core/constants.dart';`

7. Update `lib/providers/peak_correlation_settings_provider.dart`:
    - Keep `peakCorrelationDistanceKey` local
    - Replace `peakCorrelationDefaultDistanceMeters` with `PeakCorrelationConstants.defaultDistanceMeters`
    - Replace `peakCorrelationDistanceOptions` with `PeakCorrelationConstants.distanceOptions`
    - Add `import '../core/constants.dart';`

8. Update `lib/screens/map_screen.dart`:
   - Replace `_scrollSpeed` with `UiConstants.scrollSpeed`
   - Replace `_scrollInterval` with `UiConstants.scrollInterval`
   - Replace `_peakInfoPopupSize` with `UiConstants.peakInfoPopupSize`
   - Add `import '../core/constants.dart';`

9. Update `lib/widgets/peak_list_peak_dialog.dart`:
   - Replace `_dialogMargin` with `UiConstants.dialogMargin`
   - Add `import '../core/constants.dart';`

10. Update `lib/screens/peak_lists_screen.dart`:
    - Replace `_dividerWidth` with `UiConstants.dividerWidth`
    - Replace `_preferredLeftWidth` with `UiConstants.preferredLeftWidth`
    - Replace `_preferredRightWidth` with `UiConstants.preferredRightWidth`
    - Replace `_minimumMiniMapAspectWidth` with `UiConstants.minimumMiniMapAspectWidth`
    - Replace `_columnCellHorizontalPadding` with `UiConstants.columnCellHorizontalPadding`
    - Replace both `headerLabelGap` declarations with `UiConstants.headerLabelGap`
    - Replace `rowHorizontalPadding` with `UiConstants.rowHorizontalPadding`
    - Replace `columnGap` with `UiConstants.columnGap`
    - Replace `headerIconWidth` with `UiConstants.headerIconWidth`
    - Add `import '../core/constants.dart';`

11. Update `lib/widgets/map_action_rail.dart`:
    - Replace `_railSpacing` with `UiConstants.railSpacing`
    - Add `import '../core/constants.dart';`

12. Update `lib/screens/objectbox_admin_screen_table.dart`:
    - Replace `primaryColumnWidth` with `UiConstants.primaryColumnWidth`
    - Replace `actionsColumnWidth` with `UiConstants.actionsColumnWidth`
    - Add `import '../core/constants.dart';`

13. Do NOT modify:
    - Test files
    - `lib/models/peak.dart`
    - `lib/services/objectbox_schema_guard.dart`
    - `lib/services/migration_marker_store.dart`
    - Widget `Key()` declarations

14. Avoid:
    - Use relative imports only for `constants.dart`
    - Avoid barrels and re-exports
</implementation>

<validation>
1. Run `dart analyze lib/` - zero errors.
2. Run `flutter test` - all tests pass.
3. Verify `lib/core/constants.dart` has no imports from app-specific files.
4. Search for any remaining `const` declarations for `scrollSpeed`, `scrollInterval`, `peakInfoPopupSize`, `dialogMargin`, `dividerWidth`, `preferredLeftWidth`, `preferredRightWidth`, `minimumMiniMapAspectWidth`, `columnCellHorizontalPadding`, `headerLabelGap`, `rowHorizontalPadding`, `columnGap`, `headerIconWidth`, `railSpacing`, `primaryColumnWidth`, `actionsColumnWidth`, `peakCorrelationDefaultDistanceMeters`, `peakCorrelationDistanceOptions`, `minDisplayZoom`, `maxDisplayZoom`, or `zoom.clamp(6, 18)` in `lib/`; none should remain except the intentionally retained `peakCorrelationDistanceKey` and objectbox/local model constants.
5. Confirm all static classes use the `abstract final` pattern.
</validation>

<done_when>
 - `lib/core/constants.dart` exists with `MapConstants`, `GeoConstants`, `GpxConstants`, `PeakCorrelationConstants`, `RouterConstants`, and `UiConstants`.
 - `MapConstants.peakMinZoom` and `MapConstants.peakMaxZoom` are the single source of truth for zoom bounds.
 - `lib/providers/map_provider.dart` uses `MapConstants` for default center, default zoom, and shared search radius values.
 - `lib/models/gpx_track.dart` references `MapConstants.peakMinZoom` and `MapConstants.peakMaxZoom`, including `getSegmentsForZoom`.
 - `lib/services/track_display_cache_builder.dart` references `MapConstants.peakMinZoom` and `MapConstants.peakMaxZoom`.
 - `lib/providers/peak_correlation_settings_provider.dart` uses `PeakCorrelationConstants` for default distance and options while keeping the key local.
 - `lib/screens/map_screen.dart`, `lib/widgets/peak_list_peak_dialog.dart`, `lib/screens/peak_lists_screen.dart`, `lib/widgets/map_action_rail.dart`, and `lib/screens/objectbox_admin_screen_table.dart` reference `UiConstants` for their extracted layout constants.
 - `dart analyze lib/` passes with zero errors.
 - `flutter test` passes.
  - No shared config constant remains as a local `const` in `lib/` source files, except explicitly retained objectbox constants, widget keys, `peakCorrelationDistanceKey`, and model-scoped constants.
</done_when>
