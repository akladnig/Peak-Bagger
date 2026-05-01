## Overview
Persist filtered GPX for hiking tracks. Raw XML stays canonical; filtered XML drives stats and display.

**Spec**: `ai_specs/009-gpx-filter-spec.md`

## Context
- **Structure**: layer-first; services / providers / screens / tests
- **State management**: Riverpod + SharedPreferences
- **Reference implementations**: `lib/services/gpx_importer.dart`, `lib/providers/map_provider.dart`, `lib/screens/settings_screen.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`, `test/widget/gpx_tracks_shell_test.dart`
- **Assumptions/Gaps**: none blocking; stable `Key`s required for filter controls

## Plan

### Phase 1: Filter core + import slice

- **Goal**: raw GPX -> filtered XML -> persisted import path
- [x] `lib/models/gpx_track.dart` - add `filteredTrack`; keep raw fields authoritative
- [x] `lib/objectbox-model.json`, `lib/objectbox.g.dart` - regen schema for new field
- [x] `lib/services/gpx_track_filter.dart` - pure minimal GPX filter; time prune, outlier reject, Hampel, raw fallback
- [x] `lib/providers/gpx_filter_settings_provider.dart` - `GpxFilterConfig` from SharedPreferences; clamp defaults
- [x] `lib/services/gpx_importer.dart` - write `filteredTrack`; build display cache from filtered geometry; keep raw identity/dedupe rules
- [x] `lib/providers/map_provider.dart` - pass filter config into import path
- [x] `test/services/gpx_track_filter_test.dart` - filter happy path, `<time>` pruning, <2-point fallback, deterministic output
- [x] `test/services/gpx_importer_filter_test.dart` - import stores filteredTrack; refresh preserves raw-authoritative identity/org rules
- [x] TDD: filter behavior first, then importer happy path, then fallback cases
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Rescan/recalc + admin sync

- **Goal**: existing tracks refresh; recalc atomic; admin/debug reflects new field
- [x] `lib/services/gpx_importer.dart` - rescan mode re-filters all existing tracks; bypass unchanged-content skip
- [x] `lib/providers/map_provider.dart` - recalc uses filteredTrack, rebuilds display cache, atomic replace, warning on raw fallback
- [x] `lib/services/objectbox_admin_repository.dart` - include `filteredTrack` in admin/debug field listing
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - add rescan/recalc path coverage with warnings/statuses
- [x] `test/widget/gpx_tracks_shell_test.dart` - keep loading/disabled-state coverage aligned with atomic recalc behavior
- [x] TDD: rescan re-filters unchanged tracks; recalc updates stats + display cache; fallback warns once per batch
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Settings UI + journey coverage

- **Goal**: configurable filter controls in Settings; stable test selectors
- [x] `lib/screens/settings_screen.dart` - expandable filter section; stable keys; disabled/loading states
- [x] `test/widget/gpx_filter_settings_test.dart` - expand/collapse, clamp/persist, loading state, fallback warning display
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add filter-section selectors/actions
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - settings -> import/recalc journey assertions
- [x] TDD: settings persistence/clamp; UI value render; key-based journey assertions for import/recalc
- [x] Robot journey tests + selectors/seams for filter section, controls, and warning/result dialogs
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / out of scope
- **Risks**: minimal GPX output intentionally drops unrecognized extensions; rescan touches many rows; short-track fallback warnings need careful wording
- **Out of scope**: route filtering, per-track settings, keyboard shortcuts
