## Overview
Route-draft in-place editing slice.
Provider history/snapshot first, then marker gesture UI, then route-sheet controls, then robot journey.

**Spec**: `ai_specs/route-edit-spec.md` (read this file for full requirements)

## Context
- **Structure**: provider-led map feature; screen/widget split
- **State management**: Riverpod `Notifier<MapState>`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/screens/map_screen.dart`, `lib/screens/map_screen_panels.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/robot/map/map_route_journey_test.dart`
- **Assumptions/Gaps**: none material; spec resolves live-drag fallback, peak-target invalidation, popup rules

## Plan

### Phase 1: Draft history core

- **Goal**: snapshot/edit state; undo/redo safe
- [x] `lib/providers/map_provider.dart` - history stack/snapshot; undo/redo availability; public move/delete/drag entry points; monotonic request/elevation counters; empty-draft recovery
- [x] `lib/providers/map_provider.dart` - full open-route/loop semantics; peak-target invalidation edge cases; drag failure fallback parity; deeper `segmentFailure` recovery coverage
- [x] TDD: point-place undo/redo; one-drag-one-step; straight-line move; delete-last-marker recovery
- [x] TDD: interior/terminal move-delete; open-route/loop recovery; deeper `routed`/`noPath`/`offTrack`/`failed` drag parity; stale-response guard
- [x] TDD: peak-target invalidation after marker edit
- [x] `test/providers/route_draft_state_test.dart` - provider coverage for landed history/move/delete slices
- [x] Verify: `flutter analyze && flutter test test/providers/route_draft_state_test.dart`

### Phase 2: Marker gestures + delete popup

- **Goal**: marker click/drag precedence; popup overlay
- [x] `lib/screens/map_screen_layers.dart` - marker hit-test hooks; stable keys; click consumption; raw-pointer drag plumbing
- [x] `lib/screens/map_screen.dart` - marker vs map tap precedence; drag session wiring; popup overlay placement/dismissal
- [x] `lib/screens/map_screen_panels.dart` - `RouteDraftMarkerDeletePopupCard`; close icon; destructive action wiring
- [x] TDD: click-vs-drag split; marker click isolation; delete action flow; escape dismissal
- [x] TDD: hover cursor; drag cursor; popup anchor edge cases; outside-click behavior specifics
- [x] `test/widget/map_screen_route_hover_test.dart` - landed marker interaction coverage
- [x] `test/widget/route_marker_layer_test.dart` - marker shell / hitbox / selector coverage
- [x] Verify: `flutter analyze && flutter test test/widget/map_screen_route_hover_test.dart test/widget/route_marker_layer_test.dart`

### Phase 3: Route sheet controls + shortcuts

- **Goal**: square action buttons; keyboard undo/redo
- [x] `lib/widgets/map_route_bottom_sheet.dart` - square icon action strip; undo/redo buttons; placement/spacing/keys
- [x] `lib/screens/map_screen.dart` - `⌘Z` / `Shift+⌘Z`; name-field focus precedence; map focus restore
- [x] TDD: action-strip layout; square button family; enablement; shortcut gating
- [x] TDD: `Route to Peak` invalidation gating after terminal target edits
- [x] `test/widget/map_screen_route_sheet_test.dart` - route strip layout / enablement coverage
- [x] `test/widget/map_screen_keyboard_test.dart` - shortcut and focus-precedence coverage
- [x] Verify: `flutter analyze && flutter test test/widget/map_screen_route_sheet_test.dart test/widget/map_screen_keyboard_test.dart`

### Phase 4: Robot journey

- **Goal**: full visible edit loop
- [x] `test/robot/map/map_route_robot.dart` - drag/delete/undo/redo helpers; stable selectors
- [x] TDD: create route -> place points -> move marker -> delete marker -> undo/redo -> save
- [x] `test/robot/map/map_route_journey_test.dart` - end-to-end edit journey coverage
- [x] Verify: `flutter analyze && flutter test test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope
- **Risks**: marker/map click precedence; popup placement on narrow viewports; async drag results
- **Out of scope**: persistence/export/schema changes; new route mode; separate editor screen
