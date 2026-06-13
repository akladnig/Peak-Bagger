## Overview

Align route export foldering with current track import placement. Share first-point country/region resolution; stop keeping a separate route path rule.

**Spec**: `ai_specs/track-route-restructure.md` (read this file for full requirements)

## Context

- **Structure**: layer-first Flutter app; file logic in `lib/services`, orchestration in `lib/providers`, UI panels in `lib/screens` / `lib/widgets`
- **State management**: Riverpod
- **Reference implementations**: `lib/services/gpx_importer.dart`, `lib/services/gpx_export_service.dart`, `lib/services/import_path_helpers.dart`, `test/services/gpx_export_service_test.dart`, `test/widget/map_screen_route_info_test.dart`
- **Assumptions/Gaps**: request scope = route export parity with track import; route import does not currently persist GPX files; track export still targets Downloads unless separately changed; unsupported export location needs one explicit behavior choice, preferably fail with `GpxExportException`

## Plan

### Phase 1: Shared destination resolution

- **Goal**: one country/region resolver for track + route file placement
- [x] `lib/services/gpx_storage_destination_resolver.dart` - extract polygon-backed first-point classification; map asset names to `Country[/Region]`; expose track/route folder builders from `resolveBushwalkingRoot()`
- [x] `lib/services/import_path_helpers.dart` - keep Bushwalking root canonical; add only minimal helpers if needed by the new resolver
- [x] `lib/services/gpx_importer.dart` - replace private destination mapping/path assembly with shared resolver; preserve current track import behavior, polygon priority, Tasmania fallback, and planned managed paths
- [x] `test/services/gpx_storage_destination_resolver_test.dart` - TDD: Tasmania, NSW, Italy nord-est, Italy nord-ovest, Slovenia, Croatia, no-region countries omit subfolder, unsupported point returns null
- [x] `test/gpx_track_test.dart` - TDD: existing selective-import managed path expectations still hold after extraction
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: Route export parity

- **Goal**: route exports land in `Routes/Country/Region` from first route point
- [ ] `lib/services/gpx_export_service.dart` - replace hard-coded `Documents/Bushwalking/routes` target with shared resolver; derive destination from `route.gpxRoute.first`; keep existing GPX payload generation and versioning behavior; surface unsupported-location failure explicitly
- [ ] `lib/providers/gpx_export_provider.dart` - wire any new resolver dependency only if constructor injection is needed for test seams
- [ ] `test/services/gpx_export_service_test.dart` - TDD: Tasmania path, Italy regional path, Slovenia/Croatia country-only path, unsupported-point failure, existing blank-name / empty-route guards still pass, versioning stays directory-local
- [ ] `test/widget/map_screen_route_info_test.dart` - TDD: route export success snackbar shows nested `Routes/...` path; unsupported export shows failure snackbar
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: resolver extraction can accidentally change current track import placement; export unsupported-location behavior is not spelled out by spec; lower/upper-case folder drift (`Routes` vs `routes`) may affect existing manual files/tests
- **Out of scope**: route import file placement on disk; track export destination changes; migration of already-exported or already-imported files
