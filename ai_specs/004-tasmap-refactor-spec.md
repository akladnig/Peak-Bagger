<goal>
Refactor the TasMap 50K pipeline so the app imports, persists, and renders polygon points from `p1` through `p8` instead of the legacy `tl/tr/bl/br` corner fields.

This matters because users browse Tasmap coverage on the map screen, and the shape data must match the new CSV contract without breaking search, zoom, or selection flows.
</goal>

<background>
The app is a Flutter/Riverpod/ObjectBox project.
Relevant files:
- `./assets/tasmap50k.csv`
- `./lib/models/tasmap50k.dart`
- `./lib/services/csv_importer.dart`
- `./lib/services/tasmap_repository.dart`
- `./lib/providers/tasmap_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/main.dart`
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`
- `./test/csv_importer_test.dart`
- `./test/tasmap50k_test.dart`
- `./test/tasmap_repository_test.dart`
- `./test/widget/objectbox_admin_browser_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/robot/...`

The checked-in CSV already exposes `p1..p8` columns; the code still reads `tl/tr/bl/br` and draws filled polygons from those corners.
</background>

<discovery>
Before implementing, confirm:
- The CSV importer accepts only rows with 4, 6, or 8 valid points.
- Point strings may be compact or space-separated MGRS fragments.
- Existing stored Tasmap rows are discarded and reloaded from the CSV only when the user explicitly resets/reimports.
- Robot tests can use the existing `map-interaction-region` key plus new stable keys for the reset map data tile, the Goto controls, and Tasmap overlay.
</discovery>

<user_flows>
Primary flow:
1. The user triggers Tasmap reset/reimport.
2. The Tasmap CSV is read and rows are parsed into `p1..p8` point fields.
3. Valid map rows are written to ObjectBox.
4. The map screen shows Tasmap outlines using the saved point order.
5. The user can still search for a map, select it, and zoom/focus behaves as before.

Alternative flows:
- Returning user after a schema change: the old Tasmap rows remain until the user triggers Tasmap reset.
- Space-separated point values: the importer normalizes them and stores the same logical point values.

Error flows:
- Row has 5 or 7 valid points, or otherwise fails validation: skip that row, append an `import.log` entry, surface a warning, and continue importing the rest.
- A point string is malformed: skip the row and keep the batch running.
- CSV load fails entirely: keep the app running with an empty Tasmap store.
</user_flows>

<requirements>
**Functional:**
1. Replace the legacy Tasmap geometry fields with explicit `String` fields named `p1` through `p8` on `Tasmap50k`.
2. Keep the non-geometry Tasmap metadata unchanged (`series`, `name`, `parentSeries`, `mgrs100kIds`, `eastingMin`, `eastingMax`, `northingMin`, `northingMax`, `mgrsMid`, `eastingMid`, `northingMid`).
3. Update ObjectBox schema artifacts so the stored entity matches the new `p1..p8` model.
4. Parse `assets/tasmap50k.csv` using the `p1..p8` headers and accept both compact and space-separated MGRS point strings.
5. Treat blank trailing point columns as absent points, but import only rows with exactly 4, 6, or 8 sequential valid points.
6. Use CSV order as drawing order. Do not reorder the polygon point sequence before rendering.
7. Render Tasmap shapes as outline-only polygons on the map screen with a visible border and transparent fill.
8. Keep existing map lookup and navigation behavior intact: name search, MGRS lookup, select map, zoom to map extent, and center-on-location flows must still work. Compute map bounds from all valid `p1..p8` points when zooming to extent or centering on a selected map.
9. Clear and reimport Tasmap rows from the CSV only when the user explicitly resets/reimports Tasmap data.
10. Surface Tasmap import warnings through the existing warning path and append row-level failures to the same `import.log` path used by `gpx_importer.dart`; the reset import owns those log writes.
11. Update ObjectBox admin/schema views so `Tasmap50k` shows `p1..p8` and no longer shows `tl/tr/bl/br`.

**Error Handling:**
12. A malformed point value must not abort the whole import batch.
13. A Tasmap row with the wrong number of usable points must be skipped, logged, and reported in the import warning.
14. If the CSV asset cannot be loaded during a Tasmap reset/reimport, the app must remain responsive and leave Tasmap data empty rather than crashing.

**Edge Cases:**
15. Four-point maps, six-point maps, and eight-point maps are all valid.
17. The first point is `p1`; preserve it as the first vertex in the rendered polygon.
18. Do not bridge or infer missing points between valid points.

**Validation:**
19. Add focused unit tests for point parsing, whitespace normalization, and valid-point-count filtering.
20. Add importer/repository tests that verify Tasmap rows persist `p1..p8` and that invalid rows are skipped with warnings and `import.log` entries.
21. Add widget tests for map rendering that verify the Tasmap overlay is outline-only and uses the saved point order.
</requirements>

<boundaries>
Edge cases:
- 4-point, 6-point, and 8-point polygons are supported.
- Rows with 5 or 7 usable points are invalid and must not be silently coerced.
- Space-separated MGRS values must be accepted without changing the logical point.
- Legacy `tl/tr/bl/br` values are not part of the new persisted schema.

Error scenarios:
- Invalid CSV row: log to `import.log`, surface a warning, and continue.
- Broken CSV load: keep the app responsive with an empty Tasmap store.
- Stale ObjectBox rows from the old schema: keep them until the user triggers Tasmap reset.

Limits:
- This refactor only covers Tasmap 50K import, storage, and map rendering.
- Do not change GPX, peak, or route workflows.
- Do not add a new geometry library; reuse the existing MGRS conversion approach.
</boundaries>

<implementation>
Modify these files:
- `./lib/models/tasmap50k.dart`
- `./lib/services/csv_importer.dart`
- `./lib/services/tasmap_repository.dart`
- `./lib/providers/tasmap_provider.dart`
- `./lib/screens/map_screen.dart`
- `./lib/screens/settings_screen.dart`
- `./lib/main.dart`
- `./lib/objectbox-model.json`
- `./lib/objectbox.g.dart`
- `./lib/services/objectbox_admin_repository.dart`
- `./test/csv_importer_test.dart`
- `./test/tasmap50k_test.dart`
- `./test/tasmap_repository_test.dart`
- `./test/services/objectbox_admin_repository_test.dart`
- `./test/widget/objectbox_admin_browser_test.dart`
- `./test/widget/...` for Tasmap map rendering coverage
- `./test/robot/...` for the Tasmap journey coverage

Use a minimal parser seam so CSV row validation can be unit-tested without depending on the full app bootstrap.
Keep the map overlay logic in one place, but add stable keys for the reset map data tile, the Goto controls, and the Tasmap outline layer so robot tests can target them.
Reuse the existing `import.log` convention so Tasmap warnings land in the same audit trail as other import issues.
</implementation>

<stages>
Phase 1: Schema and parsing
- Replace the model fields and regenerate ObjectBox artifacts.
- Parse `p1..p8` from the CSV and reject invalid row counts.
- Verify with unit tests before moving on.

Phase 2: Reload and render
- Make the Tasmap reset action perform a real reimport from CSV.
- Draw outline-only polygons in CSV order from the persisted points.
- Verify with widget tests before moving on.

Phase 3: Journey coverage
- Add robot coverage for opening Settings, triggering Tasmap reset, and returning to the map after refresh.
- Add widget coverage for outline-only rendering and saved point-order verification.
- Verify the journey uses stable keys and deterministic fakes.
</stages>

<illustrations>
Valid:
- `p1..p4` filled, `p5..p8` blank -> import the row and draw a 4-point outline.
- `p1..p6` filled, `p7..p8` blank -> import the row and draw a 6-point outline.
- `p1..p8` filled -> import the row and draw an 8-point outline.

Invalid:
- Five usable points -> skip the row, warn, and log it.
- A point value like `EN 20000 55000` -> parse it as one logical point, not three points.
- Reordering the points before drawing -> not allowed.
</illustrations>

<validation>
Follow TDD vertically:
- Start with the pure CSV row parsing and point-count rules.
- Add importer/repository persistence tests once the parser is green.
- Add widget tests for outline-only rendering and old-schema reload behavior.
- Add robot tests only after the screen-level seams are stable.

Required automated coverage:
- Logic/business rules: row parsing, point normalization, count validation, and warning generation.
- UI behavior: Tasmap outline rendering, selection/zoom flow, and admin/schema field listing.
- Robot journey: open Settings, trigger Tasmap reset, then return to the map and confirm Tasmap selection/refresh still works.
- Widget ownership: outline-only rendering and polygon order verification live in widget tests.

Testability seams:
- A pure parser for CSV rows and point strings.
- A reusable import-log writer/path seam.
- Stable keys for `reset-map-data-tile`, `reset-map-data-confirm`, `map-interaction-region`, the Goto control, the Goto input, and the Tasmap outline layer.
- A fake Tasmap repository/provider override for map widget and robot tests.

Run `flutter analyze` and `flutter test` at the end, and ensure the Tasmap journey test is deterministic on repeated runs.
</validation>

<done_when>
The refactor is complete when:
- `Tasmap50k` stores `p1..p8` instead of `tl/tr/bl/br`.
- The CSV importer reads the new point columns and enforces the 4/6/8-point rule.
- Tasmap data is cleared and reimported only from the user-triggered reset path.
- Map polygons render as outline-only shapes in CSV order.
- Invalid rows warn, log to `import.log`, and do not block the rest of the import.
- The updated unit, widget, and robot tests pass.
- `flutter analyze` and `flutter test` are green.
</done_when>
