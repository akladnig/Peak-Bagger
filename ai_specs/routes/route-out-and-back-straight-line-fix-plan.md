## Overview

Fix straight-line draft desync that trips `Out and Back` inconsistency guard.
Keep snap-to-trail behavior unchanged; make the draft state atomic before return-leg mirroring.

**Spec**: `ai_specs/routes/route-out-and-back-spec.md`

## Context

- **Structure**: feature-first, provider + widget + robot tests
- **State management**: Riverpod `Notifier`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `test/providers/route_draft_state_test.dart`, `test/robot/map/map_route_journey_test.dart`
- **Assumptions/Gaps**: bug is straight-line-only; snap-to-trail already re-syncs through rebuild path

## Plan

### Phase 1: Draft sync repair

- **Goal**: straight-line edits leave control points + committed geometry aligned
- [x] `lib/providers/map_provider.dart` - inspect `addRouteDraftMarker`, drag/delete/undo redo, out-and-back guard; route straight-line mutations through one sync path or rebuild before consistency check
- [x] `lib/providers/map_provider.dart` - keep `applyRouteDraftOutAndBack()` strict, but only after confirming draft state was rebuilt from current control endpoints
- [x] `test/providers/route_draft_state_test.dart` - TDD: straight-line create -> out-and-back succeeds; straight-line edit path -> out-and-back still succeeds; inconsistent state still errors
- [x] Verify: `flutter analyze` && `flutter test test/providers/route_draft_state_test.dart`

### Phase 2: UI + journey regression

- **Goal**: visible route flow reproduces and protects the fix
- [x] `test/widget/map_screen_route_sheet_test.dart` - TDD: `Out and Back` enabled on valid straight-line draft, no false disable on clean draft
- [x] `test/robot/map/map_route_robot.dart` - add/keep stable helper for `Out and Back` click if needed
- [x] `test/robot/map/map_route_journey_test.dart` - TDD: build straight-line route, tap `Out and Back`, save route, no inconsistency error
- [x] Verify: `flutter analyze` && `flutter test test/widget/map_screen_route_sheet_test.dart test/robot/map/map_route_journey_test.dart`

## Risks / Out of scope

- **Risks**: fixing one straight-line path while leaving another edit path desynced
- **Risks**: full repo `flutter test` still has unrelated robot/provider failures outside this route slice
- **Out of scope**: planner changes, snap-to-trail behavior changes, new route modes
