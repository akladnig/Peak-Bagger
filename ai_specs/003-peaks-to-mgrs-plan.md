## Overview
Persist MGRS on Peak; refactor refresh through injectable Riverpod seams; mirror Settings reset dialogs.

**Spec**: `ai_specs/003-peaks-to-mgrs-spec.md`

## Context
- **Structure**: layer-first; `providers/`, `services/`, `screens/`, `models/`
- **State management**: Riverpod `Provider` + `Notifier`
- **Reference implementations**: `lib/providers/tasmap_provider.dart`, `lib/screens/settings_screen.dart`, `test/robot/tasmap/tasmap_robot.dart`
- **Assumptions/Gaps**: new provider file `lib/providers/peak_provider.dart`; `PeakRefreshResult` DTO in `lib/services/peak_refresh_result.dart`

## Plan

### Phase 1: MGRS core + repository

- **Goal**: schema + enrichment primitive
- [x] `lib/models/peak.dart` - add 4 string fields; defaults `''`; helper/copy path
- [x] `lib/providers/peak_provider.dart` - `overpassServiceProvider`, `peakRepositoryProvider`
- [x] `lib/services/peak_mgrs_converter.dart` - split `55GEN1234567890` -> `55G/EN/12345/67890`; skip malformed
- [x] `lib/services/peak_refresh_result.dart` - imported/skipped/warning DTO
- [x] `lib/services/peak_repository.dart` - rollback-safe replace API; no `clearAll()`-first path
- [x] `lib/objectbox.g.dart` - regen schema
- [x] TDD: `55GEN1234567890` maps correctly; malformed coords skipped; replace preserves existing peaks on write failure
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Notifier + Settings flow

- **Goal**: shared refresh path + modal dialogs
- [x] `lib/services/peak_refresh_service.dart` - shared fetch/enrich/replace path
- [x] `lib/providers/map_provider.dart` - inject peak providers; one shared load/refresh path; `refreshPeaks()` returns `PeakRefreshResult`, throws hard failure
- [x] `lib/main.dart` - override peak providers at bootstrap
- [x] `lib/screens/settings_screen.dart` - confirm/result/failure dialogs; keys; loading state; `X Peaks imported`
- [x] `test/services/peak_refresh_service_test.dart` - success; partial warning; hard failure
- [x] `test/widget/peak_refresh_settings_test.dart` - confirm/cancel; result; failure; loading; stable keys
- [x] TDD: success + partial warning + hard failure; cancel no-op; startup empty-store load uses same enrichment path
- [x] Widget selectors: `refresh-peak-data-tile`, `peak-refresh-confirm`, `peak-refresh-cancel`, `peak-refresh-result-close`, `peak-refresh-error-close`, `peak-refresh-status`
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey

- **Goal**: end-to-end Settings refresh path
- [x] `test/harness/test_peak_repository.dart` - deterministic fake repo
- [x] `test/harness/test_peak_overpass_service.dart` - deterministic fake overpass
- [x] `test/robot/peaks/peak_refresh_robot.dart` - robot helpers, stable selectors
- [x] `test/robot/peaks/peak_refresh_journey_test.dart` - confirm, refresh, result, warning, failure
- [x] TDD: critical journey assertions one at a time; deterministic success/warning/failure setup
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: ObjectBox regen/migration; transaction semantics; provider bootstrap wiring
- **Out of scope**: peak search/filter on new fields; any UI outside Settings refresh
