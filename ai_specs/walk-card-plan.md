## Overview
Build Latest Walk dashboard card.
Pure track selection + compact card UI + dashboard wiring + journey coverage.

**Spec**: `ai_specs/walk-card-spec.md`

## Context
- **Structure**: feature-first dashboard/widgets/services; existing `latest-walk` slot in dashboard registry
- **State management**: Riverpod `Notifier` + `MapState.tracks`
- **Reference implementations**: `lib/screens/dashboard_screen.dart`, `lib/providers/dashboard_layout_provider.dart`, `lib/screens/peak_lists_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/screens/map_screen.dart`
- **Assumptions/Gaps**: use `mapProvider.tracks`; newest track wins, broken newest track => empty state; no new repository API unless forced

## Plan

### Phase 1: Latest track summary
- **Goal**: deterministic newest-track selection + formatting seam
- [x] `lib/services/latest_walk_summary.dart` - latest-track selection, empty-state decision, display model
- [x] `test/services/latest_walk_summary_test.dart` - TDD: newest `startDateTime`, null filter, `gpxTrackId` tie-break, broken/newest-empty behavior, `distance2d`
- [x] TDD: date string matches existing `Wed, 7 January 2026` format; ascent fallback `Unknown`
- [x] Verify: `flutter analyze` && `flutter test test/services/latest_walk_summary_test.dart`

### Phase 2: Card widget + dashboard slot
- **Goal**: render populated/empty Latest Walk card in dashboard grid
- [ ] `lib/widgets/dashboard/latest_walk_card.dart` - populated card, empty placeholder, 4:3 layout, static non-interactive mini-map
- [ ] `lib/screens/dashboard_screen.dart` - swap `latest-walk` body from placeholder to card, watch `mapProvider.tracks`
- [ ] `test/widget/latest_walk_card_test.dart` - TDD: populated render, empty render, single-line metadata, long-name truncation, 1-point vs 2+ point framing, provider-driven refresh
- [ ] TDD: stable keys `latest-walk-card`, `latest-walk-mini-map`, `latest-walk-empty-state`
- [ ] Verify: `flutter analyze` && `flutter test test/widget/latest_walk_card_test.dart test/widget/dashboard_screen_test.dart`

### Phase 3: Dashboard journey coverage
- **Goal**: confirm end-to-end dashboard entry stays stable
- [ ] `test/robot/dashboard/dashboard_journey_test.dart` - assert Latest Walk card present after dashboard open; add key-based checks for empty/populated state
- [ ] `test/robot/dashboard/dashboard_robot.dart` - add selectors/actions if journey needs them
- [ ] TDD: critical path opens dashboard, card exists, refresh after track update reflected without restart
- [ ] Verify: `flutter analyze` && `flutter test test/robot/dashboard/dashboard_journey_test.dart`

## Risks / Out of scope
- **Risks**: `flutter_map` rendering in widget tests; keep assertions key/text-based, avoid tile dependence
- **Risks**: dashboard card update path can regress if track refresh stops flowing through `mapProvider.tracks`
- **Out of scope**: interactive mini-map controls, dashboard order changes, new repository APIs
