---
title: Friuli Venezia Giulia Topo Coverage and Proxy Progress
date: 2026-06-20
work_type: bugfix
tags: [flutter, proxy, maps, coverage, wms]
confidence: medium
references: [assets/region_manifest.json, assets/polygons/friuli-venezia-giulia-mainland.poly, assets/polygons/friuli-venezia-giulia-islet.poly, lib/services/region_manifest_catalog.dart, lib/screens/map_screen.dart, lib/widgets/map_basemaps_drawer.dart, lib/screens/map_screen_layers.dart, lib/services/tile_cache_service.dart, lib/services/peak_list_visibility.dart, tool/generate_region_manifest_catalog.dart, proxy/fvg-topo-proxy]
---

## Summary

Added a Friuli Venezia Giulia-specific topo basemap slice without widening the `italy-nord-est` region key. The app now resolves basemap visibility from point-scoped coverage polygons, the manifest/catalog generator preserves that metadata, and a standalone FVG proxy package was added for the WMS-backed tile flow.

## Current Progress

- Official ISTAT-derived FVG coverage polygons were added for mainland and islet areas.
- `fvgTopo` was added to the region manifest with coverage-based visibility.
- Basemap resolution now snapshots the point under the map cursor/center so the drawer stays stable while open.
- The app keeps the existing `italy-nord-est` peak/list behavior intact through a canonical alias.
- A new `proxy/fvg-topo-proxy` package exists with zoom-routed layer selection and XYZ tile handling.
- Low-zoom warmup excludes `Basemap.fvgTopo`.

## Verified

- `flutter test test/unit/region_manifest_catalog_test.dart test/widget/map_basemaps_drawer_test.dart test/unit/tile_cache_service_test.dart`
- `flutter analyze lib test tool`
- `dart test` in `proxy/fvg-topo-proxy`

## Blocker

- Live `GetCapabilities` verification against `https://serviziogc.regione.fvg.it/geoserver/CARTOGRAFIA/wms` still times out from this workspace.

## Follow-up

- Confirm the live FVG WMS capabilities when network access is available, then adjust the proxy zoom/layer mapping only if needed.
