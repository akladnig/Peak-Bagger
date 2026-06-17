## Overview

Tasmania peak-list drawer should show Tasmania lists again, not only `All Peaks`.
Fix shared region matching first; then harden save paths against legacy region values.

**Spec**: `task description` (quick plan; no spec file)

## Context

- **Structure**: feature-first; map UI in `lib/widgets`/`lib/screens`; shared rules in `lib/services`; Riverpod state in `lib/providers`
- **State management**: Riverpod `Notifier` + derived `Provider`
- **Reference implementations**: `lib/widgets/map_peak_lists_drawer.dart`, `lib/services/peak_list_visibility.dart`, `lib/providers/map_provider.dart`, `lib/services/peak_list_repository.dart`, `test/providers/peak_list_selection_provider_test.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- **Assumptions/Gaps**: likely legacy `PeakList.region` rows are blank or non-canonical Tasmania strings; basemap correctness implies `regionManifestCatalog.regionKeyForPoint(state.center)` already resolves `tasmania`

## Plan

### Phase 1: Shared match fix

- **Goal**: Tasmania rows render again through the helper already used by drawer + reconcile
- [x] `test/providers/peak_list_selection_provider_test.dart` - TDD: `renderablePeakListIds` keeps Tasmania lists when `region` is `tasmania`, blank, or legacy-cased; still rejects other-region + malformed rows
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: Tasmania center + legacy-region list shows its row beside `All Peaks`; moving outside Tasmania hides it
- [x] `lib/services/peak_list_visibility.dart` - add one region-normalization helper; make `peakListAppliesToRegion` use canonical region matching with Tasmania fallback for legacy empty values
- [x] Verify: `flutter analyze` && `flutter test test/providers/peak_list_selection_provider_test.dart test/widget/map_screen_peak_info_test.dart`

### Phase 2: Persisted-data hardening

- **Goal**: future writes stop reintroducing non-canonical list regions; journey stays covered
- [x] `test/services/peak_list_repository_test.dart` - TDD: save normalizes blank/legacy Tasmania region to `Peak.defaultRegion`; explicit non-Tas region preserved
- [x] `lib/services/peak_list_repository.dart` - normalize `PeakList.region` at repository save boundary; keep replacement/update semantics unchanged
- [x] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - robot journey: open peaks drawer in Tasmania with legacy-region list, assert row visible; move to NSW, assert row disappears; existing key selectors sufficient
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_list_repository_test.dart test/robot/gpx_tracks/gpx_tracks_journey_test.dart`

## Risks / Out of scope

- **Risks**: blank-region fallback must stay Tasmania-only; repository normalization can surprise if blank is intentionally meaningful; existing ObjectBox rows remain dirty until resaved
- **Out of scope**: ObjectBox schema migration, new peak-list UI copy, basemap-region logic changes
