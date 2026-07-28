---
type: Work Item
title: macOS Route Elevation ELVIS Runtime Adoption And Region Aware Error States
parent: ../spec.md
---

## What to build
Adopt the external `ELVIS runtime DEM` for macOS route elevation workflows in the Flutter app. This item must replace the bundled-asset ELVIS placeholder with a fixed maintainer-managed runtime path resolved through the shared Tasmania DEM resolver from `01-elvis-maintainer-cli-shared-tasmania-dem-resolver-and-artifact-contracts.md`, use the repo's existing region-classification helper or an equivalent shared seam before any dataset open, resolve Tasmania-only routes to the external runtime DEM, resolve every non-Tasmania route to `dem=none`, and surface the exact user-facing error messages required by the Spec without adding any Settings UI or file-picker affordance.

## Required context
- `lib/core/constants.dart`, `lib/services/route_elevation_sampler.dart`, `lib/providers/map_provider.dart`, `lib/widgets/map_route_bottom_sheet.dart`, and `lib/widgets/elevation_profile_chart.dart` are the current runtime and UI seams for route elevation sampling and error display.
- `lib/services/region_manifest_catalog.dart` is the preferred existing region-classification seam; do not duplicate Tasmania-only bounds logic if an equivalent shared region resolver can be reused.
- `test/services/route_elevation_sampler_test.dart`, `test/widget/map_screen_route_sheet_test.dart`, and existing fake seams such as `DemAssetCache` and `DemDatasetOpener` are the starting point for deterministic app-side coverage.
- Preserve the macOS-only maintainer-managed local-file contract for this slice and do not introduce a user-facing DEM file setting.

## Acceptance criteria
- [x] The current code contract that treats `ELVIS` as a bundled asset alias is removed, and Tasmania runtime elevation resolves to the fixed external `ELVIS runtime DEM` path rather than a bundled asset or `Copernicus GLO-30` stand-in.
- [x] Before any dataset open or elevation sampling work, app elevation workflows in this slice resolve the route DEM using the repo's existing region-classification helper or an equivalent shared seam rather than duplicating Tasmania-only bounds logic.
- [x] If every route point resolves within Tasmania, the route uses the fixed external `ELVIS runtime DEM`; otherwise the route resolves to `dem=none`.
- [x] Non-Tasmania routes do not attempt dataset open or sampling work.
- [x] When the route region resolves to `dem=none`, the interactive route elevation UI shows the exact message `Elevation unavailable for this region`, replacing the current `No elevation data yet` message for that case.
- [x] When the resolved region is Tasmania but the fixed `ELVIS runtime DEM` is missing, unreadable, or cannot be opened, the interactive route elevation UI shows the exact message `Tasmania elevation data is unavailable on this device` in both the route elevation summary error surface and the elevation profile chart error state.
- [x] Tasmania runtime elevation does not silently fall back to `theLIST 25m DEM` after ELVIS adoption.
- [x] Best-effort non-interactive elevation flows that already swallow failures, including imported-route enrichment, route-save point elevation sampling, and GPX route export elevation sampling, first short-circuit when the resolved region DEM is `none` rather than relying on swallowed dataset-open failures as control flow.
- [x] The app does not add a Settings UI, file picker, or any other user-facing control for DEM selection in this slice.
- [x] Deterministic app-side coverage proves the shared region-to-DEM resolver contract, Tasmania-only route acceptance, non-Tasmania `dem=none`, the exact `Elevation unavailable for this region` UI message, the exact `Tasmania elevation data is unavailable on this device` error state, dataset-open short-circuit behavior for `dem=none`, and reuse or equivalent replacement of external-file test seams without live GeoTIFF dependencies.

## Covers
- User Stories: 3, 5
- Requirements: 1, 4, 7-9, 11-13
- Technical Decisions: 1-2, 5-6
- Testing Strategy: 4-5
- Interview Ledger: L1, L4-L6, L8-L10, L16, L22

## Blocked by
- `01-elvis-maintainer-cli-shared-tasmania-dem-resolver-and-artifact-contracts.md`
