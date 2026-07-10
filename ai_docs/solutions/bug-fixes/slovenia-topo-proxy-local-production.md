---
title: Slovenia Topo Proxy Local Production Recovery
date: 2026-06-19
work_type: bugfix
tags: [flutter, proxy, apache, macos, caching]
confidence: high
references: [lib/screens/map_screen_layers.dart, lib/services/tile_cache_service.dart, proxy/slovenia-topo-proxy/lib/src/tile_handler.dart, proxy/slovenia-topo-proxy/local-production/README.md, proxy/slovenia-topo-proxy/local-production/apache/tiles.peakbagger.com.conf, proxy/slovenia-topo-proxy/local-production/launchd/com.peakbagger.slovenia-topo-proxy.plist, test/unit/region_manifest_catalog_test.dart, test/unit/tile_cache_service_test.dart]
---

## Summary

Recovered the Slovenia topo basemap by keeping the app on the published `tiles.peakbagger.com` contract for release builds, routing local macOS debug runs to a local proxy, reducing proxy fan-out against the upstream WMS, and documenting a local production setup that serves `tiles.peakbagger.com` through macOS Apache plus a `launchd`-managed Dart proxy.

## Reusable Insights

- Separate app contract from local development routing. Keep the manifest-backed production URL stable, but use a debug-only override when local infrastructure is required.
- `FMTCBrowsingError (noConnectionDuringFetch)` means transport failure. Check DNS and whether the local proxy process is actually running before changing app logic.
- `FMTCBrowsingError (negativeFetchResponse)` during Slovenia tile loads was a proxy/upstream problem, not a Flutter URL problem. Reading the proxy log quickly showed repeated `502` responses.
- Region-limited basemaps should not participate in global low-zoom warmup. Excluding `Basemap.sloveniaTopo` avoids FMTC startup download issues and stale failure paths.
- For this upstream WMS, lower concurrency plus more retries was better than aggressive parallelism. The working proxy defaults were `2` concurrent upstream requests, `6` attempts, and `400ms` base retry delay.
- For a macOS-only app, remove cross-platform host branching and keep local proxy defaults simple: `127.0.0.1:8080` unless explicitly overridden.

## Decisions

- Release builds still target `https://tiles.peakbagger.com/slovenia-topo/{z}/{x}/{y}.png`.
- Non-release builds default to `http://127.0.0.1:8080/slovenia-topo/{z}/{x}/{y}.png`, with optional override via `SLOVENIA_TOPO_TILE_URL`.
- The proxy package and docs were renamed from `slovenia-ortofoto-proxy` to `slovenia-topo-proxy` to match current naming.
- Local production setup was documented against the machine's real Apache install at `/usr/sbin/httpd` with config rooted in `/private/etc/apache2`.

## Pitfalls

- The repo does not contain DNS or public reverse-proxy infrastructure for `tiles.peakbagger.com`. If that hostname works, it is because of external setup.
- Simply pointing the app back to `tiles.peakbagger.com` does nothing if the hostname does not resolve locally.
- Having both old and renamed proxy directories around can leave stale `.dart_tool` artifacts that confuse future cleanup.

## Validation

- Confirmed `tiles.peakbagger.com` did not resolve in the local environment.
- Started the local proxy and verified direct tile responses from `127.0.0.1:8080`.
- Confirmed the proxy log showed initial `502` bursts followed by successful `200` tile responses after retry/concurrency tuning.
- Verified app-side and cache behavior with:
  - `flutter test test/unit/region_manifest_catalog_test.dart test/unit/tile_cache_service_test.dart`
- Verified proxy behavior with:
  - `dart test` in `proxy/slovenia-topo-proxy`

## Follow-ups

- If local production use of `tiles.peakbagger.com` is required again, follow `proxy/slovenia-topo-proxy/local-production/README.md` to bind the hostname locally through Apache and `launchd`.
- If public release use is required, restore external DNS/TLS/reverse-proxy infrastructure for `tiles.peakbagger.com`; that is not managed from this repo.
