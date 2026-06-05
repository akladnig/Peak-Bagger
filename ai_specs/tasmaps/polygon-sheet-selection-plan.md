## Overview

Polygon-backed Tasmap sheet lookup; replace rectangle winner logic.
Repo-first slice, then live-map state/readout, then remaining peak/UI callers.

**Spec**: `ai_specs/tasmaps/polygon-sheet-selection-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `lib/services`, `lib/providers`, `lib/widgets`, `test/services`, `test/widget`
- **State management**: Riverpod `Notifier`; `MapNotifier` owns map/readout state
- **Reference implementations**: `lib/services/polygon_geometry.dart`, `lib/services/tasmap_repository.dart`, `test/harness/test_tasmap_repository.dart`, `test/widget/map_screen_persistence_test.dart`
- **Assumptions/Gaps**: `gotoMgrs` branch stays MGRS-backed unless implementation proves `gotoPoint` is needed; no new dedicated robot journey required per spec unless an existing journey is cheap to extend

## Plan

### Phase 1: Core Lookup Slice

- **Goal**: polygon-backed repo seam; one real consumer
- [x] `lib/services/tasmap_repository.dart` - add `findByPoint(LatLng)`; reuse `polygonContainsPoint(...)`; keep range/MGRS prefilter as candidate-only; add deterministic `name` -> `series` -> `id` winner; add internal polygon cache + invalidation hooks
- [x] `test/harness/test_tasmap_repository.dart` - mirror `findByPoint`, tie-break, cache invalidation semantics
- [x] `test/services/tasmap_repository_lookup_test.dart` - create dedicated repo behavior coverage
- [x] `lib/services/peak_info_content_resolver.dart` - switch peak map resolution to direct point lookup
- [x] `test/services/peak_info_content_resolver_test.dart` - update fixtures/expectations for direct-point lookup
- [x] TDD: inside polygon resolves correct sheet -> implement `findByPoint`
- [x] TDD: rectangle false-positive returns `null` or neighbor -> tighten final winner logic
- [x] TDD: shared-boundary hit uses `name` -> `series` -> `id` -> lock deterministic order
- [x] TDD: repo mutation invalidates cached polygon data -> add lazy rebuild rules
- [x] TDD: peak info map name resolves from `latitude`/`longitude`, not MGRS fallback path -> wire first consumer
- [x] Verify: `flutter analyze` && `flutter test test/services/tasmap_repository_lookup_test.dart test/services/peak_info_content_resolver_test.dart`

### Phase 2: Live Map Readout / Info Slice

- **Goal**: direct-point readout; preserve current source precedence
- [x] `lib/providers/map_provider.dart` - add `cursorPoint`; sync with `cursorMgrs`; add direct-point helper(s); move info-popup/current-center lookup to `state.center`; keep `mapNameForMgrs()` MGRS-only
- [x] `lib/screens/map_screen.dart` - preserve `cursorMgrs ?? gotoMgrs ?? _liveCamera?.mgrs ?? currentMgrs` display precedence while mapping map-name lookup to `cursorPoint`, `_liveCamera.center`, `state.center`, and MGRS-backed `gotoMgrs`
- [x] `test/widget/map_screen_persistence_test.dart` - replace self-derived expectation with fixed fixture + literal map name
- [x] `test/widget/map_screen_keyboard_test.dart` - update info-popup/readout expectations for direct-point path
- [x] TDD: cursor branch reads map name from `cursorPoint` while `cursorMgrs` stays display-only -> implement state seam
- [x] TDD: clearing cursor readout clears both `cursorPoint` and `cursorMgrs` -> enforce lifecycle rules
- [x] TDD: live-camera/current-center branches preserve existing precedence while using point-based lookup -> wire map-screen readout
- [x] TDD: info popup resolves from `state.center` without `mapNameForMgrs()`/MGRS round-trip -> migrate notifier path
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_persistence_test.dart test/widget/map_screen_keyboard_test.dart`

### Phase 3: Remaining Peak/UI Callers

- **Goal**: finish direct-point caller migration; lock regressions
- [x] `lib/widgets/peak_list_peak_dialog.dart` - resolve map via direct point lookup
- [x] `lib/screens/map_screen.dart` - switch `_mapNameForPeak()` to direct point lookup
- [x] `test/widget/peak_list_peak_dialog_test.dart` - keep literal fixture-backed map-name expectations
- [x] `test/widget/map_screen_peak_search_test.dart` - assert polygon-correct map name via fixed fixture
- [x] `test/harness/test_tasmap_repository.dart` - extend fixture helpers as needed for widget callers
- [x] TDD: peak dialog/open-map path resolves sheet from peak coordinates -> migrate dialog caller
- [x] TDD: peak-search/map-screen surfaces show polygon-correct map names from fixed fixtures -> finish remaining caller adoption
- [x] TDD: if shared-border failures expose helper gap, add failing case to `test/services/polygon_geometry_test.dart` before any Tasmap-specific workaround
- [x] Robot journey tests + selectors/seams for critical flows: no new dedicated robot by default; existing widget + peak robot coverage was sufficient, so no new journey or selectors were required
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: readout precedence regression; cache invalidation misses after reload/reset; shared-border math may require extra helper coverage first
- **Out of scope**: Tasmap CSV/schema changes; new geometry package; readout display-text redesign; `gotoPoint` seam unless current `gotoMgrs` branch proves insufficient; dedicated new robot journey unless widget lane proves inadequate
