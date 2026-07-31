---
type: Work Item
title: Trail Aware Loop Closure And Drag Rerouting
parent: ../spec.md
---

## What to build

Extend the route-planner and draft-edit seams as one vertical Flutter slice so `Close Loop` first attempts the current routed return to the start, then falls back to the closest usable track reconnection, then falls back to a direct straight closing segment, and dragging a trail-backed route point onto a new trail reroutes through the moved point using the new trail context. Cover the visible loop-closing journey with deterministic planner fakes, stable selectors, and production route-draft behavior rather than test-only shortcuts.

## Required context

- `lib/providers/map_provider.dart` owns `Close Loop`, drag rebuild behavior, and the public route-draft action seams used by widget and robot tests.
- `lib/services/route_planner.dart` and related routing seams define routed, fallback, and failure outcomes that this slice must extend rather than bypass.
- `lib/screens/map_screen.dart`, `lib/screens/map_screen_layers.dart`, and `lib/widgets/map_route_bottom_sheet.dart` define the visible loop-closing and drag interaction surfaces.
- `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_route_hover_test.dart`, and `test/robot/map/map_route_journey_test.dart` are the main seams for routed closure, fallback ordering, drag rerouting, and the visible user journey.
- Reuse existing deterministic planner fakes, route repository seams, and robot selectors rather than introducing live routing dependencies.

## Acceptance criteria

- [ ] Behavior-first TDD starts with failing provider or service coverage for routed loop closure, closest-usable-track fallback, straight-line closing fallback, and trail-backed drag rerouting before implementation changes are made.
- [ ] `Close Loop` first attempts the normal routed end-to-start close; if that does not produce a usable tracked close, it next attempts to find the closest usable track connection and route along track geometry back to the start point; if that also fails, it falls back to a direct straight closing segment.
- [ ] Dragging any route point that is currently on a trail to a new trail reroutes through the moved point using the new trail context instead of preserving the old trail segment unchanged.
- [ ] The changed loop-closing journey is covered by widget or robot tests using stable app-owned selectors and deterministic planner fakes.
- [ ] Existing route-planner, elevation, and repository seams are reused so the slice does not depend on live external services.

## Covers

- User Stories: 9
- Requirements: 18-19
- Technical Decisions: 2, 7
- Testing Strategy: 1-2, 5-6
- Interview Ledger: L9, L11

## Blocked by

- `04-full-saved-geometry-rehydration-and-map-profile-edit-targeting.md`
