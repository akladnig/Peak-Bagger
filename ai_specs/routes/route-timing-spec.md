<goal>
Add route timing support for imported GPX routes.
When a user imports a GPX as a route, timestamped sources should store `estimatedTime` from the same moving-time calculation used for tracks, untimed sources should use Naismith, the route info panel should explain how the estimate was derived, and timed routes should export deterministic point-level `<time>` tags in the existing route XML shape.
</goal>

<background>
The app is a Flutter/Riverpod map application with ObjectBox persistence.

Relevant files to examine and update:
- `./lib/models/route.dart`
- `./lib/services/gpx_importer.dart`
- `./lib/services/gpx_export_service.dart`
- `./lib/providers/map_provider.dart`
- `./lib/screens/map_screen_panels.dart`
- `./lib/core/constants.dart`
- `./lib/core/number_formatters.dart`
- `./lib/services/gpx_track_statistics_calculator.dart`
- `./lib/services/route_admin_editor.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`
- `./test/providers/map_provider_import_test.dart`
- `./test/services/gpx_export_service_test.dart`
- `./test/services/route_repository_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/services/route_admin_editor_test.dart`
- `./test/services/objectbox_schema_guard_test.dart`
- `./test/widget/map_route_info_panel_test.dart`
- `./test/widget/map_screen_route_info_test.dart`
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart`
- `./test/robot/map/route_info_journey_test.dart`

Current behavior:
- Route import flows through `GpxImporter.parseRouteFile()`, then `_enrichImportedRoute()` in `MapNotifier`, then `RouteRepository.saveRoute()`.
- `Route` does not currently store any timing estimate.
- `Route` also does not currently store any timing profile or provenance needed to recompute edited geometry timing.
- Route info panels already show distance, ascent, and descent/elevation data, while track info panels already show a Time section.
- Route GPX export currently writes `<rte>`/`<rtept>` without point `<time>` tags.
- `GpxTrackStatisticsCalculator` already computes moving time from GPX timestamps for track imports; reuse that logic instead of creating a second timing parser.
</background>

<discovery>
The implementation should reuse existing timing and export conventions rather than introducing a parallel model.

Questions to answer through code inspection during implementation:
- Where is the smallest seam to recompute `estimatedTime` when a route is cloned for editing or admin updates?
- What is the cleanest way to reuse the existing track moving-time calculation for timestamped route imports?
- How can the route exporter synthesize deterministic `<time>` values without changing the current route XML shape?
- Which widget selectors need stable keys so widget and robot tests can verify the timing UI without brittle text-only assertions?
</discovery>

<user_flows>
Primary flow:
1. User chooses `Import as Route` on a GPX file that contains timestamps.
2. The app computes `estimatedTime` from moving time, saves it with the route, and keeps the existing route geometry and waypoint data intact.
3. The user opens the route info panel and sees `Estimated Time` in the summary row, a Time section, and a note that the estimate came from a verified walk.
4. The user exports the route and receives GPX with synthetic `<time>` tags on each exported route point.

Alternative flows:
- Untimed GPX import: the app computes `estimatedTime` from Naismith and shows the Naismith explanation string in the Time section.
- Returning user: reopening an imported route shows the same persisted estimate.
- Legacy route: an existing saved route without `estimatedTime` still opens, displays a dash safely, and remains exportable.
- Edited route geometry: saving an edited route recomputes the estimate from the current geometry and timing profile.

Error flows:
- Malformed GPX, empty geometry, or insufficient timed points must not persist a misleading estimate.
- Export must omit timing tags rather than invent broken values when a route has no estimate.
- Route cloning or admin editing must recompute `estimatedTime` from the updated geometry and timing profile rather than clearing it.
</user_flows>

<requirements>
**Functional:**
1. Add a nullable `estimatedTime` field to `Route` in `./lib/models/route.dart`, stored as milliseconds and persisted through ObjectBox.
2. Add a nullable serialized timing-profile field to `Route` in `./lib/models/route.dart` (for example `routeTimingProfileJson`) that stores the current route's cumulative elapsed-time value in seconds for each route point.
3. Regenerate the ObjectBox schema artifacts so `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` include the new timing fields.
4. Add route timing constants in `./lib/core/constants.dart` for the fixed Naismith flat speed and ascent/descent penalties, and use those constants in both the calculation and the user-facing explanation text.
5. Add `RouteTimingConstants.naismithsNumber = 7.92` in `./lib/core/constants.dart` and use it as the route timing weight.
6. Add `RouteTimingConstants.naismithSpeedMetresPerSecond = 1.3888888889`, `naismithAscentSecondsPerMetre = 6.0`, and `naismithDescentSecondsPerMetre = 1.8` in `./lib/core/constants.dart`.
7. Add `scarfDistance(distanceMetres, ascentMetres)` and `scarfTime(distanceMetres, ascentMetres)` helper functions under `./lib/services/`.
8. `scarfDistance` must be defined as `distanceMetres + naismithsNumber * ascentMetres` and must return metres.
9. `scarfTime` must return elapsed seconds, using `scarfDistance / naismithSpeedMetresPerSecond` as the base calculation.
10. Add `naismithTime(distanceMetres, ascentMetres, descentMetres)` under `./lib/services/`; it must return elapsed seconds using `distanceMetres / naismithSpeedMetresPerSecond + ascentMetres * 6 + descentMetres * 1.8`.
11. The fixed Naismith explanation string must reflect those exact constants and helper names, and the displayed time value must always be formatted as `hh:mm:ss` at the UI/export boundary.
12. Add a small timing service under `./lib/services/` to centralize route-time estimation and synthetic export-time generation so the importer, exporter, and UI do not each duplicate the math.
13. In `./lib/services/gpx_importer.dart` and `./lib/providers/map_provider.dart`, compute `estimatedTime` before the route is saved: use the existing track moving-time calculation when the source GPX has usable timestamps, otherwise use Naismith from the enriched route distance/ascent/descent data.
14. Compute timestamp-based estimates from the original GPX input before route simplification so the estimate reflects the source walk, not the reduced geometry.
15. When a route geometry is rebuilt or edited, recompute `estimatedTime` from the updated geometry and recompute the full timing profile from scratch. The edit path does not need to preserve per-point timing history.
16. Update `./lib/screens/map_screen_panels.dart` so the route summary row shows `Estimated Time` in place of descent, the route panel gains a Time section, and the route Time section shows the exact explanation strings and an `hh:mm:ss` estimate value derived from the seconds-based helpers.
17. Update both route and track elevation sections in `./lib/screens/map_screen_panels.dart` so `Total Ascent` becomes `Ascent` and a `Descent` row appears immediately underneath it.
18. Update `./lib/services/gpx_export_service.dart` so route exports keep the existing `<rte>`/`<rtept>` shape, but when `estimatedTime` is present they emit deterministic synthetic `<time>` children on each exported route point.
19. Synthetic export times must be monotonic, deterministic, and derived from the saved estimate plus route geometry, not from wall-clock time.
20. Preserve the existing route waypoint, elevation, metadata, and export path behavior when adding timing data.
21. Exported `<time>` tags must be synthesized from the stored timing profile; the stored profile is the source of truth, not previously exported XML.

**Error Handling:**
21. If a route has no usable estimate, the route Time section must still render and the value should be a dash (`—`) rather than a crash or fabricated duration.
22. If a GPX import cannot produce a valid route timing estimate, it should follow the existing import failure/skip behavior rather than saving misleading data.
23. If route geometry is empty or export timing cannot be synthesized, omit the `<time>` children and keep the existing export error behavior.

**Edge Cases:**
24. Legacy saved routes without timing data must remain readable after the schema change.
25. Mixed or sparse timestamps should only use the moving-time branch when the calculator can produce a real moving-time result; otherwise fall back to Naismith.
26. If ascent or descent data are missing for a Naismith import, treat the missing component as zero rather than failing the import.
27. Zero-length or nearly zero-length routes must not produce negative or non-monotonic synthetic export times.

**Validation:**
28. Add behavior-first tests for route-time estimation, ObjectBox persistence, UI rendering, export synthesis, and route edit recomputation.
29. Require baseline automated coverage for logic/business rules, UI behavior, and the critical route-import/export journey.
30. Keep the implementation deterministic by injecting or faking the timing/export seams instead of depending on the current time.
</requirements>

<boundaries>
Edge cases:
- Timestamped imports with a valid moving-time result use the verified-walk branch, even if the route was later simplified for display.
- Untimed imports use Naismith from the saved route summary, not from a second ad hoc formula in the widget layer.
- Legacy routes without timing data display safely and can still be exported.
- Routes with only one point may still be saved, but export timing should stay deterministic and non-decreasing.

Error scenarios:
- Invalid GPX input or insufficient point/time data must not create a misleading estimate.
- Export should not emit partial timing data when the route cannot be timed.
- Route edits must recompute `estimatedTime` from the updated geometry and timing profile rather than silently clearing it. The edit path recomputes the full timing profile from scratch.

Limits:
- Keep the existing route export XML shape; do not switch timed routes to a different top-level GPX representation.
- Do not change route planning, peak logic, or map interaction behavior outside the timing slice.
- Do not add a second timing model alongside the new route timing service.
</boundaries>

<implementation>
Modify or create the following files:
- `./lib/models/route.dart` add the persisted `estimatedTime` field.
- `./lib/models/route.dart` add the serialized route timing profile field.
- `./lib/services/route_timing_service.dart` create the shared calculation and synthetic export-time helper.
- `./lib/services/gpx_importer.dart` compute route timing during route import.
- `./lib/providers/map_provider.dart` carry the estimate through import and recompute it when route geometry changes during edits.
- `./lib/services/route_admin_editor.dart` recompute `estimatedTime` when admin edits rebuild a route.
- `./lib/services/gpx_export_service.dart` add point `<time>` generation for timed route exports.
- `./lib/screens/map_screen_panels.dart` update the route/track info labels and the route Time section.
- `./lib/core/constants.dart` add the Naismith constants.
- `./lib/objectbox-model.json` and `./lib/objectbox.g.dart` regenerate the schema artifacts.
- `./lib/services/objectbox_admin_repository.dart` include the new field in the admin row payload.
- `./test/services/route_timing_service_test.dart` add focused calculation coverage.
- `./test/services/gpx_export_service_test.dart` add export timing coverage.
- `./test/services/route_repository_test.dart` assert persistence round-trips the new field.
- `./test/services/objectbox_admin_repository_test.dart` and `./test/services/objectbox_schema_guard_test.dart` cover schema/admin surfaces.
- `./test/services/route_admin_editor_test.dart` cover edit recomputation and preserved timing provenance.
- `./test/providers/map_provider_import_test.dart` cover import-save behavior.
- `./test/widget/map_route_info_panel_test.dart` and `./test/widget/map_screen_route_info_test.dart` cover the UI copy and label changes.
- `./test/robot/gpx_tracks/gpx_tracks_journey_test.dart` and `./test/robot/map/route_info_journey_test.dart` cover the critical journey and route panel rendering.

Prefer a minimal helper surface:
- Keep the timing logic in one service and call it from import/export code.
- Expose the route timing helpers as `scarfDistance` and `scarfTime` so the same formula is used everywhere.
- Reuse the existing `formatDuration` and elevation formatters for display.
- Add stable keys only where widget and robot tests need deterministic selectors for the new Time section and estimate value.
</implementation>

<stages>
Phase 1: Persistence and timing service.
- Add `estimatedTime` to `Route`, regenerate ObjectBox artifacts, and write the route timing service.
- Verify the new unit tests fail before implementation and pass after.

Phase 2: Import and export wiring.
- Wire timestamped and untimed route imports through the timing service.
- Add synthetic point-time generation to route export.
- Verify import/export tests cover both branches and the legacy null path.

Phase 3: Map UI updates.
- Update the route and track panels with the new labels, route Time section, and explanation text.
- Verify widget tests cover the new copy, layout, and null-safe fallback.

Phase 4: Journey coverage.
- Extend the import-and-open journey to assert the estimated-time display on a real imported route.
- Verify the route info journey still opens, edits, and closes cleanly after the field addition.
</stages>

<validation>
Use behavior-first TDD slices, one failing test at a time.

Required automated coverage outcomes:
- Logic/business rules: route timing calculation for timestamped imports, Naismith fallback for untimed imports, persistence round-trip of `estimatedTime`, preserved values during route edits, and deterministic export-time synthesis.
- UI behavior: route summary row label change, route Time section, explanation copy, `Ascent`/`Descent` label updates, and null-safe legacy rendering.
- Critical journey: import a GPX as a route, verify the saved route carries `estimatedTime`, open the route panel, and export a timed route with `<time>` tags present.

Test expectations:
1. Start with a failing unit test for timestamped route import using the moving-time branch.
2. Add a failing unit test for untimed route import using the Naismith branch.
3. Add a failing unit test for route export that proves timed routes emit `<time>` children under the existing route points.
4. Add a failing persistence test for `Route.estimatedTime` before changing the schema artifacts.
5. Add a failing route-edit recomputation test so edited routes recompute the full profile from the updated geometry.
6. Add widget tests for the route panel copy, the Time section, and the `Ascent`/`Descent` label updates.
7. Add robot coverage for the import-and-open journey using stable keys, not private widget internals.

Required seams:
- A testable route timing service boundary.
- A deterministic export-time builder that can be exercised without the current clock.
- Stable app-owned `Key` selectors for the route Time section, the estimate value, and the explanation text.
- Fakes or fixtures for imported GPX payloads so tests can cover both timestamped and untimed inputs.

Do not consider the work complete unless the following are true:
- Timestamped route imports show the verified-walk explanation and a persisted estimate.
- Untimed route imports show the Naismith explanation and a persisted estimate.
- Route and track detail panels both show `Ascent` and `Descent`.
- Timed route exports contain point-level `<time>` tags without changing the existing route XML shell.
- Legacy routes without timing data still render and export safely.
</validation>

<done_when>
The feature is done when importing a GPX as a route produces a persisted `estimatedTime` for both timestamped and untimed sources, the route info panel explains that estimate clearly, route and track panels use the updated ascent/descent labels, route edits recompute the full profile from the updated geometry, timed route exports include deterministic point `<time>` tags in the existing route XML shape, and the new behavior is covered by unit, widget, and robot tests.
</done_when>
