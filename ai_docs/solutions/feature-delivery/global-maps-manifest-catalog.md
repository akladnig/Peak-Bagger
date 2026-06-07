---
title: Global Maps Manifest Catalog
date: 2026-06-07
work_type: feature
tags: [flutter, maps, manifest, testing, codegen]
confidence: high
references: [ai_specs/global-maps-spec.md, ai_specs/global-maps-plan.md, assets/region_manifest.json, tool/generate_region_manifest_catalog.dart, lib/services/region_manifest_catalog.dart, lib/generated/region_manifest_catalog.g.dart, lib/screens/map_screen.dart, lib/screens/map_screen_layers.dart, lib/widgets/map_basemaps_drawer.dart, lib/services/tile_cache_service.dart, test/unit/region_manifest_catalog_test.dart, test/widget/map_basemaps_drawer_test.dart, test/robot/map/basemap_selection_journey_test.dart]
---

## Summary

Implemented a manifest-backed basemap catalog and region-filtered basemap drawer. The catalog is generated and checked in, which keeps runtime lookup simple while still letting malformed manifest input fail fast in generator/CI checks.

The main UI change was to move drawer-region awareness into `MapScreen`, then pass a snapshot into the basemap drawer so the available basemaps match the active route context. Tile-cache ordering was also aligned to `Basemap.values` so the store stays consistent with the catalog.

## Reusable Insights

- Keep generated catalog data as the runtime source of truth when the input is static-ish but still authored by humans. That avoids parsing the manifest during app startup while still making ordering and lookup deterministic.
- Preserve enum ordering explicitly when UI, persistence, and tests depend on it. In this case, `Basemap.values` became the contract for cache ordering and selection fallbacks.
- Pass a route-local snapshot into widgets when availability depends on the current screen state. That keeps the drawer pure and avoids duplicating region logic in the UI tree.
- Use a fallback basemap before opening a drawer if the active choice is unavailable. Here `Basemap.tracestrack` is the safe fallback.
- Add tests at three layers when the change spans data, UI, and journeys: catalog tests for ordering/lookup, widget tests for filtering/fallback, and robot coverage for the user flow.

## Validation

- `flutter analyze` passed.
- Unit, widget, and robot tests were added/updated for the catalog, drawer, and tile-cache ordering behavior.

## Decisions

- Kept the generated catalog checked in instead of parsing `assets/region_manifest.json` at runtime.
- Preserved the existing five basemap names/order, then appended new manifest-backed entries in manifest order.
