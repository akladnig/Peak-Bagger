## Overview

Peak edits already reload map state, but the main-map projection cache still reuses stale peak geometry/text.
Fix cache invalidation on peak field changes; prove with service + UI coverage.

**Spec**: ad hoc bug report

## Context

- **Structure**: layer-first; `models/`, `providers/`, `screens/`, `services/`, `widgets/`, `test/robot/`
- **State management**: Riverpod
- **Reference implementations**: `lib/screens/objectbox_admin_screen.dart`, `lib/screens/map_screen.dart`, `lib/services/peak_projection_cache.dart`, `test/services/peak_cluster_engine_test.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/objectbox_admin/objectbox_admin_journey_test.dart`
- **Assumptions/Gaps**: save path already calls `reloadPeakMarkers()`; bug is stale peak projection cache; any alternate peak-edit path must hit the same reload seam

## Plan

### Phase 1: Cache Fingerprint

- **Goal**: rebuild peak viewport data when render-relevant fields change
- [x] `lib/services/peak_projection_cache.dart` - key cached viewport/index data on a peak render fingerprint, not ids only; keep compact + supercluster keys aligned
- [x] `test/services/peak_cluster_engine_test.dart` - extend cache invalidation coverage for changed `latitude`/`longitude`, `name`, `elevation`
- [x] TDD: changed location rebuilds marker positions + cluster membership
- [x] TDD: changed height/name rebuilds label text + seed order
- [x] Verify: `flutter analyze` && `flutter test test/services/peak_cluster_engine_test.dart`

### Phase 2: Map Proof

- **Goal**: saved edits show on the main map without restart
- [x] `test/widget/map_screen_peak_info_test.dart` - existing popup-refresh proof; saved peak details stay fresh after reload
- [x] `test/robot/objectbox_admin/objectbox_admin_journey_test.dart` - extend peak edit/save journey to confirm edited peak remains reflected on the map after navigation
- [x] `test/robot/objectbox_admin/objectbox_admin_robot.dart` - add selectors only if the edit flow needs direct height/location field access
- [x] TDD: admin save -> reload -> map marker update visible in widget harness
- [x] Robot journey tests + selectors/seams for save/reopen path; reuse existing `objectbox-admin-peak-*` keys and `map-interaction-region`
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_peak_info_test.dart test/robot/objectbox_admin/objectbox_admin_journey_test.dart`

## Risks / Out of Scope

- **Risks**: fingerprint cost on large peak sets; any alternate edit path that skips `reloadPeakMarkers()` still stays stale
- **Out of scope**: redesigning map data flow, popup content rules, non-map peak edit surfaces
- **Blocker**: full `flutter test` still fails in `test/robot/gpx_tracks/gpx_tracks_journey_test.dart: import refreshes dashboard and peak list counts` (pre-existing, unrelated)
