## Overview

Replace GPX rest detection with a stationary-window heuristic. Keep `pausedTime` gap-based; reuse the existing import/recalc path.

**Spec**: `ai_specs/tracks/005-add-gpx-stats-4-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first (`models/`, `services/`, `providers/`, `screens/`, `test/`)
- **State management**: Riverpod `MapNotifier` + providers
- **Reference implementations**: `lib/services/gpx_track_statistics_calculator.dart`, `lib/services/gpx_importer.dart`, `lib/providers/map_provider.dart`, `test/gpx_track_test.dart`, `test/services/gpx_importer_filter_test.dart`, `test/widget/map_screen_track_info_test.dart`, `test/services/objectbox_admin_repository_test.dart`, `test/widget/objectbox_admin_browser_test.dart`
- **Assumptions/Gaps**: no schema/codegen work; admin already exposes time fields; fixtures needed under `test/fixtures/`; no new robot journey unless visible copy changes

## Plan

### Phase 1: Detector core

- **Goal**: pure stationary-window math
- [x] `lib/services/gpx_track_statistics_calculator.dart` - replace low-speed cluster heuristic with stationary-window detector; keep UTC normalization, whole-second math, and segment-gap `pausedTime`
- [x] `test/gpx_track_test.dart` - TDD: true stop qualifies, slow walk rejected, jitter stop accepted, hysteresis boundary, zero/defaults, UTC + pause-gap cases
- [x] `test/fixtures/acropolis_(10-03-2025).gpx` - add regression fixture if missing
- [x] `test/fixtures/mt-wellington-loop_(04-03-2025).gpx` - add regression fixture if missing
- [x] Verify: `flutter analyze && flutter test test/gpx_track_test.dart`

### Phase 2: Wiring + regressions

- **Goal**: keep import/recalc behavior aligned
- [ ] `test/services/gpx_importer_filter_test.dart` - TDD: filtered import still populates time fields; raw fallback; invalid/empty filtered XML fallback; pause-gap handling; update Acropolis/Mt Wellington expectations
- [ ] `test/widget/map_screen_track_info_test.dart` - refresh displayed time values if the new stats change track-info output
- [ ] `lib/services/gpx_importer.dart` - only if tests expose mismatch in processTrack/fallback behavior
- [ ] `lib/providers/map_provider.dart` - only if tests expose mismatch in recalc source selection or state refresh
- [ ] Verify: `flutter analyze && flutter test`

### Phase 3: Admin + journey checks

- **Goal**: keep inspection and existing journeys green
- [ ] `test/services/objectbox_admin_repository_test.dart` - refresh time-field expectations if numeric values changed
- [ ] `test/widget/objectbox_admin_browser_test.dart` - refresh admin browser expectations if numeric values changed
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - keep import/reset/recalc journeys green; update numeric assertions only if needed
- [ ] Verify: `flutter analyze && flutter test`

## Risks / Out of scope

- **Risks**: hysteresis thresholds may need tuning if regression fixtures do not land near target; UTC/second-rounding drift; fixture timestamps must be deterministic
- **Out of scope**: new packages, schema changes, new UI, route rendering changes, ObjectBox admin schema changes
