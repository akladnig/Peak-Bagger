## Overview

Peaks Bagged dashboard card.
Mirror the Distance card shell; render total climbs + new peaks climbs from track peak correlations.
Primary header metric only; primary series uses `Theme.primary`, secondary series uses green.

**Spec**: `./ai_specs/bags-spec.md` (read this file for full requirements)

## Context

- **Structure**: dashboard card under `lib/widgets/dashboard`
- **State management**: Riverpod dashboard screen + existing `mapProvider` track flow
- **Reference implementations**: `lib/widgets/dashboard/distance_card.dart`, `lib/widgets/dashboard/elevation_card.dart`, `lib/widgets/dashboard/summary_card.dart`, `lib/widgets/dashboard/summary_chart.dart`, `lib/screens/dashboard_screen.dart`, `lib/theme.dart`
- **Assumptions/Gaps**: derive from current `GpxTrack.peaks` order; no separate bagged-history provider unless needed for determinism

## Plan

### Phase 1: Card + series math

- **Goal**: thin end-to-end Peaks Bagged slice
- [x] `lib/services/peaks_bagged_summary_service.dart` - derive per-bucket total/new peak climbs from deterministic track ordering; first occurrence = new, later repeats = total only
- [x] `lib/widgets/dashboard/peaks_bagged_card.dart` - dashboard card shell, empty/loading/content states, summary controls, primary-header-only metric wiring
- [x] `test/services/peaks_bagged_summary_service_test.dart` - TDD: total count, new-count, duplicate collapse, null-date skip, tie-break order
- [x] `test/widget/peaks_bagged_card_test.dart` - TDD: stable keys, loading/empty/content, primary header metric, controls scoped to card
- [x] Verify: `flutter analyze` && `flutter test test/services/peaks_bagged_summary_service_test.dart test/widget/peaks_bagged_card_test.dart`

### Phase 2: Dashboard wiring + regression coverage

- **Goal**: replace placeholder slot, preserve dashboard behavior
- [x] `lib/screens/dashboard_screen.dart` - swap `peaks-bagged` placeholder for real card; keep summary header bound to primary series only
- [x] `test/widget/dashboard_screen_test.dart` - TDD: card present in grid, drag order intact, primary header metric renders for Peaks Bagged
- [x] `test/robot/dashboard/dashboard_journey_test.dart` - TDD: dashboard journey still reorders cards and the Peaks Bagged slot remains stable
- [x] Verify: `flutter analyze` && `flutter test test/widget/dashboard_screen_test.dart test/robot/dashboard/dashboard_journey_test.dart`

## Risks / Out of scope

- **Risks**: first-occurrence classification depends on strict track ordering; summary math must stay deterministic
- **Out of scope**: bagged persistence changes, new dashboard slots, new edit flows, map overlays, or storage schema work
