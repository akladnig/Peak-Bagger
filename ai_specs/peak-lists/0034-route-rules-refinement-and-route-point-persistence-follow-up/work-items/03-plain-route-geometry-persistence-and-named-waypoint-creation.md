---
type: Work Item
title: Plain Route Geometry Persistence And Named Waypoint Creation
parent: ../spec.md
---

## What to build

Separate plain saved route geometry from semantic saved waypoints as one vertical Flutter slice across model, repository, provider, route-point popup UI, and regression coverage. Stop persisting generic unnamed intermediate draft points as saved `RouteWaypoint` records, treat legacy generic `Waypoint N` entries as plain route points when reopening and on next interactive save, and add explicit named waypoint creation through `Create Waypoint` above `Delete` with the exact prompt behavior from the Spec. In the same slice, reconcile `Out and Back` and `Close Loop` with the new contract so they do not auto-create generic semantic turnaround or loop waypoints, while peak-derived points continue to persist under the existing semantic-waypoint rules.

## Required context

- `lib/models/route.dart` and `lib/models/route_waypoint.dart` are the persistence boundary for plain route geometry versus semantic saved waypoints.
- `lib/providers/map_provider.dart` owns save payload construction, legacy route reopen behavior, and the point-action menu flow.
- `lib/widgets/map_route_bottom_sheet.dart` and the route-point popup code in `lib/screens/map_screen_panels.dart` define the user-visible point actions and prompt ordering.
- `lib/services/route_repository.dart` and `lib/services/gpx_export_service.dart` are the downstream consumers most likely to surface persistence regressions if plain points and semantic waypoints are not kept distinct.
- `test/providers/route_draft_state_test.dart`, `test/providers/map_provider_selected_route_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, `test/widget/route_marker_layer_test.dart`, and `test/robot/map/map_route_journey_test.dart` provide the main seams for repository-backed save behavior, popup ordering, marker rendering, and visible named-waypoint journeys.

## Acceptance criteria

- [x] Behavior-first TDD starts with failing repository-backed provider or service coverage for unnamed-intermediate non-persistence, legacy generic `Waypoint N` reopen and next-save conversion, and the explicit named-waypoint creation path before implementation changes are made.
- [x] Interactive save persists generic unnamed intermediate draft points only as plain route geometry in `gpxRoute` and any derived geometry caches, not as semantic saved `RouteWaypoint` records.
- [x] Existing saved generic `Waypoint N` entries reopen as plain route points in the editor and stop re-persisting as semantic saved waypoints on the next interactive save unless the user explicitly converts a point through `Create Waypoint`.
- [x] Clicking a route point still opens the point popup, the popup adds `Create Waypoint` above `Delete`, `Create Waypoint` opens a naming prompt immediately, submitted names are trimmed before save, blank trimmed names are rejected, cancel leaves the point as a plain route point, and duplicate waypoint names within the same route remain allowed.
- [x] Named waypoints render with `Icons.location_pin` and save as semantic waypoints distinct from plain route geometry.
- [x] `Out and Back` and `Close Loop` do not auto-create generic semantic turnaround or loop waypoints; peak-derived points remain persistable semantic waypoints under the existing peak-derived rules.
- [x] Widget or robot coverage for the changed popup and waypoint journeys uses stable app-owned selectors and deterministic seams.

## Covers

- User Stories: 3, 5
- Requirements: 6-7, 11-12, 20, 22
- Technical Decisions: 2-3, 8
- Testing Strategy: 1-2, 4-5, 7
- Interview Ledger: L3, L5, L10

## Blocked by

- `01-route-rule-artifact-alignment-and-legacy-doc-conflict-cleanup.md`
- `02-edit-save-and-save-as-route-copy-flow.md`
