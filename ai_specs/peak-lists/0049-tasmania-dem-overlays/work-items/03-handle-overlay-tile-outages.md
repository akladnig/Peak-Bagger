---
type: Work Item
title: Handle Overlay Tile Outages
parent: ../spec.md
---

## What to build

Add the standalone overlay tile-failure path: an injectable tile provider and shared concurrency-safe, deduplicated, overlay-specific reporter for tile transport exceptions, 15-second request timeouts, and HTTP 5xx responses. Preserve all map and preference state, leave missing tiles absent, and surface at most one non-blocking message per overlay outage.

Use the exact messages `Terrain relief shading is unavailable from the local tile server` and `Contour lines are unavailable from the local tile server`. Do not notify for HTTP 4xx or no-data tiles, do not automatically disable an overlay switch, and do not reset suppression after individual successful tile responses. Reset suppression only after the relevant overlay is disabled or Settings capability validation succeeds; Settings validation is the user retry path.

## Required context

- `lib/screens/map_screen_layers.dart` has the Local Topo non-cacheable tile-provider pattern; `lib/screens/map_screen.dart` composes the live map layers.
- `lib/providers/local_topo_settings_provider.dart` owns successful Settings capability validation and its existing fake HTTP seam.
- Work Item 2 provides the persisted overlay state and standalone layer composition that this failure path reports against.

## Acceptance criteria

- [x] The injectable overlay tile provider classifies tile transport exceptions, 15-second tile request timeout expiry, and HTTP 5xx responses as reportable overlay outages; HTTP 4xx and no-data tiles remain absent without notification.
- [x] The shared reporter is concurrency-safe and emits at most one non-blocking exact overlay-specific message per outage, while preserving the active basemap, overlay switches, opacity values, and all other map state.
- [x] A successful individual overlay tile response does not reset suppression. Suppression for one overlay resets only when that overlay is disabled or Settings capability validation succeeds, allowing a later independent outage to be reported once.
- [x] Deterministic fake-tile-provider tests emit transport exceptions, 15-second timeout expiry, HTTP 4xx, HTTP 5xx, no-data, and successful responses without calling a real Local tile server. They verify reporting, deduplication, state preservation, and both allowed suppression-reset paths.
- [x] `flutter analyze` and the relevant `flutter test` suite pass.

## Covers

- User Stories: 4
- Requirements: 12
- Technical Decisions: 8
- Testing Strategy: 1, 7
- Interview Ledger: L8

## Blocked by

- `02-add-persisted-map-overlay-controls.md`
