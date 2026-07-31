---
type: Work Item
title: Edit Save And Save As Route Copy Flow
parent: ../spec.md
---

## What to build

Implement the edit-session `Save` versus `Save As` contract as one vertical Flutter slice through route-sheet UI, provider state, persistence, and regression coverage. During an edit session, show `Save As` beside `Save`, keep ordinary `Save` as update-in-place on the current `sourceRouteId`, and add the distinct `Save As` prompt and duplicate-name validation flow with the exact Spec copy and success behavior. In the same slice, preserve `desc` and `walkingSpeedKmh` on interactive edit save unless the workflow explicitly changes them, and round saved route geometry plus editor-created semantic waypoint coordinates to six decimal places.

## Required context

- `lib/widgets/map_route_bottom_sheet.dart` owns the route-sheet controls, prompt launching, visible button order, and exact route-name validation copy.
- `lib/providers/map_provider.dart` owns edit-session state, `sourceRouteId`, save behavior, selected-route handoff, and production `MapNotifier` save seams.
- `lib/models/route.dart`, `lib/models/route_waypoint.dart`, and `lib/services/route_repository.dart` define persisted route data and coordinate serialization points.
- `test/providers/map_provider_selected_route_test.dart`, `test/providers/route_draft_state_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, and `test/robot/map/map_route_journey_test.dart` are the main deterministic seams for save behavior, route selection, route-sheet UI, and visible route journeys.
- `test/harness/test_map_notifier.dart` is not sufficient by itself for this slice; the Spec requires repository-backed production `MapNotifier` coverage for save-preservation behavior.

## Acceptance criteria

- [ ] Behavior-first TDD starts with failing provider or service coverage for ordinary `Save`, `Save As`, duplicate-name validation, preserved `desc` and `walkingSpeedKmh`, and six-decimal coordinate persistence before production code changes are made.
- [ ] During an edit session, the route sheet shows `Save As` beside `Save`, seeds the prompt from the current draft name, trims submitted names before validation and persistence, rejects blank trimmed names with the exact copy `A Route name must be entered`, rejects case-insensitive trimmed duplicates with the exact inline copy `A route with this name already exists`, keeps the prompt open on validation failure, and lets cancel close the prompt without changing the active edit session.
- [ ] Ordinary `Save` updates the current `sourceRouteId` in place, while successful `Save As` leaves the original source route unchanged, closes the draft, and selects the newly saved route copy.
- [ ] Interactive edit save preserves `desc` and `walkingSpeedKmh` from the source `Route` unless the current edit workflow explicitly changes those fields, without adding new editor controls for either field.
- [ ] Saving route geometry and any semantic waypoint coordinates created by the editor rounds latitude and longitude to six decimal places.
- [ ] Widget or robot coverage for the changed user-visible save flows uses stable app-owned selectors and deterministic repository, planner, and elevation seams.

## Covers

- User Stories: 1-2
- Requirements: 3-5, 10
- Technical Decisions: 2, 4
- Testing Strategy: 1-2, 5, 7
- Interview Ledger: L1, L2, L6

## Blocked by

- `01-route-rule-artifact-alignment-and-legacy-doc-conflict-cleanup.md`
