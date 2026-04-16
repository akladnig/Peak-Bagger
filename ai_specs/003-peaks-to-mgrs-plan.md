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
- [ ] `lib/models/peak.dart` - add 4 string fields; defaults `''`; helper/copy path
- [ ] `lib/providers/peak_provider.dart` - `overpassServiceProvider`, `peakRepositoryProvider`
- [ ] `lib/services/peak_mgrs_converter.dart` - split `55GEN1234567890` -> `55G/EN/12345/67890`; skip malformed
- [ ] `lib/services/peak_refresh_result.dart` - imported/skipped/warning DTO
- [ ] `lib/services/peak_repository.dart` - rollback-safe replace API; no `clearAll()`-first path
- [ ] `lib/objectbox.g.dart` - regen schema
- [ ] TDD: `55GEN1234567890` maps correctly; malformed coords skipped; replace preserves existing peaks on write failure
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 2: Notifier + Settings flow

- **Goal**: shared refresh path + modal dialogs
- [ ] `lib/providers/map_provider.dart` - inject peak providers; one shared load/refresh path; `refreshPeaks()` returns `PeakRefreshResult`, throws hard failure
- [ ] `lib/main.dart` - override peak providers at bootstrap
- [ ] `lib/screens/settings_screen.dart` - confirm/result/failure dialogs; keys; loading state; `X Peaks imported`
- [ ] `test/widget/peak_refresh_settings_test.dart` - confirm/cancel; result; failure; loading; stable keys
- [ ] TDD: success + partial warning + hard failure; cancel no-op; startup empty-store load uses same enrichment path
- [ ] Widget selectors: `refresh-peak-data-tile`, `peak-refresh-confirm`, `peak-refresh-cancel`, `peak-refresh-result-close`, `peak-refresh-error-close`, `peak-refresh-status`
- [ ] Verify: `flutter analyze` && `flutter test`

### Phase 3: Robot journey

- **Goal**: end-to-end Settings refresh path
- [ ] `test/harness/test_peak_repository.dart` - deterministic fake repo
- [ ] `test/harness/test_peak_overpass_service.dart` - deterministic fake overpass
- [ ] `test/robot/peaks/peak_refresh_robot.dart` - robot helpers, stable selectors
- [ ] `test/robot/peaks/peak_refresh_journey_test.dart` - confirm, refresh, result, warning, failure
- [ ] TDD: critical journey assertions one at a time; deterministic success/warning/failure setup
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope
- **Risks**: ObjectBox regen/migration; transaction semantics; provider bootstrap wiring
- **Out of scope**: peak search/filter on new fields; any UI outside Settings refresh
