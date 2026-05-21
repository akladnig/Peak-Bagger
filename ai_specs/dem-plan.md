## Overview

Replace route-sheet placeholders with DEM-sampled route metrics; persist matching summary on save.
Approach: Riverpod state + injected sampler seam first; GDAL asset/bootstrap second; journey hardening last.

**Spec**: `ai_specs/dem-spec.md` (read this file for full requirements)

## Context

- **Structure**: layer-first-ish; `screens/`, `widgets/`, `providers/`, `services/`, `core/`, `models/`
- **State management**: Riverpod; central `MapNotifier` in `lib/providers/map_provider.dart`
- **Reference implementations**: `lib/providers/map_provider.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/services/gpx_track_statistics_calculator.dart`
- **Assumptions/Gaps**: use committed route geometry only; runtime uses bundled `.tif`, not `.vrt`; no unresolved spec gaps

## Plan

### Phase 1: Route Elevation Slice

- **Goal**: thin E2E slice; draft geometry -> summary state -> sheet -> save
- [x] `lib/providers/map_provider.dart` - inject route elevation sampler seam; add elevation summary/loading/error + request/version state; resample on committed-geometry changes; zero-save fallback for in-flight/failure/stale summary
- [x] `lib/widgets/map_route_bottom_sheet.dart` - watch elevation state; replace placeholders; enforce precedence: route-planning loading/error before elevation loading/error; use shared distance formatter with `decimalPlaces: 1`
- [x] `test/providers/route_draft_state_test.dart` - TDD: committed-geometry change triggers resample; stale result ignored; save uses matching summary else zeros
- [x] `test/widget/map_screen_route_sheet_test.dart` - TDD: sampled ascent/descent render; loading/error states render; placeholders gone; short-route distance uses shared meter/kilometer switching
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 2: GDAL Sampler + Shared Formatting

- **Goal**: real raster-backed sampler; app config wired
- [x] `pubspec.yaml` - add `gdal_dart`; register `assets/cop30_hh.tif` and `assets/tasmania_dem_25m.tif`
- [x] `lib/core/constants.dart` - add DEM source enum/constants; default `theList`; add resolution/source metadata needed by sampler
- [x] `lib/core/number_formatters.dart` - extend `formatDistance(double value, {int decimalPlaces = 0})`; preserve existing unit switching; km honors requested precision
- [x] `lib/services/route_elevation_sampler.dart` - TDD: cache bundled asset to local path; open GDAL dataset; densify polyline; sample elevations; compute ascent/descent/distance3d/start/end/low/high; return summary tagged with request/version
- [x] `test/services/route_elevation_sampler_test.dart` - TDD: known polyline summary; short-route zero behavior; failure path; cache/bootstrap seam deterministic
- [x] Verify: `flutter analyze` && `flutter test`

### Phase 3: Journey Hardening

- **Goal**: selectors/seams stable; critical route journey covered
- [ ] `lib/screens/map_screen.dart` - update watched route state only if draft sheet rebuild/selectors need elevation fields exposed cleanly
- [ ] `test/robot/map/map_route_robot.dart` - add fake sampler injection + selectors for distance/ascent/descent/elevation error
- [ ] `test/robot/map/map_route_journey_test.dart` - TDD: happy path saves sampled elevation data; stale/in-flight path still saves zeros deterministically when required
- [ ] Robot journey tests + selectors/seams for critical flows - key-first selectors; fake sampler; deterministic async completion ordering; no real raster dependency in robot lane
- [ ] Verify: `flutter analyze` && `flutter test`

## Risks / Out of scope

- **Risks**: `gdal_dart` Flutter runtime/bootstrap friction; raster sampling cost on repeated draft edits; shared `formatDistance` ripple across existing UI
- **Out of scope**: remote DEM lookup; ELVIS runtime integration; `.vrt` runtime loading; broader route analytics UI beyond current sheet/save fields
