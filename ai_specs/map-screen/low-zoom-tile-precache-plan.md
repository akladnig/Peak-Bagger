## Overview

Pre-download low-zoom basemap tiles before first browse.
Reuse existing FMTC download path; add once-per-version warmup for zooms `< 8`.

**Spec**: quick plan from task description; no standalone spec file

## Context

- **Structure**: screen/service-heavy Flutter app; startup in `lib/main.dart`; cache logic in `lib/services`
- **State management**: Riverpod for app state; tile cache bootstrap currently service-first, outside providers
- **Reference implementations**: `lib/services/tile_cache_service.dart`, `lib/services/tile_cache_download_scope.dart`, `lib/screens/settings_screen.dart`, `test/unit/tile_cache_download_scope_test.dart`, `test/robot/settings/tile_cache_journey_test.dart`
- **Assumptions/Gaps**: assume fix = automatic, best-effort, once-per-version Tasmania-wide warmup for built-in basemaps at zooms `0..7`; manual settings download stays; overlay rebuild jank remains separate

## Plan

### Phase 1: Low-zoom warmup bootstrap

- **Goal**: ensure low-zoom tiles exist before first zoom-out
- [x] `lib/services/tile_cache_download_scope.dart` - add shared low-zoom Tasmania region builder; reuse `GeoConstants`; expose zoom constants/helper for `< 8` warmup
- [x] `lib/services/tile_cache_service.dart` - add testable `ensureLowZoomWarmup()` entrypoint; loop basemap stores; call FMTC download with `skipExistingTiles: true`; persist once-per-version completion; treat failures best-effort; avoid duplicate concurrent runs
- [x] `lib/main.dart` - trigger low-zoom warmup after cache init using non-blocking fire-and-forget startup hook; do not delay first frame on download completion
- [x] `test/unit/tile_cache_download_scope_test.dart` - TDD: low-zoom warmup region covers Tasmania bounds and uses zoom `0..7`
- [x] `test/unit/tile_cache_service_test.dart` - TDD: first run downloads missing low-zoom tiles; completed version skips rerun; partial failure does not mark success; duplicate calls coalesce
- [x] `test/robot/settings/tile_cache_journey_test.dart` - Robot journey tests: keep manual tile-cache download flow green after shared scope extraction; reuse existing selectors/seams; no new UI instrumentation unless warmup status is surfaced
- [x] Verify: `flutter analyze` && `flutter test test/unit/tile_cache_download_scope_test.dart test/unit/tile_cache_service_test.dart test/robot/settings/tile_cache_journey_test.dart`

## Risks / Out of scope

- **Risks**: startup network churn if warmup scope too broad; FMTC startup download API behavior may need a drain/await strategy; low-zoom tile warmup may improve fetch latency but not overlay-generated jank
- **Out of scope**: redesign of tile-cache settings UI; pre-downloading track/route overlay data; fixing non-cache map overlay rebuild cost below zoom 8
