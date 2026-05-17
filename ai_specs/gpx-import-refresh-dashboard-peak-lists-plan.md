## Overview
GPX import should refresh bagged-history-backed views immediately.
Stop relying on manual `Recalculate Track Statistics` for dashboard + peak-lists updates.

**Spec**: `n/a` (bug report: GPX import refresh regression)

## Context
- **Structure**: feature-first (`lib/providers`, `lib/screens`, `lib/widgets`, `test/...`)
- **State management**: Riverpod + synchronous ObjectBox repos
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/providers/my_ascents_summary_provider.dart`, `lib/providers/peak_list_selection_provider.dart`, `lib/screens/peak_lists_screen.dart`, `test/providers/map_provider_import_test.dart`
- **Assumptions/Gaps**: import already computes track stats + peak matches; missing seam is bagged-history refresh/invalidation; peak-lists screen reads repos directly and must listen to a revision signal

## Plan

### Phase 1: Import refresh seam

- **Goal**: import publishes new bagged history + invalidation
- [x] `lib/providers/map_provider.dart` - after successful GPX import, sync `peaks_bagged` from imported tracks, bump `peaksBaggedRevisionProvider`, keep current selection/status behavior
- [x] `lib/providers/my_lists_summary_provider.dart` - watch `peaksBaggedRevisionProvider` so dashboard list counts refresh on bagged-only mutations too
- [x] `lib/screens/peak_lists_screen.dart` - watch `peaksBaggedRevisionProvider` (or route summary build behind a provider) so visible peak-list counts rebuild after import/recalc
- [x] `test/providers/map_provider_import_test.dart` - TDD: import updates bagged repo, increments revision, preserves selected track, no recalc step needed
- [x] `test/providers/my_lists_summary_provider_test.dart` - TDD: summary recomputes on bagged revision bump, not just track changes
- [x] `test/widget/peak_lists_screen_test.dart` - TDD: table counts change after bagged revision bump/import seam
- [x] Verify: `flutter analyze` && `flutter test test/providers/map_provider_import_test.dart test/providers/my_lists_summary_provider_test.dart test/widget/peak_lists_screen_test.dart`

### Phase 2: Journey proof

- **Goal**: import -> refreshed dashboard/peak-lists path
- [ ] `test/robot/gpx_tracks/gpx_tracks_robot.dart` - add selectors/helpers for import result + post-import dashboard/peak-list checks
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - TDD: import GPX, assert dashboard cards refresh, assert peak-lists counts refresh without manual recalc
- [ ] `test/widget/dashboard_screen_test.dart` - regression: dashboard summary cards stay reactive after import/bagged refresh
- [ ] Verify: `flutter analyze` && `flutter test test/robot/gpx_tracks/gpx_tracks_journey_test.dart test/widget/dashboard_screen_test.dart`

## Risks / Out of scope
- **Risks**: peak-lists screen may need one extra provider seam if direct revision watch is not enough; bagged sync order must match recalc semantics; ObjectBox write timing may affect test determinism
- **Out of scope**: GPX parsing/filtering, file picker UX, manual recalc copy, background sync
