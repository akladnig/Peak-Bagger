## Overview
Reusable elevation profile chart across track popup, route popup, live route draft.

Distance default, time toggle when timestamps exist, no scroll, no densify.

**Spec**: `ai_specs/elevation-profile-spec.md`

## Context

- **Structure**: layer-first (`lib/services`, `lib/widgets`, `lib/screens`, `lib/providers`)
- **State management**: Riverpod `MapState` / `MapNotifier`
- **Reference implementations**: `lib/widgets/dashboard/summary_chart.dart`, `lib/screens/map_screen_panels.dart`, `lib/widgets/map_route_bottom_sheet.dart`, `lib/providers/map_provider.dart`
- **Assumptions/Gaps**: route/live draft x-values use cumulative 2D geodesic distance; time mode preserves source order; live draft needs transient sampled-elevations cache in `MapState`

## Plan

### Phase 1: Shared series + chart shell

- **Goal**: pure builders; reusable chart widget; track popup first.
- [x] `lib/services/elevation_profile_series_builder.dart` - parse `GpxTrack.elevationProfile`; build distance/time series; preserve gaps; gate time mode on valid timestamps.
- [x] `lib/widgets/elevation_profile_chart.dart` - chart shell; distance default; toggle; empty/loading/error states; full-width x-scale; no horizontal scroll.
- [x] `lib/screens/map_screen_panels.dart` - embed chart in track info elevation section.
- [x] `test/services/elevation_profile_series_builder_test.dart` - TDD: track JSON parse, gap preservation, missing timestamps, empty input.
- [x] `test/widget/elevation_profile_chart_test.dart` - TDD: default distance, time toggle, disabled time mode, empty/error states.
- [x] `test/widget/map_track_info_panel_test.dart` - TDD: track panel renders the embedded elevation profile chart.
- [x] Verify: `flutter analyze && flutter test test/services/elevation_profile_series_builder_test.dart test/widget/elevation_profile_chart_test.dart test/widget/map_track_info_panel_test.dart`

### Phase 2: Route + live draft wiring

- **Goal**: saved route chart; live draft chart; rescale on point growth.
- [ ] `lib/providers/map_provider.dart` - add transient live draft sampled-elevations cache; keep it aligned with draft request/geometry version gates.
- [ ] `lib/widgets/map_route_bottom_sheet.dart` - render live draft chart; use committed points + sampled elevations; keep existing summary/error UI.
- [ ] `lib/screens/map_screen_panels.dart` - embed chart in saved route elevation section from `Route.gpxRoute` + `Route.gpxRouteElevations`.
- [ ] `test/providers/route_draft_state_test.dart` - TDD: live draft x-max grows when committed points extend; stale requests ignored; error/loading states preserved.
- [ ] `test/widget/map_screen_route_sheet_test.dart` - TDD: route chart renders; live draft updates; time mode disabled for route/draft; x-axis resizes as points arrive.
- [ ] Verify: `flutter analyze && flutter test test/providers/route_draft_state_test.dart test/widget/map_screen_route_sheet_test.dart`

### Phase 3: Robot journeys + regression

- **Goal**: critical journeys stable; selectors/seams locked.
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - track popup journey; route popup journey; live route draft journey.
- [ ] `test/robot/gpx_tracks/gpx_tracks_journey_test.dart` - TDD: one journey assertion at a time; x-max growth assertion; empty/error path assertion.
- [ ] Add stable `Key` selectors for chart container, toggle, loading, empty, and error states.
- [ ] Verify: `flutter analyze && flutter test`

## Risks / Out of scope

- **Risks**: `fl_chart` axis behavior may need custom label density; live draft state shape may need one extra transient field; time mode only useful for track data unless timestamps are later added to routes.
- **Out of scope**: Latest Walk popup implementation; persistence of route-draft profile state; horizontal scrolling / panning.
