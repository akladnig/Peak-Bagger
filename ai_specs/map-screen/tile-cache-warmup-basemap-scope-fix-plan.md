# Tile Cache Warmup Scope Fix

## Overview

The first-launch slowdown and `FMTCBrowsingError (negativeFetchResponse)` spam are most likely caused by the automatic low-zoom warmup trying to fetch non-Tasmania basemaps against a Tasmania-wide region.

The smallest fix is to narrow the warmup set so it only includes basemaps that are actually safe to prefetch globally, rather than iterating over every available basemap.

## Root Cause

- `lib/main.dart` triggers `TileCacheService.ensureLowZoomWarmup()` on startup.
- `lib/services/tile_cache_service.dart` currently warms every available basemap except `sloveniaTopo` and `fvgTopo`.
- That still includes `nswImagery`, `nswBasemap`, and `nswTopo`, which are region-specific and can return non-200 responses when warmed outside their coverage.
- Failed FMTC fetches are not cached, so the app keeps retrying on later launches until a full warmup succeeds.

## Plan

### Phase 1: Narrow warmup scope

- Update `TileCacheService.warmupBasemaps` to exclude the NSW basemaps from the global low-zoom warmup.
- Keep the warmup limited to basemaps that are intended to be fetched globally, such as OpenStreetMap, Tracestrack, and Mapy.cz when available.
- Leave per-basemap store creation intact.

### Phase 2: Test the behavior

- Update `test/unit/tile_cache_service_test.dart` to assert the warmup set does not include the NSW basemaps.
- Keep the existing exclusions for `sloveniaTopo` and `fvgTopo`.
- Verify that warmup still runs once per version and still coalesces duplicate calls.

### Phase 3: Verify runtime behavior

- Run the warmup unit test.
- Confirm startup no longer logs repeated `negativeFetchResponse` errors from the warmup path.
- Confirm the map still loads cached tiles normally after restart.

## Done When

- The low-zoom warmup no longer includes the NSW region basemaps.
- First launch no longer hammers region-specific tile sources during startup.
- The app still caches tiles normally and preserves the once-per-version warmup behavior.
