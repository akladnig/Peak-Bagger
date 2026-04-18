## Overview

Thin `MapScreen`; preserve route/test surfaces.
Start with guardrail tests + one small extraction; then layers/interactions; finish panels/shell cleanup.

**Spec**: `ai_specs/map_screen_cleanup-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first; `screens/`, `widgets/`, `providers/`, `services/`, `models/`
- **State management**: Riverpod (`flutter_riverpod`)
- **Reference implementations**: `lib/screens/map_screen.dart`, `lib/widgets/map_action_rail.dart`, `test/widget/tasmap_map_screen_test.dart`, `test/robot/tasmap/tasmap_journey_test.dart`
- **Assumptions/Gaps**: `map_screen_interactions.dart` optional; add keys only where deterministic tests need them; keep existing robot journeys, add no new robot lane unless selectors/seams force it

## Plan

### Phase 1: Guardrails + Vertical Slice

- **Goal**: lock test surfaces; prove one screen-scoped extraction path
- [x] `test/widget/map_screen_keyboard_test.dart` - add dedicated keyboard/focus regressions: one zoom path, one movement path, `g` opens goto, one focus-return path, one info-popup key path
- [x] `test/widget/map_screen_peak_search_test.dart` - add dedicated peak-search regressions: open/close, empty state, select result
- [x] `lib/widgets/map_action_rail.dart` - add minimal stable keys only if keyboard/peak-search tests cannot be deterministic with existing selectors
- [x] `lib/screens/map_screen.dart` - extract one low-risk screen-scoped slice into `lib/screens/map_screen_panels.dart` or `lib/screens/map_screen_layers.dart`; keep shell-owned callbacks in place
- [x] TDD: keyboard happy-path shortcut -> failing widget test -> minimal selector/seam -> pass
- [x] TDD: peak-search open/empty/select path -> failing widget test -> minimal selector/seam -> pass
- [x] Robot journey tests + selectors/seams for critical flows: keep `test/robot/tasmap/tasmap_journey_test.dart` green; keep `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` green; add no new robot selectors unless refactor breaks determinism
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Layers + Optional Interaction Helpers

- **Goal**: move pure display logic; keep side effects in shell
- [x] `lib/screens/map_screen_layers.dart` - extract tile URL, Tasmap label/overlay builders, peak marker builders, polyline/layer ordering helpers
- [x] `lib/screens/map_screen.dart` - reduce layer/polygon/polyline/MGRS-display glue; keep `MapController`, `setState`, post-frame work in shell
- [x] `lib/screens/map_screen_interactions.dart` - create only if enough cohesive pure/support helpers remain; otherwise keep helpers in `map_screen.dart` (kept in shell; optional file not needed)
- [x] `test/widget/tasmap_map_screen_test.dart` - extend only where layer ordering/zoom gating/label behavior needs tighter coverage
- [x] `test/widget/gpx_tracks_selection_test.dart` - preserve selected-track styling/order coverage
- [x] `test/widget/gpx_tracks_recovery_test.dart` - preserve hover/recovery interaction coverage
- [x] TDD: selected-track/layer-order helper behavior -> failing focused regression -> minimal extraction -> pass
- [x] TDD: Tasmap zoom-gated label/overlay helper behavior -> failing focused regression -> minimal extraction -> pass
- [x] Robot journey tests + selectors/seams for critical flows: rerun existing Tasmap/GPX journeys; keep current key surfaces (`tasmap-layer`, `tasmap-label-layer`, `map-interaction-region`) stable
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Panels + Shell Cleanup

- **Goal**: move remaining panel UI; leave shell as orchestration only
- [x] `lib/screens/map_screen_panels.dart` - own goto/search/info popup UI and overlay readouts; accept shell-owned callbacks/explicit state inputs
- [x] `lib/screens/map_screen.dart` - keep `Focus.onKeyEvent`, `MapOptions` pointer callbacks, goto submit/zoom/camera callbacks, focus/controller mutation, post-frame sync
- [x] `lib/screens/map_screen_interactions.dart` - finalize or delete if optional extraction proved too small (not created; optional extraction stayed in shell)
- [x] `test/widget/map_screen_keyboard_test.dart` - verify final keyboard/focus surfaces after panel extraction
- [x] `test/widget/map_screen_peak_search_test.dart` - verify final peak-search behavior after panel extraction
- [x] TDD: goto/info panel callback wiring -> failing widget regression -> minimal callback extraction -> pass
- [x] TDD: final shell/panel focus recovery -> failing widget regression -> minimal fix -> pass
- [x] Robot journey tests + selectors/seams for critical flows: keep existing robot lanes green; report any residual selector risk explicitly
- [x] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: optional `map_screen_interactions.dart` may collapse back into shell; new selectors may tempt unnecessary UI churn; panel extraction may blur shell-vs-provider ownership if callbacks leak
- **Out of scope**: `mapProvider` refactor; importer/services cleanup; UX redesign; reusable widget reshuffle under `lib/widgets/`
