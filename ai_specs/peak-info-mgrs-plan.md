## Overview

Add MGRS row + singular/plural list label in map peak popup.
Keep scope tight: popup card, small map-lookup consistency fix, targeted tests.

**Spec**: `ai_specs/peak-info-mgrs-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `providers/`, `services/`, `widgets/`, `models/`, `core/`
- **State management**: Riverpod; `NotifierProvider` + repository/provider overrides in tests
- **Reference implementations**: `lib/screens/map_screen_panels.dart`, `lib/providers/map_provider.dart`, `test/widget/map_screen_peak_info_test.dart`, `test/robot/gpx_tracks/gpx_tracks_robot.dart`
- **Assumptions/Gaps**: Spec refined; no open blockers. Follow existing provider-override robot pattern. No shared formatter unless testability forces it.

## Plan

### Phase 1: Popup Content Slice

- **Goal**: popup renders correct text; map/MGRS completeness aligned
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: add one failing assertion for `MGRS:` under `Map:` with exact `55G DM 80000 95000`
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: one trimmed membership -> `List:`; multiple trimmed memberships -> `Lists:`; whitespace-only memberships hidden; visible names trimmed; repo sort preserved
- [x] `test/widget/map_screen_peak_info_test.dart` - TDD: incomplete or whitespace-only MGRS hides row and still uses lat/lng map fallback
- [x] `lib/screens/map_screen_panels.dart` - add minimal private formatting/branching for trimmed MGRS row + singular/plural list label; keep title, height, map rows intact; use monospace font styling only
- [x] `lib/providers/map_provider.dart` - switch `_resolvePeakMapName()` stored-MGRS completeness check to trimmed parts before map lookup
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_peak_info_test.dart`

### Phase 2: Placement And Journey Coverage

- **Goal**: larger popup remains edge-safe; critical map journey stays deterministic
- [x] `lib/core/constants.dart` - raise `UiConstants.peakInfoPopupSize.height` by minimum needed for extra row
- [x] `test/widget/peak_info_popup_placement_test.dart` - use `UiConstants.peakInfoPopupSize`; keep right/left/vertical clamp coverage with real popup size
- [x] `test/robot/peaks/peak_info_robot.dart` - add optional `PeakListRepository`/`TasmapRepository` seam via `ProviderScope` overrides; keep key-first selectors
- [x] `test/robot/peaks/peak_info_robot.dart` - replace hard-coded popup expectation with expected-line assertions
- [x] `test/robot/peaks/peak_info_journey_test.dart` - seed popup journeys for complete MGRS + single-list and multi-list cases; assert rendered lines deterministically
- [x] TDD: first failing robot journey opens popup and matches seeded `MGRS:` + `List:`; then add `Lists:` case; add only seams/selectors needed for each red-green cycle
- [x] Robot journey tests + selectors/seams for critical popup flow; reuse existing stable popup keys
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: fixed-height card may still feel tight with long peak/map/list text; robot fixture plumbing may need extra tasmap fake setup; trimmed duplicate list names remain duplicated by spec
- **Out of scope**: repository sorting changes; shared grid-formatting refactor; persistence/model/schema changes; coordinate-conversion changes beyond current lat/lng map fallback
