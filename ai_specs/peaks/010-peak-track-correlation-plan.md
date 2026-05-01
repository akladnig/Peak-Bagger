## Overview
Persist track-peak correlations in ObjectBox; wire into existing GPX maintenance flow.
Storage-only. No peak-correlation display UI.

**Spec**: `ai_specs/010-peak-track-correlation-spec.md`

## Context
- **Structure**: layer-first; `lib/models`, `lib/services`, `lib/providers`, `lib/screens`, `test/...`
- **State management**: Riverpod `Notifier` + `AsyncNotifier`; settings via `SharedPreferences`
- **Reference implementations**: `lib/providers/gpx_filter_settings_provider.dart`, `lib/screens/settings_screen.dart`, `lib/services/peak_refresh_service.dart`
- **Assumptions/Gaps**: `Peak.osmId` is the stable identity; first migration may rebuild peak rows; threshold values are `10m..100m` in `10m` steps

## Plan

### Phase 1: Schema + matcher core

- **Goal**: identity, relation, pure correlation logic
- [x] `lib/models/peak.dart` - add `osmId`; parse Overpass node id; carry through `copyWith`
- [x] `lib/models/gpx_track.dart` - add `peaks` relation + `peakCorrelationProcessed`; map round-trip
- [x] `lib/services/track_peak_correlation_service.dart` - bbox from `<trkpt>`; threshold pad; candidate scan; `distanceFromLine()` scoring; de-dupe; processed flag
- [x] `lib/services/peak_repository.dart` - upsert by `osmId`; first migration may delete/reinsert peak rows
- [x] `lib/objectbox.g.dart` - regen after schema change
- [x] `test/services/track_peak_correlation_service_test.dart` - threshold boundary, bbox filter, duplicate collapse, zero-length fallback, no-match processed
- [x] TDD: `osmId` parse; `peakCorrelationProcessed` map round-trip; threshold boundary match; bbox prefilter keeps valid peaks; duplicate peaks collapse; no-match marks processed
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Settings + maintenance wiring

- **Goal**: persist threshold; run correlation during import/reset/recalc, including the Recalculate Track Statistics maintenance flow
- [x] `lib/providers/peak_correlation_settings_provider.dart` - persisted threshold, defaults, bounds
- [x] `lib/screens/settings_screen.dart` - peak correlation section; stable keys `peak-correlation-settings-section` / `peak-correlation-distance-meters`; dropdown 10-100
- [x] `lib/providers/map_provider.dart` - call matcher during import/reset/recalc; save relation + processed flag atomically
- [x] `lib/services/peak_refresh_service.dart` - refresh by `osmId`; preserve ids for unchanged peaks
- [x] `lib/services/peak_repository.dart` - identity-backed refresh path for peak upserts
- [x] `test/services/peak_refresh_service_test.dart` - identity refresh; unchanged ids; rebuild-on-first-migration regression
- [x] `test/widget/peak_correlation_settings_test.dart` - render/change/persist threshold; reset/recalc dialogs still stable
- [x] TDD: setting reloads from prefs; import/reset/recalc write atomic correlation; refresh preserves unchanged peak ids; failure leaves prior tracks intact
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey + regression

- **Goal**: end-to-end Settings maintenance path
- [x] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - threshold helper/actions; stable selectors
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - change threshold; run recalc; verify result dialog/status/cancel no-op
- [x] `test/robot/gpx_tracks/recovery_journey_test.dart` - keep reset/recovery path green with new relation state
- [x] TDD: one robot assertion at a time; deterministic prefs/provider seams; no flaky async
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: ObjectBox regen/migration; identity backfill for existing peaks; selector stability in Settings
- **Out of scope**: any on-map peak-correlation visualization or track-detail display
