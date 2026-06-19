---
title: Slovenia Topo Proxy and Basemap Key Rename
date: 2026-06-16
work_type: feature
tags: [flutter, flutter_map, proxy, wms, caching]
confidence: high
references: [assets/region_manifest.json, lib/generated/region_manifest_catalog.g.dart, lib/screens/map_screen_layers.dart, lib/services/tile_cache_service.dart, proxy/slovenia-topo-proxy/lib/src/tile_handler.dart, proxy/slovenia-topo-proxy/lib/src/upstream_wms_client.dart, test/unit/region_manifest_catalog_test.dart, test/widget/map_basemaps_drawer_test.dart, test/robot/map/basemap_selection_journey_test.dart, ai_specs/map-screen/slovenia-topo-proxy-plan.md]
---

## Summary

Delivered a Slovenia topo basemap path through a dedicated XYZ proxy while keeping the app on the existing FMTC tile caching flow. The proxy hides the upstream WMS complexity, and the app-facing basemap key was renamed from `sloveniaOrtofoto` to `sloveniaTopo` with generated catalog and tests updated.

## Reusable Insights

- Keep the Flutter app on a normal `TileLayer` plus FMTC caching when the remote source is a WMS; move XYZ-to-WMS translation into a small proxy instead of special-casing the app.
- If the upstream WMS has different useful layers by zoom, select the layer in the proxy, not in the UI. That keeps the app contract stable.
- Transient upstream failures are common under viewport fan-out. A small retry/backoff policy plus a concurrency cap can turn noisy `502` bursts into a usable service.
- Basemap key renames are schema changes, not just string edits. Update the manifest, regenerate the catalog, and touch every selector test that encodes the key.
- When a basemap should not be part of global warmup, exclude it explicitly in the cache service instead of weakening the cache layer itself.

## Decisions

- App-facing URL stays at `https://tiles.peakbagger.com/slovenia-topo/{z}/{x}/{y}.png`.
- Upstream WMS stays at `https://storitve.eprostor.gov.si/ows-pub-wms/wms`.
- `SI.GURS.DK:DTK50` was the higher-zoom layer that worked reliably.

## Validation

- Proxy tests covered projection math, WMS URL building, zoom-layer selection, and recovery from transient `500`/timeout failures.
- App tests were updated for the renamed basemap key in the manifest catalog, tile cache service, drawer UI, and robot journey.
