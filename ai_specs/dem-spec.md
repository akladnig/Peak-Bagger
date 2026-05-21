<goal>
Replace the placeholder route ascent/descent values with metrics sampled from the drafted route geometry against a bundled DEM via `gdal_dart`.
This matters because route metrics need to reflect the real plotted path, persist with the saved route, and stop showing fake values in the route sheet.
</goal>

<background>
Flutter/Riverpod/ObjectBox map app.
Use the existing shared number-formatting helpers in `./lib/core/number_formatters.dart` for route labels. Elevation labels should use `formatElevationMetres(int metres)`. Update the shared distance formatter so it accepts an optional decimal-place argument with a default of zero, preserving existing callers while allowing the route sheet to opt into 1-decimal-place output. When the route sheet uses the shared formatter, it should adopt the formatter's existing meter/kilometer unit switching behavior for short routes.

Relevant files to examine and align with:
@./lib/providers/map_provider.dart
@./lib/screens/map_screen.dart
@./lib/screens/map_screen_layers.dart
@./lib/widgets/map_route_bottom_sheet.dart
@./lib/models/route.dart
@./lib/services/gpx_track_statistics_calculator.dart
@./lib/services/geo.dart
@./lib/core/constants.dart
@./pubspec.yaml
@./test/providers/route_draft_state_test.dart
@./test/widget/map_screen_route_sheet_test.dart
@./test/robot/map/map_route_journey_test.dart

Route drafting already exists, including snap-to-trail planning and straight-line fallback. The route sheet currently shows hardcoded ascent/descent placeholders, and `saveRouteDraft()` still only persists `distance2d`.
The route draft also needs a dedicated elevation sampling state so the sheet can distinguish loading, success, and sampling failure without conflating those states with route planning errors.
Elevation sampling should follow the same stale-result protection pattern as route planning: every resample gets a draft-scoped request id, and only the latest result may update the current draft.

Bundled DEM assets already exist in the repo:
- `assets/cop30_hh.tif`
- `assets/tasmania_dem_25m.tif`

Use the bundled GeoTIFF assets at runtime. Do not depend on `assets/tasmania_dem_25m.vrt` because its referenced extracted source tiles are not bundled for the Flutter app.
</background>

<discovery>
1. Confirm the drafted route geometry that should be sampled matches the same committed polyline rendered on the map.
2. Confirm the selected DEM asset can be copied to a local filesystem cache path before opening it with GDAL.
3. Confirm the existing route sheet tests and robot journey tests that still assert the hardcoded placeholder values.
</discovery>

<user_flows>
Primary flow:
1. User starts route drafting from the Map screen.
2. User adds route points through snap-to-trail routing or straight-line fallback.
3. The app samples the current drafted route geometry against the selected DEM.
4. The route sheet shows real ascent and descent instead of placeholder numbers.
5. The user saves the route and the computed elevation metrics persist with the route record.

Alternative flows:
- Snap-to-trail routing: sample the routed polyline returned by route planning.
- Off-track fallback: sample the straight-line segment used when route planning cannot snap to trail.
- Returning draft after re-entry: a new route draft starts with a clean elevation state.

Error flows:
- If the DEM cannot be loaded or sampled, show a clear elevation error state instead of fake metrics.
- If route geometry is still valid but elevation sampling fails, keep the drafting flow intact and do not crash the map screen.
</user_flows>

<requirements>
**Functional:**
1. Add `gdal_dart` to `pubspec.yaml` and register the bundled DEM GeoTIFF assets required for runtime sampling.
2. Add a hardcoded DEM selection in `./lib/core/constants.dart` with `Copernicus GLO-30`, `theList`, and `ELVIS`, and default the app to `theList` for Tasmania route drafting.
3. Create a dedicated elevation sampler service in `./lib/services/route_elevation_sampler.dart` that opens the selected bundled DEM from a local cache path and samples elevations along a route polyline.
4. Sample the same committed route geometry that is rendered in `buildDraftRoutePolylines(...)`, not a placeholder or separate path.
5. Densify long line segments before sampling so the ascent/descent result is not limited to the route vertices only.
6. Return a route elevation summary containing ascent, descent, start elevation, end elevation, lowest elevation, highest elevation, and 3D distance.
7. Update `saveRouteDraft()` in `./lib/providers/map_provider.dart` to persist the computed elevation summary into `Route` before save.
8. Update `./lib/widgets/map_route_bottom_sheet.dart` to remove the hardcoded ascent/descent constants and render the live sampled values instead.
9. Preserve the existing route drafting behavior, including snap-to-trail planning and straight-line fallback.
10. Keep the current save/cancel route sheet flow unchanged aside from the new elevation values.
11. Add explicit route elevation loading/success/error state so the sheet can show a sampling-in-progress indicator, then either live metrics or an elevation-specific error message.
12. Format route ascent and descent with `formatElevationMetres(int metres)`, and update the route distance formatter to support whole-number or 1-decimal-place display as required by the sheet.
13. Update the shared `formatDistance(...)` helper to accept an optional decimal-place argument defaulting to `0`, so existing callers continue to render as before.
14. The route sheet must call the shared distance formatter with 1 decimal place and use its shared meter/kilometer unit switching behavior.
15. Recompute elevation whenever the committed route geometry changes, and ignore any sampler result that does not match the current route elevation request id.
16. Store the route elevation summary with the request id or geometry version it was computed from.

**Error Handling:**
17. If the selected DEM cannot be loaded or sampled, surface a clear elevation error in the route sheet instead of stale placeholder metrics.
18. Do not block normal route drafting or route saving on a transient elevation sampling error unless the route geometry itself is invalid.
19. If elevation sampling fails for the current draft, persist zeroed ascent, descent, distance3d, start elevation, end elevation, lowest elevation, and highest elevation on save rather than stale or partial values.
20. If save is triggered while a route elevation request is still in flight and no successful summary is available yet, save zeroed elevation fields rather than waiting on the sample.
21. If a successful elevation summary exists but its request id or geometry version does not match the current committed route geometry, do not save it; save zeroed elevation fields instead.

**Edge Cases:**
22. Short routes with only one valid sampled point should produce zero ascent and descent.
23. Straight-line fallback segments should use the same elevation sampling path as routed segments.
24. Re-entering route drafting must clear any previous elevation summary, error state, and pending elevation request id.
25. A save after sampling failure should still succeed with the zeroed elevation summary.

**Validation:**
26. Tests must prove ascent and descent come from sampled elevations, not hardcoded constants.
27. Tests must prove saving a route persists the computed elevation fields.
28. Tests must prove the route sheet no longer renders the placeholder ascent/descent numbers.
29. Tests must prove sampling failure saves zeroed elevation fields rather than stale values.
30. Tests must prove the route sheet uses 1-decimal-place distance formatting with the shared meter/kilometer switching behavior while existing callers continue to use the default whole-number display.
31. Tests must prove stale elevation results are ignored after the draft changes or ends.
32. Tests must prove save rejects stale successful summaries whose request id or geometry version no longer matches the current committed route geometry.
</requirements>

<boundaries>
Edge cases:
- Short routes with one point: ascent/descent stay at zero and the draft remains saveable if geometry is otherwise valid.
- Routes with sparse vertices: sample a densified polyline so the totals are not vertex-only.
- Straight-line fallback: use the same elevation sampler and summary model as routed segments.
- Bundled asset loading: copy the selected DEM asset to a local path once and reuse it.

Error scenarios:
- Missing or unreadable DEM asset: show an elevation-specific error state, not fake numbers.
- GDAL open/read failure: treat it as sampler failure, not route-planning failure.
- Save failure after successful sampling: keep the existing route save error behavior intact.

Limits:
- Do not introduce `geoimage`; use `gdal_dart` only for raster sampling.
- Do not add network DEM lookup or remote fallback behavior.
- Do not make the runtime depend on the `.vrt` asset unless its referenced source tiles are also bundled.
</boundaries>

<implementation>
Modify or create:
- `./pubspec.yaml` add `gdal_dart` and the DEM GeoTIFF asset declarations.
- `./lib/core/constants.dart` add the DEM selection constant/enum and resolution metadata.
- `./lib/core/number_formatters.dart` update the shared distance formatter so kilometer output can use 1 decimal place while preserving the existing meter/kilometer unit switching behavior.
- `./lib/services/route_elevation_sampler.dart` add the GDAL-backed sampler and summary model.
- `./lib/providers/map_provider.dart` store the sampled route elevation summary together with its request id or geometry version, clear it when drafts reset, and persist it in `saveRouteDraft()` only when it matches the current committed route geometry.
- `./lib/widgets/map_route_bottom_sheet.dart` render actual ascent/descent and any elevation error state.
- `./lib/screens/map_screen.dart` only if needed to ensure the draft sheet rebuilds when the elevation summary changes.
- `./test/services/route_elevation_sampler_test.dart` add deterministic service coverage with a fake or fixture-backed seam.
- `./test/providers/route_draft_state_test.dart` extend route draft save coverage for elevation persistence.
- `./test/widget/map_screen_route_sheet_test.dart` update route sheet assertions to the live summary and remove placeholder expectations.
- `./test/robot/map/map_route_journey_test.dart` confirm the end-to-end route journey still saves with elevation data.

Keep the sampler behind a small interface so widget and robot tests can override it with deterministic fakes. Cache the selected DEM path and the opened dataset handle so the app does not reopen the asset on every tap.
</implementation>

<stages>
Phase 1: Add DEM asset/bootstrap plumbing and the elevation sampler service.
Verify the sampler can open the selected bundled DEM and return a repeatable elevation summary for a known route polyline.

Phase 2: Wire the sampler into route drafting and route save.
Verify the route sheet shows sampled ascent/descent and `saveRouteDraft()` persists the computed elevation fields.

Phase 3: Update automated coverage.
Verify placeholder values are gone and the critical route journey still passes with deterministic test seams.
</stages>

<validation>
Behavior-first TDD slices:
1. Add a failing service test for a known polyline sampling summary.
2. Add a failing provider test for saving a route with computed elevation fields.
3. Add a failing widget test that expects the route sheet to stop showing `315 m` and `234 m`.
4. Implement the minimum code to make each slice green before moving to the next.

Testability seams:
- Inject the elevation sampler into `MapNotifier` as an interface.
- Override the sampler with a fake in widget and robot tests.
- Keep DEM asset path resolution isolated from the sampling math.

Required coverage:
- Logic/business rules: route elevation summary calculation, densification, and field persistence.
- UI behavior: route sheet shows live ascent/descent and an elevation error state when sampling fails, and route-planning loading/error takes precedence over elevation loading/error.
- Critical user journeys: drafting a route, saving it, and keeping the saved elevation data intact.

Robot coverage:
- Add or update the route journey so it still drafts a route, saves it, and asserts the saved route count plus the route sheet metrics state.
- Use stable `Key` selectors for the route sheet root, ascent/descent texts, and any elevation error text.
- Keep robot tests deterministic by faking the elevation sampler rather than depending on a full-size raster in the journey lane.

Baseline automated outcomes:
- No hardcoded placeholder ascent/descent values remain in the route sheet.
- Saved routes persist sampled elevation data.
- Route drafting remains unchanged for snap-to-trail and straight-line fallback paths.
- The route sampler is covered by a deterministic unit test and the user journey is covered by widget and robot tests.
</validation>

<done_when>
The route sheet shows real ascent/descent derived from the drafted route geometry, route saves persist the sampled elevation fields, the implementation uses `gdal_dart` with bundled DEM GeoTIFF assets, and the placeholder metrics are gone from UI and tests.
</done_when>
