---
type: Work Item
title: Elevation-Aware Route-Export Correlation
parent: ../spec.md
---

## What to build

Update route-export peak correlation so its generated route geometry includes the stored `Route.gpxRouteElevations`, or values from the existing route-elevation resolver when stored values are unavailable. Pass both current correlation thresholds to the shared correlation service so correlated peak waypoints use the same elevation-aware rules as Tracks.

## Required context

- `lib/services/gpx_export_service.dart` resolves route elevations in `planRouteExport()` and builds correlation XML in `_buildCorrelationRouteGpx()`.
- Reuse the correlation behavior from `01-elevation-aware-track-peak-correlation.md` and the persisted settings boundary from `02-persisted-peak-correlation-threshold-settings.md`.
- `test/services/gpx_export_service_test.dart` contains current correlated-route-waypoint service coverage.

## Acceptance criteria

- [x] Route-export correlation geometry includes `Route.gpxRouteElevations` when stored and otherwise uses the existing route-elevation resolver output.
- [x] The resolved elevation values used for route correlation are the same values used by route export, so correlation and emitted route elevations cannot diverge.
- [x] Correlated peak waypoints use both current `Distance threshold` and `Elevation threshold` through `TrackPeakCorrelationService`.
- [x] Service coverage proves correlated route peak waypoints use stored route elevations and resolved route elevations without real GPX files, ObjectBox databases, network services, or SharedPreferences outside the established mocks.

## Covers

- User Stories: 1
- Requirements: 4
- Technical Decisions: 2
- Testing Strategy: 3
- Interview Ledger: L1, L3, L4, L6

## Blocked by

01-elevation-aware-track-peak-correlation.md
02-persisted-peak-correlation-threshold-settings.md
