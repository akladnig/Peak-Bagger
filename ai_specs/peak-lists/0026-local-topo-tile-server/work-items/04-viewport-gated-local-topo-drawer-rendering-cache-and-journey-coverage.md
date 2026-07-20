---
type: Work Item
title: Viewport Gated Local Topo Drawer Rendering Cache And Journey Coverage
parent: ../spec.md
---

## What to build
Finish the end-to-end `Local Topo` app behavior by surfacing one logical `Local Topo` basemap entry only when the current visible bounds intersect accepted supported regions, routing live tile requests and manual tile-cache flows through the shared runtime contract, excluding `Local Topo` from automatic startup low-zoom warmup, preserving the current selection through temporary tile outages, and adding deterministic widget plus robot coverage for the Tasmania configure-and-select journey.

## Required context
- `lib/widgets/map_basemaps_drawer.dart` already uses the stable selector pattern `Key('basemap-option-<key>')`; preserve that pattern for `Local Topo` rather than inventing a new basemap-option key shape.
- `lib/providers/map_provider.dart` already tracks `visibleBounds`, and `lib/services/region_manifest_catalog.dart` already exposes `regionsForBounds(...)`. Reuse those viewport-oriented seams for `Local Topo` availability instead of the current point-scoped `cursorPoint ?? center` basemap decision path.
- `lib/screens/map_screen_layers.dart` and `lib/services/tile_cache_service.dart` are the shared map-rendering and cache-path consumers that must both resolve `Local Topo` through the same runtime contract.
- `lib/screens/settings_screen.dart` currently renders the tile-cache basemap chips from `TileCacheService.availableBasemaps`; this slice should apply the `Local Topo` hide or disable rule there until a last successful capability snapshot exists.
- Existing tests already cover the basemap drawer, tile-cache settings, and robot basemap selection flows, including stable selectors under `test/widget/map_basemaps_drawer_test.dart`, `test/widget/tile_cache_settings_screen_test.dart`, and `test/robot/map/basemap_selection_journey_test.dart`.

## Acceptance criteria
- [x] The basemap drawer shows one logical `Local Topo` entry only when the current visible map bounds intersect at least one supported `Local Topo` region from the accepted capability snapshot, and v1 does not show a disabled `Local Topo` row when unsupported.
- [x] The `Local Topo` drawer-availability decision uses viewport-region intersection for this app-owned basemap path rather than a single cursor-point or map-center lookup, while existing manifest-backed basemap availability rules remain unchanged unless needed to support this slice.
- [x] The effective runtime tile URL for `Local Topo` resolves from the validated or restored base URL plus the capability-advertised relative tile path template, including the Tasmania route shape `/tasmania/local-topo/{z}/{x}/{y}.png`.
- [x] Map rendering, manual tile-cache download flows, and any browse or download URL transformation used by the tile-cache stack for `Local Topo` all use the same shared resolved runtime contract instead of the checked-in placeholder catalog URL.
- [x] `Local Topo` participates in the existing basemap-specific tile-cache architecture for manual cache management after a successful capability snapshot exists, but it is excluded from automatic startup low-zoom warmup.
- [x] Tile-cache Settings hides or disables `Local Topo` until a last successful capability snapshot exists for the currently saved `Local tile server base URL`, and manual cache download or clear flows become available only after that successful snapshot exists.
- [x] If the accepted capability response does not advertise support for any region intersecting the current visible bounds, `Local Topo` stays hidden in the drawer; if `Local Topo` is currently selected when clearing, failed revalidation, or accepted-capability region removal invalidates support, the app immediately falls back to `Tracestrack Topo`.
- [x] A viewport change caused only by panning or zooming hides `Local Topo` from the drawer when unsupported for the new viewport, but it does not auto-switch the active basemap by itself.
- [x] If the user has selected `Local Topo` and later tile requests fail, time out, or return temporary server errors while the validated or restored contract remains in place, the app does not crash and does not automatically switch to another basemap.
- [x] Deterministic widget and robot coverage proves the Tasmania flow: configure a valid local tile server URL, validate successfully, open the basemap drawer on a viewport intersecting supported Tasmania coverage, select `Local Topo`, and complete the normal basemap-selection path without live secrets or live LAN dependencies.

## Covers
- User Stories: 1-2, 4
- Requirements: 11-14, 23-25
- Technical Decisions: 1-3, 6-7
- Testing Strategy: 3-4, 6-8
- Interview Ledger: L1, L3-L4, L8-L10

## Blocked by
- 02-app-local-topo-contract-persistence-and-runtime-url-resolver.md
- 03-settings-validation-flow-and-safe-fallback-behavior.md
