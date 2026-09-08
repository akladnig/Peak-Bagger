---
type: Work Item
title: Deliver Coverage-Aware Map Routing and Driving Time
parent: ../spec.md
---

## What to build

Apply persisted coverage selection to graph-backed Snap to Trail, Route to Peak, loop closure, local road-hit driving-time actions, and trail overlays. Preserve route drafts, existing Straight Line behavior, and OpenRouteService driving distance/duration while enforcing the exact coverage-specific loading, failed, ready-to-Retry, and outside-coverage behavior.

Extend map state, widgets, semantics, responsive layout, and robot journeys so valid segments in one multi-point draft may independently use different coverages while no individual segment or loop closure crosses coverage boundaries.

## Required context

- Keep existing planner fallback and draft behavior in `lib/providers/map_provider.dart`; coverage rejection must happen before ordinary off-track/no-path straight-line fallback.
- Update selection consumers in `lib/services/route_planner.dart`, `lib/services/route_graph_drive_eta_hit_service.dart`, `lib/services/route_graph_trail_service.dart`, `lib/providers/route_planner_provider.dart`, `lib/providers/drive_eta_provider.dart`, `lib/screens/map_screen.dart`, and route widgets.
- Preserve fake OpenRouteService and controlled planner seams. Robot conventions and stable keys are in `test/robot/routes/route_graph_robot.dart`, `test/robot/map/drive_eta_robot.dart`, and `test/robot/settings/route_graph_refresh_robot.dart`.

## Acceptance criteria

- [ ] A graph-backed route segment or loop closure proceeds only when each endpoint matches exactly one active coverage by inclusive active chunk bounds and both coverage keys are equal. A road target proceeds only when it matches exactly one active coverage. Use stored chunk bounds without an additional selection buffer; retain existing buffered viewport and route-payload queries after selection.
- [ ] A saved multi-point route may contain independently planned valid segments from different coverages, but cross-coverage or outside-coverage graph operations preserve the draft, append no segment, loop closure, or control endpoint, invoke neither the route planner nor reconnect probe, and do not use straight-line fallback. Existing off-track/no-path fallback remains only after a valid same-coverage graph request returns that result.
- [ ] When no active coverage selects the endpoints, unavailable footprints identify loading or failed feedback only when both endpoints each match exactly one identical unavailable coverage. Show exactly `Routing data for <coverage> is still loading.` while queued/importing and no active generation; show exactly `Routing data for <coverage> is unavailable. Use Refresh Route Graph to retry.` after failure with no active generation; otherwise show the exact outside-coverage route message specified by the existing route UI contract.
- [ ] When the loading coverage first becomes ready, retain the draft and replace feedback with exactly `Routing data for <coverage> is ready. Retry to plan this route.` and a `Retry` action. Retry is bound to operation type, original endpoints or peak target, and draft revision; draft edits invalidate it. Before a valid Retry plans, re-evaluate active eligibility and apply current feedback without invoking the planner or fallback when it fails.
- [ ] Resolve a road target's coverage before hit testing. Enable driving time only for exactly one active coverage; otherwise disable it with exactly `Routing data for <coverage> is still loading.`, exactly `Routing data for <coverage> is unavailable. Use Refresh Route Graph to retry.`, or exactly `Driving time is unavailable outside routing coverage.` Re-evaluate the bound target immediately before OpenRouteService; never request OpenRouteService after a failed recheck.
- [ ] Keep OpenRouteService as the only authority for driving distance and duration. Do not add local car-routing, speed, turn-restriction, access-time calculations, or change API-key behavior.
- [ ] Trail overlays render trail-display chunks from every ready active coverage intersecting the buffered viewport, omit coverages without an active generation, and continue rendering active generations through replacement imports/failures. Trail-overlay cache keys include ordered `(routingCoverageKey, activeGeneration, chunkKey)` values.
- [ ] Coverage status feedback, `Retry`, and enabled or disabled driving-time actions wrap without clipping and remain visible/operable at 360x800 logical pixels and 200% text scale. Semantics expose every coverage-status message and the reason a driving-time action is disabled.
- [ ] Test first with focused service and map-provider tests for matched-coverage routing, cross-boundary merged Northeast Alps routing, selection rejection, retry invalidation/recheck, road-target recheck, all-ready overlays, and fake OpenRouteService with no API key or real request. Add widget and robot coverage using stable keys and the coordinator's deterministic status/completion seam for draft preservation, loading/failure/outside feedback, ready-to-Retry without auto-replanning, distinct valid segment coverages, ready-coverage isolation, exact disabled-action messages, accessible responsive feedback, and partial refresh outcomes.

## Covers

- User Stories: 1-4
- Requirements: 1, 5-7
- Contract Clarifications: 3, 5, 7-9
- Technical Decisions: 3, 5, 6
- Testing Strategy: 3-7
- Interview Ledger: L1, L2, L4, L7, L8, L9

## Blocked by

02-coverage-graph-persistence-and-selection.md
03-coverage-import-coordination-and-refresh.md
