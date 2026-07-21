---
type: Work Item
title: Flutter Local Topo Contract And Max Zoom 16
parent: ../spec.md
---

## What to build
Update the app-owned `Local Topo` basemap integration so the Flutter app keeps consuming the same HTTP `XYZ` `Local Topo` contract while capping app-owned metadata at `maxZoom: 16`. This slice must preserve `Local Topo` as the single user-facing basemap label, keep runtime URL resolution rooted in the validated base URL plus the capability-advertised Tasmania path `/tasmania/local-topo/{z}/{x}/{y}.png`, and add explicit app-side enforcement so `Local Topo` does not issue native `z17+` tile requests even when the user interactively zooms beyond `z16`.

## Required context
- `tool/generate_region_manifest_catalog.dart` is the authoritative source for generated app-owned basemap metadata, and `lib/generated/region_manifest_catalog.g.dart` plus `lib/services/region_manifest_catalog.dart` are the current runtime source of truth.
- `lib/services/local_topo_runtime.dart`, `lib/screens/map_screen_layers.dart`, `lib/providers/local_topo_settings_provider.dart`, and `lib/widgets/map_basemaps_drawer.dart` already define the app's `Local Topo` runtime contract, selection flow, and availability seams. Reuse those seams instead of introducing a second basemap concept or a non-HTTP integration path.
- Existing Local Topo regression coverage and stable selectors already live in `test/services/local_topo_runtime_test.dart`, `test/providers/local_topo_settings_provider_test.dart`, `test/widget/local_topo_settings_screen_test.dart`, `test/widget/map_basemaps_drawer_test.dart`, and `test/robot/map/basemap_selection_journey_test.dart`.

## Acceptance criteria
- [x] The app-owned `Local Topo` basemap metadata is updated to `maxZoom: 16`, while `Local Topo` remains labeled exactly `Local Topo` and remains an HTTP-based raster `XYZ` basemap from the app's perspective.
- [x] The Flutter app continues to resolve `Local Topo` tile URLs from the validated `Local tile server base URL` plus the capability-advertised relative tile path, with Tasmania still addressed as `/tasmania/local-topo/{z}/{x}/{y}.png`.
- [x] When `Local Topo` is selected, the app does not issue native `z17+` `Local Topo` tile requests; interactive zoom above `z16` overzooms the highest supported `Local Topo` tiles instead of requesting unsupported higher native zooms.
- [x] This slice does not add direct device-file tile reading, embedded `MBTiles`, direct `PMTiles` reading, capability-schema max-zoom advertising, or a second user-facing basemap entry for pre-rendered delivery.
- [x] Deterministic app-side regression coverage proves the shared HTTP contract stays unchanged, `Local Topo` metadata now caps at `maxZoom: 16`, and `Local Topo` does not issue native `z17+` tile requests.
- [x] The existing configure-and-select `Local Topo` app journey still works through fake capability and tile seams without the app needing to know whether the backend is serving static or on-demand tiles, and any robot coverage keeps using stable selectors.

## Covers
- User Stories: 1, 4
- Requirements: 1-3, 7
- Technical Decisions: 1-4
- Testing Strategy: 3-4
- Interview Ledger: L1-L5

## Blocked by
None - ready to start
