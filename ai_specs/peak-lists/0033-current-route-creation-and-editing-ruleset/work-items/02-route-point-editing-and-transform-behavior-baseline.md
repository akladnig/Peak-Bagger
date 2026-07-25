---
type: Work Item
title: Route Point Editing And Transform Behavior Baseline
parent: ../spec.md
---

## What to build

Extend `ai_specs/routes/route-rules.md` so the `Current Behavior Baseline` captures the exact current rules for route-point classes, interactive editing, and route transforms during map drafting and editing. Document how `Hover point`, `Numbered route point`, `Plain route point`, and `Waypoint` behave today; current tap-to-add behavior; duplicate-point failure behavior; current marker-limit behavior including `Peak Bagger only supports a maximum of 99 route points` if the visible limit contract is recorded; segment insertion from hover preview; drag-to-move behavior; delete behavior; current route-point class changes when points are moved, inserted, or rebuilt; desktop hover and click-to-insert and drag-threshold behavior; keyboard undo and redo behavior; dismiss-priority `Escape` behavior where it affects route drafting or surrounding UI; and the exact current `Straight Line`, `Snap to Trail`, `Route to Peak`, `Out and Back`, and `Close Loop` affordances, enablement, disablement, and fallback behavior.

## Required context

- `lib/providers/map_provider.dart` contains the route-draft editing state machine, history snapshots, marker drag and delete behavior, duplicate-point and limit handling, and mode transforms including `Out and Back` and `Close Loop`.
- `lib/screens/map_screen.dart` and `lib/screens/map_screen_layers.dart` define the current desktop hover preview, click and drag plumbing, marker thresholds, and route-segment insertion affordances.
- `lib/widgets/map_route_bottom_sheet.dart` defines the exact current route-mode controls, undo and redo controls, tooltips, and enabled or disabled behavior for `Straight Line`, `Snap to Trail`, `Route to Peak`, `Out and Back`, and `Close Loop`.
- `ai_docs/solutions/feature-delivery/route-edit-in-place.md` summarizes the shipped provider-led editing model, history semantics, drag intent split, and stable-selector expectations that explain why current behavior works the way it does.
- `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_route_draft_hover_test.dart`, `test/widget/map_screen_route_hover_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_keyboard_test.dart`, `test/widget/route_marker_layer_test.dart`, and `test/robot/map/map_route_journey_test.dart` are the authoritative deterministic seams for subtle hover, insert, drag, delete, undo or redo, `Escape`, and transform behavior.

## Acceptance criteria

- [x] The baseline clearly distinguishes `Hover point`, `Numbered route point`, `Plain route point`, and `Waypoint` using the agreed canonical meanings while still describing the current implementation exactly as it behaves today.
- [x] The baseline documents current route-point interaction behavior for add, duplicate rejection, marker-limit handling, hover insertion, drag-to-move, delete, and current route-point-class transitions after move, insert, and rebuild paths.
- [x] The baseline captures current desktop input-specific behavior, including hover preview, click-to-insert, drag thresholds, keyboard undo and redo behavior, and dismiss-priority `Escape` behavior where it affects route drafting or surrounding UI surfaces.
- [x] The baseline documents the current `Straight Line`, `Snap to Trail`, `Route to Peak`, `Out and Back`, and `Close Loop` controls, including visible affordances, enable and disable conditions, and current off-track, no-path, and route-graph-load fallback behavior.
- [x] Any quoted visible error or helper text preserved by this slice matches the implemented text exactly.
- [x] The documented behavior is evidenced against existing deterministic provider, widget, and robot seams rather than inferred only from casual UI inspection.

## Covers

- User Stories: 1-2, 4
- Requirements: 1-2, 4, 6-7, 11-13, 16
- Technical Decisions: 1-2, 5
- Testing Strategy: 1-3
- Interview Ledger: L1-L4, L6-L7, L10

## Blocked by

- `01-route-rules-artifact-skeleton-and-draft-lifecycle-baseline.md`
