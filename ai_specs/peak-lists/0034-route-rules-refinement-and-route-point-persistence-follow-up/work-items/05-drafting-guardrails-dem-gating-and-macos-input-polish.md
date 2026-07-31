---
type: Work Item
title: Drafting Guardrails Dem Gating And Macos Input Polish
parent: ../spec.md
---

## What to build

Update route-drafting guardrails and macOS-specific interaction polish as one vertical Flutter slice across provider logic, elevation sampling seams, route-sheet and keyboard behavior, and regression coverage. Make duplicate endpoint taps a no-op without entering `segmentFailure`, replace the visible ninety-nine-marker hard stop with wrapped `number mod 100` labels over an unbounded internal sequence, gate route-draft elevation sampling on current Tasmania DEM availability, and remove `Ctrl+Z` and `Ctrl+Shift+Z` while preserving `Cmd+Z` and `Cmd+Shift+Z`.

## Required context

- `lib/providers/map_provider.dart` owns duplicate-point handling, marker numbering state, undo and redo shortcuts, and route-draft elevation sampling triggers.
- `lib/services/route_elevation_sampler.dart` and any DEM-region helper seams determine when elevation requests should run and when distance-only behavior should remain active.
- `lib/widgets/map_route_bottom_sheet.dart` and `lib/screens/map_screen.dart` expose the visible draft controls and desktop shortcut wiring.
- `test/providers/route_draft_state_test.dart`, `test/services/route_elevation_sampler_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/map_screen_keyboard_test.dart`, and `test/robot/map/map_route_journey_test.dart` are the main seams for duplicate-point, DEM-gating, marker-limit, and macOS-input coverage.
- Existing deterministic elevation fakes and repository-backed route harnesses should be reused instead of introducing live DEM dependencies.

## Acceptance criteria

- [x] Behavior-first TDD starts with failing provider, service, or widget coverage for duplicate-point no-op behavior, wrapped marker labels beyond ninety-nine visible intermediates, DEM-aware elevation request gating, and macOS-only shortcut behavior before implementation changes are made.
- [x] If the user taps the same effective next point as the current end point, the draft remains unchanged and does not enter `segmentFailure`.
- [x] Visible numbered intermediate marker labels display `number mod 100`, while internal point ordering and numbering continue increasing without truncating the underlying route definition.
- [x] The route editor issues route-draft elevation sampling requests only when the drafted route is fully inside the current Tasmania DEM-supported region model; when the route is outside coverage, it avoids the request, does not surface an elevation error for that case, and keeps the existing distance-only draft behavior.
- [x] Route-drafting shortcuts remove `Ctrl+Z` and `Ctrl+Shift+Z` while preserving `Cmd+Z` and `Cmd+Shift+Z` behavior.
- [x] Widget or robot coverage for the changed user-visible draft behavior uses stable selectors and deterministic elevation seams.

## Covers

- User Stories: 6-8
- Requirements: 13-15, 17
- Technical Decisions: 5-6
- Testing Strategy: 1-2, 4-5
- Interview Ledger: L6-L8

## Blocked by

- `01-route-rule-artifact-alignment-and-legacy-doc-conflict-cleanup.md`
