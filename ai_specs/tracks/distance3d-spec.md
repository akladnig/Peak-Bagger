<goal>
Add 3D distance to the existing saved-track, saved-route, latest-walk, and route-draft summary UI so users can compare 2D and 3D distance without leaving the current screen.
This matters for map and dashboard users because `distance3d` is already calculated and stored, but the current UI only exposes part of that data.
</goal>

<background>
The app is a Flutter desktop app using Riverpod-backed map state, persisted `GpxTrack` and `Route` models, and an existing route-draft elevation sampling flow.

`distance3d` already exists on `./lib/models/gpx_track.dart`, `./lib/models/route.dart`, and `RouteElevationSummary` in `./lib/services/route_elevation_sampler.dart`. Existing summary UI currently exposes only `distance2d` in the saved track and route info panel, and the latest walk card only shows one distance string.

The requested surfaces map to these files:
- `./lib/screens/map_screen_panels.dart`
- `./lib/services/latest_walk_summary.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`

Existing focused coverage already lives near those surfaces:
- `./test/services/latest_walk_summary_test.dart`
- `./test/widget/latest_walk_card_test.dart`
- `./test/widget/map_track_info_panel_test.dart`
- `./test/widget/map_route_info_panel_test.dart`
- `./test/widget/map_screen_route_sheet_test.dart`
- `./test/robot/map/map_route_journey_test.dart`
- `./test/robot/map/map_route_robot.dart`

Do not change the underlying `distance3d` calculation pipeline, persistence schema, or unrelated dashboard/map layout outside the affected summary areas.
</background>

<user_flows>
Primary flow:
1. User opens a saved GPX track on the map.
2. The track info panel summary shows one combined `Distance (2d/3d)` metric, plus `Ascent` and the existing time metric.
3. User can scan both 2D and 3D distance without leaving the panel.

Alternative flows:
- User opens a saved route on the map: the route info panel summary shows one combined `Distance (2d/3d)` metric, plus `Ascent` and `Descent`.
- User views the dashboard latest walk card: the metadata line shows `date • 2d/3d distance • ascent`, remains left-aligned, and keeps working while paging between tracks.
- User creates a route on the map: once `RouteElevationSummary` is available, the route draft bottom sheet shows one combined `Distance (2d/3d)` value alongside ascent and descent.

Error flows:
- Route draft is still sampling elevation: keep the existing loading message and do not render a stale or guessed combined distance value.
- Route draft elevation sampling fails: keep the existing error message behavior and suppress the combined distance value until a valid summary exists.
- Latest walk track has valid geometry but sub-kilometre values: render each side of the combined `2d/3d` string using the existing formatter rules, even if that produces mixed units such as `850 m/0.9 km`.
</user_flows>

<requirements>
**Functional:**
1. Update the saved route info summary in `./lib/screens/map_screen_panels.dart` so the distance metric becomes one combined metric labeled `Distance (2d/3d)`, with the value rendered as `distance2d / distance3d` using the existing distance formatter on each side.
2. Update the saved track info summary in `./lib/screens/map_screen_panels.dart` so the distance metric becomes one combined metric labeled `Distance (2d/3d)`, with the value rendered as `distance2d / distance3d` using the existing distance formatter on each side.
3. Use the visible label text `Distance (2d/3d)` exactly as written in the saved-track summary, saved-route summary, and the route draft success state.
4. Preserve the existing summary metric count in the saved panels by replacing the old `Distance` metric rather than adding a fourth column. Track order remains `Distance (2d/3d)`, `Ascent`, `Total Time`. Route order remains `Distance (2d/3d)`, `Ascent`, `Descent`.
5. Keep saved-track and saved-route combined-distance formatting aligned with existing summary distance formatting by reusing the current `formatDistance(..., decimalPlaces: 1)` convention for each side of the `2d / 3d` value.
6. Extend `LatestWalkSummary` in `./lib/services/latest_walk_summary.dart` so it exposes the combined latest-walk distance text as `2d/3d`, where each side is formatted independently using the existing distance formatter rules.
7. Update `./lib/widgets/dashboard/latest_walk_card.dart` so the latest walk metadata becomes a left-aligned, dot-separated line in the order `date • 2d/3d distance • ascent`.
8. Keep ascent visible on the latest walk card. The new `2d/3d` distance text replaces the old single-distance slot, not the ascent value.
9. Match the latest walk metadata separator style to the existing track/route chooser subtitle style that already uses `•` separators.
10. Update the route draft summary in `./lib/widgets/map_route_bottom_sheet.dart` so its success state shows one combined metric labeled `Distance (2d/3d)` with a value rendered as `routeDraftDistanceMeters / routeDraftElevationSummary.distance3d`.
11. During route-draft loading or route-draft elevation-error states, preserve the existing 2D distance text and message priority rather than forcing a partially-combined distance value.
12. Reuse the existing `Key('route-distance-text')` selector for the route-draft combined-distance value if possible, so current route robot and widget harnesses can evolve with minimal churn.
13. Keep this slice limited to summary presentation. Do not change how `distance3d` is calculated, persisted, imported, or backfilled.

**Error Handling:**
14. Saved-track and saved-route summaries must render their stored `distance3d` values through the normal formatter path even when the value is `0`; do not hide the combined metric for saved entities just because the 3D side is zero.
15. Route draft combined distance must render only when a valid `routeDraftElevationSummary` exists and no higher-priority loading or elevation-error message is currently active.
16. Existing route draft loading, retry, and elevation-error messaging must remain unchanged in behavior and priority.
17. Latest walk empty-state behavior must remain unchanged: if the chosen track has no usable geometry, the card still resolves to the existing empty state instead of partially rendering metadata.

**Edge Cases:**
18. Combined latest-walk distance text must format each side independently, so mixed-unit outputs like `850 m/0.9 km` are valid and expected.
19. If 2D and 3D distance are numerically equal after formatting, still show both values; do not collapse to one number.
20. Long latest-walk metadata must truncate gracefully within the card instead of wrapping into a broken multi-column layout.
21. Saved track, saved route, and route draft combined-distance values must remain readable within the existing summary layouts without introducing new overflow.
22. Route draft success state must continue to render correctly while ascent and descent are present together with the new combined-distance metric.

**Validation:**
23. Add or update focused automated coverage for the saved-track summary, saved-route summary, latest-walk summary formatting, latest-walk card layout, and route-draft summary states.
24. Keep the test split explicit: service or unit tests for pure summary formatting, widget tests for saved track/route panel rendering and latest-walk layout, and robot-driven widget journey coverage for the route-draft happy path that now surfaces the combined distance output.
25. Any new selectors added for this slice must be key-first and app-owned, but do not require a new latest-walk metadata key unless implementation proves text-based widget assertions are too brittle.
</requirements>

<boundaries>
Edge cases:
- This slice is about showing existing and already-sampled 3D distance, not recomputing it on the fly.
- The latest walk card changes its metadata layout, but it does not need a broader dashboard redesign.
- The route draft bottom sheet may change its success-state distance presentation, but it must keep the existing loading, retry, and elevation-chart behavior.

Error scenarios:
- No `routeDraftElevationSummary`: keep the current 2D distance and preserve current loading or error text.
- Stored saved-track or saved-route `distance3d == 0`: still render the combined value with a `0 m` 3D side through the normal formatter.
- Tight summary widths: keep the existing summary layout and make the combined distance string truncate cleanly rather than redesigning the panel.

Limits:
- Do not modify `./lib/models/gpx_track.dart`, `./lib/models/route.dart`, or ObjectBox schema as part of this slice.
- Do not change route-draft elevation sampling rules, request timing, or persistence.
- Do not change latest-walk track selection logic or mini-map behavior outside what is required for the metadata row.
- Do not broaden this into a generic map-panel typography or spacing refactor.
</boundaries>

<implementation>
Modify these files:
- `./lib/screens/map_screen_panels.dart`
- `./lib/services/latest_walk_summary.dart`
- `./lib/widgets/dashboard/latest_walk_card.dart`
- `./lib/widgets/map_route_bottom_sheet.dart`

Update the saved-track and saved-route summary block in `MapTrackInfoPanel` with the smallest possible layout change. Prefer replacing the current `Distance` value with a combined `Distance (2d/3d)` value so the summary stays at three metrics instead of expanding to four.

For the latest walk card, keep the current selection, paging, and mini-map behavior intact. Prefer extending `LatestWalkSummary` with one additional presentation field for the combined `2d/3d` text rather than introducing a new state layer.

For the route draft bottom sheet, keep the current loading and error-state structure. In the success branch where `routeDraftElevationSummary` already exists, change the distance presentation to one combined `Distance (2d/3d)` metric and reuse `route-distance-text` as the value anchor if that stays practical. Do not duplicate route-draft summary logic in a second source of truth.

If any summary layout logic becomes non-trivial, extract only a tiny pure helper or presentation seam near the affected widget so it can be tested directly. Avoid new services, providers, or persistence code.

Prefer updating the existing focused test files before creating new ones unless a new pure formatter helper clearly deserves its own test file.

If implementation work for this slice is committed, include both `./ai_specs/tracks/distance3d.md` and `./ai_specs/tracks/distance3d-spec.md` in the relevant commit set for traceability.
</implementation>

<stages>
Phase 1: Summary formatting seam
- Add the latest-walk combined `2d/3d` summary field or equivalent pure presentation seam.
- Verify the first failing test covers the intended combined-distance behavior before widget edits begin.

Phase 2: Saved panel and dashboard UI
- Replace saved track and route `Distance` with the combined `Distance (2d/3d)` metric.
- Restructure the latest-walk metadata row into the requested left-aligned dot-separated line.
- Verify no layout regressions in the focused widget tests.

Phase 3: Route draft UI and journey coverage
- Replace the route-draft success-state distance text with the combined `Distance (2d/3d)` metric behind the existing elevation-summary availability seam.
- Verify loading, success, and error states with focused widget coverage.
- Extend the existing route journey robot coverage so the happy path asserts the new combined-distance output.
</stages>

<validation>
Use vertical-slice TDD. Add one failing test at a time, implement the smallest change that makes it pass, then refactor only after green.

Preferred behavior-first slice order:
1. `LatestWalkSummary` produces the new combined `2d/3d` distance text.
2. Latest walk card renders `date • 2d/3d distance • ascent` in a left-aligned metadata line.
3. Saved track and saved route panels show `Distance (2d/3d)` with the correct combined formatting.
4. Route draft bottom sheet shows the combined distance value only when a valid elevation summary exists.
5. Existing route draft loading and error states continue to suppress the combined value correctly.

Testability seams:
- Keep `LatestWalkSummary` as the primary pure presentation seam for latest-walk text.
- Reuse existing injected route-elevation fakes in `./test/widget/map_screen_route_sheet_test.dart` and robot harnesses instead of adding new mocks.
- Prefer widget assertions against app-owned `Key` selectors for route-draft metrics and any restructured latest-walk metadata row.

Required automated coverage outcome:
- `service` or `unit`: `./test/services/latest_walk_summary_test.dart` covers combined `2d/3d` formatting rules, including a sub-kilometre mixed-unit case.
- `widget`: `./test/widget/latest_walk_card_test.dart` covers the new latest-walk metadata line and retained ascent text.
- `widget`: `./test/widget/map_track_info_panel_test.dart` and `./test/widget/map_route_info_panel_test.dart` cover the new `Distance (2d/3d)` metric in saved track and route summaries.
- `widget`: `./test/widget/map_screen_route_sheet_test.dart` covers route-draft success, loading, and error states for the new combined-distance metric.
- `robot`: extend `./test/robot/map/map_route_journey_test.dart` and `./test/robot/map/map_route_robot.dart` so the route-draft happy path asserts the combined-distance output through the route distance selector after elevation sampling succeeds.

Prefer fakes over mocks. Only external boundaries such as route planning and elevation sampling should remain mocked or faked through the existing harnesses.
</validation>

<done_when>
1. Saved track info shows `Distance (2d/3d)` with correctly formatted 2D and 3D values.
2. Saved route info shows `Distance (2d/3d)` with correctly formatted 2D and 3D values.
3. Latest walk metadata is left-aligned, dot-separated, and reads as `date • 2d/3d distance • ascent`.
4. Route draft bottom sheet shows the combined distance when elevation sampling succeeds, and does not show a combined value during loading or error-only states.
5. No underlying distance-calculation or persistence behavior changed.
6. Focused service, widget, and route-journey robot coverage was updated and passes for this slice.
</done_when>
