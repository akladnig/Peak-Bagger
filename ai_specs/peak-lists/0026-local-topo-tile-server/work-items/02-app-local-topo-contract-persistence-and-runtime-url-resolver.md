---
type: Work Item
title: App Local Topo Contract Persistence And Runtime URL Resolver
parent: ../spec.md
---

## What to build
Add the app-owned `Local Topo` integration contract inside the existing basemap architecture without changing the app's raster `XYZ` rendering path. This slice must add the checked-in `localTopo` basemap identity to the generated catalog path with a fixed placeholder `tileUrl` and fixed attribution, implement capability-response parsing and accepted-region filtering, persist both `Local tile server base URL` and the last successful capability snapshot, expose one shared source of truth for the resolved runtime `Local Topo` tile contract, and include any required macOS networking configuration so trusted `http://` and `https://` local tile server hosts can be validated and used.

## Required context
- `lib/generated/region_manifest_catalog.g.dart` and `lib/services/region_manifest_catalog.dart` are the current runtime source of truth for basemap identity, ordering, and manifest-backed metadata. Extend that path with one checked-in app-owned `localTopo` entry rather than introducing per-user manifest rewrites.
- `tool/generate_region_manifest_catalog.dart` is the generation entrypoint for catalog output and should remain the authoritative path if catalog source data changes are required.
- `lib/screens/map_screen_layers.dart` currently resolves tile URLs from `Basemap` identity, and `lib/services/tile_cache_service.dart` reuses that path for download and browse transformations. This item should establish the shared runtime `Local Topo` resolver those consumers can use later.
- Existing persisted app state patterns live around `SharedPreferences`-backed providers and `mapProvider`. Follow those conventions for storing the saved base URL and last successful capability snapshot.

## Acceptance criteria
- [x] The generated basemap catalog and `Basemap` enum gain one checked-in app-owned basemap key `localTopo` labeled exactly `Local Topo`, with a fixed non-routable placeholder `tileUrl` and fixed checked-in attribution for v1.
- [x] The app continues to treat `Basemap` identity, ordering, and selection state through the existing catalog-driven basemap architecture rather than introducing per-user manifest edits or a parallel dynamic-basemap system.
- [x] The app can parse the v1 capability response, require `service` exactly `peak-bagger-local-topo`, require `version` exactly `1`, require one compatible `localTopo` basemap contract labeled exactly `Local Topo`, reject malformed required fields, and ignore unknown additional fields for forward compatibility.
- [x] Accepted capability data is filtered to region entries whose `regionKey` exactly matches an existing app canonical region key and whose `tilePathTemplate` is relative and contains `{z}`, `{x}`, and `{y}`, with the response rejected when no accepted region entries remain.
- [x] The app persists both the saved `Local tile server base URL` and the last successful capability snapshot, with the snapshot tied to the currently saved URL so it can be restored on launch without an automatic live probe.
- [x] The app exposes one shared source of truth for the effective `Local Topo` runtime tile contract after validation, and that source is designed for reuse by map rendering, manual tile-cache download flows, and tile-cache browse/download URL transformation.
- [x] The checked-in placeholder catalog URL is never treated as the live runtime tile URL once a validated or restored capability snapshot exists for the currently saved base URL.
- [x] The app remains on its existing raster `XYZ` contract for `Local Topo` and does not gain direct vector-tile rendering, WMS rendering, or custom CRS logic.
- [x] The checked-in macOS Flutter target includes the required networking configuration for trusted `http://` hosts as well as `https://` hosts so local or LAN `Local tile server base URL` values can be validated and used in v1.
- [x] Deterministic app-side unit or service coverage proves base-URL parsing constraints, capability parsing, region support filtering, snapshot persistence or restore behavior, and the shared runtime resolver contract without live network dependencies.

## Covers
- User Stories: 1, 4
- Requirements: 1-2, 6-7, 9-10, 16, 18, 23-24
- Technical Decisions: 1-3, 5
- Testing Strategy: 1
- Interview Ledger: L1, L4, L8-L10

## Blocked by
None - ready to start
