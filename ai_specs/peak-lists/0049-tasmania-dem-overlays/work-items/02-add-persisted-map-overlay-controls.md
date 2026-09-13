---
type: Work Item
title: Add Persisted Map Overlay Controls
parent: ../spec.md
---

## What to build

Deliver the normal standalone-overlay journey through the Flutter map: accept and persist v1 and v2 Local Topo capability snapshots, persist independent enabled and opacity settings, expose the exact `Overlays` drawer controls, and compose non-cacheable standalone layers only when Tasmania is eligible. Keep relief below contours and both below all app-owned map content.

The drawer must use its fixed cursor-or-centre and visible-bounds snapshot behavior. Show `Overlays` only when the point is in Tasmania, visible bounds intersect Tasmania, and the validated v2 Local tile server capability has at least one usable Tasmania overlay declaration. The live map must independently remove layers and stop tile requests outside that same Tasmania point-and-bounds eligibility without clearing preferences or changing the selected basemap.

## Required context

- `lib/services/local_topo_runtime.dart`, `lib/providers/local_topo_settings_provider.dart`, and `test/services/local_topo_runtime_test.dart` define Local Topo capabilities, snapshot persistence, validation, and injectable `SharedPreferences` conventions.
- `lib/services/region_manifest_catalog.dart`, `lib/screens/map_screen.dart`, and `lib/screens/map_screen_layers.dart` provide `basemapsForDrawer`, `isLocalTopoAvailableForBounds`, the drawer snapshot, map composition, and disabled cache behavior.
- `lib/widgets/map_basemaps_drawer.dart`, `test/widget/map_basemaps_drawer_test.dart`, and `test/robot/map/basemap_selection_journey_test.dart` define the visible control and stable-selector conventions.
- `pubspec.yaml` already provides `flutter_map`, Riverpod, and `shared_preferences`; no dependency change is expected.

## Acceptance criteria

- [x] `LocalTopoCapabilitySnapshot` accepts the existing v1 Local Topo-only contract and represents it as no overlays. A v2 snapshot persists an optional `overlays` list beside its existing regions, while a stored v1 snapshot without `overlays` remains valid. Changing or clearing the Local tile server base URL clears the full capability snapshot.
- [x] V2 parsing accepts declarations only with the exact pairs `terrainReliefShading` / `Terrain relief shading` and `contourLines` / `Contour lines`. It discards an individually malformed declaration while retaining valid overlays and `localTopo` for external URLs, query strings, fragments, malformed templates, unsupported keys, unknown manifest region keys, or an incorrect label; a duplicate accepted key or duplicate region declaration invalidates that entire overlay key while retaining unrelated valid overlays and `localTopo`.
- [x] A small persisted Riverpod settings state, with an injectable `SharedPreferences` loader, holds both enabled values and both integer opacity values. Enabled values default off; relief defaults to 35% and contours to 70%; all values persist independently and a persistence failure retains the prior valid in-memory value.
- [x] `MapBasemapsDrawer` places an `Overlays` section below `Basemaps` with independently toggleable `Terrain relief shading` and `Contour lines` controls. Switch changes update the map immediately and leave the drawer open. If a validated v2 snapshot has no usable Tasmania declaration for one key, its visible control is disabled and shows `Unavailable from the local tile server`.
- [x] Each enabled and currently available standalone overlay displays an `Opacity` control with a 0% through 100% slider in 5% increments and a direct integer percentage entry field. Blank, non-numeric, or out-of-range input reverts to its prior valid value on focus loss.
- [x] Selecting `Local Topo` does not draw either standalone overlay, leaves stored switches and opacities unchanged, disables both switches with `Included in Local Topo`, and hides both standalone `Opacity` controls. Selecting another eligible Tasmania basemap restores the stored choices.
- [x] Standalone `TileLayer` instances are built independently of `buildBasemapTileLayer`, resolve only validated Local tile server relative templates, and have app tile-cache integration disabled. When active, order is basemap, Terrain relief shading, Contour lines, then trails, routes, tracks, peaks, markers, grids, and other app-owned map content.
- [ ] Dart unit and provider tests use Local Topo runtime snapshot fixtures and mocked `SharedPreferences` to cover v1/v2 parsing, stored restore, all required declaration rejection and duplicate behavior, base-URL invalidation, eligibility, non-cacheable URL resolution, defaults, restoration, slider/direct-entry persistence, invalid-entry reversion, and persistence failure.
- [ ] Widget tests use stable keys for the `Overlays` section, both switches, and both opacity controls, and cover v1 hidden state, partial v2 unavailability, `Local Topo` included states, hidden opacity, and relief-before-contours ordering.
- [ ] The map basemap robot journey uses a validated Tasmania v2 fixture and stable selectors to verify selecting `TasMap 25K`, independently enabling both overlays, changing opacity, selecting `Local Topo` without duplicate layers, restoring choices on another Tasmania basemap, and removing layers outside Tasmania without clearing choices.
- [ ] Desktop and mobile drawer layouts are manually inspected at enlarged text scale so labels, switches, sliders, and integer fields remain reachable and readable.
- [ ] `flutter analyze` and `flutter test` pass.

## Covers

- User Stories: 1-3
- Requirements: 1-11 except 6
- Technical Decisions: 2-6
- Testing Strategy: 1, 3-6, 8-9
- Interview Ledger: L1-L7, L9-L12

## Blocked by

None - ready to start
