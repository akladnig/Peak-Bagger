---
type: Work Item
title: Enable Roads Search and Selection
parent: ../spec.md
---

## What to build

Wire the production named route-graph way search through Riverpod into `MapNotifier`, while allowing an injected fake in map-search tests. Enable the existing `Roads` control in `MapSearchPopup`, preserving its exact `Roads` label, vehicle icon, selector `map-search-entity-roads`, and entity-filter interaction/selected-state behavior. Complete exhaustive result-type handling for road icons and groups so road results expose the stable selector `map-search-result-road-<osmWayId>`.

Make selecting every Search popup result first clear selected peaks, selected track, selected route, selected map, and their associated popups. Selecting a Roads result must then close the Search popup, preserve the current zoom, center the map on the resolved midpoint, and set that point as the selected location. It must not create a persistent road highlight, road details popup, or saved object.

## Required context

- `lib/providers/map_provider.dart` contains `MapNotifier`, `MapState`, selection state, and existing optional service injection conventions. Add a capability to explicitly clear `selectedMap`; the current `copyWith` null semantics preserve it.
- `lib/providers/route_planner_provider.dart` exposes the optional `routeGraphQueryServiceProvider`; `lib/main.dart` contains production route-graph construction and overrides.
- `lib/widgets/map_search_popup.dart` already renders the disabled Roads control. `lib/widgets/map_search_results_list.dart` derives stable result selectors from result type and ID and has exhaustive icon/group switches.
- `lib/screens/map_screen.dart` dispatches Search popup result selection. Use the current visible-map camera zoom for Roads, not a fixed peak zoom.
- Existing widget tests use `ProviderScope` and `TestMapNotifier`; robot journeys use reusable actions in `test/robot/map/` and `*_journey_test.dart` files.

## Acceptance criteria

- [x] Production named route-graph way search is wired through Riverpod to `MapNotifier`; map-search tests can inject a deterministic fake without a real import, network call, external service dependency, or API key.
- [x] The existing `Roads` control is enabled and preserves its `Roads` label, vehicle icon, `map-search-entity-roads` selector, selected state, and interaction behavior alongside existing entity-filter controls.
- [x] Road results have complete icon and group handling and expose `map-search-result-road-<osmWayId>` as their stable result selector.
- [x] Selecting any Search popup result first clears selected peaks, selected track, selected route, selected map, and their associated popups.
- [x] Selecting a Roads result closes the Search popup, retains the current zoom, centers the map on the result midpoint, and sets that point as the selected location.
- [x] Selecting a Roads result does not create a persistent road highlight, road details popup, or saved object.
- [x] No active route-graph coverage leaves Roads enabled and uses the existing `No results found` empty state without beginning or retrying an import or introducing a Roads-specific loading or error UI.
- [x] Add widget or robot journey coverage using `map-search-entity-roads` and `map-search-result-road-<osmWayId>` that selects Roads, renders a result, and verifies selection clears prior search-result selection and associated popup, closes the popup, and centers the map at current zoom.
- [x] Add regression coverage that each existing Search popup result type also clears prior search-result selection and associated popup state.

## Covers

- User Stories: 1, 3
- Requirements: 1, 7, 9-10
- Technical Decisions: 2, 5-6
- Testing Strategy: 3, 5
- Interview Ledger: L1-L3, L6, L10

## Blocked by

02-compose-roads-search-results.md
