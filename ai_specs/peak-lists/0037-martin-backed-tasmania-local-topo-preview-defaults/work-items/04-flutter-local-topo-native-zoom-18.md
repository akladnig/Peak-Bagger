---
type: Work Item
title: Flutter Local Topo Native Zoom 18
parent: ../spec.md
---

## What to build
Update the existing Flutter `Local Topo` basemap contract so the app-owned `Local Topo` basemap entry can request native Tasmania `z17` and `z18` tiles through the unchanged local tile server route `/tasmania/local-topo/{z}/{x}/{y}.png` and unchanged `GET /capabilities` contract, while leaving the current basemap drawer choices and labels unchanged. This slice must keep `Local Topo` as the existing basemap entry, must not add a new basemap drawer choice such as `Local Topo Legacy`, and must preserve the current basemap selection flow while changing the app-owned native zoom cap from exactly `16` to exactly `18`.

## Required context
- Existing app-owned Local Topo seams already live in `tool/generate_region_manifest_catalog.dart`, `lib/generated/region_manifest_catalog.g.dart`, `lib/services/region_manifest_catalog.dart`, `lib/services/local_topo_runtime.dart`, `lib/screens/map_screen_layers.dart`, and related tests such as `test/unit/region_manifest_catalog_test.dart` and `test/services/local_topo_runtime_test.dart`.
- Reuse the existing stable `Local Topo` basemap selectors and journey coverage conventions in `test/robot/map/basemap_selection_journey_test.dart`, `test/widget/map_basemaps_drawer_test.dart`, and `test/widget/local_topo_settings_screen_test.dart` if UI journey coverage is touched.
- Follow the existing app basemap metadata seam established by earlier Local Topo work rather than introducing runtime negotiation through `GET /capabilities` for native zoom limits.

## Acceptance criteria
- [x] The app-owned `Local Topo` native zoom cap for Tasmania changes from exactly `16` to exactly `18` at the existing app-owned basemap metadata seam.
- [x] The existing `Local Topo` basemap entry continues to request tiles through the unchanged route `/tasmania/local-topo/{z}/{x}/{y}.png` and unchanged `GET /capabilities` contract.
- [x] `GET /capabilities` remains unchanged in this slice and does not become the source of truth for native zoom limits.
- [x] The current Flutter basemap drawer choices and labels remain unchanged in this slice.
- [x] This slice does not expose a separate `Local Topo Legacy` drawer choice and does not change the basemap selection flow.
- [x] Deterministic Flutter Dart coverage proves the existing `Local Topo` basemap can request native Tasmania `z17` and `z18` tiles through the unchanged capabilities contract without changing drawer labels or basemap selection flow.
- [x] Deterministic tests at the existing app-owned basemap metadata seam prove the native zoom cap changes from exactly `16` to exactly `18`.
- [x] If UI journey coverage is touched, it reuses the existing stable `Local Topo` basemap selectors.

## Covers
- User Stories: 4
- Requirements: 2, 7-8, 24
- Technical Decisions: 1, 8
- Testing Strategy: 8
- Interview Ledger: L2, L5, L14

## Blocked by
None - ready to start
